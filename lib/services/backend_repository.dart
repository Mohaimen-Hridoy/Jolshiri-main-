import 'dart:typed_data';

import '../data/mock_data.dart';
import '../models/app_models.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Maps JSON from the Jolshiri backend (see jolshiri-backend/src/controllers)
/// onto the existing Dart model classes in models/app_models.dart, so the
/// rest of the app doesn't need to change to consume live data.
///
/// Every method here can throw [ApiException] (server reachable, request
/// rejected) or [ApiUnreachableException] (server not reachable) — callers
/// in sync_service.dart catch both and fall back to the mock seed data.
/// Result of POST /api/payments/:id/pay — see [BackendRepository.payPayment].
class PaymentInitiationResult {
  final PaymentStatus status;
  final String? checkoutUrl;

  const PaymentInitiationResult({required this.status, this.checkoutUrl});
}

class BackendRepository {
  BackendRepository._();

  // ── Auth ──────────────────────────────────────────────────────────────

  /// POST /api/auth/login — returns (token, AppUser, role, adminType)
  static Future<AuthResult> login({required String email, required String password}) async {
    final json = await ApiClient.post('/auth/login', body: {'email': email, 'password': password});
    return AuthResult._fromJson(json);
  }

  /// POST /api/auth/signup — creates the account and returns a login
  /// token right away. (Email-OTP verification used to gate this — see
  /// auth.controller.js — but that made every signup depend on a mail
  /// server that wasn't reliably reachable from the deployed backend, so
  /// the account is now verified immediately and signup logs the user in
  /// the same way [login] does.)
  static Future<AuthResult> signup(Map<String, dynamic> payload) async {
    final json = await ApiClient.post('/auth/signup', body: payload);
    return AuthResult._fromJson(json);
  }

  /// POST /api/auth/verify-signup-otp — confirms the OTP emailed at
  /// signup and returns the login token + user on success.
  static Future<AuthResult> verifySignupOtp({
    required String email,
    required String otp,
  }) async {
    final json = await ApiClient.post('/auth/verify-signup-otp', body: {
      'email': email,
      'otp': otp,
    });
    return AuthResult._fromJson(json);
  }

  /// POST /api/auth/resend-signup-otp — requests a fresh verification
  /// code. Returns the OTP string in dev mode (no Gmail configured),
  /// null in production.
  static Future<String?> resendSignupOtp(String email) async {
    final json = await ApiClient.post('/auth/resend-signup-otp', body: {'email': email});
    return json['otp'] as String?;
  }

  /// POST /api/auth/sso/google
  /// Sends the Firebase ID token to the backend, which verifies it and
  /// returns a Jolshiri JWT. [role] is only needed for first-time sign-up
  /// (backend defaults to RESIDENT_OWNER if not provided).
  static Future<AuthResult> googleSignIn({
    required String idToken,
    String? role,
  }) async {
    final body = <String, dynamic>{'idToken': idToken};
    if (role != null) body['role'] = role;
    final json = await ApiClient.post('/auth/sso/google', body: body);
    return AuthResult._fromJson(json);
  }

  // ── Rentals (To-Let) ──────────────────────────────────────────────────

  // ── Notifications ────────────────────────────────────────────────────

  /// GET /api/notifications/mine
  static Future<List<AppNotification>> fetchMyNotifications() async {
    final json = await ApiClient.get('/notifications/mine', auth: true);
    final list = (json['notifications'] as List? ?? []);
    return list.map((n) => AppNotification(
          id: n['id'],
          title: n['title'] ?? '',
          message: n['message'] ?? '',
          isRead: n['isRead'] ?? false,
        )).toList();
  }

  /// PATCH /api/notifications/:id/read
  static Future<void> markNotificationRead(String id) =>
      ApiClient.patch('/notifications/$id/read', auth: true);

  /// PATCH /api/notifications/read-all
  static Future<void> markAllNotificationsRead() =>
      ApiClient.patch('/notifications/read-all', auth: true);

  static Future<List<RentalListing>> fetchRentals() async {
    final json = await ApiClient.get('/rentals');
    final list = (json['rentals'] as List? ?? []);
    return list.map((r) => _rentalFromJson(r as Map<String, dynamic>)).toList();
  }

  static RentalListing _rentalFromJson(Map<String, dynamic> r) => RentalListing(
        id: r['id'],
        title: r['title'] ?? '',
        location: r['location'] ?? '',
        rentAmount: r['rentAmount'] ?? '',
        availability: r['availability'] ?? '',
        description: r['description'] ?? '',
        bedrooms: (r['bedrooms'] as num?)?.toInt() ?? 0,
        imageUrl: r['imageUrl'] ?? 'assets/listings/house1.jpg',
        // `ownerId` is a raw scalar on the backend record and is always
        // present; `owner.id` is only present when the controller included
        // the relation (e.g. GET /rentals). Prefer the scalar so create/
        // update responses (which don't include the relation) still carry
        // it — otherwise a listing's own Edit/Delete menu would disappear
        // right after creating or editing it, until the next refresh.
        ownerId: r['ownerId'] ?? r['owner']?['id'],
        ownerName: r['owner']?['fullName'],
      );

  /// POST /api/rentals — RESIDENT_OWNER lists a home, with an optional
  /// photo (multipart, matches the `image` field the backend's `upload`
  /// middleware expects — see rental.routes.js).
  static Future<RentalListing> createRentalListing({
    required String title,
    required String location,
    required String rentAmount,
    required String availability,
    required String description,
    required int bedrooms,
    Uint8List? imageBytes,
  }) async {
    final json = await ApiClient.postMultipart(
      '/rentals',
      auth: true,
      fields: {
        'title': title,
        'location': location,
        'rentAmount': rentAmount,
        'availability': availability,
        'description': description,
        'bedrooms': '$bedrooms',
      },
      fileBytes: imageBytes,
      fileField: 'image',
      fileName: 'rental.jpg',
    );
    return _rentalFromJson(json['rental'] as Map<String, dynamic>);
  }

  /// PATCH /api/rentals/:id — listing owner (or admin) edits their listing.
  /// A new photo is optional; if omitted the existing imageUrl is kept.
  static Future<RentalListing> updateRentalListing({
    required String id,
    required String title,
    required String location,
    required String rentAmount,
    required String availability,
    required String description,
    required int bedrooms,
    Uint8List? imageBytes,
  }) async {
    final json = await ApiClient.patchMultipart(
      '/rentals/$id',
      auth: true,
      fields: {
        'title': title,
        'location': location,
        'rentAmount': rentAmount,
        'availability': availability,
        'description': description,
        'bedrooms': '$bedrooms',
      },
      fileBytes: imageBytes,
      fileField: 'image',
      fileName: 'rental.jpg',
    );
    return _rentalFromJson(json['rental'] as Map<String, dynamic>);
  }

  /// DELETE /api/rentals/:id — listing owner (or admin) removes their listing.
  static Future<void> deleteRentalListing(String id) =>
      ApiClient.delete('/rentals/$id', auth: true);

  /// POST /api/rentals/:id/viewing-requests
  static Future<RentalViewingRequest> requestViewing({
    required RentalListing listing,
    required String requesterName,
    required String requesterPhone,
    String note = '',
  }) async {
    final json = await ApiClient.post('/rentals/${listing.id}/viewing-requests', auth: true, body: {
      'requesterName': requesterName,
      'requesterPhone': requesterPhone,
      'note': note,
    });
    final req = json['request'] as Map<String, dynamic>;
    return RentalViewingRequest(
      id: req['id'],
      listingId: listing.id,
      listingTitle: listing.title,
      listingLocation: listing.location,
      listingImageUrl: listing.imageUrl,
      requesterName: req['requesterName'] ?? requesterName,
      requesterPhone: req['requesterPhone'] ?? requesterPhone,
      requesterId: req['requesterId'] ?? AuthSession.userId,
      ownerId: listing.ownerId,
      ownerName: listing.ownerName,
      note: req['note'] ?? note,
      requestedAt: DateTime.tryParse(req['requestedAt'] ?? '') ?? DateTime.now(),
      status: requestStatusFromBackend(req['status']),
    );
  }

