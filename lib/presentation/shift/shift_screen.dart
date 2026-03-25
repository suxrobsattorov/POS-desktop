import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/router/app_router.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

const List<String> _shiftWeekdays = [
  'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba',
  'Juma', 'Shanba', 'Yakshanba',
];
const List<String> _shiftMonths = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
];

class _ShiftScreenState extends State<ShiftScreen>
    with TickerProviderStateMixin {
  // Clock
  DateTime _now = DateTime.now();
  late Timer _clockTimer;

  // Shift action state
  final _balanceCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _balanceCtrl.dispose();
    _notesCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shift = context.watch<ShiftProvider>();
    final isOpen = shift.isShiftOpen;

    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    final weekday = _shiftWeekdays[_now.weekday - 1];
    final month = _shiftMonths[_now.month - 1];
    final dateStr = '$weekday, ${_now.day} $month ${_now.year}';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // ── Clock header ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE0E0E0),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  tooltip: 'Orqaga',
                  onPressed: () => context.go(AppRoutes.home),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.access_time_rounded, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Smena boshqaruvi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$h:$m:$s',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Main content ─────────────────────────────────────────────
          Expanded(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildShiftAction(context, theme, isDark, shift, isOpen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shift Action Panel ─────────────────────────────────────────

  Widget _buildShiftAction(BuildContext context, ThemeData theme, bool isDark,
      ShiftProvider shift, bool isOpen) {
    return Container(
      width: 480,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: (isOpen ? Colors.red : Colors.green).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOpen ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
              color: isOpen ? Colors.red : Colors.green,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            isOpen ? 'close_shift'.tr() : 'open_shift'.tr(),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            isOpen
                ? 'Smenani yopish uchun yakuniy qoldiqni kiriting'
                : 'Smenani ochish uchun boshlang\'ich qoldiqni kiriting',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),

          // Shift stats (when closing)
          if (isOpen && shift.currentShift != null) ...[
            const SizedBox(height: 24),
            _buildShiftStats(isDark, shift),
          ],

          const SizedBox(height: 24),

          // Balance input
          TextField(
            controller: _balanceCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: isOpen ? 'closing_balance'.tr() : 'opening_balance'.tr(),
              suffixText: 'UZS',
              prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          // Notes (when closing)
          if (isOpen) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'notes'.tr(),
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text('cancel'.tr()),
                  onPressed: () => context.go(AppRoutes.home),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: shift.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(
                          isOpen ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          size: 20,
                        ),
                  label: Text(
                    isOpen ? 'close_shift'.tr() : 'open_shift'.tr(),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: shift.loading
                      ? null
                      : () => _performShiftAction(context, shift, isOpen),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOpen ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftStats(bool isDark, ShiftProvider shiftProv) {
    final s = shiftProv.currentShift!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        children: [
          _StatRow(
            icon: Icons.receipt_long_rounded,
            label: 'total_sales'.tr(),
            value: '${s.totalSales}',
            color: Colors.blue,
          ),
          const SizedBox(height: 10),
          _StatRow(
            icon: Icons.monetization_on_rounded,
            label: 'shift_revenue'.tr(),
            value: '${_fmtNum(s.totalRevenue)} UZS',
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          _StatRow(
            icon: Icons.timer_rounded,
            label: 'shift_duration'.tr(),
            value: _fmtDuration(s.duration),
            color: Colors.orange,
          ),
          const SizedBox(height: 10),
          _StatRow(
            icon: Icons.account_balance_wallet_rounded,
            label: 'opening_balance'.tr(),
            value: '${_fmtNum(s.openingBalance)} UZS',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Future<void> _performShiftAction(
      BuildContext context, ShiftProvider shift, bool isOpen) async {
    final balance = double.tryParse(_balanceCtrl.text.trim()) ?? 0.0;

    bool ok;
    if (isOpen) {
      ok = await shift.closeShift(balance, _notesCtrl.text.trim());
    } else {
      ok = await shift.openShift(balance);
    }

    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isOpen ? 'shift_closed'.tr() : 'shift_open'.tr()),
        backgroundColor: isOpen ? Colors.orange : Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      context.go(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(shift.error ?? 'error'.tr()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String _fmtNum(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '$h ${'hours'.tr()} $m ${'minutes'.tr()}';
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }
}
