import '../models/app_models.dart';

/// Static, in-memory app data. Screens read these the same way they always
/// have (`MockData.rentals`, `MockData.notices`, …) — but on launch,
/// lib/services/sync_service.dart tries to replace each list with live data
/// from the backend (jolshiri-backend). If the backend is unreachable, the
/// seed data below stays exactly as it is, so the app keeps working
/// standalone. See lib/services/ for the backend integration.
class MockData {
  MockData._();

  static AppUser currentUser = const AppUser(
    fullName: 'Fatima Ashraf',
    email: 'fatima.ashraf@jolshiri.army.bd',
    phone: '+880 1711-223344',
    role: UserRole.residentOwner,
  );

  static final rentals = <RentalListing>[
    const RentalListing(
      title: 'Furnished 3-Bed Apartment',
      location: 'Sector 7, near Lake Park',
      rentAmount: '৳ 35,000 / month',
      availability: 'Available from Aug 1',
      description: 'South-facing, 1,800 sqft, generator backup, close to the officers\' mess.',
      bedrooms: 3,
      imageUrl: 'assets/listings/house1.jpg',
    ),
    const RentalListing(
      title: 'Cozy 2-Bed Flat',
      location: 'Sector 12, Golf Course Road',
      rentAmount: '৳ 22,000 / month',
      availability: 'Available now',
      description: 'Ground floor, small garden, ideal for a small family.',
      bedrooms: 2,
      imageUrl: 'assets/listings/house2.jpg',
    ),
    const RentalListing(
      title: 'Duplex 4-Bed House',
      location: 'Sector 3, Main Boulevard',
      rentAmount: '৳ 55,000 / month',
      availability: 'From Sep 15',
      description: 'Private parking, rooftop access, walking distance to school.',
      bedrooms: 4,
      imageUrl: 'assets/listings/house3.jpg',
    ),
  ];

  static final viewingRequests = <RentalViewingRequest>[];

  static final developers = <Developer>[
    const Developer(companyName: 'Progoti Builders Ltd.', contact: '+880 1922-334455', rating: 4.6, specialty: 'Residential construction'),
    const Developer(companyName: 'Shikder Engineering', contact: '+880 1833-556677', rating: 4.3, specialty: 'Boundary walls & foundation'),
    const Developer(companyName: 'Green Horizon Developers', contact: '+880 1755-889900', rating: 4.8, specialty: 'Turnkey home building'),
  ];

  static final serviceProviders = <ServiceProvider>[
    const ServiceProvider(name: 'Karim Uddin', serviceType: 'Electrician', phone: '+880 1611-112233', rating: 4.7, reviews: 58),
    const ServiceProvider(name: 'Jolshiri Plumbing Co.', serviceType: 'Plumber', phone: '+880 1611-223344', rating: 4.5, reviews: 41),
    const ServiceProvider(name: 'Rafiq Carpentry', serviceType: 'Carpenter', phone: '+880 1611-334455', rating: 4.4, reviews: 33),
    const ServiceProvider(name: 'CleanCity Services', serviceType: 'Cleaner', phone: '+880 1611-445566', rating: 4.2, reviews: 27),
    const ServiceProvider(name: 'Salam Driver Service', serviceType: 'Driver', phone: '+880 1611-556677', rating: 4.6, reviews: 49),
    const ServiceProvider(name: 'Jolshiri AC & Electronics', serviceType: 'Technician', phone: '+880 1611-667788', rating: 4.3, reviews: 22),
  ];