  /// GET /api/viewing-requests — JOLSHIRI_MANAGEMENT admin, every viewing
  /// request across every listing (Property Office overview tab).
  static Future<List<RentalViewingRequest>> fetchAllViewingRequests() async {
    final json = await ApiClient.get('/viewing-requests', auth: true);
    final list = (json['requests'] as List? ?? []);
    return list.map((req) {
      final listing = req['listing'] as Map<String, dynamic>?;
      return RentalViewingRequest(
        id: req['id'],
        listingId: listing?['id'],
        listingTitle: listing?['title'] ?? '',
        listingLocation: listing?['location'] ?? '',
        listingImageUrl: listing?['imageUrl'],
        requesterName: req['requesterName'] ?? '',
        requesterPhone: req['requesterPhone'] ?? '',
        requesterId: req['requesterId'],
        ownerId: listing?['ownerId'],
        note: req['note'] ?? '',
        requestedAt: DateTime.tryParse(req['requestedAt'] ?? '') ?? DateTime.now(),
        status: requestStatusFromBackend(req['status']),
      );
    }).toList();
  }

  /// GET /api/viewing-requests/mine — the current user's own sent viewing
  /// requests, with the listing owner attached so the "Flat View Requests"
  /// screen can open a chat with them.
  static Future<List<RentalViewingRequest>> fetchMyViewingRequests() async {
    final json = await ApiClient.get('/viewing-requests/mine', auth: true);
    final list = (json['requests'] as List? ?? []);
    return list.map((req) {
      final listing = req['listing'] as Map<String, dynamic>?;
      final owner = listing?['owner'] as Map<String, dynamic>?;
      return RentalViewingRequest(
        id: req['id'],
        listingId: listing?['id'],
        listingTitle: listing?['title'] ?? '',
        listingLocation: listing?['location'] ?? '',
        listingImageUrl: listing?['imageUrl'],
        requesterName: req['requesterName'] ?? '',
        requesterPhone: req['requesterPhone'] ?? '',
        requesterId: req['requesterId'] ?? AuthSession.userId,
        ownerId: owner?['id'],
        ownerName: owner?['fullName'],
        note: req['note'] ?? '',
        requestedAt: DateTime.tryParse(req['requestedAt'] ?? '') ?? DateTime.now(),
        status: requestStatusFromBackend(req['status']),
      );
    }).toList();
  }

  /// GET /api/viewing-requests/for-my-listings — the calling RESIDENT_OWNER's
  /// "Flat View Requests" inbox: requests sent for any listing they own,
  /// with the requester attached so they can approve/decline and chat.
  static Future<List<RentalViewingRequest>> fetchViewingRequestsForMyListings() async {
    final json = await ApiClient.get('/viewing-requests/for-my-listings', auth: true);
    final list = (json['requests'] as List? ?? []);
    return list.map((req) {
      final listing = req['listing'] as Map<String, dynamic>?;
      final requester = req['requester'] as Map<String, dynamic>?;
      return RentalViewingRequest(
        id: req['id'],
        listingId: listing?['id'],
        listingTitle: listing?['title'] ?? '',
        listingLocation: listing?['location'] ?? '',
        listingImageUrl: listing?['imageUrl'],
        requesterName: req['requesterName'] ?? '',
        requesterPhone: req['requesterPhone'] ?? '',
        requesterId: requester?['id'],
        ownerId: listing?['ownerId'] ?? AuthSession.userId,
        ownerName: MockData.currentUser.fullName,
        note: req['note'] ?? '',
        requestedAt: DateTime.tryParse(req['requestedAt'] ?? '') ?? DateTime.now(),
        status: requestStatusFromBackend(req['status']),
      );
    }).toList();
  }

  /// PATCH /api/viewing-requests/:id/status
  static Future<void> updateViewingRequestStatus(String id, RequestStatus status) {
    return ApiClient.patch('/viewing-requests/$id/status', auth: true, body: {
      'status': requestStatusToBackend(status),
    });
  }

  // ── Messaging (viewing-request chat) ────────────────────────────────

  /// GET /api/viewing-requests/:id/messages
  static Future<List<ChatMessage>> fetchMessageThread(String viewingRequestId) async {
    final json = await ApiClient.get('/viewing-requests/$viewingRequestId/messages', auth: true);
    final list = (json['messages'] as List? ?? []);
    return list.map((m) => ChatMessage(
          id: m['id'] ?? '',
          senderId: m['senderId'] ?? '',
          receiverId: m['receiverId'] ?? '',
          content: m['content'] ?? '',
          sentAt: DateTime.tryParse(m['sentAt'] ?? '') ?? DateTime.now(),
        )).toList();
  }

  /// POST /api/viewing-requests/:id/messages
  static Future<ChatMessage> sendMessage(String viewingRequestId, String content) async {
    final json = await ApiClient.post('/viewing-requests/$viewingRequestId/messages', auth: true, body: {
      'content': content,
    });
    final m = json['message'] as Map<String, dynamic>;
    return ChatMessage(
      id: m['id'] ?? '',
      senderId: m['senderId'] ?? '',
      receiverId: m['receiverId'] ?? '',
      content: m['content'] ?? content,
      sentAt: DateTime.tryParse(m['sentAt'] ?? '') ?? DateTime.now(),
    );
  }

  // ── Notices & Offices ────────────────────────────────────────────────

  static Future<List<Notice>> fetchNotices() async {
    final json = await ApiClient.get('/notices');
    final list = (json['notices'] as List? ?? []);
    return list.map((n) => _noticeFromJson(n as Map<String, dynamic>)).toList();
  }

  static Notice _noticeFromJson(Map<String, dynamic> n) => Notice(
        id: n['id'],
        title: n['title'] ?? '',
        description: n['description'] ?? '',
        publishDate: DateTime.tryParse(n['publishDate'] ?? '') ?? DateTime.now(),
        category: n['category'] ?? '',
      );

  /// POST /api/notices — JOLSHIRI_MANAGEMENT / SYSTEM_MODERATOR admin only.
  static Future<Notice> createNotice({
    required String title,
    required String description,
    required String category,
  }) async {
    final json = await ApiClient.post('/notices', auth: true, body: {
      'title': title,
      'description': description,
      'category': category,
    });
    return _noticeFromJson(json['notice'] as Map<String, dynamic>);
  }

  static Future<List<Office>> fetchOffices() async {
    final json = await ApiClient.get('/offices');
    final list = (json['offices'] as List? ?? []);
    return list.map((o) => Office(
          name: o['name'] ?? '',
          contact: o['contact'] ?? '',
          location: o['location'] ?? '',
        )).toList();
  }

  // ── Appointments (Authority Portal — "Book a visit") ──────────────────

  /// POST /api/appointments
  static Future<void> createAppointment({
    required String officeName,
    required DateTime preferredDate,
    required String reason,
  }) {
    return ApiClient.post('/appointments', auth: true, body: {
      'officeName': officeName,
      'preferredDate': preferredDate.toIso8601String(),
      'reason': reason,
    });
  }

  // ── Community posts ──────────────────────────────────────────────────

  static Future<List<CommunityPost>> fetchCommunityPosts() async {
    final json = await ApiClient.get('/community-posts');
    final list = (json['posts'] as List? ?? []);
    return list.map((p) => _communityPostFromJson(p as Map<String, dynamic>)).toList();
  }

  static CommunityPost _communityPostFromJson(Map<String, dynamic> p) {
    final comments = (p['comments'] as List? ?? []).map((c) => PostComment(
          author: c['author']?['fullName'] ?? 'Resident',
          text: c['text'] ?? '',
          postedAt: DateTime.tryParse(c['postedAt'] ?? '') ?? DateTime.now(),
        )).toList();
    return CommunityPost(
      id: p['id'],
      author: p['author']?['fullName'] ?? 'Resident',
      authorId: p['authorId'],
      content: p['content'] ?? '',
      category: p['category'] ?? 'Announcement',
      postedAt: DateTime.tryParse(p['postedAt'] ?? '') ?? DateTime.now(),
      price: p['price'],
      imageUrl: p['imageUrl'],
      comments: comments,
    );
  }

  // ── Developer & Service Provider directory ──────────────────────────

  static Future<List<Developer>> fetchDevelopers() async {
    final json = await ApiClient.get('/developers');
    final list = (json['developers'] as List? ?? []);
    return list.map((d) => Developer(
          id: d['id'],
          companyName: d['companyName'] ?? '',
          contact: d['contact'] ?? '',
          rating: (d['rating'] as num?)?.toDouble() ?? 0,
          specialty: d['specialty'] ?? '',
          verified: d['verified'] ?? false,
        )).toList();
  }

