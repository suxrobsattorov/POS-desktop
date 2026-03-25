import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/injection.dart';
import '../../core/providers/app_settings_provider.dart';
import '../../core/services/receipt_service.dart';
import '../../data/local/hive_service.dart';
import '../pos/bloc/pos_bloc.dart';
import '../pos/bloc/pos_event.dart';
import '../pos/bloc/pos_state.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  final Map<int, double> _paymentAmounts = {};
  int? _selectedMethodId;
  String _numpadValue = '';
  double _enteredTotal = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.95,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Payment method colors and icons
  static const Map<String, _MethodStyle> _methodStyles = {
    'cash': _MethodStyle(Icons.payments_rounded, Color(0xFF27AE60), Color(0xFF1B7A3F)),
    'card': _MethodStyle(Icons.credit_card_rounded, Color(0xFF2196F3), Color(0xFF1565C0)),
    'click': _MethodStyle(Icons.touch_app_rounded, Color(0xFF8E24AA), Color(0xFF6A1B7A)),
    'payme': _MethodStyle(Icons.phone_iphone_rounded, Color(0xFF00BCD4), Color(0xFF00838F)),
    'uzum': _MethodStyle(Icons.account_balance_wallet_rounded, Color(0xFFFF9800), Color(0xFFE65100)),
    'qr': _MethodStyle(Icons.qr_code_2_rounded, Color(0xFFE91E63), Color(0xFFC2185B)),
  };

  _MethodStyle _getStyle(String type) {
    return _methodStyles[type.toLowerCase()] ??
        const _MethodStyle(Icons.payment_rounded, Color(0xFF607D8B), Color(0xFF455A64));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocConsumer<PosBloc, PosState>(
      listener: (context, state) {
        if (state.status == PosStatus.success) {
          _handleReceipt(context, state);
        }
      },
      builder: (context, state) {
        final total = state.netAmount;
        final remaining = total - _enteredTotal;

        return Scaffold(
          backgroundColor: isDark ? AppColors.background : const Color(0xFFF0F2F5),
          appBar: _buildAppBar(theme, isDark, total),
          body: Row(
            children: [
              // ── Left: Payment method cards ──────────────────────────
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    // Title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.payment_rounded,
                              color: isDark ? AppColors.primary : const Color(0xFF1976D2),
                              size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'select_payment_method'.tr(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Payment method grid
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.25,
                        ),
                        itemCount: state.paymentMethods.length,
                        itemBuilder: (context, index) {
                          final method = state.paymentMethods[index];
                          final selected = _selectedMethodId == method.id;
                          final amount = _paymentAmounts[method.id];
                          final style = _getStyle(method.type);

                          return _PaymentMethodCard(
                            method: method,
                            style: style,
                            isSelected: selected,
                            amount: amount,
                            isDark: isDark,
                            formatPrice: _fmtPrice,
                            onTap: () {
                              _pulseController.reverse().then((_) {
                                _pulseController.forward();
                              });
                              setState(() {
                                _selectedMethodId = method.id;
                                if (amount != null && amount > 0) {
                                  // Show existing assigned amount
                                  _numpadValue = amount.toStringAsFixed(0);
                                } else if (_numpadValue.isNotEmpty &&
                                    (double.tryParse(_numpadValue) ?? 0) > 0) {
                                  // Keep any number already typed in numpad
                                  // (user typed first, then selected method)
                                } else {
                                  // Auto-assign remaining amount
                                  final remaining = total - _enteredTotal;
                                  if (remaining > 0) {
                                    _numpadValue = remaining.toStringAsFixed(0);
                                  } else {
                                    _numpadValue = '';
                                  }
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),

                    // Summary card
                    _buildSummaryCard(theme, isDark, total, remaining),
                  ],
                ),
              ),

              // ── Right: Numpad panel ────────────────────────────────
              _buildNumpadPanel(theme, isDark, state, total),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, bool isDark, double total) {
    return AppBar(
      backgroundColor: isDark ? AppColors.surface : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded,
            color: isDark ? AppColors.textPrimary : Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'payment'.tr(),
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.shopping_cart_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                _fmtPrice(total),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      ThemeData theme, bool isDark, double total, double remaining) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFE0E0E0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          _SumRow(
            'total'.tr(),
            _fmtPrice(total),
            icon: Icons.receipt_long_rounded,
            iconColor: isDark ? AppColors.textSecondary : Colors.grey,
          ),
          const SizedBox(height: 8),
          _SumRow(
            'entered'.tr(),
            _fmtPrice(_enteredTotal),
            color: AppColors.success,
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.success,
          ),
          if (_enteredTotal > total) ...[
            const SizedBox(height: 8),
            _SumRow(
              'change'.tr(),
              _fmtPrice(_enteredTotal - total),
              color: AppColors.primary,
              bold: true,
              icon: Icons.currency_exchange_rounded,
              iconColor: AppColors.primary,
            ),
          ] else if (remaining > 0) ...[
            const SizedBox(height: 8),
            _SumRow(
              'remaining'.tr(),
              _fmtPrice(remaining),
              color: AppColors.warning,
              bold: true,
              icon: Icons.pending_rounded,
              iconColor: AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumpadPanel(
      ThemeData theme, bool isDark, PosState state, double total) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? AppColors.border : const Color(0xFFE0E0E0),
          ),
        ),
      ),
      child: Column(
        children: [
          // Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceVariant
                  : const Color(0xFFF5F5F5),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.border : const Color(0xFFE0E0E0),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_selectedMethodId != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStyle(
                        state.paymentMethods
                                .where((m) => m.id == _selectedMethodId)
                                .firstOrNull
                                ?.type ??
                            '',
                      ).color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      state.paymentMethods
                              .where((m) => m.id == _selectedMethodId)
                              .firstOrNull
                              ?.name ??
                          '',
                      style: TextStyle(
                        color: _getStyle(
                          state.paymentMethods
                                  .where((m) => m.id == _selectedMethodId)
                                  .firstOrNull
                                  ?.type ??
                              '',
                        ).color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  _numpadValue.isEmpty ? '0' : _formatDisplay(_numpadValue),
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimary : Colors.black87,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'UZS',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondary : Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                // Quick amount buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    _quickBtn(total, 'exact'.tr(), AppColors.success, isDark),
                    if (total < 50000)
                      _quickBtn(50000, '50K', AppColors.primary, isDark),
                    if (total < 100000)
                      _quickBtn(100000, '100K', AppColors.primary, isDark),
                    if (total < 200000)
                      _quickBtn(200000, '200K', AppColors.primary, isDark),
                  ],
                ),
              ],
            ),
          ),

          // Numpad grid
          Expanded(
            child: _NumpadGrid(
              isDark: isDark,
              onDigit: _onDigit,
              onDelete: _onDelete,
              onClear: _onClear,
            ),
          ),

          // Add + Confirm buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text('add_payment'.tr()),
                onPressed: _selectedMethodId != null &&
                        _numpadValue.isNotEmpty &&
                        (double.tryParse(_numpadValue) ?? 0) > 0
                    ? _addPayment
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: state.status == PosStatus.processingPayment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded, size: 22),
                label: Text(
                  'confirm'.tr().toUpperCase(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _canConfirm(total) && state.status != PosStatus.processingPayment
                    ? () => _confirm(context, state)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? AppColors.surfaceVariant
                      : const Color(0xFFE0E0E0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(double amt, String label, Color color, bool isDark) {
    return GestureDetector(
      onTap: () => _setAmount(amt),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────

  void _onDigit(String d) {
    setState(() {
      if (d == '.' && _numpadValue.contains('.')) return;
      _numpadValue += d;
    });
    // Show hint if no method selected yet (non-blocking)
    if (_selectedMethodId == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Text("To'lov usulini tanlang"),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 220,
            backgroundColor: AppColors.warning,
          ),
        );
    }
  }

  void _onDelete() {
    if (_numpadValue.isEmpty) return;
    setState(() {
      _numpadValue = _numpadValue.substring(0, _numpadValue.length - 1);
    });
  }

  void _onClear() {
    setState(() {
      _numpadValue = '';
      if (_selectedMethodId != null) {
        _paymentAmounts.remove(_selectedMethodId);
        _recalcTotal();
      }
    });
  }

  void _setAmount(double amt) {
    if (_selectedMethodId == null) return;
    setState(() {
      _numpadValue = amt.toStringAsFixed(0);
      _paymentAmounts[_selectedMethodId!] = amt;
      _recalcTotal();
    });
  }

  void _addPayment() {
    if (_selectedMethodId == null) return;
    final val = double.tryParse(_numpadValue) ?? 0;
    if (val <= 0) return;
    setState(() {
      _paymentAmounts[_selectedMethodId!] = val;
      _recalcTotal();
      _numpadValue = '';
    });
  }

  void _recalcTotal() {
    _enteredTotal = _paymentAmounts.values.fold(0, (s, v) => s + v);
  }

  bool _canConfirm(double total) {
    // Allow confirm if: already have enough payment recorded, OR a method is selected
    // (will auto-assign remaining amount on confirm)
    if (_paymentAmounts.isNotEmpty && _enteredTotal >= total) return true;
    if (_selectedMethodId != null) return true;
    return false;
  }

  void _confirm(BuildContext context, PosState state) {
    final total = state.netAmount;

    // If a method is selected and numpad has a value, add it first
    if (_selectedMethodId != null && _numpadValue.isNotEmpty) {
      final val = double.tryParse(_numpadValue) ?? 0;
      if (val > 0) {
        _paymentAmounts[_selectedMethodId!] = val;
        _recalcTotal();
      }
    }

    // If method selected but no amount entered yet, auto-assign the full total
    if (_selectedMethodId != null && _paymentAmounts.isEmpty) {
      _paymentAmounts[_selectedMethodId!] = total;
      _recalcTotal();
    } else if (_selectedMethodId != null && _enteredTotal < total) {
      // Top up the selected method with remaining amount
      final remaining = total - _enteredTotal;
      _paymentAmounts[_selectedMethodId!] =
          (_paymentAmounts[_selectedMethodId!] ?? 0) + remaining;
      _recalcTotal();
    }

    final payments = _paymentAmounts.entries
        .where((e) => e.value > 0)
        .map((e) => SalePaymentEntry(e.key, e.value))
        .toList();
    context.read<PosBloc>().add(SaleSubmitted(payments));
  }

  // ── Receipt handling ─────────────────────────────────────────────

  Future<void> _handleReceipt(BuildContext context, PosState state) async {
    final settings = context.read<AppSettingsProvider>();
    final receiptService = GetIt.I<ReceiptService>();

    // Build receipt data
    final items = state.cartItems
        .map((item) => {
              'name': item.product.name,
              'price': item.product.sellPrice,
              'qty': item.quantity.toInt(),
              'total': item.subtotal,
            })
        .toList();

    final paymentMethodNames = _paymentAmounts.entries
        .where((e) => e.value > 0)
        .map((e) {
      final method = state.paymentMethods.firstWhere(
        (m) => m.id == e.key,
        orElse: () => state.paymentMethods.first,
      );
      return method.name;
    }).join(', ');

    final receiptNo = DateTime.now().millisecondsSinceEpoch.toString().substring(5);

    try {
      final hive = sl<HiveService>();
      final user = hive.getUser();
      final pdf = await receiptService.buildReceiptPdf(
        shopName: hive.getShopName(),
        shopAddress: hive.getShopAddress(),
        shopPhone: hive.getShopPhone(),
        receiptHeader: hive.getReceiptHeader(),
        receiptFooter: hive.getReceiptFooter(),
        cashierName: user?.fullName.isNotEmpty == true
            ? user!.fullName
            : (user?.username ?? ''),
        receiptNo: receiptNo,
        date: DateTime.now(),
        items: items,
        total: state.netAmount,
        paid: _enteredTotal,
        change: _enteredTotal > state.netAmount
            ? _enteredTotal - state.netAmount
            : 0,
        paymentMethod: paymentMethodNames,
      );

      if (!context.mounted) return;

      // Auto-send receipt immediately based on settings
      if (settings.printerEnabled) {
        final printed = await receiptService.printReceipt(pdf);
        if (context.mounted && printed) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chek chop etildi'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ));
        }
      }

      if (settings.pdfEnabled) {
        final path = await receiptService.savePdfToFile(pdf, receiptNo);
        if (context.mounted && path != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Chek saqlandi: $path'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ));
        }
      }

      // If neither printer nor PDF enabled, show receipt dialog
      if (!settings.printerEnabled && !settings.pdfEnabled) {
        if (context.mounted) {
          final action = await ReceiptService.showReceiptDialog(
            context, true, true,
          );
          if (action == ReceiptAction.print) {
            await receiptService.printReceipt(pdf);
          } else if (action == ReceiptAction.savePdf) {
            await receiptService.savePdfToFile(pdf, receiptNo);
          }
        }
      }
    } catch (_) {
      // Receipt failed, but sale was already saved — just close
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  // ── Formatting ───────────────────────────────────────────────────

  String _fmtPrice(double v) {
    final formatted = v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
    return '$formatted UZS';
  }

  String _formatDisplay(String v) {
    final num = double.tryParse(v);
    if (num == null) return v;
    return num.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }
}

// ── Payment method card widget ─────────────────────────────────────

class _PaymentMethodCard extends StatefulWidget {
  final dynamic method;
  final _MethodStyle style;
  final bool isSelected;
  final double? amount;
  final bool isDark;
  final String Function(double) formatPrice;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.method,
    required this.style,
    required this.isSelected,
    required this.amount,
    required this.isDark,
    required this.formatPrice,
    required this.onTap,
  });

  @override
  State<_PaymentMethodCard> createState() => _PaymentMethodCardState();
}

class _PaymentMethodCardState extends State<_PaymentMethodCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final hasAmount = widget.amount != null && widget.amount! > 0;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) {
          _scaleController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _scaleController.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [style.color, style.darkColor],
                  )
                : null,
            color: widget.isSelected
                ? null
                : (widget.isDark ? AppColors.surfaceVariant : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? style.color
                  : (hasAmount
                      ? style.color.withValues(alpha: 0.5)
                      : (widget.isDark
                          ? AppColors.border
                          : const Color(0xFFE0E0E0))),
              width: widget.isSelected ? 2 : (hasAmount ? 2 : 1),
            ),
            boxShadow: [
              if (widget.isSelected)
                BoxShadow(
                  color: style.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              if (!widget.isDark && !widget.isSelected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : style.color.withValues(alpha: widget.isDark ? 0.15 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    style.icon,
                    color: widget.isSelected ? Colors.white : style.color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                // Method name
                Text(
                  widget.method.name,
                  style: TextStyle(
                    color: widget.isSelected
                        ? Colors.white
                        : (widget.isDark
                            ? AppColors.textPrimary
                            : Colors.black87),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Amount badge
                if (hasAmount) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : style.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.formatPrice(widget.amount!),
                      style: TextStyle(
                        color: widget.isSelected ? Colors.white : style.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Style helper ───────────────────────────────────────────────────

class _MethodStyle {
  final IconData icon;
  final Color color;
  final Color darkColor;

  const _MethodStyle(this.icon, this.color, this.darkColor);
}

// ── Summary row ────────────────────────────────────────────────────

class _SumRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  final IconData? icon;
  final Color? iconColor;

  const _SumRow(this.label, this.value,
      {this.color, this.bold = false, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: iconColor ?? Colors.grey),
          const SizedBox(width: 8),
        ],
        Text(label,
            style: TextStyle(
              color: isDark ? AppColors.textSecondary : Colors.grey[600],
              fontSize: 13,
            )),
        const Spacer(),
        Text(value,
            style: TextStyle(
              color: color ??
                  (isDark ? AppColors.textPrimary : Colors.black87),
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            )),
      ],
    );
  }
}

// ── Numpad grid ────────────────────────────────────────────────────

class _NumpadGrid extends StatelessWidget {
  final Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final bool isDark;

  const _NumpadGrid({
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final keys = [
      '7', '8', '9',
      '4', '5', '6',
      '1', '2', '3',
      'C', '0', '.',
    ];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (int row = 0; row < 4; row++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: row < 3 ? 8 : 0),
                child: Row(
                  children: [
                    for (int col = 0; col < 3; col++) ...[
                      if (col > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _NumKey(
                          label: keys[row * 3 + col],
                          isDark: isDark,
                          onTap: () {
                            final key = keys[row * 3 + col];
                            key == 'C' ? onClear() : onDigit(key);
                          },
                          isSpecial: keys[row * 3 + col] == 'C',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Backspace row
          SizedBox(
            height: 44,
            width: double.infinity,
            child: _NumKey(
              icon: Icons.backspace_rounded,
              isDark: isDark,
              onTap: onDelete,
              isSpecial: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isSpecial;
  final bool isDark;

  const _NumKey({
    this.label,
    this.icon,
    required this.onTap,
    this.isSpecial = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSpecial
          ? (isDark ? AppColors.surfaceVariant : const Color(0xFFEEEEEE))
          : (isDark ? AppColors.surface : Colors.white),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.border : const Color(0xFFE0E0E0),
            ),
          ),
          alignment: Alignment.center,
          child: label != null
              ? Text(
                  label!,
                  style: TextStyle(
                    color: isSpecial
                        ? AppColors.error
                        : (isDark ? AppColors.textPrimary : Colors.black87),
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : Icon(icon,
                  color: isDark ? AppColors.textSecondary : Colors.grey[600],
                  size: 22),
        ),
      ),
    );
  }
}
