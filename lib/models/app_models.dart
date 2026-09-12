/// Data models mirroring the ER diagram in the SDP-II report.
/// These are plain Dart classes for now; swap the mock repositories in
/// `data/mock_data.dart` for real API calls against the endpoints listed
/// in Section 6 of the report (e.g. GET /plots, POST /book-service) when
/// the backend is ready.
library;

import 'dart:typed_data';

enum UserRole { residentOwner, serviceProvider, developer, admin }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.residentOwner => 'Resident / Plot Owner / Tenant',
        UserRole.serviceProvider => 'Service Provider',
        UserRole.developer => 'Developer',
        UserRole.admin => 'Authority / Admin',
      };
}

class AppUser {
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String address;

  const AppUser({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.address = 'Jolshiri Abashon, Purbachal, Dhaka',
  });

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class RentalListing {
  // Backend record id (see jolshiri-backend `RentalListing` model) — null
  // for entries that only exist in local mock data. Needed to send
  // POST /rentals/:id/viewing-requests with a real listingId.
  final String? id;
  final String title;
  final String location;
  final String rentAmount;
  final String availability;
  final String description;
  final int bedrooms;
  final String imageUrl;
  final Uint8List? imageBytes; // set when the user picks an image from device
  // The listing owner — needed so a requester can open a chat thread with
  // them from the "Flat View Requests" screen. Null for local mock data.
  final String? ownerId;
  final String? ownerName;

  const RentalListing({
    this.id,
    required this.title,
    required this.location,
    required this.rentAmount,
    required this.availability,
    required this.description,
    required this.bedrooms,
    required this.imageUrl,
    this.imageBytes,
    this.ownerId,
    this.ownerName,
  });
}

/// A viewing request a resident sends for a To-Let rental listing.
class RentalViewingRequest {
  // Backend record id — null for local-only mock entries. Needed to send
  // PATCH /viewing-requests/:id/status (accept/decline from the admin or
  // listing-owner side) and to open the chat thread at
  // /viewing-requests/:id/messages.
  final String? id;
  final String? listingId;
  final String listingTitle;
  final String listingLocation;
  final String? listingImageUrl;
  final String requesterName;
  final String requesterPhone;
  // Set when this request was fetched from the backend — lets the "Flat
  // View Requests" screen know which side of the chat the current user is
  // on and who the other participant is.
  final String? requesterId;
  final String? ownerId;
  final String? ownerName;
  final String note;
  final DateTime requestedAt;
  RequestStatus status;

  RentalViewingRequest({
    this.id,
    this.listingId,
    required this.listingTitle,
    required this.listingLocation,
    this.listingImageUrl,
    required this.requesterName,
    required this.requesterPhone,
    this.requesterId,
    this.ownerId,
    this.ownerName,
    required this.note,
    required this.requestedAt,
    this.status = RequestStatus.pending,
  });
}

/// One chat message on a viewing request's thread (requester <-> listing
/// owner). Mirrors the backend `Message` model.
class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime sentAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.sentAt,
  });
}

class Developer {
  // Backend record id (see jolshiri-backend `Developer` model) — null for
  // entries that only exist in local mock data. Needed to send
  // POST /quotes / POST /meetings with a real developerId.
  final String? id;
  final String companyName;
  final String contact;
  final double rating;
  final String specialty;
  final bool verified;

  const Developer({
    this.id,
    required this.companyName,
    required this.contact,
    required this.rating,
    required this.specialty,
    this.verified = true,
  });
}

class ServiceProvider {
  // Backend record id (see jolshiri-backend `ServiceProvider` model) —
  // null for entries that only exist in local mock data. Needed to send
  // POST /bookings with a real providerId.
  final String? id;
  final String name;
  final String serviceType;
  final String phone;
  final double rating;
  final int reviews;
  final bool verified;

  const ServiceProvider({
    this.id,
    required this.name,
    required this.serviceType,
    required this.phone,
    required this.rating,
    required this.reviews,
    this.verified = true,
  });
}

class ServiceReview {
  final String providerName;
  final String serviceType;
  final String residentName;
  final int rating;
  final String comment;
  final DateTime reviewedAt;