  static Future<List<ServiceProvider>> fetchServiceProviders() async {
    final json = await ApiClient.get('/providers');
    final list = (json['providers'] as List? ?? []);
    return list.map((s) => ServiceProvider(
          id: s['id'],
          name: s['name'] ?? '',
          serviceType: s['serviceType'] ?? '',
          phone: s['phone'] ?? '',
          rating: (s['rating'] as num?)?.toDouble() ?? 0,
          reviews: (s['reviews'] as num?)?.toInt() ?? 0,
          verified: s['verified'] ?? false,
        )).toList();
  }

  /// GET /api/providers/me — the logged-in SERVICE_PROVIDER's own profile.
  static Future<ServiceProvider> fetchMyProviderProfile() async {
    final json = await ApiClient.get('/providers/me', auth: true);
    final s = json['provider'] as Map<String, dynamic>;
    return ServiceProvider(
      id: s['id'],
      name: s['name'] ?? '',
      serviceType: s['serviceType'] ?? '',
      phone: s['phone'] ?? '',
      rating: (s['rating'] as num?)?.toDouble() ?? 0,
      reviews: (s['reviews'] as num?)?.toInt() ?? 0,
      verified: s['verified'] ?? false,
    );
  }

  /// PATCH /api/providers/me — the logged-in SERVICE_PROVIDER edits their
  /// own name / serviceType / phone (the ServiceProvider directory record,
  /// separate from the account's User profile).
  static Future<ServiceProvider> updateMyProviderProfile({
    String? name,
    String? serviceType,
    String? phone,
  }) async {
    final json = await ApiClient.patch('/providers/me', auth: true, body: {
      if (name != null) 'name': name,
      if (serviceType != null) 'serviceType': serviceType,
      if (phone != null) 'phone': phone,
    });
    final s = json['provider'] as Map<String, dynamic>;
    return ServiceProvider(
      id: s['id'],
      name: s['name'] ?? '',
      serviceType: s['serviceType'] ?? '',
      phone: s['phone'] ?? '',
      rating: (s['rating'] as num?)?.toDouble() ?? 0,
      reviews: (s['reviews'] as num?)?.toInt() ?? 0,
      verified: s['verified'] ?? false,
    );
  }

  /// GET /api/developers/me — the logged-in DEVELOPER's own profile.
  static Future<Developer> fetchMyDeveloperProfile() async {
    final json = await ApiClient.get('/developers/me', auth: true);
    final d = json['developer'] as Map<String, dynamic>;
    return Developer(
      id: d['id'],
      companyName: d['companyName'] ?? '',
      contact: d['contact'] ?? '',
      rating: (d['rating'] as num?)?.toDouble() ?? 0,
      specialty: d['specialty'] ?? '',
      verified: d['verified'] ?? false,
    );
  }

  /// PATCH /api/developers/me — the logged-in DEVELOPER edits their own
  /// companyName / contact / specialty.
  static Future<Developer> updateMyDeveloperProfile({
    String? companyName,
    String? contact,
    String? specialty,
  }) async {
    final json = await ApiClient.patch('/developers/me', auth: true, body: {
      if (companyName != null) 'companyName': companyName,
      if (contact != null) 'contact': contact,
      if (specialty != null) 'specialty': specialty,
    });
    final d = json['developer'] as Map<String, dynamic>;
    return Developer(
      id: d['id'],
      companyName: d['companyName'] ?? '',
      contact: d['contact'] ?? '',
      rating: (d['rating'] as num?)?.toDouble() ?? 0,
      specialty: d['specialty'] ?? '',
      verified: d['verified'] ?? false,
    );
  }

  // ── Provider Reviews ──────────────────────────────────────────────────

  /// GET /api/providers/:id/reviews
  static Future<List<ServiceReview>> fetchProviderReviews(ServiceProvider provider) async {
    final json = await ApiClient.get('/providers/${provider.id}/reviews');
    final list = (json['reviews'] as List? ?? []);
    return list.map((r) => ServiceReview(
          providerName: provider.name,
          serviceType: provider.serviceType,
          residentName: r['resident']?['fullName'] ?? 'Resident',
          rating: (r['rating'] as num?)?.toInt() ?? 0,
          comment: r['comment'] ?? '',
          reviewedAt: DateTime.tryParse(r['reviewedAt'] ?? '') ?? DateTime.now(),
        )).toList();
  }

  /// POST /api/providers/:id/reviews — RESIDENT_OWNER only.
  static Future<ServiceReview> addProviderReview({
    required ServiceProvider provider,
    required int rating,
    String comment = '',
  }) async {
    final json = await ApiClient.post('/providers/${provider.id}/reviews', auth: true, body: {
      'rating': rating,
      'comment': comment,
    });
    final r = json['review'] as Map<String, dynamic>;
    return ServiceReview(
      providerName: provider.name,
      serviceType: provider.serviceType,
      residentName: r['resident']?['fullName'] ?? 'You',
      rating: (r['rating'] as num?)?.toInt() ?? rating,
      comment: r['comment'] ?? comment,
      reviewedAt: DateTime.tryParse(r['reviewedAt'] ?? '') ?? DateTime.now(),
    );
  }

  // ── Service Bookings (resident -> provider) ────────────────────────────

  /// POST /api/bookings
  static Future<void> createBooking({
    required String providerId,
    required String serviceType,
    required String address,
    String note = '',
  }) {
    return ApiClient.post('/bookings', auth: true, body: {
      'providerId': providerId,
      'serviceType': serviceType,
      'address': address,
      'note': note,
    });
  }

  /// GET /api/bookings/provider — incoming bookings for the signed-in
  /// SERVICE_PROVIDER account.
  static Future<List<ServiceBooking>> fetchProviderBookings() async {
    final json = await ApiClient.get('/bookings/provider', auth: true);
    final list = (json['bookings'] as List? ?? []);
    return list.map((b) => ServiceBooking(
          id: b['id'],
          customerName: b['customer']?['fullName'] ?? 'Resident',
          providerName: '',
          serviceType: b['serviceType'] ?? '',
          address: b['address'] ?? '',
          note: b['note'] ?? '',
          requestedAt: DateTime.tryParse(b['requestedAt'] ?? '') ?? DateTime.now(),
          status: requestStatusFromBackend(b['status']),
        )).toList();
  }

  /// PATCH /api/bookings/:id/status — provider accepts/declines/completes.
  static Future<void> updateBookingStatus(String id, RequestStatus status) {
    return ApiClient.patch('/bookings/$id/status', auth: true, body: {
      'status': requestStatusToBackend(status),
    });
  }

  // ── Quote Requests (resident -> developer) ─────────────────────────────

  /// POST /api/quotes
  static Future<QuoteRequest> createQuote({
    required String developerId,
    required String projectType,
    required String plotLocation,
    required String budget,
    String note = '',
  }) async {
    final json = await ApiClient.post('/quotes', auth: true, body: {
      'developerId': developerId,
      'projectType': projectType,
      'plotLocation': plotLocation,
      'budget': budget,
      'note': note,
    });
    final q = json['quote'] as Map<String, dynamic>;
    return QuoteRequest(
      id: q['id'],
      customerName: '',
      projectType: q['projectType'] ?? projectType,
      plotLocation: q['plotLocation'] ?? plotLocation,
      budget: q['budget'] ?? budget,
      note: q['note'] ?? note,
      requestedAt: DateTime.tryParse(q['requestedAt'] ?? '') ?? DateTime.now(),
      status: requestStatusFromBackend(q['status']),
    );
  }

  /// GET /api/quotes/mine — resident's own quote requests.
  static Future<List<QuoteRequest>> fetchMyQuotes() async {
    final json = await ApiClient.get('/quotes/mine', auth: true);
    final list = (json['quotes'] as List? ?? []);
    return list.map((q) => QuoteRequest(
          id: q['id'],
          customerName: '',
          projectType: q['projectType'] ?? '',
          plotLocation: q['plotLocation'] ?? '',
          budget: q['budget'] ?? '',
          note: q['note'] ?? '',
          requestedAt: DateTime.tryParse(q['requestedAt'] ?? '') ?? DateTime.now(),
          status: requestStatusFromBackend(q['status']),
        )).toList();
  }

