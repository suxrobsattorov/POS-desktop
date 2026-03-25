import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/shift_provider.dart';

class ShiftDialog extends StatefulWidget {
  final bool isOpen;
  const ShiftDialog({super.key, required this.isOpen});

  @override
  State<ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<ShiftDialog> {
  final _balanceCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _balanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isOpen ? _buildCloseDialog(context) : _buildOpenDialog(context);
  }

  Widget _buildOpenDialog(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.play_circle, color: Colors.green),
        const SizedBox(width: 8),
        Text('open_shift'.tr()),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Kassadagi boshlang\'ich qoldiqni kiriting',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _balanceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'opening_balance'.tr(),
              suffixText: 'UZS',
              prefixIcon: const Icon(Icons.account_balance_wallet),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        Consumer<ShiftProvider>(
          builder: (ctx, shift, _) => ElevatedButton.icon(
            icon: shift.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow, size: 18),
            label: Text('open_shift'.tr()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: shift.loading
                ? null
                : () async {
                    final bal =
                        double.tryParse(_balanceCtrl.text.trim()) ?? 0.0;
                    final ok = await shift.openShift(bal);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            ok ? 'shift_open'.tr() : shift.error ?? 'error'.tr()),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ));
                    }
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildCloseDialog(BuildContext context) {
    final shiftProvider = context.read<ShiftProvider>();
    final shift = shiftProvider.currentShift;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.stop_circle, color: Colors.red),
        const SizedBox(width: 8),
        Text('close_shift'.tr()),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shift != null) ...[
            _InfoRow(
                icon: Icons.receipt_long,
                label: 'total_sales'.tr(),
                value: '${shift.totalSales} ta'),
            _InfoRow(
                icon: Icons.monetization_on,
                label: 'shift_revenue'.tr(),
                value:
                    '${_fmt(shift.totalRevenue)} UZS'),
            _InfoRow(
                icon: Icons.timer,
                label: 'shift_duration'.tr(),
                value: _duration(shift.duration)),
            const Divider(height: 24),
          ],
          TextField(
            controller: _balanceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'closing_balance'.tr(),
              suffixText: 'UZS',
              prefixIcon: const Icon(Icons.account_balance_wallet),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'notes'.tr(),
              prefixIcon: const Icon(Icons.notes),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        Consumer<ShiftProvider>(
          builder: (ctx, shift, _) => ElevatedButton.icon(
            icon: shift.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.stop, size: 18),
            label: Text('close_shift'.tr()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: shift.loading
                ? null
                : () async {
                    final bal =
                        double.tryParse(_balanceCtrl.text.trim()) ?? 0.0;
                    final ok =
                        await shift.closeShift(bal, _notesCtrl.text.trim());
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'shift_closed'.tr()
                            : shift.error ?? 'error'.tr()),
                        backgroundColor: ok ? Colors.orange : Colors.red,
                      ));
                    }
                  },
          ),
        ),
      ],
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');

  String _duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}s ${m}d';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