  const ServiceReview({
    required this.providerName,
    required this.serviceType,
    required this.residentName,
    required this.rating,
    required this.comment,
    required this.reviewedAt,
  });
}

// Whether the meeting is held online (video call) or offline (in-person).
enum MeetingType { online, offline }

extension MeetingTypeLabel on MeetingType {
  String get label => switch (this) {
        MeetingType.online => 'Online (video call)',
        MeetingType.offline => 'Offline (in-person)',
      };
}

enum MeetingPlatform { zoom, googleMeet }

extension MeetingPlatformLabel on MeetingPlatform {
  String get label => switch (this) {
        MeetingPlatform.zoom => 'Zoom',
        MeetingPlatform.googleMeet => 'Google Meet',
      };
}

enum MeetingStatus { pending, confirmed, completed, cancelled }

extension MeetingStatusLabel on MeetingStatus {
  String get label => switch (this) {
        MeetingStatus.pending => 'Pending',
        MeetingStatus.confirmed => 'Confirmed',
        MeetingStatus.completed => 'Completed',
        MeetingStatus.cancelled => 'Cancelled',
      };
}

class DeveloperMeeting {
  // Backend record id — null for local-only mock entries. Needed to send
  // PATCH /meetings/:id/status.
  final String? id;
  final String developerName;
  final String residentName;
  final String subject;
  final String plotReference;
  final MeetingType meetingType;   // online or offline
  final MeetingPlatform? platform; // only for online meetings
  // Only for online meetings, and only once the developer has pasted their
  // own Zoom/Google Meet link in when confirming — empty until then, so
  // it's mutable (not final) to be filled in locally after that PATCH.
  String meetingLink;
  final String venue;              // only for offline meetings
  final DateTime scheduledFor;
  final String note;
  MeetingStatus status;

  DeveloperMeeting({
    this.id,
    required this.developerName,
    required this.residentName,
    required this.subject,
    required this.plotReference,
    this.meetingType = MeetingType.online,
    this.platform,
    this.meetingLink = '',
    this.venue = '',
    required this.scheduledFor,
    required this.note,
    this.status = MeetingStatus.pending,
  });
}

enum PaymentPurpose { consultationFee, developmentAgreement, soilTestFee }

extension PaymentPurposeLabel on PaymentPurpose {
  String get label => switch (this) {
        PaymentPurpose.consultationFee => 'Consultation fee',
        PaymentPurpose.developmentAgreement => 'Development agreement',
        PaymentPurpose.soilTestFee => 'Soil test fee',
      };
}

enum PaymentStatus { due, processing, paid, failed }

extension PaymentStatusLabel on PaymentStatus {
  String get label => switch (this) {
        PaymentStatus.due => 'Due',
        PaymentStatus.processing => 'Processing',
        PaymentStatus.paid => 'Paid',
        PaymentStatus.failed => 'Failed',
      };
}

class PaymentRecord {
  // Backend record id (see jolshiri-backend `PaymentRecord` model) — null
  // for entries that only exist in local mock data. Needed to send
  // POST /payments/:id/pay against a real record.
  final String? id;
  final String title;
  final String description;
  final PaymentPurpose purpose;
  final String amount;
  final DateTime createdAt;
  final String reference;
  PaymentStatus status;

  PaymentRecord({
    this.id,
    required this.title,
    required this.description,
    required this.purpose,
    required this.amount,
    required this.createdAt,
    required this.reference,
    this.status = PaymentStatus.due,
  });
}

enum ConstructionStageStatus {
  completed,
  inProgress,
  upcoming,
  delayed,
  pendingApproval,
}

extension ConstructionStageStatusLabel on ConstructionStageStatus {
  String get label => switch (this) {
        ConstructionStageStatus.completed => 'Completed',
        ConstructionStageStatus.inProgress => 'In progress',
        ConstructionStageStatus.upcoming => 'Upcoming',
        ConstructionStageStatus.delayed => 'Delayed',
        ConstructionStageStatus.pendingApproval => 'Pending review',
      };
}

class ConstructionStage {
  // Backend record id — null for local-only mock entries. Needed to send
  // PATCH /construction/stages/:id and /:id/review.
  final String? id;
  final String title;
  final String description;
  double progress;
  ConstructionStageStatus status;
  String eta;
  // Developer note / update log (latest entry shown in the card)
  String developerNote;