  /// GET /api/quotes/developer — incoming quote requests for the signed-in
  /// DEVELOPER account.
  static Future<List<QuoteRequest>> fetchDeveloperQuotes() async {
    final json = await ApiClient.get('/quotes/developer', auth: true);
    final list = (json['quotes'] as List? ?? []);
    return list.map((q) => QuoteRequest(
          id: q['id'],
          customerName: q['customer']?['fullName'] ?? 'Resident',
          projectType: q['projectType'] ?? '',
          plotLocation: q['plotLocation'] ?? '',
          budget: q['budget'] ?? '',
          note: q['note'] ?? '',
          requestedAt: DateTime.tryParse(q['requestedAt'] ?? '') ?? DateTime.now(),
          status: requestStatusFromBackend(q['status']),
        )).toList();
  }

  /// PATCH /api/quotes/:id/status — developer accepts/declines/completes.
  static Future<void> updateQuoteStatus(String id, RequestStatus status) {
    return ApiClient.patch('/quotes/$id/status', auth: true, body: {
      'status': requestStatusToBackend(status),
    });
  }

  // ── Developer Meetings ──────────────────────────────────────────────────

  /// POST /api/meetings
  static Future<DeveloperMeeting> createMeeting({
    required String developerId,
    required String developerName,
    required String subject,
    required String plotReference,
    required MeetingType meetingType,
    MeetingPlatform? platform,
    String? location,
    required DateTime scheduledFor,
    String note = '',
  }) async {
    final json = await ApiClient.post('/meetings', auth: true, body: {
      'developerId': developerId,
      'subject': subject,
      'plotReference': plotReference,
      'mode': meetingType == MeetingType.online ? 'ONLINE' : 'OFFLINE',
      if (meetingType == MeetingType.online)
        'platform': platform == MeetingPlatform.zoom ? 'ZOOM' : 'GOOGLE_MEET',
      if (meetingType == MeetingType.offline) 'location': location ?? '',
      'scheduledFor': scheduledFor.toIso8601String(),
      'note': note,
    });
    final m = json['meeting'] as Map<String, dynamic>;
    return DeveloperMeeting(
      id: m['id'],
      developerName: developerName,
      residentName: '',
      subject: m['subject'] ?? subject,
      plotReference: m['plotReference'] ?? plotReference,
      meetingType: m['mode'] == 'OFFLINE' ? MeetingType.offline : MeetingType.online,
      platform: m['platform'] == 'ZOOM'
          ? MeetingPlatform.zoom
          : (m['platform'] == 'GOOGLE_MEET' ? MeetingPlatform.googleMeet : null),
      meetingLink: m['meetingLink'] ?? '',
      venue: m['location'] ?? '',
      scheduledFor: DateTime.tryParse(m['scheduledFor'] ?? '') ?? scheduledFor,
      note: m['note'] ?? note,
      status: meetingStatusFromBackend(m['status']),
    );
  }

  /// GET /api/meetings/mine — resident's own scheduled meetings.
  static Future<List<DeveloperMeeting>> fetchMyMeetings() async {
    final json = await ApiClient.get('/meetings/mine', auth: true);
    final list = (json['meetings'] as List? ?? []);
    return list.map((m) => DeveloperMeeting(
          id: m['id'],
          developerName: m['developer']?['companyName'] ?? '',
          // Was AuthSession.userId (a raw id, e.g. a cuid) — the resident
          // Meetings screen filters this list by
          // `residentName == MockData.currentUser.fullName`, so an id here
          // meant every meeting fetched from the backend silently failed
          // that filter and never showed up in "My meetings" after
          // login/refresh. This endpoint is already scoped to the calling
          // resident server-side (see listMyMeetings), so it's safe to use
          // the signed-in user's display name here to match that filter.
          residentName: MockData.currentUser.fullName,
          subject: m['subject'] ?? '',
          plotReference: m['plotReference'] ?? '',
          meetingType: m['mode'] == 'OFFLINE' ? MeetingType.offline : MeetingType.online,
          platform: m['platform'] == 'ZOOM'
              ? MeetingPlatform.zoom
              : (m['platform'] == 'GOOGLE_MEET' ? MeetingPlatform.googleMeet : null),
          meetingLink: m['meetingLink'] ?? '',
          venue: m['location'] ?? '',
          scheduledFor: DateTime.tryParse(m['scheduledFor'] ?? '') ?? DateTime.now(),
          note: m['note'] ?? '',
          status: meetingStatusFromBackend(m['status']),
        )).toList();
  }

  /// GET /api/meetings/developer — incoming meetings for the signed-in
  /// DEVELOPER account.
  static Future<List<DeveloperMeeting>> fetchDeveloperMeetings() async {
    final json = await ApiClient.get('/meetings/developer', auth: true);
    final list = (json['meetings'] as List? ?? []);
    return list.map((m) => DeveloperMeeting(
          id: m['id'],
          developerName: '',
          residentName: m['resident']?['fullName'] ?? 'Resident',
          subject: m['subject'] ?? '',
          plotReference: m['plotReference'] ?? '',
          meetingType: m['mode'] == 'OFFLINE' ? MeetingType.offline : MeetingType.online,
          platform: m['platform'] == 'ZOOM'
              ? MeetingPlatform.zoom
              : (m['platform'] == 'GOOGLE_MEET' ? MeetingPlatform.googleMeet : null),
          meetingLink: m['meetingLink'] ?? '',
          venue: m['location'] ?? '',
          scheduledFor: DateTime.tryParse(m['scheduledFor'] ?? '') ?? DateTime.now(),
          note: m['note'] ?? '',
          status: meetingStatusFromBackend(m['status']),
        )).toList();
  }

  /// PATCH /api/meetings/:id/status — developer confirms/cancels/completes.
  /// [meetingLink] is the developer's own Zoom/Google Meet link, pasted in
  /// when confirming an ONLINE meeting — required by the backend the first
  /// time an ONLINE meeting is confirmed (see meeting.controller.js).
  static Future<void> updateMeetingStatus(String id, MeetingStatus status, {String? meetingLink}) {
    return ApiClient.patch('/meetings/$id/status', auth: true, body: {
      'status': meetingStatusToBackend(status),
      if (meetingLink != null && meetingLink.isNotEmpty) 'meetingLink': meetingLink,
    });
  }

  // ── Construction Projects & Stages (Build Track) ────────────────────────

  /// GET /api/construction/projects/mine — role-scoped server-side:
  /// resident sees their own project(s), developer sees the ones they run,
  /// admin sees every project. Used for the Build Track tab and the
  /// Jolshiri Management "active projects" overview alike.
  static Future<List<ConstructionProject>> fetchConstructionProjects() async {
    final json = await ApiClient.get('/construction/projects/mine', auth: true);
    final list = (json['projects'] as List? ?? []);
    return list.map((p) {
      final stages = (p['stages'] as List? ?? []).map((s) => ConstructionStage(
            id: s['id'],
            title: s['title'] ?? '',
            description: s['description'] ?? '',
            // Backend stores progress as 0–100 (see construction.controller.js
            // reviewStage's `stage.progress >= 100` check); the Flutter side
            // uses 0.0–1.0 for LinearProgressIndicator and multiplies by 100
            // for the percentage label (construction_lifecycle_screen.dart).
            // Without dividing here, a fetched stage's progress bar was
            // pinned to 100% and the label showed e.g. "4500%" instead of
            // "45%" as soon as this screen refreshed from the backend.
            progress: ((s['progress'] as num?)?.toDouble() ?? 0) / 100,
            status: constructionStageStatusFromBackend(s['status']),
            eta: s['eta'] ?? '',
            developerNote: s['developerNote'] ?? '',
          )).toList();
      return ConstructionProject(
        id: p['id'],
        projectName: p['projectName'] ?? '',
        plotReference: p['plotReference'] ?? '',
        developerName: p['developer']?['companyName'] ?? '',
        estimatedCompletion: p['estimatedCompletion'] ?? '',
        stages: stages,
        permitStatus: constructionPermitStatusFromBackend(p['permitStatus']),
      );
    }).toList();
  }

  /// PATCH /api/construction/projects/:id/permit — JOLSHIRI_MANAGEMENT admin.
  static Future<void> updatePermitStatus(String projectId, ConstructionPermitStatus status) {
    return ApiClient.patch('/construction/projects/$projectId/permit', auth: true, body: {
      'status': constructionPermitStatusToBackend(status),
    });
  }

  /// PATCH /api/construction/stages/:id/review — JOLSHIRI_MANAGEMENT admin
  /// approves or sends a stage back with a note.
  static Future<void> reviewConstructionStage(String stageId, {required bool approve, String? note}) {
    return ApiClient.patch('/construction/stages/$stageId/review', auth: true, body: {
      'approve': approve,
      if (note != null) 'note': note,
    });
  }

