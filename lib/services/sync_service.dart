import 'package:flutter/foundation.dart';
import '../data/mock_data.dart';
import '../models/app_models.dart';
import 'api_client.dart';
import 'backend_repository.dart';

/// Pulls the public (no-login-required) lists from the Jolshiri backend and
/// drops them straight into MockData's static lists — so every screen that
/// already reads `MockData.rentals`, `MockData.notices`, etc. shows live data
/// the moment it's available, with ZERO changes needed in those screens.
///
/// If the backend isn't reachable (not running, wrong host in
/// lib/services/api_config.dart, no network) each module silently keeps
/// its existing mock seed data — the app keeps working offline/standalone.
class BackendSync {
  BackendSync._();

  /// Call this once, early (see splash_screen.dart). Every module is
  /// fetched independently so one failing endpoint doesn't block the rest.
  static Future<void> syncPublicData() async {
    await Future.wait([
      _syncRentals(),
      _syncNotices(),
      _syncOffices(),
      _syncCommunityPosts(),
      _syncDevelopers(),
      _syncServiceProviders(),
    ]);
  }

  static Future<void> _syncRentals() async {
    try {
      final rentals = await BackendRepository.fetchRentals();
      if (rentals.isNotEmpty) {
        MockData.rentals
          ..clear()
          ..addAll(rentals);
      }
    } catch (e) {
      _log('rentals', e);
    }
  }

  static Future<void> _syncNotices() async {
    try {
      final notices = await BackendRepository.fetchNotices();
      if (notices.isNotEmpty) {
        MockData.notices
          ..clear()
          ..addAll(notices);
      }
    } catch (e) {
      _log('notices', e);
    }
  }

  static Future<void> _syncOffices() async {
    try {
      final offices = await BackendRepository.fetchOffices();
      if (offices.isNotEmpty) {
        MockData.offices
          ..clear()
          ..addAll(offices);
      }
    } catch (e) {
      _log('offices', e);
    }
  }

  static Future<void> _syncCommunityPosts() async {
    try {
      final posts = await BackendRepository.fetchCommunityPosts();
      if (posts.isNotEmpty) {
        MockData.communityPosts
          ..clear()
          ..addAll(posts);
      }
    } catch (e) {
      _log('community posts', e);
    }
  }

  static Future<void> _syncDevelopers() async {
    try {
      final developers = await BackendRepository.fetchDevelopers();
      if (developers.isNotEmpty) {
        MockData.developers
          ..clear()
          ..addAll(developers);
      }
    } catch (e) {
      _log('developers', e);
    }
  }

  static Future<void> _syncServiceProviders() async {
    try {
      final providers = await BackendRepository.fetchServiceProviders();
      if (providers.isNotEmpty) {
        MockData.serviceProviders
          ..clear()
          ..addAll(providers);
      }
    } catch (e) {
      _log('service providers', e);
    }
  }

  /// Call this once right after a successful login/signup (see
  /// login_screen.dart / signup_screen.dart) — pulls whatever
  /// role-specific "mine"/incoming lists exist for the signed-in account
  /// so those screens show live data immediately. Same fallback rule as
  /// [syncPublicData]: any failure quietly keeps the existing mock data.
  static Future<void> syncUserData(UserRole role, {AdminType? adminType}) async {
    final tasks = <Future<void>>[_syncNotifications()];
    switch (role) {
      case UserRole.residentOwner:
        tasks.addAll([
          _syncMyMeetings(),
          _syncMyQuotes(),
          _syncMySoilTests(),
          _syncMyPayments(),
          _syncConstructionProjects(),
          _syncMyComplaints(),
          _syncMyBookings(),
        ]);
        break;
      case UserRole.serviceProvider:
        tasks.add(_syncProviderBookings());
        break;
      case UserRole.developer:
        tasks.addAll([_syncDeveloperQuotes(), _syncDeveloperMeetings(), _syncConstructionProjects(), _syncPlotArchive()]);
        break;
      case UserRole.admin:
        if (adminType == AdminType.jolshiriManagement) {
          tasks.addAll([_syncAllSoilTests(), _syncConstructionProjects(), _syncAllViewingRequests(), _syncPlotArchive(), _syncAllComplaints()]);
        }
        if (adminType == AdminType.jolshiriManagement || adminType == AdminType.armyOversight) {
          tasks.add(_syncSecurityReports());
        }
        break;
    }
    await Future.wait(tasks);
  }

  static Future<void> _syncConstructionProjects() async {
    try {
      final projects = await BackendRepository.fetchConstructionProjects();
      // Bug fix: this used to only replace MockData when the fetch came
      // back non-empty, so a resident/developer with zero REAL projects on
      // the backend kept seeing the hardcoded demo project (fake "Ashraf
      // Family Residence", Plot 7-142, with an already-completed soil
      // test) forever — making it look like their own data, hiding the
      // "Apply for soil testing" button (which only shows when there's no
      // existing application), and generally showing stale/wrong info. A
      // successful fetch — even an empty one — is the real truth for this
      // account and must always replace the mock seed.
      MockData.constructionProjects
        ..clear()
        ..addAll(projects);
    } catch (e) {
      _log('construction projects', e);
    }
  }

  static Future<void> _syncAllViewingRequests() async {
    try {
      final requests = await BackendRepository.fetchAllViewingRequests();
      if (requests.isNotEmpty) {
        MockData.viewingRequests
          ..clear()
          ..addAll(requests);
      }
    } catch (e) {
      _log('viewing requests', e);
    }
  }

