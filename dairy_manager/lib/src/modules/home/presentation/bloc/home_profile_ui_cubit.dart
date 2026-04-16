import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

class HomeProfileUiCubit extends Cubit<HomeProfileUiState> {
  HomeProfileUiCubit() : super(const HomeProfileUiState.initial());

  void toggleEditing() {
    emit(state.copyWith(isEditing: !state.isEditing));
  }

  void setEditing(bool isEditing) {
    emit(state.copyWith(isEditing: isEditing));
  }

  void startSubmitting() {
    emit(state.copyWith(isSubmitting: true));
  }

  void finishSubmitting({required bool stayInEditMode}) {
    emit(
      state.copyWith(
        isSubmitting: false,
        isEditing: stayInEditMode ? state.isEditing : false,
      ),
    );
  }
}

class HomeProfileUiState extends Equatable {
  const HomeProfileUiState({
    required this.isEditing,
    required this.isSubmitting,
  });

  const HomeProfileUiState.initial()
    : this(isEditing: false, isSubmitting: false);

  final bool isEditing;
  final bool isSubmitting;

  HomeProfileUiState copyWith({bool? isEditing, bool? isSubmitting}) {
    return HomeProfileUiState(
      isEditing: isEditing ?? this.isEditing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object> get props => [isEditing, isSubmitting];
}
