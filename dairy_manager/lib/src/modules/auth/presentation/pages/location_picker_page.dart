import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as geo;

import '../cubit/profile_setup_ui_cubit.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.initialCenter,
    required this.uiCubit,
    this.initialSelection,
  });

  final geo.LatLng initialCenter;
  final ProfileSetupUiCubit uiCubit;
  final geo.LatLng? initialSelection;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();
  static const String _streetTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  late geo.LatLng? _selectedPoint;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialSelection;
  }

  void _setSelectedPoint(geo.LatLng point) {
    setState(() {
      _selectedPoint = point;
    });
  }

  void _moveToSelectedOrInitialPoint() {
    final target = _selectedPoint ?? widget.initialCenter;
    _mapController.move(target, 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 15,
              onTap: (_, point) => _setSelectedPoint(point),
              onLongPress: (_, point) => _setSelectedPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate: _streetTileUrl,
                userAgentPackageName: 'com.example.dairy_manager',
                tileDimension: 256,
                maxZoom: 18.0,
                minZoom: 1.0,
              ),
              MarkerLayer(
                markers: _selectedPoint == null
                    ? const <Marker>[]
                    : [
                        Marker(
                          point: _selectedPoint!,
                          rotate: false,
                          width: 42,
                          height: 42,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
              ),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 140,
            child: FloatingActionButton.small(
              onPressed: _moveToSelectedOrInitialPoint,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tap map to place the red pin (or long-press).'),
                    const SizedBox(height: 4),
                    const Text(
                      'Street map view is enabled for stable location selection.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (_selectedPoint != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Selected: ${_selectedPoint!.latitude.toStringAsFixed(5)}, ${_selectedPoint!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _selectedPoint == null
                            ? null
                            : () => Navigator.of(context).pop(_selectedPoint),
                        child: const Text('Use This Location'),
                      ),
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
