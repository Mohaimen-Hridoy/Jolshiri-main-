import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

// Jolshiri Abashon's real centre (verified via OpenStreetMap — Kayetpara,
// Rupganj Upazila, Narayanganj) — used as the map's initial camera position
// and as the destination for the AppBar's "my location" shortcut into
// Google Maps.
const double _jolshiriLat = 23.81119;
const double _jolshiriLng = 90.50089;

/// Opens Google Maps (app if installed, else the web) centred on [point],
/// via a plain Google Maps URL — no API key or native SDK setup needed.
/// Falls back to a snackbar if no maps app/browser can handle the link.
Future<void> _openInGoogleMaps(BuildContext context, {required String label, double? lat, double? lng}) async {
  final query = (lat != null && lng != null) ? '$lat,$lng' : Uri.encodeComponent('$label, Jolshiri Abashon, Purbachal, Dhaka');
  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    showActionSnackBar(context, 'Could not open Google Maps');
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String _filter = 'All';
  MapPoint? _selected;
  final MapController _mapController = MapController();

  static const categories = ['All', 'Plot', 'Park', 'Lake', 'Golf Course', 'School', 'Restaurant', 'Office'];

  static const LatLng _initialCenter = LatLng(_jolshiriLat, _jolshiriLng);

  IconData _iconFor(String category) => switch (category) {
        'Plot' => Icons.crop_square_rounded,
        'Park' => Icons.park_outlined,
        'Lake' => Icons.water_outlined,
        'Golf Course' => Icons.golf_course_outlined,
        'School' => Icons.school_outlined,
        'Restaurant' => Icons.restaurant_outlined,
        'Office' => Icons.apartment_outlined,
        _ => Icons.place_outlined,
      };

  Color _colorFor(String category) => switch (category) {
        'Plot' => AppColors.brass,
        'Park' => AppColors.lake,
        'Lake' => AppColors.lake,
        'Golf Course' => AppColors.lake,
        'School' => AppColors.parade,
        'Restaurant' => AppColors.brick,
        'Office' => AppColors.parade,
        _ => AppColors.ink,
      };

  @override
  Widget build(BuildContext context) {
    final points = MockData.mapPoints.where((p) => _filter == 'All' || p.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              _filter == 'All' ? Icons.map_outlined : _iconFor(_filter),
              color: _filter == 'All' ? AppColors.parade : _colorFor(_filter),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(_filter == 'All' ? 'Jolshiri Map' : _filter),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open in Google Maps',
            icon: const Icon(Icons.my_location_outlined),
            onPressed: () => _openInGoogleMaps(context, label: 'Jolshiri Abashon', lat: _jolshiriLat, lng: _jolshiriLng),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = categories[i];
                final selected = c == _filter;
                return ChoiceChip(
                  avatar: Icon(
                    c == 'All' ? Icons.apps_outlined : _iconFor(c),
                    size: 16,
                    color: selected ? Colors.white : (c == 'All' ? AppColors.ink : _colorFor(c)),
                  ),
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _filter = c;
                      _selected = null;
                    });
                    // Fly to the centroid of the filtered markers so the
                    // user immediately sees the relevant pins.
                    final filtered = MockData.mapPoints
                        .where((p) => c == 'All' || p.category == c)
                        .where((p) => p.latitude != null && p.longitude != null)
                        .toList();
                    if (filtered.isEmpty) return;
                    final avgLat = filtered.map((p) => p.latitude!).reduce((a, b) => a + b) / filtered.length;
                    final avgLng = filtered.map((p) => p.longitude!).reduce((a, b) => a + b) / filtered.length;
                    final zoom = filtered.length == 1 ? 16.5 : (c == 'All' ? 15.0 : 15.5);
                    _mapController.move(LatLng(avgLat, avgLng), zoom);
                  },
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600, fontSize: 12.5),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 15,
                  ),
                  children: [
                    // OpenStreetMap tiles — free, no API key or billing needed.
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.jolshiri_smart_city',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final p in points)
                          if (p.latitude != null && p.longitude != null)
                            Marker(
                              point: LatLng(p.latitude!, p.longitude!),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _selected = p);
                                  _mapController.move(LatLng(p.latitude!, p.longitude!), _mapController.camera.zoom);
                                },
                                child: _Marker(color: _colorFor(p.category), icon: _iconFor(p.category)),
                              ),
                            ),
                      ],
                    ),
                    // Attribution is required by OpenStreetMap's usage policy.
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _selected == null
                ? Text('Tap a marker to see details.', style: Theme.of(context).textTheme.bodyMedium)
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(_iconFor(_selected!.category), color: _colorFor(_selected!.category)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selected!.name, style: Theme.of(context).textTheme.titleMedium),
                                Text(_selected!.category, style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.directions_outlined, size: 18),
                            onPressed: () => _openInGoogleMaps(
                              context,
                              label: _selected!.name,
                              lat: _selected!.latitude,
                              lng: _selected!.longitude,
                            ),
                            label: const Text('Navigate'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _Marker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}


