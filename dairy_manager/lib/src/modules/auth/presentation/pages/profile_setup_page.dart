import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../../../core/utility/routes/app_routes.dart';
import '../../auth_barrel.dart';

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

  String? _selectedRole;
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isPickingLocation = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthCubit>().state;
    if (state is AuthProfileIncomplete) {
      _nameController.text = state.user.name ?? '';
      _mobileController.text = state.user.mobileNumber ?? '';
      _addressController.text = state.user.displayAddress ?? '';
      _selectedLatitude = state.user.latitude;
      _selectedLongitude = state.user.longitude;
      _shopNameController.text = state.user.shopName ?? '';
      _selectedRole = state.user.role;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  Future<String> _resolveAddressFromCoordinates(LatLng point) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      ).timeout(const Duration(seconds: 8));

      if (placemarks.isEmpty) {
        return 'Selected map location';
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
        return 'Selected map location';
      }

      return parts.join(', ');
    } catch (_) {
      return 'Selected map location';
    }
  }

  Future<void> _pickOnMap() async {
    if (_isPickingLocation) {
      return;
    }

    setState(() {
      _isPickingLocation = true;
    });

    final bool hasExistingLocation =
        _selectedLatitude != null && _selectedLongitude != null;

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
            initialSelection: hasExistingLocation
                ? LatLng(_selectedLatitude!, _selectedLongitude!)
                : null,
          ),
        ),
      );

      if (selectedPoint == null || !mounted) {
        return;
      }

      setState(() {
        _selectedLatitude = selectedPoint.latitude;
        _selectedLongitude = selectedPoint.longitude;
        _addressController.text = 'Resolving address...';
      });

      final resolvedAddress = await _resolveAddressFromCoordinates(
        selectedPoint,
      );
      if (!mounted) {
        return;
      }

      // Prevent stale geocode results from overwriting a newer location selection.
      if (_selectedLatitude == selectedPoint.latitude &&
          _selectedLongitude == selectedPoint.longitude) {
        setState(() {
          _addressController.text = resolvedAddress;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingLocation = false;
        });
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
        return LatLng(_selectedLatitude!, _selectedLongitude!);
      }
      return const LatLng(20.5937, 78.9629);
    }
  }

  void _submitProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLatitude == null || _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select location using Pick on Map.'),
        ),
      );
      return;
    }

    final role = _selectedRole ?? '';

    context.read<AuthCubit>().saveProfile(
      name: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      role: role,
      displayAddress: _addressController.text.trim(),
      latitude: _selectedLatitude!,
      longitude: _selectedLongitude!,
      shopName: role == 'seller' ? _shopNameController.text.trim() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
          }

          if (state is AuthError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;

          return AppPageBody(
            maxWidth: AppSizes.maxAuthWidth,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Complete Your Profile',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add role and location details for personalized access.',
                  ),
                  const SizedBox(height: AppSizes.sectionGap),
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
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'I am a',
                      prefixIcon: Icon(Icons.groups_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'seller', child: Text('Seller')),
                      DropdownMenuItem(
                        value: 'customer',
                        child: Text('Customer'),
                      ),
                    ],
                    validator: AuthValidators.validateRole,
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppSizes.fieldGap),
                  if (_selectedRole == 'seller') ...[
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
                      onPressed: _isPickingLocation ? null : _pickOnMap,
                      icon: const Icon(Icons.map_rounded),
                      label: Text(
                        _isPickingLocation ? 'Opening map...' : 'Pick on Map',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.fieldGap),
                  FormField<void>(
                    validator: (_) {
                      if (_selectedLatitude == null ||
                          _selectedLongitude == null) {
                        return 'Please select location on map';
                      }
                      if (_addressController.text.trim().isEmpty) {
                        return 'Address could not be resolved for selected point';
                      }
                      return null;
                    },
                    builder: (state) {
                      final selectedAddress = _addressController.text.trim();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: state.hasError
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Text(
                              selectedAddress.isNotEmpty
                                  ? selectedAddress
                                  : 'Location not selected yet.',
                            ),
                          ),
                          if (state.hasError) ...[
                            const SizedBox(height: 6),
                            Text(
                              state.errorText ?? '',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      );
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
      ),
    );
  }
}
