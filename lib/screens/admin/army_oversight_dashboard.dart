import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

// ── Jolshiri Abashon centre (Rupganj Upazila, Narayanganj) ───────────────────
const double _jolshiriLat = 23.81119;
const double _jolshiriLng = 90.50089;

// ── Map tile configuration ────────────────────────────────────────────────────
// Using OpenStreetMap tiles — free, no API key required.
// OSM tile policy: https://operations.osmfoundation.org/policies/tiles/
const String _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String _tileAttribution = 'Map data © OpenStreetMap contributors.';
const String _userAgent = 'com.jolshiri.smartcity';

// ── Static fallback clusters — shown when the backend is unreachable ─────────
// Coordinates are approximate block centres within Jolshiri Abashon.
// Severity/colour here just mirrors the count-based tiers (1-3 green,
// 4-6 orange, 7+ red) — see IncidentSeverity.forCount.
const _mockClusters = [
  IncidentCluster(
    block: 'Sector 1',
    incidents: 1,
    note: 'Gate damage',
    severity: IncidentSeverity.mild,
    latitude: 23.8136,
    longitude: 90.4986,
  ),
  IncidentCluster(
    block: 'Sector 2',
    incidents: 3,
    note: 'Suspicious vehicle, streetlight',
    severity: IncidentSeverity.mild,
    latitude: 23.8125,
    longitude: 90.5012,
  ),
  IncidentCluster(
    block: 'Sector 3',
    incidents: 5,
    note: 'SOS alert, loitering, noise',
    severity: IncidentSeverity.moderate,
    latitude: 23.8108,
    longitude: 90.5035,
  ),
  IncidentCluster(
    block: 'Sector 4',
    incidents: 2,
    note: 'Trespassing attempt',
    severity: IncidentSeverity.mild,
    latitude: 23.8095,
    longitude: 90.5005,
  ),
  IncidentCluster(
    block: 'Sector 7',
    incidents: 2,
    note: 'Vandalism report',
    severity: IncidentSeverity.mild,
    latitude: 23.8118,
    longitude: 90.4965,
  ),
];