  ConstructionStage({
    this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.status,
    required this.eta,
    this.developerNote = '',
  });
}

class ConstructionProject {
  // Backend record id — null for local-only mock entries. Needed to send
  // PATCH /construction/projects/:id/permit and POST .../stages.
  final String? id;
  final String projectName;
  final String plotReference;
  final String developerName;
  final String estimatedCompletion;
  final List<ConstructionStage> stages;
  // Admin permit status
  ConstructionPermitStatus permitStatus;

  ConstructionProject({
    this.id,
    required this.projectName,
    required this.plotReference,
    required this.developerName,
    required this.estimatedCompletion,
    required this.stages,
    this.permitStatus = ConstructionPermitStatus.pending,
  });
}

enum ConstructionPermitStatus { pending, approved, rejected }

extension ConstructionPermitStatusLabel on ConstructionPermitStatus {
  String get label => switch (this) {
        ConstructionPermitStatus.pending => 'Permit pending',
        ConstructionPermitStatus.approved => 'Permit approved',
        ConstructionPermitStatus.rejected => 'Permit rejected',
      };
}

/// A resident's application for a soil test permit on their plot, tracked
/// under the "Permits" section for both the resident (Build Track) and
/// the Jolshiri Authority (Permits tab).
class SoilTestApplication {
  // Backend record id — null for local-only mock entries. Needed to send
  // PATCH /construction/soil-tests/:id/status.
  final String? id;
  final String applicantName;
  final String plotReference;
  final String projectName;
  final DateTime appliedAt;
  SoilTestStatus status;
  String note;
  // Id of the PaymentRecord raised for this application's fee once the
  // permit is granted — null until then. Lets the resident's "Pay now"
  // button and the Payments screen resolve to the same record.
  String? paymentId;

  SoilTestApplication({
    this.id,
    required this.applicantName,
    required this.plotReference,
    required this.projectName,
    required this.appliedAt,
    this.status = SoilTestStatus.requested,
    this.note = '',
    this.paymentId,
  });
}

/// requested -> permitGranted -> paymentDone -> completed. rejected can
/// follow requested or permitGranted. See SoilTestStatus in the backend's
/// prisma/schema.prisma for the same flow server-side.
enum SoilTestStatus { requested, permitGranted, paymentDone, completed, rejected }

extension SoilTestStatusLabel on SoilTestStatus {
  String get label => switch (this) {
        SoilTestStatus.requested => 'Requested',
        SoilTestStatus.permitGranted => 'Permit granted',
        SoilTestStatus.paymentDone => 'Payment done',
        SoilTestStatus.completed => 'Completed',
        SoilTestStatus.rejected => 'Rejected',
      };
}

// ── Part 7: Complaint Register ──────────────────────────────────────────────

class Complaint {
  // Backend record id — null for local-only mock entries. Needed to send
  // GET /complaints/:id/updates and POST /complaints/:id/updates.
  final String? id;
  final String title;
  final String category;
  final String description;
  final String plotReference;
  final String? imageUrl;
  final Uint8List? imageBytes; // local-only preview when offline
  final DateTime createdAt;
  ComplaintStatus status;
  double progress;
  // Populated for the admin "all complaints" view only.
  final String residentName;

  Complaint({
    this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.plotReference,
    this.imageUrl,
    this.imageBytes,
    required this.createdAt,
    this.status = ComplaintStatus.submitted,
    this.progress = 0,
    this.residentName = '',
  });
}

class ComplaintUpdate {
  final String id;
  final String note;
  final ComplaintStatus status;
  final DateTime updatedAt;
  final String authorName;

  const ComplaintUpdate({
    required this.id,
    required this.note,
    required this.status,
    required this.updatedAt,
    this.authorName = '',
  });
}

enum ComplaintStatus { submitted, inProgress, resolved }

extension ComplaintStatusLabel on ComplaintStatus {
  String get label => switch (this) {
        ComplaintStatus.submitted => 'Submitted',
        ComplaintStatus.inProgress => 'In Progress',
        ComplaintStatus.resolved => 'Resolved',
      };
}