  // ── Soil Test Applications (Build Track permits) ────────────────────────

  /// POST /api/construction/soil-tests
  static Future<SoilTestApplication> createSoilTest({
    required String plotReference,
    required String projectName,
  }) async {
    final json = await ApiClient.post('/construction/soil-tests', auth: true, body: {
      'plotReference': plotReference,
      'projectName': projectName,
    });
    final a = json['application'] as Map<String, dynamic>;
    return SoilTestApplication(
      id: a['id'],
      applicantName: '',
      plotReference: a['plotReference'] ?? plotReference,
      projectName: a['projectName'] ?? projectName,
      appliedAt: DateTime.tryParse(a['appliedAt'] ?? '') ?? DateTime.now(),
      status: soilTestStatusFromBackend(a['status']),
      note: a['note'] ?? '',
      paymentId: a['paymentId'] as String?,
    );
  }

  /// GET /api/construction/soil-tests/mine
  static Future<List<SoilTestApplication>> fetchMySoilTests() async {
    final json = await ApiClient.get('/construction/soil-tests/mine', auth: true);
    final list = (json['applications'] as List? ?? []);
    return list.map((a) => SoilTestApplication(
          id: a['id'],
          // Was always '' — this endpoint is scoped to the signed-in
          // resident's own applications (see listMySoilTests), so after
          // any sync/refresh the "Applied by" line on the Build Track
          // permits card went blank instead of showing the resident's
          // name. Use the signed-in user's name, same as the local
          // insert done right after a successful submission.
          applicantName: MockData.currentUser.fullName,
          plotReference: a['plotReference'] ?? '',
          projectName: a['projectName'] ?? '',
          appliedAt: DateTime.tryParse(a['appliedAt'] ?? '') ?? DateTime.now(),
          status: soilTestStatusFromBackend(a['status']),
          note: a['note'] ?? '',
          paymentId: a['paymentId'] as String?,
        )).toList();
  }

  /// GET /api/construction/soil-tests — JOLSHIRI_MANAGEMENT admin, every application.
  static Future<List<SoilTestApplication>> fetchAllSoilTests() async {
    final json = await ApiClient.get('/construction/soil-tests', auth: true);
    final list = (json['applications'] as List? ?? []);
    return list.map((a) => SoilTestApplication(
          id: a['id'],
          applicantName: a['applicant']?['fullName'] ?? '',
          plotReference: a['plotReference'] ?? '',
          projectName: a['projectName'] ?? '',
          appliedAt: DateTime.tryParse(a['appliedAt'] ?? '') ?? DateTime.now(),
          status: soilTestStatusFromBackend(a['status']),
          note: a['note'] ?? '',
          paymentId: a['paymentId'] as String?,
        )).toList();
  }

  /// PATCH /api/construction/soil-tests/:id/status — JOLSHIRI_MANAGEMENT
  /// admin schedules / completes / rejects a soil test application.
  static Future<void> updateSoilTestStatus(String id, SoilTestStatus status, {String? note}) {
    return ApiClient.patch('/construction/soil-tests/$id/status', auth: true, body: {
      'status': soilTestStatusToBackend(status),
      if (note != null) 'note': note,
    });
  }

  // ── Payments ─────────────────────────────────────────────────────────

  /// GET /api/payments/mine
  static Future<List<PaymentRecord>> fetchMyPayments() async {
    final json = await ApiClient.get('/payments/mine', auth: true);
    final list = (json['payments'] as List? ?? []);
    return list.map((p) => PaymentRecord(
          id: p['id'],
          title: p['title'] ?? '',
          description: p['description'] ?? '',
          purpose: paymentPurposeFromBackend(p['purpose']),
          amount: p['amount'] ?? '',
          createdAt: DateTime.tryParse(p['createdAt'] ?? '') ?? DateTime.now(),
          reference: p['reference'] ?? '',
          status: paymentStatusFromBackend(p['status']),
        )).toList();
  }

  /// POST /api/payments/:id/pay. If Stripe is configured on the
  /// backend, this returns a `checkoutUrl` that must be opened (browser/
  /// webview) for the resident to actually pay — status stays PROCESSING
  /// until the gateway calls back. If no gateway is configured, the backend
  /// settles the demo payment as PAID immediately and checkoutUrl is null.
  static Future<PaymentInitiationResult> payPayment(String id) async {
    final json = await ApiClient.post('/payments/$id/pay', auth: true);
    final p = json['payment'] as Map<String, dynamic>;
    return PaymentInitiationResult(
      status: paymentStatusFromBackend(p['status']),
      checkoutUrl: json['checkoutUrl'] as String?,
    );
  }

  // ── Complaint Register ───────────────────────────────────────────────────

  /// POST /api/complaints — resident files a complaint against
  /// title/category/description/plotReference, with an optional photo.
  static Future<Complaint> createComplaint({
    required String title,
    required String category,
    required String description,
    required String plotReference,
    Uint8List? imageBytes,
  }) async {
    final json = await ApiClient.postMultipart(
      '/complaints',
      auth: true,
      fields: {
        'title': title,
        'category': category,
        'description': description,
        'plotReference': plotReference,
      },
      fileBytes: imageBytes,
      fileField: 'image',
      fileName: 'complaint.jpg',
    );
    return _complaintFromJson(json['complaint'] as Map<String, dynamic>);
  }

  /// GET /api/complaints/mine
  static Future<List<Complaint>> fetchMyComplaints() async {
    final json = await ApiClient.get('/complaints/mine', auth: true);
    final list = (json['complaints'] as List? ?? []);
    return list.map((c) => _complaintFromJson(c as Map<String, dynamic>)).toList();
  }

  /// GET /api/complaints — JOLSHIRI_MANAGEMENT admin, every complaint.
  static Future<List<Complaint>> fetchAllComplaints() async {
    final json = await ApiClient.get('/complaints', auth: true);
    final list = (json['complaints'] as List? ?? []);
    return list.map((c) => _complaintFromJson(c as Map<String, dynamic>)).toList();
  }

  /// GET /api/complaints/:id/updates — full timeline for one complaint.
  static Future<List<ComplaintUpdate>> fetchComplaintUpdates(String id) async {
    final json = await ApiClient.get('/complaints/$id/updates', auth: true);
    final list = (json['updates'] as List? ?? []);
    return list.map((u) => ComplaintUpdate(
          id: u['id'] ?? '',
          note: u['note'] ?? '',
          status: complaintStatusFromBackend(u['status']),
          updatedAt: DateTime.tryParse(u['updatedAt'] ?? '') ?? DateTime.now(),
          authorName: u['author']?['fullName'] ?? '',
        )).toList();
  }

  /// POST /api/complaints/:id/updates — JOLSHIRI_MANAGEMENT admin appends a
  /// timeline entry and updates status/progress in one step.
  static Future<void> addComplaintUpdate(
    String id, {
    required String note,
    required ComplaintStatus status,
    double? progress,
  }) {
    return ApiClient.post('/complaints/$id/updates', auth: true, body: {
      'note': note,
      'status': complaintStatusToBackend(status),
      if (progress != null) 'progress': progress,
    });
  }

  static Complaint _complaintFromJson(Map<String, dynamic> c) => Complaint(
        id: c['id'],
        title: c['title'] ?? '',
        category: c['category'] ?? '',
        description: c['description'] ?? '',
        plotReference: c['plotReference'] ?? '',
        imageUrl: c['imageUrl'],
        createdAt: DateTime.tryParse(c['createdAt'] ?? '') ?? DateTime.now(),
        status: complaintStatusFromBackend(c['status']),
        progress: (c['progress'] as num?)?.toDouble() ?? 0,
        residentName: c['resident']?['fullName'] ?? '',
      );

  // ── Security / Incident Reports ─────────────────────────────────────────