  static final serviceReviews = <ServiceReview>[
    ServiceReview(
      providerName: 'Karim Uddin',
      serviceType: 'Electrician',
      residentName: 'Fatima Ashraf',
      rating: 5,
      comment: 'Very punctual and fixed the ceiling fan wiring in one visit.',
      reviewedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    ServiceReview(
      providerName: 'Jolshiri Plumbing Co.',
      serviceType: 'Plumber',
      residentName: 'Ahmed Al Imran',
      rating: 4,
      comment: 'Solved the bathroom leakage quickly and explained the issue clearly.',
      reviewedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    ServiceReview(
      providerName: 'Salam Driver Service',
      serviceType: 'Driver',
      residentName: 'Taslimul Alam',
      rating: 5,
      comment: 'Driver arrived on time and handled a late-night airport pickup smoothly.',
      reviewedAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
  ];

  static final developerMeetings = <DeveloperMeeting>[
    DeveloperMeeting(
      developerName: 'Progoti Builders Ltd.',
      residentName: 'Fatima Ashraf',
      subject: 'Consultation on 2-storey home layout',
      plotReference: 'Plot 7-142, Sector 7, Lake View',
      meetingType: MeetingType.online,
      platform: MeetingPlatform.googleMeet,
      meetingLink: 'https://meet.google.com/jol-consult-b142',
      venue: '',
      scheduledFor: DateTime.now().add(const Duration(days: 1, hours: 3)),
      note: 'Need to discuss room layout, car parking, and approximate consultation cost.',
      status: MeetingStatus.confirmed,
    ),
    DeveloperMeeting(
      developerName: 'Green Horizon Developers',
      residentName: 'Mohaimen Hridoy',
      subject: 'Plot development agreement discussion',
      plotReference: 'Plot 15-203, Sector 15, School Zone',
      meetingType: MeetingType.online,
      platform: MeetingPlatform.zoom,
      meetingLink: 'https://zoom.us/j/2034509876',
      venue: '',
      scheduledFor: DateTime.now().add(const Duration(days: 2, hours: 1)),
      note: 'Review draft agreement and payment milestones for joint development.',
    ),
    DeveloperMeeting(
      developerName: 'Shikder Engineering',
      residentName: 'Fatima Ashraf',
      subject: 'Site visit and boundary wall discussion',
      plotReference: 'Plot 7-142, Sector 7, Lake View',
      meetingType: MeetingType.offline,
      venue: 'Jolshiri Project Office, Admin Block, Sector 3',
      scheduledFor: DateTime.now().add(const Duration(days: 5, hours: 10)),
      note: 'Please bring original land documents and the approved drawing.',
    ),
  ];

  static final payments = <PaymentRecord>[
    PaymentRecord(
      title: 'Architect consultation',
      description: 'Consultation fee for a design session with Progoti Builders Ltd.',
      purpose: PaymentPurpose.consultationFee,
      amount: '৳ 5,000',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      reference: 'SSLZ-CONS-1024',
    ),
    PaymentRecord(
      title: 'Development agreement booking money',
      description: 'Initial advance for joint development agreement review and booking.',
      purpose: PaymentPurpose.developmentAgreement,
      amount: '৳ 50,000',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      reference: 'SSLZ-AGR-2088',
      status: PaymentStatus.paid,
    ),
    // Matches soilTestApplications' permitGranted entry above (same
    // paymentId) — this is what the resident's "Pay now" button forwards to.
    PaymentRecord(
      id: 'mock-soil-payment-imran',
      title: 'Soil Test Application Fee',
      description: 'Soil test fee for "Imran Residence Extension" (Plot 3-015, Sector 3, Main Boulevard).',
      purpose: PaymentPurpose.soilTestFee,
      amount: '৳ 2,000',
      createdAt: DateTime.now().subtract(const Duration(days: 9)),
      reference: 'JLS-MOCK-SOIL1',
    ),
  ];

  static final constructionProjects = <ConstructionProject>[
    ConstructionProject(
      projectName: 'Ashraf Family Residence',
      plotReference: 'Plot 7-142, Sector 7, Lake View',
      developerName: 'Progoti Builders Ltd.',
      estimatedCompletion: 'December 2026',
      permitStatus: ConstructionPermitStatus.approved,
      stages: [
        ConstructionStage(
          title: 'Planning & design',
          description: 'Architectural drawings, space planning, and design revisions.',
          progress: 1,
          status: ConstructionStageStatus.completed,
          eta: 'Completed',
          developerNote: 'Approved by lead architect on 12 Jan 2026.',
        ),
        ConstructionStage(
          title: 'Authority approval',
          description: 'Plan submission, permit review, and compliance checks.',
          progress: 1,
          status: ConstructionStageStatus.completed,
          eta: 'Completed',
          developerNote: 'RAJUK approval received. All clearances done.',
        ),
        ConstructionStage(
          title: 'Foundation work',
          description: 'Site preparation, piling, and reinforced footing works.',
          progress: 0.72,
          status: ConstructionStageStatus.inProgress,
          eta: '2 weeks left',
          developerNote: 'Piling complete; footing casting underway.',
        ),
        ConstructionStage(
          title: 'Structural frame',
          description: 'Columns, beams, slabs, and roof casting.',
          progress: 0.2,
          status: ConstructionStageStatus.upcoming,
          eta: 'Starts next month',
        ),
        ConstructionStage(
          title: 'Utilities & interior',
          description: 'Electrical, plumbing, finishing, and handover preparation.',
          progress: 0,
          status: ConstructionStageStatus.upcoming,
          eta: 'After structural frame',
        ),
      ],
    ),
    ConstructionProject(
      projectName: 'Imran Residence Extension',
      plotReference: 'Plot 3-015, Sector 3, Main Boulevard',
      developerName: 'Asha Developers',
      estimatedCompletion: 'June 2027',
      permitStatus: ConstructionPermitStatus.approved,
      stages: [
        ConstructionStage(
          title: 'Planning & design',
          description: 'Architectural drawings and space planning.',
          progress: 1,
          status: ConstructionStageStatus.completed,
          eta: 'Completed',
          developerNote: 'Design approved by resident on 15 Feb 2026.',
        ),
        ConstructionStage(
          title: 'Soil testing',
          description: 'Soil bearing-capacity test required before foundation work.',
          progress: 0.3,
          status: ConstructionStageStatus.inProgress,
          eta: 'Permit granted — awaiting payment',
          developerNote: 'Permit granted. Resident must pay the soil test fee to schedule the visit.',
        ),
        ConstructionStage(
          title: 'Foundation work',
          description: 'Site preparation, piling, and reinforced footing works.',
          progress: 0,
          status: ConstructionStageStatus.upcoming,
          eta: 'After soil test',
        ),
        ConstructionStage(
          title: 'Structural frame',
          description: 'Columns, beams, slabs, and roof casting.',
          progress: 0,
          status: ConstructionStageStatus.upcoming,
          eta: 'After foundation',
        ),
      ],
    ),
    ConstructionProject(
      projectName: 'Hridoy Duplex Build',
      plotReference: 'Plot 15-203, Sector 15, School Zone',
      developerName: 'Green Horizon Developers',
      estimatedCompletion: 'March 2027',
      permitStatus: ConstructionPermitStatus.pending,
      stages: [
        ConstructionStage(
          title: 'Consultation & scope',
          description: 'Developer consultation and budget planning.',
          progress: 1,
          status: ConstructionStageStatus.completed,
          eta: 'Completed',
          developerNote: 'Scope finalised with owner on 5 Mar 2026.',
        ),
        ConstructionStage(
          title: 'Agreement signing',
          description: 'Joint development agreement review and signing.',
          progress: 0.55,
          status: ConstructionStageStatus.inProgress,
          eta: 'Awaiting final payment',
          developerNote: 'Owner reviewing final draft; payment pending.',
        ),
        ConstructionStage(
          title: 'Permit preparation',
          description: 'Document collection and permit application readiness.',
          progress: 0.3,
          status: ConstructionStageStatus.delayed,
          eta: 'Delayed by 1 week',
          developerNote: 'Missing NOC from utility company; follow-up sent.',
        ),
        ConstructionStage(
          title: 'Mobilisation',
          description: 'Contractor mobilisation and material planning.',
          progress: 0,
          status: ConstructionStageStatus.upcoming,
          eta: 'Pending permit approval',
        ),
      ],
    ),
  ];

  // Incoming booking requests shown to a logged-in service provider.
  static final serviceBookings = <ServiceBooking>[
    ServiceBooking(
      customerName: 'Fatima Ashraf',
      providerName: 'Karim Uddin',
      serviceType: 'Electrician',
      address: 'Plot 7-142, Sector 7, Lake View',
      note: 'Two ceiling fans not working, need a check today if possible.',
      requestedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    ServiceBooking(
      customerName: 'Ahmed Al Imran',
      providerName: 'Karim Uddin',
      serviceType: 'Electrician',
      address: 'Plot 3-015, Sector 3, Main Boulevard',
      note: 'New light fittings installation in the drawing room.',
      requestedAt: DateTime.now().subtract(const Duration(hours: 6)),
      status: RequestStatus.accepted,
    ),
    ServiceBooking(
      customerName: 'Taslimul Alam',
      providerName: 'Karim Uddin',
      serviceType: 'Electrician',
      address: 'Sector 12, Golf Course Road',
      note: 'Main distribution board tripping frequently.',
      requestedAt: DateTime.now().subtract(const Duration(days: 1)),
      status: RequestStatus.completed,
    ),
  ];

  // Soil test permit applications, tracked under "Permits" for both the
  // resident (Build Track) and the Jolshiri Authority dashboard.
  static final soilTestApplications = <SoilTestApplication>[
    SoilTestApplication(
      applicantName: 'Fatima Ashraf',
      plotReference: 'Plot 7-142, Sector 7, Lake View',
      projectName: 'Ashraf Family Residence',
      appliedAt: DateTime.now().subtract(const Duration(days: 20)),
      status: SoilTestStatus.completed,
      note: 'Bearing capacity confirmed suitable for a 2-storey structure.',
    ),
    SoilTestApplication(
      applicantName: 'Ahmed Al Imran',
      plotReference: 'Plot 3-015, Sector 3, Main Boulevard',
      projectName: 'Imran Residence Extension',
      appliedAt: DateTime.now().subtract(const Duration(days: 9)),
      status: SoilTestStatus.permitGranted,
      note: 'Permit granted — pay the testing fee to schedule your visit.',
      paymentId: 'mock-soil-payment-imran',
    ),
  ];

  static List<SoilTestApplication> soilTestApplicationsFor(String plotReference) {
    final applications = soilTestApplications.where((a) => a.plotReference == plotReference).toList();
    applications.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    return applications;
  }

  // Complaint register — resident-filed maintenance/security/utility
  // complaints tracked under Part 7.
  static final complaints = <Complaint>[
    Complaint(
      title: 'Streetlight not working',
      category: 'Utility',
      description: 'The streetlight near the Sector 7 park entrance has been off for a week.',
      plotReference: 'Plot 7-142, Sector 7, Lake View',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      status: ComplaintStatus.inProgress,
      progress: 50,
      residentName: 'Fatima Ashraf',
    ),
    Complaint(
      title: 'Water pressure too low',
      category: 'Utility',
      description: 'Low water pressure in the mornings for the past few days.',
      plotReference: 'Plot 15-203, Sector 15, School Zone',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      status: ComplaintStatus.submitted,
      residentName: 'Ahmed Al Imran',
    ),
  ];

  static List<Complaint> complaintsFor(String plotReference) {
    final list = complaints.where((c) => c.plotReference == plotReference).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // Incoming quote requests shown to a logged-in developer.
  static final quoteRequests = <QuoteRequest>[
    QuoteRequest(
      customerName: 'Mohaimen Hridoy',
      projectType: 'Turnkey home building',
      plotLocation: 'Plot 15-203, Sector 15, School Zone',
      budget: '৳ 60,00,000 – 80,00,000',
      note: 'Looking to build a 2-storey house, need a full quote.',
      requestedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    QuoteRequest(
      customerName: 'Fatima Ashraf',
      projectType: 'Boundary walls & foundation',
      plotLocation: 'Plot 7-142, Sector 7, Lake View',
      budget: '৳ 8,00,000 – 12,00,000',
      note: 'Boundary wall around a 5 katha plot.',
      requestedAt: DateTime.now().subtract(const Duration(days: 2)),
      status: RequestStatus.accepted,
    ),
  ];

  static final securityReports = <SecurityReport>[
    SecurityReport(
      title: 'Suspicious vehicle near Sector 7 gate',
      description: 'A grey sedan has been parked near the gate for over 3 hours without occupants.',
      status: 'In Progress',
      reportedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    SecurityReport(
      title: 'Streetlight not working',
      description: 'The streetlight opposite Plot 12-078 has been off for 4 nights.',
      status: 'Open',
      reportedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    SecurityReport(
      title: 'Minor gate damage reported',
      description: 'Sector 3 side gate latch is broken, reported and fixed by security team.',
      status: 'Resolved',
      reportedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  static final notices = <Notice>[
    Notice(
      title: 'Road resurfacing — Sector 7 Main Road',
      description: 'Resurfacing work will continue from Jul 8–12. Please use the Sector 12 detour during this period.',
      publishDate: DateTime.now().subtract(const Duration(days: 1)),
      category: 'Construction',
    ),
    Notice(
      title: 'Water supply maintenance',
      description: 'Water supply will be temporarily suspended on Jul 9 from 10 AM–2 PM for pipeline maintenance.',
      publishDate: DateTime.now().subtract(const Duration(days: 2)),
      category: 'Utility',
    ),
    Notice(
      title: 'Community Eid Reunion',
      description: 'All residents are invited to the community reunion at the Central Park on Jul 20, 5 PM onward.',
      publishDate: DateTime.now().subtract(const Duration(days: 4)),
      category: 'Event',
    ),
  ];

  static final offices = <Office>[
    const Office(name: 'Jolshiri Project Office', contact: '+880 2-224455667', location: 'Admin Block, Sector 3'),
    const Office(name: 'Estate & Allotment Office', contact: '+880 2-224455668', location: 'Admin Block, Sector 3'),
    const Office(name: 'Utility & Maintenance Cell', contact: '+880 2-224455669', location: 'Service Complex, Sector 12'),
  ];

  static final communityPosts = <CommunityPost>[
    CommunityPost(
      author: 'Ahmed Al Imran',
      content: 'Selling a barely used treadmill, great condition. Message if interested.',
      category: 'Buy & Sell',
      postedAt: DateTime.now().subtract(const Duration(hours: 3)),
      price: '৳ 18,000',
    ),
    CommunityPost(
      author: 'Taslimul Alam',
      content: 'Found a set of house keys near the Central Park gate yesterday evening.',
      category: 'Lost & Found',
      postedAt: DateTime.now().subtract(const Duration(hours: 10)),
      comments: [
        PostComment(
          author: 'Fatima Ashraf',
          text: 'Could you describe the keychain? I think these might be mine.',
          postedAt: DateTime.now().subtract(const Duration(hours: 9)),
        ),
      ],
    ),
    CommunityPost(
      author: 'Community Desk',
      content: 'Weekend badminton meetup at the community court, all residents welcome!',
      category: 'Event',
      postedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    CommunityPost(
      author: 'Mohaimen Hridoy',
      content: 'Reminder: monthly maintenance fee due by the 10th of every month.',
      category: 'Announcement',
      postedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  static final notifications = <AppNotification>[
    AppNotification(title: 'Appointment confirmed', message: 'Your appointment with the Estate Office is confirmed for Jul 10, 11 AM.'),
    AppNotification(title: 'Service booked', message: 'Karim Uddin (Electrician) accepted your booking request.'),
    AppNotification(title: 'New notice published', message: 'Water supply maintenance scheduled for Jul 9.', isRead: true),
    AppNotification(title: 'Security alert', message: 'Suspicious vehicle report near Sector 7 is under review.'),
  ];

  static const mapPoints = <MapPoint>[
    // Parks
    MapPoint(name: 'Jolshiri Central Park', category: 'Park', dx: 0.32, dy: 0.28, latitude: 23.80821, longitude: 90.49933),
    MapPoint(name: 'Sector 7 Community Garden', category: 'Park', dx: 0.62, dy: 0.35, latitude: 23.81320, longitude: 90.50210),
    MapPoint(name: 'Lake View Promenade', category: 'Park', dx: 0.48, dy: 0.18, latitude: 23.81510, longitude: 90.50050),

    // Lakes
    MapPoint(name: 'Jolshiri Central Lake', category: 'Lake', dx: 0.50, dy: 0.40, latitude: 23.81050, longitude: 90.50120),
    MapPoint(name: 'Sector 12 Decorative Lake', category: 'Lake', dx: 0.72, dy: 0.55, latitude: 23.80950, longitude: 90.50380),

    // Golf Course
    MapPoint(name: 'Jolshiri Golf Course', category: 'Golf Course', dx: 0.70, dy: 0.25, latitude: 23.81450, longitude: 90.50450),

    // Plots
    MapPoint(name: 'Plot 7-142 (Sector 7)', category: 'Plot', dx: 0.38, dy: 0.50, latitude: 23.81000, longitude: 90.49970),
    MapPoint(name: 'Plot 3-015 (Sector 3)', category: 'Plot', dx: 0.25, dy: 0.38, latitude: 23.81200, longitude: 90.49760),
    MapPoint(name: 'Plot 15-203 (Sector 15)', category: 'Plot', dx: 0.58, dy: 0.62, latitude: 23.80780, longitude: 90.50130),
    MapPoint(name: 'Plot 12-078 (Sector 12)', category: 'Plot', dx: 0.80, dy: 0.45, latitude: 23.81080, longitude: 90.50520),

    // Schools
    MapPoint(name: 'Jolshiri Public School and College', category: 'School', dx: 0.22, dy: 0.55, latitude: 23.81133, longitude: 90.49814),
    MapPoint(name: 'Sector 5 Primary School', category: 'School', dx: 0.42, dy: 0.70, latitude: 23.80670, longitude: 90.50010),

    // Restaurants
    MapPoint(name: 'Jolshiri Restaurant', category: 'Restaurant', dx: 0.55, dy: 0.72, latitude: 23.80742, longitude: 90.49787),
    MapPoint(name: 'Golf Course Cafe & Dining', category: 'Restaurant', dx: 0.68, dy: 0.30, latitude: 23.81390, longitude: 90.50410),
    MapPoint(name: 'Lake Side Food Court', category: 'Restaurant', dx: 0.52, dy: 0.48, latitude: 23.81020, longitude: 90.50160),

    // Offices
    MapPoint(name: 'Jolshiri Site Office', category: 'Office', dx: 0.20, dy: 0.80, latitude: 23.80716, longitude: 90.50242),
    MapPoint(name: 'Property Management Office', category: 'Office', dx: 0.30, dy: 0.65, latitude: 23.80860, longitude: 90.49890),
    MapPoint(name: 'Security Control Centre', category: 'Office', dx: 0.15, dy: 0.45, latitude: 23.81150, longitude: 90.49680),
  ];

  static List<ChatbotMessage> get chatStarter => [
        ChatbotMessage(text: 'Assalamu Alaikum! I\'m the Jolshiri assistant. Ask me about plots, services, notices, or anything else in the city.', fromUser: false, time: DateTime.now()),
      ];

  static List<ServiceReview> reviewsForProvider(String providerName) {
    final reviews = serviceReviews.where((review) => review.providerName == providerName).toList();
    reviews.sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    return reviews;
  }

  static double providerAverageRating(ServiceProvider provider) {
    final reviews = reviewsForProvider(provider.name);
    if (reviews.isEmpty) return provider.rating;
    final baseTotal = provider.rating * provider.reviews;
    final addedTotal = reviews.fold<int>(0, (sum, review) => sum + review.rating);
    return (baseTotal + addedTotal) / (provider.reviews + reviews.length);
  }

  static int providerReviewCount(ServiceProvider provider) {
    return provider.reviews + reviewsForProvider(provider.name).length;
  }

  // ── Plot Archive (for Developer dashboard) ──────────────────────────────────
  /// Live plot archive synced from backend (GET /api/admin/plots).
  /// Falls back to the const [plotArchive] seed below when the backend
  /// is unreachable or the user is not yet signed in as DEVELOPER/ADMIN.
  static final List<PlotArchiveEntry> livePlotArchive = [];

  /// Returns livePlotArchive when populated, const seed otherwise.
  static List<PlotArchiveEntry> get effectivePlotArchive =>
      livePlotArchive.isNotEmpty ? livePlotArchive : plotArchive;

  static const plotArchive = <PlotArchiveEntry>[
    PlotArchiveEntry(
      plotNumber: '3-015',
      sectorNumber: 3,
      constructionStatus: PlotConstructionStatus.completed,
      developerCompany: 'Progoti Builders Ltd.',
      ownerName: 'Ahmed Al Imran',
      lastUpdated: 'Jun 2025',
    ),
    PlotArchiveEntry(
      plotNumber: '7-142',
      sectorNumber: 7,
      constructionStatus: PlotConstructionStatus.underConstruction,
      developerCompany: 'Progoti Builders Ltd.',
      ownerName: 'Fatima Ashraf',
      lastUpdated: 'Jul 2025',
    ),
    PlotArchiveEntry(
      plotNumber: '7-089',
      sectorNumber: 7,
      constructionStatus: PlotConstructionStatus.notStarted,
      developerCompany: null,
      ownerName: 'Taslimul Alam',
      lastUpdated: 'May 2025',
    ),
    PlotArchiveEntry(
      plotNumber: '12-078',
      sectorNumber: 12,
      constructionStatus: PlotConstructionStatus.underConstruction,
      developerCompany: 'Shikder Engineering',
      ownerName: 'Raihan Kabir',
      lastUpdated: 'Jul 2025',
    ),
    PlotArchiveEntry(
      plotNumber: '12-034',
      sectorNumber: 12,
      constructionStatus: PlotConstructionStatus.notStarted,
      developerCompany: null,
      ownerName: 'Nusrat Jahan',
      lastUpdated: 'Apr 2025',
    ),
    PlotArchiveEntry(
      plotNumber: '15-203',
      sectorNumber: 15,
      constructionStatus: PlotConstructionStatus.underConstruction,
      developerCompany: 'Green Horizon Developers',
      ownerName: 'Mohaimen Hridoy',
      lastUpdated: 'Jul 2025',
    ),
    PlotArchiveEntry(
      plotNumber: '15-110',
      sectorNumber: 15,
      constructionStatus: PlotConstructionStatus.notStarted,
      developerCompany: null,
      ownerName: 'Saiful Islam',
      lastUpdated: 'Mar 2025',
    ),
    PlotArchiveEntry(
      plotNumber: '1-008',
      sectorNumber: 1,
      constructionStatus: PlotConstructionStatus.completed,
      developerCompany: 'Green Horizon Developers',
      ownerName: 'Col. Mahbubur Rahman',
      lastUpdated: 'Jan 2025',
    ),
  ];
}
