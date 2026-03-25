import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/services/receipt_service.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/sale_repository.dart';
import 'history_bloc.dart';

// ── HistoryScreen Entry Point ─────────────────────────────────────────────────

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HistoryBloc(
        hiveService: sl<HiveService>(),
        saleRepository: sl<SaleRepository>(),
      )..add(HistoryLoaded()),
      child: const _HistoryView(),
    );
  }
}

// ── _HistoryView ──────────────────────────────────────────────────────────────

class _HistoryView extends StatefulWidget {
  const _HistoryView();

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  // Pagination
  int _currentPage = 0;
  static const int _pageSize = 20;

  // Filter state (local)
  DateTimeRange? _dateRange;
  String? _selectedCashier;
  HistoryDateFilter _quickFilter = HistoryDateFilter.today;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistoryBloc, HistoryState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              _AppBar(
                onRefresh: () {
                  context.read<HistoryBloc>().add(HistoryRefreshed());
                  setState(() {
                    _currentPage = 0;
                  });
                },
                isLoading: state.status == HistoryStatus.loading,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Left filter panel 220px ─────────────────────────
                    _FilterPanel(
                      dateRange: _dateRange,
                      selectedCashier: _selectedCashier,
                      quickFilter: _quickFilter,
                      cashiers: _extractCashiers(state.allSales),
                      onQuickFilter: (f) {
                        setState(() {
                          _quickFilter = f;
                          _dateRange = null;
                          _currentPage = 0;
                        });
                        context
                            .read<HistoryBloc>()
                            .add(HistoryDateRangeChanged(f));
                      },
                      onDateRange: (range) {
                        setState(() {
                          _dateRange = range;
                          _currentPage = 0;
                        });
                        if (range != null) {
                          context
                              .read<HistoryBloc>()
                              .add(HistoryCustomDateRange(range));
                        }
                      },
                      onCashierChanged: (cashier) {
                        setState(() {
                          _selectedCashier = cashier;
                          _currentPage = 0;
                        });
                        context
                            .read<HistoryBloc>()
                            .add(HistoryCashierChanged(cashier));
                      },
                      onClear: () {
                        setState(() {
                          _dateRange = null;
                          _selectedCashier = null;
                          _quickFilter = HistoryDateFilter.today;
                          _currentPage = 0;
                        });
                        context.read<HistoryBloc>().add(HistoryFiltersCleared());
                      },
                    ),

                    // ── Right content: table + pagination ────────────────
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _SaleTable(
                              state: state,
                              currentPage: _currentPage,
                              pageSize: _pageSize,
                              onRowTap: (sale) =>
                                  _showDetailDialog(context, sale),
                            ),
                          ),
                          _Pagination(
                            totalItems: state.filteredSales.length,
                            currentPage: _currentPage,
                            pageSize: _pageSize,
                            onPageChanged: (p) =>
                                setState(() => _currentPage = p),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _extractCashiers(List<Map<String, dynamic>> sales) {
    final set = <String>{};
    for (final s in sales) {
      final name = s['cashierName'] as String?;
      if (name != null && name.isNotEmpty) set.add(name);
    }
    return set.toList()..sort();
  }

  void _showDetailDialog(BuildContext context, Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (_) => _SaleDetailDialog(sale: sale),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool isLoading;

  const _AppBar({required this.onRefresh, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: AppColors.textSecondary,
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
          const SizedBox(width: 8),
          const Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          const Text(
            'Sotuv tarixi',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              color: AppColors.textSecondary,
              tooltip: 'Yangilash',
              onPressed: onRefresh,
            ),
        ],
      ),
    );
  }
}

