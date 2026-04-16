import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

class HomeFeatureUiCubit extends Cubit<HomeFeatureUiState> {
  HomeFeatureUiCubit() : super(const HomeFeatureUiState.initial());

  void setLoading(bool loading) {
    emit(state.copyWith(loading: loading));
  }

  void setSaving(bool saving) {
    emit(state.copyWith(saving: saving));
  }

  void setIssueType(String issueType) {
    emit(state.copyWith(issueType: issueType));
  }

  void setProcessingPayment(bool processingPayment) {
    emit(state.copyWith(processingPayment: processingPayment));
  }

  void replaceData({
    List<Map<String, dynamic>>? items,
    Map<String, dynamic>? summary,
  }) {
    emit(
      state.copyWith(
        items: items ?? const <Map<String, dynamic>>[],
        summary: summary ?? <String, dynamic>{},
      ),
    );
  }
}

class HomeFeatureUiState extends Equatable {
  const HomeFeatureUiState({
    required this.loading,
    required this.saving,
    required this.processingPayment,
    required this.items,
    required this.summary,
    required this.issueType,
  });

  const HomeFeatureUiState.initial()
    : this(
        loading: true,
        saving: false,
        processingPayment: false,
        items: const <Map<String, dynamic>>[],
        summary: const <String, dynamic>{},
        issueType: 'not_delivered',
      );

  final bool loading;
  final bool saving;
  final bool processingPayment;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> summary;
  final String issueType;

  HomeFeatureUiState copyWith({
    bool? loading,
    bool? saving,
    bool? processingPayment,
    List<Map<String, dynamic>>? items,
    Map<String, dynamic>? summary,
    String? issueType,
  }) {
    return HomeFeatureUiState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      processingPayment: processingPayment ?? this.processingPayment,
      items: items ?? this.items,
      summary: summary ?? this.summary,
      issueType: issueType ?? this.issueType,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    saving,
    processingPayment,
    items,
    summary,
    issueType,
  ];
}
