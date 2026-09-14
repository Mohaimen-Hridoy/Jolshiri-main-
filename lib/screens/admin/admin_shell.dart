import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_bell.dart';
import '../auth/login_screen.dart';
import 'jolshiri_management_dashboard.dart';
import 'army_oversight_dashboard.dart';
import 'system_moderator_dashboard.dart';

class AdminShell extends StatelessWidget {
  final AdminType adminType;
  const AdminShell({super.key, required this.adminType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(adminType.label),
        actions: [
          const NotificationBellButton(),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              // Was navigating to LoginScreen without ever clearing the
              // saved session — see the same fix in resident/profile_screen.dart.
              await AuthSession.clear();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const SectionHeader(eyebrow: 'Overview', title: 'KPI Dashboard'),
          const SizedBox(height: 16),
          const _KpiGrid(),
          const SizedBox(height: 28),
          const SectionHeader(eyebrow: 'Management', title: 'Admin Panel'),
          const SizedBox(height: 16),
          _adminDashboard(),
        ],
      ),
    );
  }

  Widget _adminDashboard() {
    switch (adminType) {
      case AdminType.jolshiriManagement:
        return const JolshiriManagementDashboard();
      case AdminType.armyOversight:
        return const ArmyOversightDashboard();
      case AdminType.systemModerator:
        return const SystemModeratorDashboard();
    }
  }
}

class _KpiGrid extends StatefulWidget {
  const _KpiGrid();

  @override
  State<_KpiGrid> createState() => _KpiGridState();
}

class _KpiGridState extends State<_KpiGrid> {
  static const _fallback = [
    _KpiData(Icons.people_outline, 'Registered Residents', '1,248', AppColors.parade),
    _KpiData(Icons.home_work_outlined, 'Rental Listings', '342', AppColors.lake),
    _KpiData(Icons.construction_outlined, 'Active Projects', '18', AppColors.brass),
    _KpiData(Icons.handyman_outlined, 'Registered Providers', '27', AppColors.brick),
    _KpiData(Icons.shield_outlined, 'Open Security Reports', '3', AppColors.brick),
    _KpiData(Icons.key_outlined, 'Pending Viewing Requests', '9', AppColors.lake),
    _KpiData(Icons.groups_outlined, 'Registered Developers', '14', AppColors.parade),
    _KpiData(Icons.fact_check_outlined, 'Stages Pending Approval', '5', AppColors.brass),
  ];

  List<_KpiData>? _live;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final k = await BackendRepository.fetchAdminKpis();
      if (!mounted) return;
      setState(() {
        _live = [
          _KpiData(Icons.people_outline, 'Registered Residents', '${k.residentCount}', AppColors.parade),
          _KpiData(Icons.home_work_outlined, 'Rental Listings', '${k.rentalCount}', AppColors.lake),
          _KpiData(Icons.construction_outlined, 'Active Projects', '${k.activeProjects}', AppColors.brass),
          _KpiData(Icons.handyman_outlined, 'Registered Providers', '${k.providerCount}', AppColors.brick),
          _KpiData(Icons.shield_outlined, 'Open Security Reports', '${k.openSecurityReports}', AppColors.brick),
          _KpiData(Icons.key_outlined, 'Pending Viewing Requests', '${k.pendingViewingRequests}', AppColors.lake),
          _KpiData(Icons.groups_outlined, 'Registered Developers', '${k.developerCount}', AppColors.parade),
          _KpiData(Icons.fact_check_outlined, 'Stages Pending Approval', '${k.stagesPendingApproval}', AppColors.brass),
        ];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false); // fall back to _fallback below
    }
  }

  @override
  Widget build(BuildContext context) {
    final kpis = _live ?? _fallback;
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_loading) const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemCount: kpis.length,
          itemBuilder: (context, i) => _KpiCard(data: kpis[i]),
        ),
      ],
    );
  }
}

class _KpiData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _KpiData(this.icon, this.label, this.value, this.color);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(data.icon, color: data.color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: data.color)),
              Text(data.label,
                  style: const TextStyle(fontSize: 11, color: AppColors.inkFaint, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}
