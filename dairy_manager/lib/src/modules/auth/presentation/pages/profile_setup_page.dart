import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../../../core/utility/network/connectivity_recovery_bus.dart';
import '../../../../../core/utility/routes/app_routes.dart';
import '../../auth_barrel.dart';
import '../cubit/profile_setup_ui_cubit.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _shopNameController = TextEditingController();

  late final ProfileSetupUiCubit _uiCubit;
  StreamSubscription<int>? _connectivityRecoverySubscription;
  bool _retryProfileSaveOnReconnect = false;

  @override
  void initState() {
    super.initState();

    String? selectedRole;
    double? selectedLatitude;
    double? selectedLongitude;

    final state = context.read<AuthCubit>().state;
    if (state is AuthProfileIncomplete) {
      _nameController.text = state.user.name ?? '';
      _mobileController.text = state.user.mobileNumber ?? '';
      _addressController.text = state.user.displayAddress ?? '';
      selectedLatitude = state.user.latitude;
      selectedLongitude = state.user.longitude;
      _shopNameController.text = state.user.shopName ?? '';
      selectedRole = state.user.role;
    }

    _uiCubit = ProfileSetupUiCubit(
      initialRole: selectedRole,
      initialLatitude: selectedLatitude,
      initialLongitude: selectedLongitude,
    );

    _connectivityRecoverySubscription = ConnectivityRecoveryBus.stream.listen((
      _,
    ) {
      if (!mounted || !_retryProfileSaveOnReconnect) {
        return;
      }

      final state = context.read<AuthCubit>().state;
      if (state is AuthLoading) {
        return;
      }

      _submitProfile();
    });
  }

  @override
  void dispose() {
    _connectivityRecoverySubscription?.cancel();
    _uiCubit.close();
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  Future<String> _resolveAddressFromCoordinates(LatLng point) async {
    try {
      // Try geocoding with 2-second timeout to prevent UI freeze
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      ).timeout(const Duration(seconds: 2), onTimeout: () => <Placemark>[]);

      if (placemarks.isEmpty) {
        // Fallback to coordinates if geocoding fails/times out
        return 'Location: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      }

      final place = placemarks.first;
      final parts =
          <String?>[
                place.street,
                place.subLocality,
                place.locality,
                place.administrativeArea,
                place.postalCode,
                place.country,
              ]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toList();

      if (parts.isEmpty) {
        return 'Location: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      }

      return parts.join(', ');
    } catch (_) {
      return 'Location: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
    }
  }

  Future<void> _pickOnMap() async {
    if (_uiCubit.state.isPickingLocation) {
      return;
    }

    _uiCubit.setPickingLocation(true);

    final bool hasExistingLocation =
        _uiCubit.state.selectedLatitude != null &&
        _uiCubit.state.selectedLongitude != null;

    try {
      final permissionApproved = await _ensureLocationPermission();
      if (!permissionApproved || !mounted) {
        return;
      }

      final initialCenter = await _resolveInitialCenter(hasExistingLocation);
      if (!mounted) {
        return;
      }

      final selectedPoint = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(
          builder: (_) => LocationPickerPage(
            initialCenter: initialCenter,
            uiCubit: _uiCubit,
            initialSelection: hasExistingLocation
                ? LatLng(
                    _uiCubit.state.selectedLatitude!,
                    _uiCubit.state.selectedLongitude!,
                  )
                : null,
          ),
        ),
      );

      if (selectedPoint == null || !mounted) {
        return;
      }

      // Save coordinates immediately
      _uiCubit.setLocation(
        latitude: selectedPoint.latitude,
        longitude: selectedPoint.longitude,
      );

      // Show loading while geocoding
      _addressController.text = 'Resolving location...';

      // Try to geocode with timeout - this won't freeze the UI
      final resolvedAddress = await _resolveAddressFromCoordinates(
        selectedPoint,
      );

      if (!mounted) {
        return;
      }

      // Update address field with result
      _addressController.text = resolvedAddress;
    } finally {
      if (mounted) {
        _uiCubit.setPickingLocation(false);
      }
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Please enable device location services to continue.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: Geolocator.openLocationSettings,
            ),
          ),
        );
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission denied. Please allow it to pick your location.',
            ),
          ),
        );
      }
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location permission is permanently denied. Open settings to allow it.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: Geolocator.openAppSettings,
            ),
          ),
        );
      }
      return false;
    }

    return true;
  }

  Future<LatLng> _resolveInitialCenter(bool hasExistingLocation) async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return LatLng(lastKnown.latitude, lastKnown.longitude);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      if (hasExistingLocation) {
        return LatLng(
          _uiCubit.state.selectedLatitude!,
          _uiCubit.state.selectedLongitude!,
        );
      }
      return const LatLng(20.5937, 78.9629);
    }
  }

  void _submitProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_uiCubit.state.selectedLatitude == null ||
        _uiCubit.state.selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select location using Pick on Map.'),
        ),
      );
      return;
    }

    _retryProfileSaveOnReconnect = true;

    final role = _uiCubit.state.selectedRole ?? '';

    context.read<AuthCubit>().saveProfile(
      name: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      role: role,
      displayAddress: _addressController.text.trim(),
      latitude: _uiCubit.state.selectedLatitude!,
      longitude: _uiCubit.state.selectedLongitude!,
      shopName: role == 'seller' ? _shopNameController.text.trim() : null,
    );
  }

  bool _looksLikeNetworkIssue(String message) {
    final value = message.trim().toLowerCase();
    return value.contains('network') ||
        value.contains('internet') ||
        value.contains('connection') ||
        value.contains('timeout');
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _uiCubit,
      child: Scaffold(
        body: AuthStateFeedback(
          onAuthenticated: (context, _) {
            _retryProfileSaveOnReconnect = false;
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.authGate, (route) => false);
          },
          onError: (context, message) {
            _retryProfileSaveOnReconnect = _looksLikeNetworkIssue(message);
          },
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final loading = state is AuthLoading;

              return BlocBuilder<ProfileSetupUiCubit, ProfileSetupUiState>(
                builder: (context, uiState) {
                  return AppPageBody(
                    maxWidth: AppSizes.maxAuthWidth,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AuthPageHeader(
                            title: 'Complete Your Profile',
                            subtitle:
                                'Add role and location details for personalized access.',
                          ),
                          AppAuthTextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            label: 'Full Name',
                            icon: Icons.person_outline_rounded,
                            validator: AuthValidators.validateName,
                          ),
                          const SizedBox(height: AppSizes.fieldGap),
                          AppAuthTextField(
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            label: 'Mobile Number',
                            icon: Icons.phone_rounded,
                            validator: AuthValidators.validateMobile,
                          ),
                          const SizedBox(height: AppSizes.fieldGap),
                          DropdownButtonFormField<String>(
                            initialValue: uiState.selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'I am a',
                              prefixIcon: Icon(Icons.groups_rounded),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'seller',
                                child: Text('Seller'),
                              ),
                              DropdownMenuItem(
                                value: 'customer',
                                child: Text('Customer'),
                              ),
                            ],
                            validator: AuthValidators.validateRole,
                            onChanged: _uiCubit.setRole,
                          ),
                          const SizedBox(height: AppSizes.fieldGap),
                          if (uiState.selectedRole == 'seller') ...[
                            AppAuthTextField(
                              controller: _shopNameController,
                              textCapitalization: TextCapitalization.words,
                              label: 'Shop Name (optional)',
                              icon: Icons.storefront_rounded,
                              validator: (_) => null,
                            ),
                            const SizedBox(height: AppSizes.fieldGap),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: uiState.isPickingLocation
                                  ? null
                                  : _pickOnMap,
                              icon: const Icon(Icons.map_rounded),
                              label: Text(
                                uiState.isPickingLocation
                                    ? 'Opening map...'
                                    : 'Pick on Map',
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.fieldGap),
                          AppAuthTextField(
                            controller: _addressController,
                            textCapitalization: TextCapitalization.sentences,
                            label: 'Address / Location',
                            icon: Icons.location_on_rounded,
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return 'Please select location and provide address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.fieldGap),
                          const SizedBox(height: AppSizes.sectionGap),
                          AppPrimaryButton(
                            label: 'Save and Continue',
                            loading: loading,
                            onPressed: _submitProfile,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
