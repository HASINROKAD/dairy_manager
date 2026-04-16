import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  void _moveToSelectedOrInitialPoint(geo.LatLng? selectedPoint) {
    final target = selectedPoint ?? widget.initialCenter;
    _mapController.move(target, 16);
  }

  String _tileUrlFor(PickerMapStyle mapStyle) {
    switch (mapStyle) {
      case PickerMapStyle.street:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case PickerMapStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.uiCubit,
      child: BlocBuilder<ProfileSetupUiCubit, ProfileSetupUiState>(
        builder: (context, uiState) {
          final selectedPoint = widget.uiCubit.selectedPoint(
            fallback: widget.initialSelection,
          );

          return Scaffold(
            appBar: AppBar(title: const Text('Pick Location')),
            body: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.initialCenter,
                    initialZoom: 15,
                    onTap: (_, point) => widget.uiCubit.setLocation(
                      latitude: point.latitude,
                      longitude: point.longitude,
                    ),
                    onLongPress: (_, point) => widget.uiCubit.setLocation(
                      latitude: point.latitude,
                      longitude: point.longitude,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _tileUrlFor(uiState.mapStyle),
                      userAgentPackageName: 'com.example.dairy_manager',
                    ),
                    MarkerLayer(
                      markers: selectedPoint == null
                          ? const <Marker>[]
                          : [
                              Marker(
                                point: selectedPoint,
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
                        child: DropdownButton<PickerMapStyle>(
                          value: uiState.mapStyle,
                          borderRadius: BorderRadius.circular(12),
                          iconSize: 20,
                          icon: const Icon(Icons.layers_rounded, size: 20),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            widget.uiCubit.setMapStyle(value);
                          },
                          items: const [
                            DropdownMenuItem(
                              value: PickerMapStyle.street,
                              child: Text('Street'),
                            ),
                            DropdownMenuItem(
                              value: PickerMapStyle.satellite,
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
                    onPressed: () =>
                        _moveToSelectedOrInitialPoint(selectedPoint),
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
                          const Text(
                            'Tap map to place the red pin (or long-press).',
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Use Street or Satellite from top-right layer button.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: selectedPoint == null
                                  ? null
                                  : () => Navigator.of(
                                      context,
                                    ).pop(selectedPoint),
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
        },
      ),
    );
  }
}
