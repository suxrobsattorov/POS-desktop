import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/sale_repository.dart';
import '../../core/network/network_info.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class HistoryEvent {}

class HistoryLoaded extends HistoryEvent {}

class HistoryRefreshed extends HistoryEvent {}

class HistorySearchChanged extends HistoryEvent {
  final String query;
  HistorySearchChanged(this.query);
}

class HistoryDateRangeChanged extends HistoryEvent {
  final HistoryDateFilter filter;
  HistoryDateRangeChanged(this.filter);
}

class HistoryCustomDateRange extends HistoryEvent {
  final DateTimeRange range;
  HistoryCustomDateRange(this.range);
}

class HistoryCashierChanged extends HistoryEvent {
  final String? cashier;
  HistoryCashierChanged(this.cashier);
}

class HistoryFiltersCleared extends HistoryEvent {}

// ── Date Filter Enum ──────────────────────────────────────────────────────────

enum HistoryDateFilter { today, yesterday, week, month, custom }

extension HistoryDateFilterLabel on HistoryDateFilter {
  String get label {
    switch (this) {
      case HistoryDateFilter.today:
        return 'Bugun';
      case HistoryDateFilter.yesterday:
        return 'Kecha';
      case HistoryDateFilter.week:
        return '7 kun';
      case HistoryDateFilter.month:
        return 'Bu oy';
      case HistoryDateFilter.custom:
        return 'Maxsus';
    }
  }
}

// ── States ────────────────────────────────────────────────────────────────────

enum HistoryStatus { initial, loading, loaded, error }

class HistoryState {
  final HistoryStatus status;
  final List<Map<String, dynamic>> allSales;
  final List<Map<String, dynamic>> filteredSales;
  final String searchQuery;
  final HistoryDateFilter dateFilter;
  final DateTimeRange? customDateRange;
  final String? selectedCashier;
  final String? errorMessage;

  const HistoryState({
    this.status = HistoryStatus.initial,
    this.allSales = const [],
    this.filteredSales = const [],
    this.searchQuery = '',
    this.dateFilter = HistoryDateFilter.today,
    this.customDateRange,
    this.selectedCashier,
    this.errorMessage,
  });

  HistoryState copyWith({
    HistoryStatus? status,
    List<Map<String, dynamic>>? allSales,
    List<Map<String, dynamic>>? filteredSales,
    String? searchQuery,
    HistoryDateFilter? dateFilter,
    DateTimeRange? customDateRange,
    bool clearCustomDateRange = false,
    String? selectedCashier,
    bool clearCashier = false,
    String? errorMessage,
  }) {
    return HistoryState(
      status: status ?? this.status,
      allSales: allSales ?? this.allSales,
      filteredSales: filteredSales ?? this.filteredSales,
      searchQuery: searchQuery ?? this.searchQuery,
      dateFilter: dateFilter ?? this.dateFilter,
      customDateRange:
          clearCustomDateRange ? null : (customDateRange ?? this.customDateRange),
      selectedCashier:
          clearCashier ? null : (selectedCashier ?? this.selectedCashier),
      errorMessage: errorMessage,
    );
  }
}