enum AdminType { jolshiriManagement, armyOversight, systemModerator }

extension AdminTypeLabel on AdminType {
  String get label => switch (this) {
        AdminType.jolshiriManagement => 'Jolshiri Management Authority',
        AdminType.armyOversight => 'Army Affiliated Oversight Unit',
        AdminType.systemModerator => 'System Moderator',
      };
}

class KpiMetric {
  final String label;
  final String value;
  final String note;

  const KpiMetric({
    required this.label,
    required this.value,
    required this.note,
  });
}

class TrendPoint {
  final String label;
  final double value;

  const TrendPoint({
    required this.label,
    required this.value,
  });
}

class ProgressItem {
  final String label;
  final double progress;
  final String note;

  const ProgressItem({
    required this.label,
    required this.progress,
    required this.note,
  });
}

/// Alert level of a security incident cluster (a sector/block on the map).
///
/// There is no more per-report severity picker (mild/moderate/severe) on
/// the "Report an incident" form — this is now purely a colour tier driven
/// by how many reports/SOS alerts that sector has received. An SOS alert
/// counts the same as any other report; it doesn't force a sector red by
/// itself.
///
///   1-3 reports → green  (AppColors.lake)
///   4-6 reports → orange (AppColors.brass)
///   7+ reports  → red    (AppColors.brick)
enum IncidentSeverity {
  mild,
  moderate,
  severe;

  /// Parse the tier string coming from the backend heatmap
  /// ('MILD' | 'MODERATE' | 'SEVERE' — count-based, see above).
  static IncidentSeverity fromString(String? s) {
    switch (s?.toUpperCase()) {
      case 'SEVERE':   return IncidentSeverity.severe;
      case 'MILD':     return IncidentSeverity.mild;
      case 'MODERATE':
      default:         return IncidentSeverity.moderate;
    }
  }

  /// Derive the tier directly from a report count (1-3 / 4-6 / 7+).
  static IncidentSeverity forCount(int count) {
    if (count >= 7) return IncidentSeverity.severe;
    if (count >= 4) return IncidentSeverity.moderate;
    return IncidentSeverity.mild;
  }

  String get label {
    switch (this) {
      case IncidentSeverity.mild:     return 'Green';
      case IncidentSeverity.moderate: return 'Orange';
      case IncidentSeverity.severe:   return 'Red';
    }
  }
}

class IncidentCluster {
  final String block;
  final int incidents;
  final String note;
  /// Colour tier for this block cluster, derived from its report count
  /// (see IncidentSeverity.forCount) — drives the map circle colour.
  final IncidentSeverity severity;
  // Real-world coordinates for map marker placement.
  // Jolshiri Abashon sectors (Rupganj, Narayanganj) — approximate positions
  // derived from the estate's block layout around the central lake.
  final double latitude;
  final double longitude;

  const IncidentCluster({
    required this.block,
    required this.incidents,
    required this.note,
    this.severity = IncidentSeverity.moderate,
    required this.latitude,
    required this.longitude,
  });
}

class ModerationItem {
  final String title;
  final String type;
  final String reason;
  final String status;

  const ModerationItem({
    required this.title,
    required this.type,
    required this.reason,
    required this.status,
  });
}

class ReportTemplate {
  final String title;
  final String description;

  const ReportTemplate({
    required this.title,
    required this.description,
  });
}

/// Status of an incoming request (booking or quote) as seen by a
/// service provider / developer.
enum RequestStatus { pending, accepted, declined, completed }

extension RequestStatusLabel on RequestStatus {
  String get label => switch (this) {
        RequestStatus.pending => 'Pending',
        RequestStatus.accepted => 'Accepted',
        RequestStatus.declined => 'Declined',
        RequestStatus.completed => 'Completed',
      };
}

/// A service booking request a resident sends to a service provider.
class ServiceBooking {
  // Backend record id — null for local-only mock entries. Needed to send
  // PATCH /bookings/:id/status.
  final String? id;
  final String customerName;
  final String providerName;
  final String serviceType;
  final String address;
  final String note;
  final DateTime requestedAt;
  RequestStatus status;
  // Whether the resident has already submitted a rating/review for this
  // completed booking. Used to show the "rate & review" card exactly once.
  bool reviewed;

