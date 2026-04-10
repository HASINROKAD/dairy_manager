import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as geo;

enum _PickerMapStyle { street, satellite }

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.initialCenter,
    this.initialSelection,
  });

  final geo.LatLng initialCenter;
  final geo.LatLng? initialSelection;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();
  geo.LatLng? _selectedPoint;
  _PickerMapStyle _mapStyle = _PickerMapStyle.street;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialSelection ?? widget.initialCenter;
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

  String get _tileUrl {
    switch (_mapStyle) {
      case _PickerMapStyle.street:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _PickerMapStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
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
                urlTemplate: _tileUrl,
                userAgentPackageName: 'com.example.dairy_manager',
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
            top: 12,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<_PickerMapStyle>(
                    value: _mapStyle,
                    borderRadius: BorderRadius.circular(12),
                    iconSize: 20,
                    icon: const Icon(Icons.layers_rounded, size: 20),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _mapStyle = value;
                      });
                    },
                    items: const [
                      DropdownMenuItem(
                        value: _PickerMapStyle.street,
                        child: Text('Street'),
                      ),
                      DropdownMenuItem(
                        value: _PickerMapStyle.satellite,
                        child: Text('Satellite'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                      'Use Street or Satellite from top-right layer button.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
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