// ── Bloc ──────────────────────────────────────────────────────────────────────

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final HiveService _hiveService;
  final SaleRepository _saleRepository;

  HistoryBloc({
    required HiveService hiveService,
    required SaleRepository saleRepository,
  })  : _hiveService = hiveService,
        _saleRepository = saleRepository,
        super(const HistoryState()) {
    on<HistoryLoaded>(_onLoaded);
    on<HistoryRefreshed>(_onRefreshed);
    on<HistorySearchChanged>(_onSearchChanged);
    on<HistoryDateRangeChanged>(_onDateRangeChanged);
    on<HistoryCustomDateRange>(_onCustomDateRange);
    on<HistoryCashierChanged>(_onCashierChanged);
    on<HistoryFiltersCleared>(_onFiltersCleared);
  }

  Future<void> _onLoaded(
      HistoryLoaded event, Emitter<HistoryState> emit) async {
    emit(state.copyWith(status: HistoryStatus.loading));

    // 1. Avval Hive-dan ko'rsat (darhol)
    final local = _hiveService.getLocalReceipts();
    final filtered = _applyAllFilters(local, state);
    emit(state.copyWith(
      status: HistoryStatus.loaded,
      allSales: local,
      filteredSales: filtered,
    ));

    // 2. Server-dan yangilaymiz
    await _fetchFromServer(emit, currentAll: local);
  }

  Future<void> _onRefreshed(
      HistoryRefreshed event, Emitter<HistoryState> emit) async {
    emit(state.copyWith(status: HistoryStatus.loading));

    final local = _hiveService.getLocalReceipts();
    final filtered = _applyAllFilters(local, state);
    emit(state.copyWith(
      status: HistoryStatus.loaded,
      allSales: local,
      filteredSales: filtered,
    ));

    await _fetchFromServer(emit, currentAll: local);
  }

  void _onSearchChanged(
      HistorySearchChanged event, Emitter<HistoryState> emit) {
    final newState = state.copyWith(searchQuery: event.query);
    final filtered = _applyAllFilters(state.allSales, newState);
    emit(newState.copyWith(filteredSales: filtered));
  }

  void _onDateRangeChanged(
      HistoryDateRangeChanged event, Emitter<HistoryState> emit) {
    final newState = state.copyWith(
      dateFilter: event.filter,
      clearCustomDateRange: true,
    );
    final filtered = _applyAllFilters(state.allSales, newState);
    emit(newState.copyWith(filteredSales: filtered));
  }

  void _onCustomDateRange(
      HistoryCustomDateRange event, Emitter<HistoryState> emit) {
    final newState = state.copyWith(
      dateFilter: HistoryDateFilter.custom,
      customDateRange: event.range,
    );
    final filtered = _applyAllFilters(state.allSales, newState);
    emit(newState.copyWith(filteredSales: filtered));
  }

  void _onCashierChanged(
      HistoryCashierChanged event, Emitter<HistoryState> emit) {
    final newState = event.cashier == null
        ? state.copyWith(clearCashier: true)
        : state.copyWith(selectedCashier: event.cashier);
    final filtered = _applyAllFilters(state.allSales, newState);
    emit(newState.copyWith(filteredSales: filtered));
  }

  void _onFiltersCleared(
      HistoryFiltersCleared event, Emitter<HistoryState> emit) {
    final newState = state.copyWith(
      dateFilter: HistoryDateFilter.today,
      clearCustomDateRange: true,
      clearCashier: true,
      searchQuery: '',
    );
    final filtered = _applyAllFilters(state.allSales, newState);
    emit(newState.copyWith(filteredSales: filtered));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Future<void> _fetchFromServer(
    Emitter<HistoryState> emit, {
    required List<Map<String, dynamic>> currentAll,
  }) async {
    try {
      final isOnline = await NetworkInfo.isConnected();
      if (!isOnline) return;

      final remote = await _saleRepository.getSales();
      if (remote.isEmpty) return;

      final serverIds = remote
          .map((s) => s['id']?.toString())
          .whereType<String>()
          .toSet();
      final localOnly = currentAll
          .where((s) =>
              s['id'] == null || !serverIds.contains(s['id']?.toString()))
          .toList();
      final merged = [...remote, ...localOnly];

      merged.sort((a, b) {
        final da = _parseDate(a['createdAt'] ?? a['saleDate']);
        final db = _parseDate(b['createdAt'] ?? b['saleDate']);
        return db.compareTo(da);
      });

      final filtered = _applyAllFilters(merged, state);
      emit(state.copyWith(
        allSales: merged,
        filteredSales: filtered,
      ));
    } catch (_) {
      // Server xato bo'lsa — Hive ma'lumotlar saqlanib qoladi
    }
  }

  List<Map<String, dynamic>> _applyAllFilters(
    List<Map<String, dynamic>> sales,
    HistoryState st,
  ) {
    return sales.where((s) {
      // Date filter
      final date = _parseDate(s['createdAt'] ?? s['saleDate']);
      if (st.dateFilter == HistoryDateFilter.custom &&
          st.customDateRange != null) {
        final range = st.customDateRange!;
        if (date.isBefore(range.start) ||
            date.isAfter(range.end.add(const Duration(days: 1)))) {
          return false;
        }
      } else {
        final now = DateTime.now();
        DateTime? from;
        DateTime? to;
        switch (st.dateFilter) {
          case HistoryDateFilter.today:
            from = DateTime(now.year, now.month, now.day);
            to = from.add(const Duration(days: 1));
            break;
          case HistoryDateFilter.yesterday:
            from = DateTime(now.year, now.month, now.day - 1);
            to = DateTime(now.year, now.month, now.day);
            break;
          case HistoryDateFilter.week:
            from = now.subtract(const Duration(days: 7));
            to = now;
            break;
          case HistoryDateFilter.month:
            from = DateTime(now.year, now.month, 1);
            to = now;
            break;
          case HistoryDateFilter.custom:
            break;
        }
        if (from != null && to != null) {
          if (date.isBefore(from) || date.isAfter(to)) return false;
        }
      }

      // Cashier filter
      if (st.selectedCashier != null) {
        final cashier = s['cashierName'] as String? ?? '';
        if (cashier != st.selectedCashier) return false;
      }

      // Search filter
      if (st.searchQuery.isNotEmpty) {
        final str = s.toString().toLowerCase();
        if (!str.contains(st.searchQuery.toLowerCase())) return false;
      }

      return true;
    }).toList();
  }

  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime(2000);
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime(2000);
    return DateTime(2000);
  }
}
