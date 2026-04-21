part of 'audit_timeline_cubit.dart';

class AuditTimelineState extends Equatable {
  const AuditTimelineState({
    required this.isLoading,
    required this.entries,
    required this.errorMessage,
  });

  const AuditTimelineState.initial()
    : isLoading = false,
      entries = const <Map<String, dynamic>>[],
      errorMessage = null;

  final bool isLoading;
  final List<Map<String, dynamic>> entries;
  final String? errorMessage;

  AuditTimelineState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? entries,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuditTimelineState(
      isLoading: isLoading ?? this.isLoading,
      entries: entries ?? this.entries,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, entries, errorMessage];
}