  ServiceBooking({
    this.id,
    required this.customerName,
    required this.providerName,
    required this.serviceType,
    required this.address,
    required this.note,
    required this.requestedAt,
    this.status = RequestStatus.pending,
    this.reviewed = false,
  });
}

/// A quote request a resident sends to a developer.
class QuoteRequest {
  // Backend record id — null for local-only mock entries. Needed to send
  // PATCH /quotes/:id/status.
  final String? id;
  final String customerName;
  final String projectType;
  final String plotLocation;
  final String budget;
  final String note;
  final DateTime requestedAt;
  RequestStatus status;

  QuoteRequest({
    this.id,
    required this.customerName,
    required this.projectType,
    required this.plotLocation,
    required this.budget,
    required this.note,
    required this.requestedAt,
    this.status = RequestStatus.pending,
  });
}

class SecurityReport {
  // Backend record id — null for local-only mock entries. Needed to send
  // PATCH /security-reports/:id/status.
  final String? id;
  final String title;
  final String description;
  final String status; // Open, In Progress, Resolved
  final DateTime reportedAt;
  // Which block the incident happened in — feeds the security heatmap
  // (see BackendRepository.fetchHeatmapClusters). Null for older/local
  // entries that predate the block selector.
  final String? block;

  const SecurityReport({
    this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.reportedAt,
    this.block,
  });
}

class Notice {
  // Backend record id — null for local-only mock entries.
  final String? id;
  final String title;
  final String description;
  final DateTime publishDate;
  final String category;

  const Notice({
    this.id,
    required this.title,
    required this.description,
    required this.publishDate,
    required this.category,
  });
}

class Office {
  final String name;
  final String contact;
  final String location;

  const Office({required this.name, required this.contact, required this.location});
}

class CommunityPost {
  // Backend record id (see jolshiri-backend `CommunityPost` model) — null
  // for entries that only exist in local mock data. Needed to send
  // POST /community-posts/:id/comments against a real post.
  final String? id;
  final String author;
  // Author's backend user id — needed to show Edit/Delete only to the
  // post's own author (or an admin). Null for local-only mock entries.
  final String? authorId;
  // Mutable so editing a post (PATCH /community-posts/:id) can update it
  // in place without losing the `comments` list identity.
  String content;
  String category; // Announcement, Buy & Sell, Lost & Found, Event
  final DateTime postedAt;
  String? price;
  // Server-stored photo URL, once uploaded (see POST/PATCH /community-posts).
  String? imageUrl;
  // Optional photo attached when composing the post, shown immediately
  // as a local preview before/without a round trip to the server.
  Uint8List? imageBytes;
  final List<PostComment> comments;

  CommunityPost({
    this.id,
    required this.author,
    this.authorId,
    required this.content,
    required this.category,
    required this.postedAt,
    this.price,
    this.imageUrl,
    this.imageBytes,
    List<PostComment>? comments,
  }) : comments = comments ?? [];
}

/// A comment left on a community post.
class PostComment {
  final String author;
  final String text;
  final DateTime postedAt;

  const PostComment({
    required this.author,
    required this.text,
    required this.postedAt,
  });
}

/// One message bubble in the AI chatbot widget (Jolshiri Assistant).
/// Distinct from `ChatMessage` above, which is the viewing-request chat
/// thread between a resident and a listing owner — same-name classes here
/// used to collide and break compilation, so this one is named separately.
class ChatbotMessage {
  final String text;
  final bool fromUser;
  final DateTime time;

  const ChatbotMessage({required this.text, required this.fromUser, required this.time});
}

class AppNotification {
  // Backend record id (see jolshiri-backend `Notification` model) — null
  // for entries that only exist in local mock data. Needed to send
  // PATCH /notifications/:id/read against a real record.
  final String? id;
  final String title;
  final String message;
  bool isRead;

  AppNotification({this.id, required this.title, required this.message, this.isRead = false});
}