  /// POST /api/security-reports — any authenticated resident can file one.
  /// [block]/[latitude]/[longitude] are optional location fields the
  /// backend stores and later aggregates for the security heatmap (see
  /// GET /security-reports/heatmap) — without them, a report never shows
  /// up on the heatmap.
  static Future<SecurityReport> createSecurityReport({
    required String title,
    required String description,
    String? block,
    double? latitude,
    double? longitude,
  }) async {
    // No severity is sent — the admin heatmap colour is now driven purely
    // by how many reports/SOS alerts a sector has received (see
    // fetchHeatmapClusters below), not by a per-report severity level.
    final json = await ApiClient.post('/security-reports', auth: true, body: {
      'title': title,
      'description': description,
      if (block != null) 'block': block,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    final r = json['report'] as Map<String, dynamic>;
    return SecurityReport(
      id: r['id'],
      title: r['title'] ?? title,
      description: r['description'] ?? description,
      status: r['status'] ?? 'Open',
      reportedAt: DateTime.tryParse(r['reportedAt'] ?? '') ?? DateTime.now(),
      block: r['block'] ?? block,
    );
  }

  /// POST /api/security-reports — the SOS button. This is just a security
  /// report filed with a fixed emergency title/description so it lands in
  /// the same admin queue and heatmap as a normal incident report, but is
  /// instantly recognisable and comes from a single tap instead of a form.
  static Future<SecurityReport> sendSOS({String? block, double? latitude, double? longitude}) {
    return createSecurityReport(
      title: '🚨 SOS Emergency Alert',
      description: 'Resident triggered the SOS button and needs immediate assistance.',
      block: block,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// GET /api/security-reports — JOLSHIRI_MANAGEMENT / ARMY_OVERSIGHT admins only.
  static Future<List<SecurityReport>> fetchSecurityReports() async {
    final json = await ApiClient.get('/security-reports', auth: true);
    final list = (json['reports'] as List? ?? []);
    return list.map((r) => SecurityReport(
          id: r['id'],
          title: r['title'] ?? '',
          description: r['description'] ?? '',
          status: r['status'] ?? 'Open',
          reportedAt: DateTime.tryParse(r['reportedAt'] ?? '') ?? DateTime.now(),
          block: r['block'],
        )).toList();
  }

  /// PATCH /api/security-reports/:id/status — JOLSHIRI_MANAGEMENT /
  /// ARMY_OVERSIGHT admin updates Open / In Progress / Resolved.
  static Future<void> updateSecurityReportStatus(String id, String status) {
    return ApiClient.patch('/security-reports/$id/status', auth: true, body: {
      'status': status,
    });
  }

  /// GET /api/security-reports/heatmap — ARMY_OVERSIGHT / JOLSHIRI_MANAGEMENT.
  /// Returns incidents grouped by block with counts and GPS coordinates.
  /// Falls back to an empty list on any error so the heatmap can still show
  /// the static mock clusters.
  ///
  /// The report/SOS *count* in a sector drives the map circle colour
  /// (an SOS alert counts the same as a normal report):
  ///   1-3 reports → green  (low)
  ///   4-6 reports → orange (elevated)
  ///   7+ reports  → red    (high, immediate attention)
  static Future<List<IncidentCluster>> fetchHeatmapClusters() async {
    try {
      final json = await ApiClient.get('/security-reports/heatmap', auth: true);
      final list = (json['clusters'] as List? ?? []);
      return list
          .where((c) => c['latitude'] != null && c['longitude'] != null)
          .map((c) => IncidentCluster(
                block: c['block'] as String? ?? 'Unknown',
                incidents: (c['incidents'] as num?)?.toInt() ?? 0,
                note: c['topNote'] as String? ?? '',
                severity: IncidentSeverity.fromString(c['severity'] as String?),
                latitude: (c['latitude'] as num).toDouble(),
                longitude: (c['longitude'] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Directory verification (admin) ──────────────────────────────────────

  /// PATCH /api/providers/:id/verify — JOLSHIRI_MANAGEMENT / SYSTEM_MODERATOR admin.
  static Future<void> verifyProvider(String id, bool verified) {
    return ApiClient.patch('/providers/$id/verify', auth: true, body: {
      'verified': verified,
    });
  }

  /// PATCH /api/developers/:id/verify — admin only.
  static Future<void> verifyDeveloper(String id, bool verified) {
    return ApiClient.patch('/developers/$id/verify', auth: true, body: {
      'verified': verified,
    });
  }

  // ── Admin: User Management ──────────────────────────────────────────────

  /// GET /api/admin/kpis — any admin type; summary counters for the KPI Dashboard.
  static Future<AdminKpis> fetchAdminKpis() async {
    final json = await ApiClient.get('/admin/kpis', auth: true);
    final k = json['kpis'] as Map<String, dynamic>? ?? {};
    final usersByRole = (k['usersByRole'] as Map?) ?? {};
    return AdminKpis(
      residentCount: (usersByRole['RESIDENT_OWNER'] as num?)?.toInt() ?? 0,
      developerCount: (k['developerCount'] as num?)?.toInt() ?? 0,
      providerCount: (k['providerCount'] as num?)?.toInt() ?? 0,
      rentalCount: (k['rentalCount'] as num?)?.toInt() ?? 0,
      activeProjects: (k['activeProjects'] as num?)?.toInt() ?? 0,
      pendingViewingRequests: (k['pendingViewingRequests'] as num?)?.toInt() ?? 0,
      stagesPendingApproval: (k['stagesPendingApproval'] as num?)?.toInt() ?? 0,
      openSecurityReports: (k['openSecurityReports'] as num?)?.toInt() ?? 0,
    );
  }

  /// GET /api/admin/users — any admin type.
  static Future<List<AdminUserSummary>> fetchAdminUsers() async {
    final json = await ApiClient.get('/admin/users', auth: true);
    final list = (json['users'] as List? ?? []);
    return list.map((u) => AdminUserSummary(
          id: u['id'] ?? '',
          fullName: u['fullName'] ?? '',
          email: u['email'] ?? '',
          role: u['role'] ?? '',
          accountStatus: u['accountStatus'] ?? 'ACTIVE',
          isEmailVerified: u['isEmailVerified'] as bool? ?? true,
        )).toList();
  }

  /// PATCH /api/admin/users/:id — suspend, unsuspend, or ban a user.
  /// [action] must be 'suspend', 'unsuspend', or 'ban'.
  static Future<void> updateAdminUserStatus(String id, String action) {
    return ApiClient.patch('/admin/users/$id', auth: true, body: {'action': action});
  }

  /// DELETE /api/admin/users/:id — SYSTEM_MODERATOR admin only.
  static Future<void> deleteAdminUser(String id) {
    return ApiClient.delete('/admin/users/$id', auth: true);
  }

  /// POST /api/admin/users/:id/reset-password — any admin type. Emails the
  /// user a password-reset OTP; returns the confirmation message from the
  /// backend (surfaced to the moderator in a snackbar).
  static Future<String> adminResetUserPassword(String id) async {
    final json = await ApiClient.post('/admin/users/$id/reset-password', auth: true);
    return (json['message'] as String?) ?? 'Password reset email sent';
  }

  /// POST /api/admin/users/:id/verify — any admin type. Manually marks a
  /// user's account as email-verified.
  static Future<String> adminVerifyUser(String id) async {
    final json = await ApiClient.post('/admin/users/$id/verify', auth: true);
    return (json['message'] as String?) ?? 'User verified';
  }

  /// POST /api/payments — ADMIN only. Issues a DUE payment record (e.g. a
  /// consultation or development-agreement fee) against a resident, who
  /// then sees and pays it from their own Payments screen.
  static Future<PaymentRecord> createAdminPayment({
    required String userId,
    required String title,
    required String description,
    required PaymentPurpose purpose,
    required String amount,
  }) async {
    final json = await ApiClient.post('/payments', auth: true, body: {
      'userId': userId,
      'title': title,
      'description': description,
      'purpose': purpose == PaymentPurpose.developmentAgreement ? 'DEVELOPMENT_AGREEMENT' : 'CONSULTATION_FEE',
      'amount': amount,
    });
    final p = json['payment'] as Map<String, dynamic>;
    return PaymentRecord(
      id: p['id'],
      title: p['title'] ?? '',
      description: p['description'] ?? '',
      purpose: paymentPurposeFromBackend(p['purpose']),
      amount: p['amount'] ?? '',
      createdAt: DateTime.tryParse(p['createdAt'] ?? '') ?? DateTime.now(),
      reference: p['reference'] ?? '',
      status: paymentStatusFromBackend(p['status']),
    );
  }

  /// GET /api/payments — ADMIN only, optionally filtered by status.
  static Future<List<PaymentRecord>> fetchAdminPayments({String? status}) async {
    final json = await ApiClient.get(
      '/payments',
      auth: true,
      query: status != null ? {'status': status} : null,
    );
    final list = (json['payments'] as List? ?? []);
    return list.map((p) => PaymentRecord(
          id: p['id'],
          title: p['title'] ?? '',
          description: p['description'] ?? '',
          purpose: paymentPurposeFromBackend(p['purpose']),
          amount: p['amount'] ?? '',
          createdAt: DateTime.tryParse(p['createdAt'] ?? '') ?? DateTime.now(),
          reference: p['reference'] ?? '',
          status: paymentStatusFromBackend(p['status']),
        )).toList();
  }

  // ── Profile ──────────────────────────────────────────────────────────────

  /// POST /api/auth/change-password — requires current password for verification.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      ApiClient.post('/auth/change-password', auth: true, body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  /// PATCH /api/auth/profile — the signed-in user edits their own name,
  /// phone, or address. Email and role are immutable after signup.
  static Future<AppUser> updateProfile({
    String? fullName,
    String? phone,
    String? address,
  }) async {
    final json = await ApiClient.patch('/auth/profile', auth: true, body: {
      if (fullName != null) 'fullName': fullName,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
    });
    final u = json['user'] as Map<String, dynamic>;
    return AppUser(
      fullName: u['fullName'] ?? '',
      email: u['email'] ?? '',
      phone: u['phone'] ?? '',
      role: roleFromBackend(u['role'] ?? 'RESIDENT_OWNER'),
      address: (u['address'] ?? '').toString().isEmpty
          ? 'Jolshiri Abashon, Purbachal, Dhaka'
          : u['address'],
    );
  }

  /// PATCH /api/auth/role — switch the signed-in user to a different
  /// non-admin role. Fails with [ApiException] if backend rejects the change.
  static Future<void> changeRole(UserRole role) async {
    final backendRole = switch (role) {
      UserRole.residentOwner  => 'RESIDENT_OWNER',
      UserRole.serviceProvider => 'SERVICE_PROVIDER',
      UserRole.developer      => 'DEVELOPER',
      UserRole.admin          => 'ADMIN',
    };
    await ApiClient.patch('/auth/role', auth: true, body: {'role': backendRole});
  }

  // ── Community Posts (write side) ────────────────────────────────────────

  /// POST /api/community-posts — optional photo (multipart `image` field,
  /// matches the backend's `upload` middleware — see community.routes.js).
  static Future<CommunityPost> createCommunityPost({
    required String content,
    required String category,
    String? price,
    Uint8List? imageBytes,
  }) async {
    final json = await ApiClient.postMultipart(
      '/community-posts',
      auth: true,
      fields: {
        'content': content,
        'category': category,
        if (price != null && price.isNotEmpty) 'price': price,
      },
      fileBytes: imageBytes,
      fileField: 'image',
      fileName: 'post.jpg',
    );
    return _communityPostFromJson(json['post'] as Map<String, dynamic>);
  }

  /// PATCH /api/community-posts/:id — post author (or admin) edits their
  /// post. A new photo is optional; if omitted the existing imageUrl is kept.
  static Future<CommunityPost> updateCommunityPost({
    required String id,
    required String content,
    required String category,
    String? price,
    Uint8List? imageBytes,
  }) async {
    final json = await ApiClient.patchMultipart(
      '/community-posts/$id',
      auth: true,
      fields: {
        'content': content,
        'category': category,
        if (price != null && price.isNotEmpty) 'price': price,
      },
      fileBytes: imageBytes,
      fileField: 'image',
      fileName: 'post.jpg',
    );
    return _communityPostFromJson(json['post'] as Map<String, dynamic>);
  }

  /// DELETE /api/community-posts/:id — post author (or admin) removes it.
  static Future<void> deleteCommunityPost(String id) =>
      ApiClient.delete('/community-posts/$id', auth: true);

  /// POST /api/community-posts/:id/comments
  static Future<PostComment> addComment({required String postId, required String text}) async {
    final json = await ApiClient.post('/community-posts/$postId/comments', auth: true, body: {'text': text});
    final c = json['comment'] as Map<String, dynamic>;
    return PostComment(
      author: c['author']?['fullName'] ?? '',
      text: c['text'] ?? text,
      postedAt: DateTime.tryParse(c['postedAt'] ?? '') ?? DateTime.now(),
    );
  }

  // ── Forgot / Reset Password ────────────────────────────────────────────────

  /// POST /api/auth/forgot-password — sends OTP to the email.
  /// Returns the OTP string (demo mode — backend returns it directly since
  /// no email service is wired). In production this would be null.
  static Future<String?> forgotPassword(String email) async {
    final json = await ApiClient.post('/auth/forgot-password', body: {'email': email});
    return json['token'] as String?; // null when production email is wired
  }

  /// POST /api/auth/reset-password — verifies OTP and sets new password.
  static Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    await ApiClient.post('/auth/reset-password', body: {
      'email': email,
      'token': token,
      'newPassword': newPassword,
    });
  }

  // ── Plot Archive ────────────────────────────────────────────────────────────

  /// GET /api/admin/plots — full plot registry from registered residents.
  /// Available to ADMIN and DEVELOPER roles.
  static Future<List<PlotArchiveEntry>> fetchPlotArchive() async {
    final json = await ApiClient.get('/admin/plots', auth: true);
    final list = (json['plots'] as List? ?? []);
    return list.map((p) => PlotArchiveEntry(
          plotNumber: p['plotNumber'] ?? '',
          sectorNumber: (p['sectorNumber'] as num?)?.toInt() ?? 0,
          constructionStatus: _plotStatusFromBackend(p['constructionStatus']),
          ownerName: p['ownerName'] ?? '',
          developerCompany: p['developerCompany'],
          lastUpdated: p['lastUpdated'] ?? '',
        )).toList();
  }

  static PlotConstructionStatus _plotStatusFromBackend(String? s) {
    switch (s) {
      case 'UNDER_CONSTRUCTION':
        return PlotConstructionStatus.underConstruction;
      case 'COMPLETED':
        return PlotConstructionStatus.completed;
      case 'NOT_STARTED':
      default:
        return PlotConstructionStatus.notStarted;
    }
  }

  // ── My Bookings (resident) ──────────────────────────────────────────────────

  /// GET /api/bookings/mine — the signed-in RESIDENT_OWNER's own bookings
  /// (as customer). Used by reviews_screen to show completed bookings
  /// that are eligible for a review.
  static Future<List<ServiceBooking>> fetchMyBookings() async {
    final json = await ApiClient.get('/bookings/mine', auth: true);
    final list = (json['bookings'] as List? ?? []);
    return list.map((b) => ServiceBooking(
          id: b['id'],
          customerName: MockData.currentUser.fullName,
          providerName: b['provider']?['name'] ?? '',
          serviceType: b['serviceType'] ?? '',
          address: b['address'] ?? '',
          note: b['note'] ?? '',
          requestedAt: DateTime.tryParse(b['requestedAt'] ?? '') ?? DateTime.now(),
          status: requestStatusFromBackend(b['status']),
          reviewed: b['reviewed'] == true,
        )).toList();
  }

  /// PATCH /api/bookings/:id/reviewed — marks a completed booking as
  /// reviewed right after the resident submits a rating, so the "rate &
  /// review" prompt doesn't show again on future syncs.
  static Future<void> markBookingReviewed(String bookingId) {
    return ApiClient.patch('/bookings/$bookingId/reviewed', auth: true);
  }

  // ── Construction Stage Update (developer) ──────────────────────────────────

  /// PATCH /api/construction/stages/:id — developer updates progress,
  /// status, ETA, or note. The backend sets status to PENDING_APPROVAL
  /// automatically on save, waiting for Jolshiri Management to review.
  /// [progress] is 0.0–1.0 in Flutter; backend expects 0–100.
  static Future<ConstructionStage> updateConstructionStage(
    String stageId, {
    double? progress,
    ConstructionStageStatus? status,
    String? eta,
    String? developerNote,
  }) async {
    final json = await ApiClient.patch('/construction/stages/$stageId', auth: true, body: {
      if (progress != null) 'progress': (progress * 100).round(),
      if (eta != null && eta.isNotEmpty) 'eta': eta,
      if (developerNote != null) 'developerNote': developerNote,
    });
    final s = json['stage'] as Map<String, dynamic>;
    return ConstructionStage(
      id: s['id'],
      title: s['title'] ?? '',
      description: s['description'] ?? '',
      progress: ((s['progress'] as num?)?.toDouble() ?? 0) / 100,
      status: constructionStageStatusFromBackend(s['status']),
      eta: s['eta'] ?? '',
      developerNote: s['developerNote'] ?? '',
    );
  }

  /// PATCH /api/auth/fcm-token — saves FCM device token for push notifications
  static Future<void> updateFcmToken(String fcmToken) async {
    await ApiClient.patch('/auth/fcm-token', body: {'fcmToken': fcmToken}, auth: true);
  }
}

/// Result of POST /api/auth/signup — the account was created but still
/// needs its OTP verified before a login token is issued.
class SignupResult {
  final String email;
  final String message;
  final String? otp; // only present in dev mode (no Gmail configured)

  SignupResult._({required this.email, required this.message, this.otp});

  factory SignupResult._fromJson(Map<String, dynamic> json) {
    return SignupResult._(
      email: json['email'] ?? '',
      message: json['message'] ?? '',
      otp: json['otp'] as String?,
    );
  }
}

/// Result of a successful login/signup call: the JWT plus enough of the
/// user record to route to the right dashboard (see role_home.dart).
class AuthResult {
  final String token;
  final String userId;
  final String role; // RESIDENT_OWNER / SERVICE_PROVIDER / DEVELOPER / ADMIN
  final String? adminType; // JOLSHIRI_MANAGEMENT / ARMY_OVERSIGHT / SYSTEM_MODERATOR
  /// Raw account status string from the backend: ACTIVE / SUSPENDED / BANNED.
  /// The backend now rejects SUSPENDED/BANNED logins with a 403 before this
  /// object is ever constructed, but we carry the field so callers can react
  /// defensively (e.g. show a specific UI message rather than a generic error).
  final String accountStatus;
  final AppUser user;

  AuthResult._({
    required this.token,
    required this.userId,
    required this.role,
    required this.adminType,
    required this.accountStatus,
    required this.user,
  });

  factory AuthResult._fromJson(Map<String, dynamic> json) {
    final u = json['user'] as Map<String, dynamic>;
    return AuthResult._(
      token: json['token'] ?? '',
      userId: u['id'] ?? '',
      role: u['role'] ?? 'RESIDENT_OWNER',
      adminType: u['adminType'],
      // Bug 6 supplement: carry accountStatus so the login screen can surface
      // a meaningful message if the backend ever returns a non-ACTIVE status.
      accountStatus: u['accountStatus'] ?? 'ACTIVE',
      user: AppUser(
        fullName: u['fullName'] ?? '',
        email: u['email'] ?? '',
        phone: u['phone'] ?? '',
        role: roleFromBackend(u['role'] ?? 'RESIDENT_OWNER'),
        address: (u['address'] ?? '').toString().isEmpty
            ? 'Jolshiri Abashon, Purbachal, Dhaka'
            : u['address'],
      ),
    );
  }
}

UserRole roleFromBackend(String backendRole) {
  switch (backendRole) {
    case 'SERVICE_PROVIDER':
      return UserRole.serviceProvider;
    case 'DEVELOPER':
      return UserRole.developer;
    case 'ADMIN':
      return UserRole.admin;
    case 'RESIDENT_OWNER':
    default:
      return UserRole.residentOwner;
  }
}

RequestStatus requestStatusFromBackend(String? status) {
  switch (status) {
    case 'ACCEPTED':
      return RequestStatus.accepted;
    case 'DECLINED':
      return RequestStatus.declined;
    case 'COMPLETED':
      return RequestStatus.completed;
    case 'PENDING':
    default:
      return RequestStatus.pending;
  }
}

String requestStatusToBackend(RequestStatus status) {
  switch (status) {
    case RequestStatus.accepted:
      return 'ACCEPTED';
    case RequestStatus.declined:
      return 'DECLINED';
    case RequestStatus.completed:
      return 'COMPLETED';
    case RequestStatus.pending:
      return 'ACCEPTED'; // backend rejects PENDING on this endpoint — default forward
  }
}

ConstructionStageStatus constructionStageStatusFromBackend(String? status) {
  switch (status) {
    case 'COMPLETED':
      return ConstructionStageStatus.completed;
    case 'IN_PROGRESS':
      return ConstructionStageStatus.inProgress;
    case 'DELAYED':
      return ConstructionStageStatus.delayed;
    case 'PENDING_APPROVAL':
      return ConstructionStageStatus.pendingApproval;
    case 'UPCOMING':
    default:
      return ConstructionStageStatus.upcoming;
  }
}

ConstructionPermitStatus constructionPermitStatusFromBackend(String? status) {
  switch (status) {
    case 'APPROVED':
      return ConstructionPermitStatus.approved;
    case 'REJECTED':
      return ConstructionPermitStatus.rejected;
    case 'PENDING':
    default:
      return ConstructionPermitStatus.pending;
  }
}

String constructionPermitStatusToBackend(ConstructionPermitStatus status) {
  switch (status) {
    case ConstructionPermitStatus.approved:
      return 'APPROVED';
    case ConstructionPermitStatus.rejected:
      return 'REJECTED';
    case ConstructionPermitStatus.pending:
      return 'PENDING';
  }
}

MeetingStatus meetingStatusFromBackend(String? status) {
  switch (status) {
    case 'CONFIRMED':
      return MeetingStatus.confirmed;
    case 'COMPLETED':
      return MeetingStatus.completed;
    case 'CANCELLED':
      return MeetingStatus.cancelled;
    case 'PENDING':
    default:
      return MeetingStatus.pending;
  }
}

String meetingStatusToBackend(MeetingStatus status) {
  switch (status) {
    case MeetingStatus.confirmed:
      return 'CONFIRMED';
    case MeetingStatus.completed:
      return 'COMPLETED';
    case MeetingStatus.cancelled:
      return 'CANCELLED';
    case MeetingStatus.pending:
      return 'CONFIRMED'; // backend rejects PENDING on this endpoint
  }
}

SoilTestStatus soilTestStatusFromBackend(String? status) {
  switch (status) {
    case 'PERMIT_GRANTED':
      return SoilTestStatus.permitGranted;
    case 'PAYMENT_DONE':
      return SoilTestStatus.paymentDone;
    case 'COMPLETED':
      return SoilTestStatus.completed;
    case 'REJECTED':
      return SoilTestStatus.rejected;
    case 'REQUESTED':
    default:
      return SoilTestStatus.requested;
  }
}

String soilTestStatusToBackend(SoilTestStatus status) {
  switch (status) {
    case SoilTestStatus.permitGranted:
      return 'PERMIT_GRANTED';
    case SoilTestStatus.paymentDone:
      return 'PAYMENT_DONE';
    case SoilTestStatus.completed:
      return 'COMPLETED';
    case SoilTestStatus.rejected:
      return 'REJECTED';
    case SoilTestStatus.requested:
      return 'REQUESTED';
  }
}

ComplaintStatus complaintStatusFromBackend(String? status) {
  switch (status) {
    case 'IN_PROGRESS':
      return ComplaintStatus.inProgress;
    case 'RESOLVED':
      return ComplaintStatus.resolved;
    case 'SUBMITTED':
    default:
      return ComplaintStatus.submitted;
  }
}

String complaintStatusToBackend(ComplaintStatus status) {
  switch (status) {
    case ComplaintStatus.inProgress:
      return 'IN_PROGRESS';
    case ComplaintStatus.resolved:
      return 'RESOLVED';
    case ComplaintStatus.submitted:
      return 'SUBMITTED';
  }
}

PaymentStatus paymentStatusFromBackend(String? status) {
  switch (status) {
    case 'PROCESSING':
      return PaymentStatus.processing;
    case 'PAID':
      return PaymentStatus.paid;
    case 'FAILED':
      return PaymentStatus.failed;
    case 'DUE':
    default:
      return PaymentStatus.due;
  }
}

PaymentPurpose paymentPurposeFromBackend(String? purpose) {
  switch (purpose) {
    case 'DEVELOPMENT_AGREEMENT':
      return PaymentPurpose.developmentAgreement;
    case 'SOIL_TEST_FEE':
      return PaymentPurpose.soilTestFee;
    case 'CONSULTATION_FEE':
    default:
      return PaymentPurpose.consultationFee;
  }
}

AdminType? adminTypeFromBackend(String? backendAdminType) {
  switch (backendAdminType) {
    case 'JOLSHIRI_MANAGEMENT':
      return AdminType.jolshiriManagement;
    case 'ARMY_OVERSIGHT':
      return AdminType.armyOversight;
    case 'SYSTEM_MODERATOR':
      return AdminType.systemModerator;
    default:
      return null;
  }
}