// ── Filter Panel ──────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final DateTimeRange? dateRange;
  final String? selectedCashier;
  final HistoryDateFilter quickFilter;
  final List<String> cashiers;
  final void Function(HistoryDateFilter) onQuickFilter;
  final void Function(DateTimeRange?) onDateRange;
  final void Function(String?) onCashierChanged;
  final VoidCallback onClear;

  const _FilterPanel({
    required this.dateRange,
    required this.selectedCashier,
    required this.quickFilter,
    required this.cashiers,
    required this.onQuickFilter,
    required this.onDateRange,
    required this.onCashierChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Filtrlar',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Quick date filters
          _FilterSection(
            title: 'Vaqt oralig\'i',
            child: Column(
              children: HistoryDateFilter.values
                  .where((f) => f != HistoryDateFilter.custom)
                  .map((f) {
                final isSelected = quickFilter == f && dateRange == null;
                return _FilterChip(
                  label: f.label,
                  isSelected: isSelected,
                  onTap: () => onQuickFilter(f),
                );
              }).toList(),
            ),
          ),

          Divider(color: AppColors.border, height: 1),

          // Date range picker
          _FilterSection(
            title: 'Maxsus sana',
            child: GestureDetector(
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: dateRange,
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: AppColors.primary,
                        surface: AppColors.surface,
                        onSurface: AppColors.textPrimary,
                      ),
                    ),
                    child: child!,
                  ),
                );
                onDateRange(picked);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dateRange != null
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: dateRange != null
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.date_range,
                      size: 16,
                      color: dateRange != null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateRange != null
                            ? '${_fmtDate(dateRange!.start)} – ${_fmtDate(dateRange!.end)}'
                            : 'Sana tanlash',
                        style: TextStyle(
                          color: dateRange != null
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Divider(color: AppColors.border, height: 1),

          // Cashier filter
          _FilterSection(
            title: 'Kassir',
            child: DropdownButton<String?>(
              value: selectedCashier,
              isExpanded: true,
              hint: Text(
                'Hammasi',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              dropdownColor: AppColors.surfaceVariant,
              underline: Container(height: 1, color: AppColors.border),
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Hammasi'),
                ),
                ...cashiers.map((c) => DropdownMenuItem<String?>(
                      value: c,
                      child: Text(c, overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: onCashierChanged,
            ),
          ),

          const Spacer(),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClear,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Tozalash', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Sale Table ────────────────────────────────────────────────────────────────

class _SaleTable extends StatelessWidget {
  final HistoryState state;
  final int currentPage;
  final int pageSize;
  final void Function(Map<String, dynamic>) onRowTap;

  const _SaleTable({
    required this.state,
    required this.currentPage,
    required this.pageSize,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    if (state.status == HistoryStatus.loading && state.allSales.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.filteredSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Sotuv topilmadi',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.pos),
              icon: const Icon(Icons.point_of_sale_rounded, size: 16),
              label: const Text('POS ga o\'tish'),
            ),
          ],
        ),
      );
    }

    // Paginate
    final start = currentPage * pageSize;
    final end = (start + pageSize).clamp(0, state.filteredSales.length);
    final pageItems = state.filteredSales.sublist(start, end);

    return Column(
      children: [
        // Table header
        _TableHeader(),

        // Table rows
        Expanded(
          child: ListView.builder(
            itemCount: pageItems.length,
            itemBuilder: (ctx, i) {
              final sale = pageItems[i];
              final isEven = i % 2 == 0;
              return _TableRow(
                sale: sale,
                isEven: isEven,
                onTap: () => onRowTap(sale),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          _HeaderCell('Sana', flex: 3),
          _HeaderCell('Raqam', flex: 2),
          _HeaderCell('Kassir', flex: 3),
          _HeaderCell('Mahsulotlar', flex: 2),
          _HeaderCell('Jami', flex: 2),
          _HeaderCell('To\'lov', flex: 2),
          _HeaderCell('Status', flex: 2),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;

  const _HeaderCell(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final Map<String, dynamic> sale;
  final bool isEven;
  final VoidCallback onTap;

  const _TableRow(
      {required this.sale, required this.isEven, required this.onTap});

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  String _fmt(dynamic v) {
    final d = (v as num?)?.toDouble() ?? 0.0;
    return d
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
  }

  String _formatDate(String? raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SYNCED':
      case 'COMPLETED':
        return AppColors.success;
      case 'PENDING':
        return AppColors.warning;
      case 'VOIDED':
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final total =
        sale['totalAmount'] ?? sale['total'] ?? sale['netAmount'] ?? 0;
    final saleNo = '${sale['saleNumber'] ?? sale['id'] ?? '-'}';
    final dateRaw = sale['createdAt'] as String?;
    final cashier = sale['cashierName'] as String? ?? '-';
    final items = (sale['items'] as List?)?.length ?? 0;
    final status = sale['syncStatus'] ?? sale['status'] ?? 'SYNCED';
    final payments = sale['payments'] as List?;
    final paymentLabel = payments != null && payments.isNotEmpty
        ? (payments.first['paymentMethodName'] ??
            payments.first['type'] ??
            'Naqd')
        : (sale['paymentMethod'] ?? 'Naqd');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primary.withValues(alpha: 0.06)
                : (widget.isEven
                    ? AppColors.background
                    : AppColors.surface.withValues(alpha: 0.5)),
            border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  _formatDate(dateRaw),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '#$saleNo',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  cashier,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '$items ta',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${_fmt(total)} UZS',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '$paymentLabel',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(status.toString())
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _statusLabel(status.toString()),
                    style: TextStyle(
                      color: _statusColor(status.toString()),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'SYNCED':
      case 'COMPLETED':
        return 'SYNCED';
      case 'PENDING':
        return 'PENDING';
      case 'VOIDED':
      case 'CANCELLED':
        return 'BEKOR';
      default:
        return status;
    }
  }
}

// ── Pagination ────────────────────────────────────────────────────────────────

class _Pagination extends StatelessWidget {
  final int totalItems;
  final int currentPage;
  final int pageSize;
  final void Function(int) onPageChanged;

  const _Pagination({
    required this.totalItems,
    required this.currentPage,
    required this.pageSize,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();

    final totalPages = (totalItems / pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    final start = currentPage * pageSize + 1;
    final end = ((currentPage + 1) * pageSize).clamp(0, totalItems);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            '$start–$end / $totalItems ta',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const Spacer(),
          // Previous
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            color: currentPage > 0
                ? AppColors.textPrimary
                : AppColors.textDisabled,
            onPressed:
                currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
          ),

          // Page numbers
          ..._buildPageNumbers(currentPage, totalPages, onPageChanged),

          // Next
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            color: currentPage < totalPages - 1
                ? AppColors.textPrimary
                : AppColors.textDisabled,
            onPressed: currentPage < totalPages - 1
                ? () => onPageChanged(currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(
      int current, int total, void Function(int) onChanged) {
    final pages = <Widget>[];
    for (int i = 0; i < total; i++) {
      if (total > 7) {
        if (i != 0 && i != total - 1 && (i - current).abs() > 2) {
          if (pages.isNotEmpty &&
              pages.last is! _EllipsisWidget) {
            pages.add(const _EllipsisWidget());
          }
          continue;
        }
      }
      pages.add(_PageButton(
        page: i,
        isCurrent: i == current,
        onTap: () => onChanged(i),
      ));
    }
    return pages;
  }
}

class _EllipsisWidget extends StatelessWidget {
  const _EllipsisWidget();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '...',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final int page;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PageButton(
      {required this.page, required this.isCurrent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.primary
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          '${page + 1}',
          style: TextStyle(
            color: isCurrent ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight:
                isCurrent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Sale Detail Dialog ────────────────────────────────────────────────────────

class _SaleDetailDialog extends StatelessWidget {
  final Map<String, dynamic> sale;

  const _SaleDetailDialog({required this.sale});

  String _fmt(dynamic v) {
    final d = (v as num?)?.toDouble() ?? 0.0;
    return d
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
  }

  String _formatDate(String? raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final items = (sale['items'] as List?) ?? [];
    final payments = (sale['payments'] as List?) ?? [];
    final saleNo = '${sale['saleNumber'] ?? sale['id'] ?? '-'}';
    final cashier = sale['cashierName'] as String? ?? '-';
    final dateRaw = sale['createdAt'] as String?;
    final total =
        sale['totalAmount'] ?? sale['total'] ?? sale['netAmount'] ?? 0;
    final discount =
        sale['discountAmount'] ?? sale['discount'] ?? 0;
    final paid = sale['paidAmount'] ?? total;
    final change = sale['changeAmount'] ?? 0;
    final status = sale['syncStatus'] ?? sale['status'] ?? 'SYNCED';
    final hive = sl<HiveService>();
    final user = hive.getUser();
    final isAdmin = user?.isAdmin ?? false;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Sotuv #$saleNo',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Content
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta info
                    _MetaRow(label: 'Chek raqami', value: '#$saleNo'),
                    _MetaRow(
                        label: 'Sana', value: _formatDate(dateRaw)),
                    _MetaRow(label: 'Kassir', value: cashier),
                    _MetaRow(label: 'Status', value: status.toString()),
                    const SizedBox(height: 20),

                    // Items table
                    const Text(
                      'MAHSULOTLAR',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          // Items header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                    flex: 4,
                                    child: _ColHeader('Mahsulot')),
                                Expanded(
                                    flex: 1,
                                    child: _ColHeader('Soni')),
                                Expanded(
                                    flex: 2,
                                    child: _ColHeader('Narx')),
                                Expanded(
                                    flex: 2,
                                    child: _ColHeader('Jami')),
                              ],
                            ),
                          ),
                          // Items rows
                          ...items.asMap().entries.map((e) {
                            final i = e.key;
                            final item = e.value as Map;
                            final name = item['productName'] ??
                                item['name'] ??
                                'Noma\'lum';
                            final qty = item['quantity'] ?? 1;
                            final price = item['unitPrice'] ??
                                item['price'] ??
                                0;
                            final subtotal = item['subtotal'] ??
                                item['total'] ??
                                (((qty as num).toDouble()) *
                                    ((price as num).toDouble()));
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: i % 2 == 0
                                    ? Colors.transparent
                                    : AppColors.background
                                        .withValues(alpha: 0.5),
                                border: Border(
                                    top: BorderSide(
                                        color: AppColors.border,
                                        width: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      '$name',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '$qty',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${_fmt(price)} UZS',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${_fmt(subtotal)} UZS',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Payments
                    if (payments.isNotEmpty) ...[
                      const Text(
                        'TO\'LOV USULLARI',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...payments.map((p) {
                        final pm = p as Map;
                        final pName = pm['paymentMethodName'] ??
                            pm['type'] ??
                            pm['method'] ??
                            'Noma\'lum';
                        final pAmount = pm['amount'] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$pName',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${_fmt(pAmount)} UZS',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Summary footer
                    Divider(color: AppColors.border),
                    const SizedBox(height: 8),
                    if ((discount as num).toDouble() > 0)
                      _SummaryRow(
                          label: 'Chegirma',
                          value: '- ${_fmt(discount)} UZS',
                          color: Colors.green),
                    _SummaryRow(label: 'To\'landi', value: '${_fmt(paid)} UZS'),
                    if ((change as num).toDouble() > 0)
                      _SummaryRow(
                          label: 'Qaytim', value: '${_fmt(change)} UZS'),
                    const SizedBox(height: 4),
                    _SummaryRow(
                      label: 'JAMI',
                      value: '${_fmt(total)} UZS',
                      isBold: true,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  // Print button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _printReceipt(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Chop etish'),
                  ),

                  const Spacer(),

                  // Cancel sale (ADMIN only)
                  if (isAdmin &&
                      status.toString().toUpperCase() != 'VOIDED' &&
                      status.toString().toUpperCase() != 'CANCELLED')
                    TextButton.icon(
                      onPressed: () => _confirmCancel(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Bekor qilish'),
                    ),

                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceVariant,
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: const Text('Yopish'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _printReceipt(BuildContext context) async {
    final receiptService = sl<ReceiptService>();
    final hive = sl<HiveService>();
    final items = (sale['items'] as List?) ?? [];
    final total =
        (sale['totalAmount'] ?? sale['total'] ?? sale['netAmount'] ?? 0)
            .toDouble();
    final paid =
        ((sale['paidAmount'] ?? total) as num).toDouble();
    final change =
        ((sale['changeAmount'] ?? 0) as num).toDouble();
    final saleNo = '${sale['saleNumber'] ?? sale['id'] ?? '-'}';
    final cashier = sale['cashierName'] as String? ?? '-';
    final dateRaw = sale['createdAt'] as String?;
    final date = dateRaw != null
        ? (DateTime.tryParse(dateRaw) ?? DateTime.now())
        : DateTime.now();
    final payments = (sale['payments'] as List?) ?? [];
    final paymentMethod = payments.isNotEmpty
        ? (payments.first['paymentMethodName'] ??
            payments.first['type'] ??
            'Naqd')
        : (sale['paymentMethod'] ?? 'Naqd');

    try {
      final pdf = await receiptService.buildReceiptPdf(
        shopName: hive.getShopName(),
        shopAddress: hive.getSetting('shop_address') ?? '',
        shopPhone: hive.getSetting('shop_phone') ?? '',
        receiptFooter: hive.getReceiptFooter(),
        receiptNo: saleNo,
        date: date,
        items: items
            .map((i) => Map<String, dynamic>.from(i as Map))
            .toList(),
        total: total,
        paid: paid,
        change: change,
        paymentMethod: '$paymentMethod',
        cashierName: cashier,
      );
      await receiptService.printPdf(pdf);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Chop etishda xato: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Sotuvni bekor qilish',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Bu sotuvni bekor qilmoqchimisiz? Bu amal qaytarib bo\'lmaydi.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Yo\'q', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close confirm
              Navigator.pop(context); // close detail
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Bekor qilish so\'rovi yuborildi'),
                backgroundColor: AppColors.warning,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Ha, bekor qilish'),
          ),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String label;
  const _ColHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBold
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: isBold ? 15 : 13,
              fontWeight:
                  isBold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ??
                  (isBold
                      ? AppColors.textPrimary
                      : AppColors.textSecondary),
              fontSize: isBold ? 16 : 13,
              fontWeight:
                  isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── SaleHistoryCard (kept for backward compat) ────────────────────────────────

class SaleHistoryCard extends StatelessWidget {
  final Map<String, dynamic> sale;
  final VoidCallback? onTap;

  const SaleHistoryCard({super.key, required this.sale, this.onTap});

  String _fmt(dynamic v) {
    final d = (v as num?)?.toDouble() ?? 0.0;
    return d
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
  }

  @override
  Widget build(BuildContext context) {
    final total =
        sale['totalAmount'] ?? sale['total'] ?? sale['netAmount'] ?? 0;
    final saleNo = sale['saleNumber'] ?? sale['id'] ?? '-';
    final status = sale['syncStatus'] ?? sale['status'] ?? 'SYNCED';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '#$saleNo',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${_fmt(total)} UZS',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SaleDetailSheet (kept for backward compat) ────────────────────────────────

class SaleDetailSheet extends StatelessWidget {
  final Map<String, dynamic> sale;
  const SaleDetailSheet({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return _SaleDetailDialog(sale: sale);
  }
}