class MapPoint {
  final String name;
  final String category; // Plot, Park, School, Restaurant, Golf Course, Lake, Office
  final double dx; // relative x position (0..1) on the illustrated map
  final double dy; // relative y position (0..1) on the illustrated map
  // Real-world coordinates (approximate, around Jolshiri Abashon, Purbachal,
  // Dhaka) used for the "Open in Google Maps" action — the illustrated map
  // above still uses dx/dy for its stylised layout, this is only for
  // handing off to Google Maps for real navigation.
  final double? latitude;
  final double? longitude;

  const MapPoint({
    required this.name,
    required this.category,
    required this.dx,
    required this.dy,
    this.latitude,
    this.longitude,
  });
}


// Admin Models
class KpiData {
  final String title;
  final String value;
  final String iconName;
  final double percentageChange;

  KpiData({
    required this.title,
    required this.value,
    required this.iconName,
    required this.percentageChange,
  });
}

class IncidentReport {
  final String id;
  final String title;
  final String location;
  final String severity; // High, Medium, Low
  final String status;   // Pending, Resolved
  final DateTime date;

  IncidentReport({
    required this.id,
    required this.title,
    required this.location,
    required this.severity,
    required this.status,
    required this.date,
  });
}

/// A row in the SYSTEM_MODERATOR admin's user-management list — the
/// backend only exposes id/fullName/email/role for this list, since
/// suspend/ban aren't modelled in the User schema yet.
class AdminUserSummary {
  final String id;
  final String fullName;
  final String email;
  final String role; // RESIDENT_OWNER / SERVICE_PROVIDER / DEVELOPER / ADMIN
  final String accountStatus; // ACTIVE / SUSPENDED / BANNED
  final bool isEmailVerified;

  const AdminUserSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.accountStatus = 'ACTIVE',
    this.isEmailVerified = true,
  });
}

/// GET /api/admin/kpis — summary counters shown on the KPI Dashboard.
class AdminKpis {
  final int residentCount;
  final int developerCount;
  final int providerCount;
  final int rentalCount;
  final int activeProjects;
  final int pendingViewingRequests;
  final int stagesPendingApproval;
  final int openSecurityReports;

  const AdminKpis({
    this.residentCount = 0,
    this.developerCount = 0,
    this.providerCount = 0,
    this.rentalCount = 0,
    this.activeProjects = 0,
    this.pendingViewingRequests = 0,
    this.stagesPendingApproval = 0,
    this.openSecurityReports = 0,
  });
}
// ── Plot Ownership (collected at resident/owner sign-up) ──────────────────────

enum PlotConstructionStatus { notStarted, underConstruction, completed }

extension PlotConstructionStatusLabel on PlotConstructionStatus {
  String get label => switch (this) {
        PlotConstructionStatus.notStarted => 'Not started yet',
        PlotConstructionStatus.underConstruction => 'Under construction',
        PlotConstructionStatus.completed => 'Construction completed',
      };
}

enum PlotRentStatus { ownerOccupied, rentingOut, notRenting }

extension PlotRentStatusLabel on PlotRentStatus {
  String get label => switch (this) {
        PlotRentStatus.ownerOccupied => 'I live here (owner-occupied)',
        PlotRentStatus.rentingOut => 'Renting out flats / units',
        PlotRentStatus.notRenting => 'Not renting out',
      };
}

/// Information a plot owner/resident submits at sign-up.
class PlotOwnershipInfo {
  final String plotNumber;   // e.g. '7-142'
  final int sectorNumber;    // 1-18
  final PlotConstructionStatus constructionStatus;
  final PlotRentStatus rentStatus;

  const PlotOwnershipInfo({
    required this.plotNumber,
    required this.sectorNumber,
    required this.constructionStatus,
    required this.rentStatus,
  });
}

// ── Developer Plot Archive entry ──────────────────────────────────────────────

/// One row in the developer's plot archive / spreadsheet view.
class PlotArchiveEntry {
  final String plotNumber;
  final int sectorNumber;
  final PlotConstructionStatus constructionStatus;
  final String? developerCompany; // null if not under construction
  final String ownerName;
  final String lastUpdated;

  const PlotArchiveEntry({
    required this.plotNumber,
    required this.sectorNumber,
    required this.constructionStatus,
    this.developerCompany,
    required this.ownerName,
    required this.lastUpdated,
  });
}
