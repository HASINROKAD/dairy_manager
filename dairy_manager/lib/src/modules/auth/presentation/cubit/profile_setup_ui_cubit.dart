import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

enum PickerMapStyle { street, satellite }

class ProfileSetupUiCubit extends Cubit<ProfileSetupUiState> {
  ProfileSetupUiCubit({
    String? initialRole,
    double? initialLatitude,
    double? initialLongitude,
  }) : super(
         ProfileSetupUiState.initial(
           selectedRole: initialRole,
           selectedLatitude: initialLatitude,
           selectedLongitude: initialLongitude,
         ),
       );

  void setRole(String? role) {
    emit(state.copyWith(selectedRole: role));
  }

  void setLocation({required double latitude, required double longitude}) {
    emit(
      state.copyWith(selectedLatitude: latitude, selectedLongitude: longitude),
    );
  }

  void setPickingLocation(bool isPickingLocation) {
    emit(state.copyWith(isPickingLocation: isPickingLocation));
  }

  void setMapStyle(PickerMapStyle mapStyle) {
    emit(state.copyWith(mapStyle: mapStyle));
  }

  LatLng? selectedPoint({LatLng? fallback}) {
    if (state.selectedLatitude == null || state.selectedLongitude == null) {
      return fallback;
    }
    return LatLng(state.selectedLatitude!, state.selectedLongitude!);
  }
}

class ProfileSetupUiState extends Equatable {
  const ProfileSetupUiState({
    required this.selectedRole,
    required this.selectedLatitude,
    required this.selectedLongitude,
    required this.isPickingLocation,
    required this.mapStyle,
  });

  factory ProfileSetupUiState.initial({
    required String? selectedRole,
    required double? selectedLatitude,
    required double? selectedLongitude,
  }) {
    return ProfileSetupUiState(
      selectedRole: selectedRole,
      selectedLatitude: selectedLatitude,
      selectedLongitude: selectedLongitude,
      isPickingLocation: false,
      mapStyle: PickerMapStyle.street,
    );
  }

  final String? selectedRole;
  final double? selectedLatitude;
  final double? selectedLongitude;
  final bool isPickingLocation;
  final PickerMapStyle mapStyle;

  ProfileSetupUiState copyWith({
    String? selectedRole,
    double? selectedLatitude,
    double? selectedLongitude,
    bool? isPickingLocation,
    PickerMapStyle? mapStyle,
  }) {
    return ProfileSetupUiState(
      selectedRole: selectedRole ?? this.selectedRole,
      selectedLatitude: selectedLatitude ?? this.selectedLatitude,
      selectedLongitude: selectedLongitude ?? this.selectedLongitude,
      isPickingLocation: isPickingLocation ?? this.isPickingLocation,
      mapStyle: mapStyle ?? this.mapStyle,
    );
  }

  @override
  List<Object?> get props => [
    selectedRole,
    selectedLatitude,
    selectedLongitude,
    isPickingLocation,
    mapStyle,
  ];
}
