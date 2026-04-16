import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../milk/milk_barrel.dart';

class CustomerLedgerUiCubit extends Cubit<CustomerLedgerUiState> {
  CustomerLedgerUiCubit({
    required Future<List<LedgerEntry>> initialLedgerFuture,
    required String initialMonthKey,
  }) : super(
         CustomerLedgerUiState.initial(
           ledgerFuture: initialLedgerFuture,
           selectedMonthKey: initialMonthKey,
         ),
       );

  void retryLedger(Future<List<LedgerEntry>> ledgerFuture) {
    emit(state.copyWith(ledgerFuture: ledgerFuture, clearSummaryError: true));
  }

  void setSelectedMonthKey(String monthKey) {
    emit(state.copyWith(selectedMonthKey: monthKey, clearSummaryError: true));
  }

  void setMonthlySummary(Map<String, dynamic> summary) {
    emit(
      state.copyWith(
        monthlySummary: summary,
        isSummaryLoading: false,
        clearSummaryError: true,
      ),
    );
  }

  void setSummaryLoading(bool isLoading) {
    emit(state.copyWith(isSummaryLoading: isLoading));
  }

  void setSummaryError(String errorMessage) {
    emit(state.copyWith(isSummaryLoading: false, summaryError: errorMessage));
  }
}

class CustomerLedgerUiState extends Equatable {
  const CustomerLedgerUiState({
    required this.ledgerFuture,
    required this.selectedMonthKey,
    required this.monthlySummary,
    required this.isSummaryLoading,
    this.summaryError,
  });

  factory CustomerLedgerUiState.initial({
    required Future<List<LedgerEntry>> ledgerFuture,
    required String selectedMonthKey,
  }) {
    return CustomerLedgerUiState(
      ledgerFuture: ledgerFuture,
      selectedMonthKey: selectedMonthKey,
      monthlySummary: const <String, dynamic>{},
      isSummaryLoading: false,
    );
  }

  final Future<List<LedgerEntry>> ledgerFuture;
  final String selectedMonthKey;
  final Map<String, dynamic> monthlySummary;
  final bool isSummaryLoading;
  final String? summaryError;

  CustomerLedgerUiState copyWith({
    Future<List<LedgerEntry>>? ledgerFuture,
    String? selectedMonthKey,
    Map<String, dynamic>? monthlySummary,
    bool? isSummaryLoading,
    String? summaryError,
    bool clearSummaryError = false,
  }) {
    return CustomerLedgerUiState(
      ledgerFuture: ledgerFuture ?? this.ledgerFuture,
      selectedMonthKey: selectedMonthKey ?? this.selectedMonthKey,
      monthlySummary: monthlySummary ?? this.monthlySummary,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      summaryError: clearSummaryError
          ? null
          : (summaryError ?? this.summaryError),
    );
  }

  @override
  List<Object?> get props => [
    ledgerFuture,
    selectedMonthKey,
    monthlySummary,
    isSummaryLoading,
    summaryError,
  ];
}