class ArmyOversightDashboard extends StatelessWidget {
  const ArmyOversightDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabBodyHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - 48
            : MediaQuery.of(context).size.height * 0.62;
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                labelColor: AppColors.parade,
                unselectedLabelColor: AppColors.inkFaint,
                indicatorColor: AppColors.brass,
                tabs: [
                  Tab(text: 'Incident Monitoring'),
                  Tab(text: 'Security Heatmap'),
                ],
              ),
              SizedBox(
                height: tabBodyHeight.clamp(400, 900),
                child: const TabBarView(children: [
                  _IncidentTab(),
                  _HeatmapTab(),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Incident Tab
// ─────────────────────────────────────────────────────────────────────────────

class _IncidentTab extends StatefulWidget {
  const _IncidentTab();

  @override
  State<_IncidentTab> createState() => _IncidentTabState();
}

class _IncidentTabState extends State<_IncidentTab> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final reports = await BackendRepository.fetchSecurityReports();
      if (mounted && reports.isNotEmpty) {
        setState(() {
          MockData.securityReports..clear()..addAll(reports);
        });
      }
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setStatus(SecurityReport report, String status) async {
    if (report.id != null) {
      try {
        await BackendRepository.updateSecurityReportStatus(report.id!, status);
      } on ApiException catch (e) {
        if (!mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        // fall through — apply the optimistic local update anyway
      }
    }
    final index = MockData.securityReports.indexOf(report);
    if (index != -1) {
      setState(() {
        MockData.securityReports[index] = SecurityReport(
          id: report.id,
          title: report.title,
          description: report.description,
          status: status,
          reportedAt: report.reportedAt,
        );
      });
    }
    if (!mounted) return;
    showActionSnackBar(context, 'Marked as $status: ${report.title}');
  }

  @override
  Widget build(BuildContext context) {
    final reports = MockData.securityReports;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          const SectionHeader(eyebrow: 'Live', title: 'Incident Reports'),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            const EmptyState(
              icon: Icons.shield_outlined,
              title: 'No incident reports',
              message: 'Security reports residents file will show up here.',
            )
          else
            ...reports.map((r) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(r.title,
                                  style: Theme.of(context).textTheme.titleMedium)),
                          StatusPill.status(r.status),
                        ]),
                        const SizedBox(height: 6),
                        Text(r.description,
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.access_time_outlined,
                              size: 14, color: AppColors.inkFaint),
                          const SizedBox(width: 4),
                          Text(_relativeTime(r.reportedAt),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.inkFaint)),
                          const Spacer(),
                          if (r.status != 'In Progress' &&
                              r.status != 'Resolved')
                            TextButton(
                              onPressed: () => _setStatus(r, 'In Progress'),
                              child: const Text('Start review'),
                            ),
                          if (r.status != 'Resolved')
                            TextButton(
                              onPressed: () => _setStatus(r, 'Resolved'),
                              child: const Text('Resolve'),
                            ),
                        ]),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 20),
          const SectionHeader(eyebrow: 'Alerts', title: 'SOS & Suspicious Activity'),
          const SizedBox(height: 12),
          _AlertCard(
            icon: Icons.sos_outlined,
            color: AppColors.brick,
            title: 'SOS Alert — Sector 3',
            subtitle: 'Resident triggered emergency alert at 11:42 PM.',
            onAction: () => showActionSnackBar(context, 'SOS acknowledged'),
            actionLabel: 'Acknowledge',
          ),
          const SizedBox(height: 8),
          _AlertCard(
            icon: Icons.warning_amber_outlined,
            color: AppColors.brass,
            title: 'Suspicious activity — Gate 2',
            subtitle:
                'Unidentified individual loitering near Gate 2 for 45 minutes.',
            onAction: () =>
                showActionSnackBar(context, 'Unit dispatched to Gate 2'),
            actionLabel: 'Dispatch',
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onAction;
  final String actionLabel;

  const _AlertCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onAction,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Heatmap Tab — Google Maps or OpenStreetMap tiles + report-count-coloured circles
// ─────────────────────────────────────────────────────────────────────────────

class _HeatmapTab extends StatefulWidget {
  const _HeatmapTab();

  @override
  State<_HeatmapTab> createState() => _HeatmapTabState();
}

class _HeatmapTabState extends State<_HeatmapTab> {
  final MapController _mapController = MapController();
  IncidentCluster? _selected;

  // Cluster data — starts as mock; replaced by backend data when available.
  List<IncidentCluster> _clusters = List.unmodifiable(_mockClusters);
  bool _loading = false;
  bool _fromBackend = false;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
  }

  Future<void> _loadFromBackend() async {
    setState(() => _loading = true);
    try {
      final live = await BackendRepository.fetchHeatmapClusters();
      if (mounted && live.isNotEmpty) {
        setState(() {
          _clusters = List.unmodifiable(live);
          _fromBackend = true;
          _selected = null;
        });
      }
    } catch (_) {
      // backend unreachable — keep mock data, no error shown
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const LatLng _center = LatLng(_jolshiriLat, _jolshiriLng);

  // ── Count-based colour logic ──────────────────────────────────────────────
  //
  // Colour is driven purely by how many reports/SOS alerts a sector has
  // received (an SOS alert counts the same as any other report — it does
  // not force a sector red by itself):
  //   • 1-3 reports → green  (low)
  //   • 4-6 reports → orange (elevated)
  //   • 7+ reports  → red    (high, immediate attention)
  //
  // Incident count also controls circle size — bigger = more reports.
  //
  Color _severityColor(IncidentSeverity severity) {
    switch (severity) {
      case IncidentSeverity.severe:   return AppColors.brick;  // red
      case IncidentSeverity.moderate: return AppColors.brass;  // orange/gold
      case IncidentSeverity.mild:     return AppColors.lake;   // green/teal
    }
  }

  Future<void> _openGoogleMaps(IncidentCluster c) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${c.latitude},${c.longitude}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      showActionSnackBar(context, 'Could not open Google Maps');
    }
  }

  @override
  Widget build(BuildContext context) {
    final clusters = _clusters;
    if (clusters.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // Max incident count — used only for circle SIZE scaling (not colour).
    final maxCount = clusters
        .map((c) => c.incidents)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(eyebrow: 'Live Map', title: 'Incident Heatmap'),
        const SizedBox(height: 4),
        // Source badge + loading indicator
        Row(children: [
          if (_loading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Icon(
              _fromBackend ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 14,
              color: _fromBackend ? AppColors.lake : AppColors.inkFaint,
            ),
          const SizedBox(width: 5),
          Text(
            _fromBackend ? 'Live data from server' : 'Showing sample data (server offline)',
            style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadFromBackend,
            child: const Icon(Icons.refresh, size: 16, color: AppColors.inkFaint),
          ),
        ]),
        const SizedBox(height: 8),
        // Legend row — explains the report-count colour scheme
        const _SeverityLegend(),
        const SizedBox(height: 12),
        // ── Map ─────────────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 320,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 14.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onTap: (_, __) => setState(() => _selected = null),
              ),
              children: [
                // OpenStreetMap tile layer — free, no API key required.
                TileLayer(
                  urlTemplate: _tileUrl,
                  userAgentPackageName: _userAgent,
                ),
                // Filled circle markers — one per block cluster.
                // SIZE   = incident count (scaled 16–32 px radius).
                // COLOUR = report count tier (1-3 green / 4-6 orange / 7+ red).
                CircleLayer(
                  circles: clusters.map((c) {
                    final color = _severityColor(c.severity);
                    final sizeRatio = c.incidents / maxCount;
                    final isSelected = _selected == c;
                    return CircleMarker(
                      point: LatLng(c.latitude, c.longitude),
                      // Radius scales with incident count (min 16, max 32 px).
                      radius: 16 + (sizeRatio * 16),
                      color: color.withValues(
                          alpha: isSelected ? 0.85 : 0.60),
                      borderColor: color,
                      borderStrokeWidth: isSelected ? 2.5 : 1.5,
                      useRadiusInMeter: false,
                    );
                  }).toList(),
                ),
                // Tappable marker layer on top for tap-detection
                MarkerLayer(
                  markers: clusters.map((c) {
                    final color = _severityColor(c.severity);
                    return Marker(
                      point: LatLng(c.latitude, c.longitude),
                      width: 80,
                      height: 48,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selected = _selected == c ? null : c),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${c.incidents}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c.block,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        // ── Selected cluster detail card ─────────────────────────────────────
        if (_selected != null) ...[
          const SizedBox(height: 12),
          _ClusterDetailCard(
            cluster: _selected!,
            severityColor: _severityColor(_selected!.severity),
            onOpenMap: () => _openGoogleMaps(_selected!),
          ),
        ],
        const SizedBox(height: 16),
        // ── Bar-chart summary (blocks list) ──────────────────────────────────
        const SectionHeader(eyebrow: 'Summary', title: 'Incidents by Sector'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: clusters.map((c) {
                final color = _severityColor(c.severity);
                final sizeRatio = c.incidents / maxCount;
                final isSelected = _selected == c;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selected = isSelected ? null : c);
                    _mapController.move(
                        LatLng(c.latitude, c.longitude), 15.5);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: isSelected
                        ? const EdgeInsets.all(8)
                        : EdgeInsets.zero,
                    decoration: isSelected
                        ? BoxDecoration(
                            color: color.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: color.withValues(alpha: 0.3),
                                width: 1),
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          // Severity-coloured dot
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(c.block,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                          // Severity badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              c.severity.label,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Incident count badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.paperDim,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${c.incidents} incident${c.incidents == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        // Progress bar shows relative volume (same count that drives colour)
                        LinearProgressIndicator(
                          value: sizeRatio,
                          backgroundColor: AppColors.paperDim,
                          color: color,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 3),
                        Text(c.note,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.inkFaint)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Attribution note (switches between OSM and Google Maps)
        const Text(
          '$_tileAttribution  '
          'Tap a block row or a map circle to highlight it.',
          style: TextStyle(fontSize: 10.5, color: AppColors.inkFaint),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

/// Colour legend explaining the report-count colour scheme.
class _SeverityLegend extends StatelessWidget {
  const _SeverityLegend();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: AppColors.paperDim,
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Circle colour = number of reports/SOS alerts in that sector',
              style: TextStyle(fontSize: 11, color: AppColors.inkFaint),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                _LegendDot(color: AppColors.lake, label: 'Green',
                    hint: '1-3 reports'),
                SizedBox(width: 14),
                _LegendDot(color: AppColors.brass, label: 'Orange',
                    hint: '4-6 reports'),
                SizedBox(width: 14),
                _LegendDot(color: AppColors.brick, label: 'Red',
                    hint: '7+ reports'),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'An SOS alert counts the same as a normal report — it does not '
              'turn a sector red by itself; the total count does.',
              style: TextStyle(fontSize: 10, color: AppColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final String hint;
  const _LegendDot({
    required this.color,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkFaint)),
          Text(hint,
              style: const TextStyle(fontSize: 9, color: AppColors.inkFaint)),
        ],
      ),
    ]);
  }
}

class _ClusterDetailCard extends StatelessWidget {
  final IncidentCluster cluster;
  final Color severityColor;
  final VoidCallback onOpenMap;

  const _ClusterDetailCard({
    required this.cluster,
    required this.severityColor,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: severityColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: severityColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(cluster.block,
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(cluster.severity.label,
                    style: TextStyle(
                        color: severityColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              '${cluster.incidents} incident${cluster.incidents == 1 ? '' : 's'} reported',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(cluster.note,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.inkFaint)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.inkFaint),
              const SizedBox(width: 4),
              Text(
                '${cluster.latitude.toStringAsFixed(4)}, '
                '${cluster.longitude.toStringAsFixed(4)}',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.inkFaint),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Open in Maps'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.parade,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