  static Future<void> _syncNotifications() async {
    try {
      final notifications = await BackendRepository.fetchMyNotifications();
      MockData.notifications
        ..clear()
        ..addAll(notifications);
    } catch (e) {
      _log('notifications', e);
    }
  }

  static Future<void> _syncMyMeetings() async {
    try {
      final meetings = await BackendRepository.fetchMyMeetings();
      // Always reflect the real list (even empty) — see the note on
      // _syncConstructionProjects above for why an isNotEmpty guard here
      // was hiding/confusing resident data with the mock seed.
      MockData.developerMeetings
        ..clear()
        ..addAll(meetings);
    } catch (e) {
      _log('meetings', e);
    }
  }

  static Future<void> _syncMyQuotes() async {
    try {
      final quotes = await BackendRepository.fetchMyQuotes();
      MockData.quoteRequests
        ..clear()
        ..addAll(quotes);
    } catch (e) {
      _log('quote requests', e);
    }
  }

  static Future<void> _syncMySoilTests() async {
    try {
      final applications = await BackendRepository.fetchMySoilTests();
      // Same class of bug as _syncConstructionProjects above — a resident
      // with zero real applications must see an empty list, not the
      // leftover mock "Imran Residence Extension" application (which had a
      // fake payment id that doesn't exist on the backend — the cause of
      // "Payment record not found" when tapping Pay now on it).
      MockData.soilTestApplications
        ..clear()
        ..addAll(applications);
    } catch (e) {
      _log('soil test applications', e);
    }
  }

  static Future<void> _syncMyPayments() async {
    try {
      final payments = await BackendRepository.fetchMyPayments();
      // Same fix as above — always reflect the real (possibly empty) list
      // so a stale mock PaymentRecord (with an id the backend has never
      // heard of) can't stick around and 404 when the user taps Pay now.
      MockData.payments
        ..clear()
        ..addAll(payments);
    } catch (e) {
      _log('payments', e);
    }
  }

  static Future<void> _syncProviderBookings() async {
    try {
      final bookings = await BackendRepository.fetchProviderBookings();
      if (bookings.isNotEmpty) {
        MockData.serviceBookings
          ..clear()
          ..addAll(bookings);
      }
    } catch (e) {
      _log('provider bookings', e);
    }
  }

  static Future<void> _syncDeveloperQuotes() async {
    try {
      final quotes = await BackendRepository.fetchDeveloperQuotes();
      if (quotes.isNotEmpty) {
        MockData.quoteRequests
          ..clear()
          ..addAll(quotes);
      }
    } catch (e) {
      _log('developer quotes', e);
    }
  }

  static Future<void> _syncDeveloperMeetings() async {
    try {
      final meetings = await BackendRepository.fetchDeveloperMeetings();
      if (meetings.isNotEmpty) {
        MockData.developerMeetings
          ..clear()
          ..addAll(meetings);
      }
    } catch (e) {
      _log('developer meetings', e);
    }
  }

  static Future<void> _syncAllSoilTests() async {
    try {
      final applications = await BackendRepository.fetchAllSoilTests();
      if (applications.isNotEmpty) {
        MockData.soilTestApplications
          ..clear()
          ..addAll(applications);
      }
    } catch (e) {
      _log('soil test applications', e);
    }
  }

  static Future<void> _syncMyBookings() async {
    try {
      final bookings = await BackendRepository.fetchMyBookings();
      // Always remove any stale mock booking attributed to this user, even
      // when the real list is empty — otherwise a fake booking under their
      // name lingers forever (same class of bug as _syncConstructionProjects).
      MockData.serviceBookings
        ..removeWhere((b) => b.customerName == MockData.currentUser.fullName)
        ..insertAll(0, bookings);
    } catch (e) {
      _log('my bookings', e);
    }
  }

  static Future<void> _syncMyComplaints() async {
    try {
      final complaints = await BackendRepository.fetchMyComplaints();
      MockData.complaints
        ..removeWhere((c) => c.id != null)
        ..insertAll(0, complaints);
    } catch (e) {
      _log('my complaints', e);
    }
  }

  static Future<void> _syncAllComplaints() async {
    try {
      final complaints = await BackendRepository.fetchAllComplaints();
      if (complaints.isNotEmpty) {
        MockData.complaints
          ..clear()
          ..addAll(complaints);
      }
    } catch (e) {
      _log('all complaints', e);
    }
  }

  static Future<void> _syncSecurityReports() async {
    try {
      final reports = await BackendRepository.fetchSecurityReports();
      if (reports.isNotEmpty) {
        MockData.securityReports
          ..clear()
          ..addAll(reports);
      }
    } catch (e) {
      _log('security reports', e);
    }
  }

  static Future<void> _syncPlotArchive() async {
    try {
      final plots = await BackendRepository.fetchPlotArchive();
      if (plots.isNotEmpty) {
        MockData.livePlotArchive
          ..clear()
          ..addAll(plots);
      }
    } catch (e) {
      _log('plot archive', e);
    }
  }

  static void _log(String what, Object e) {
    if (e is ApiUnreachableException) {
      debugPrint('[BackendSync] backend unreachable — keeping mock $what');
    } else {
      debugPrint('[BackendSync] failed to load $what from backend: $e — keeping mock data');
    }
  }
}
