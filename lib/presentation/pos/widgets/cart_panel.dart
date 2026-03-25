import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/local/hive_service.dart';
import '../../../domain/models/cart_item_model.dart';
import '../../../core/di/injection.dart';
import '../bloc/pos_bloc.dart';
import '../bloc/pos_event.dart';
import '../bloc/pos_state.dart';
import '../../payment/payment_screen.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(left: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              _CartHeader(state: state),
              Expanded(child: _CartItemList(state: state)),
              if (state.selectedCustomer != null) _CustomerChip(state: state),
              _CartSummary(state: state),
              _CartActions(state: state),
            ],
          ),
        );
      },
    );
  }
}

class _CartHeader extends StatelessWidget {
  final PosState state;
  const _CartHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cart tabs — shown only when more than one cart is open
        if (state.carts.length > 1)
          Container(
            color: AppColors.surfaceVariant,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: state.carts.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final cart = entry.value;
                  final isActive = idx == state.activeCartIndex;
                  return GestureDetector(
                    onTap: () => context.read<PosBloc>().add(CartSwitched(idx)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : AppColors.surface,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        border: Border.all(
                          color: isActive ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cart.label,
                            style: TextStyle(
                              color: isActive ? Colors.white : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          if (cart.hasItems) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${cart.itemCount}',
                                style: TextStyle(
                                  color: isActive ? Colors.white : AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => context.read<PosBloc>().add(CartRemoved(idx)),
                            child: Icon(
                              Icons.close,
                              size: 13,
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                '${state.activeCart.label} (${state.cartItemCount})',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // Add new cart button
              IconButton(
                icon: Icon(Icons.add_box_outlined, color: AppColors.primary, size: 20),
                tooltip: 'Yangi savat',
                onPressed: () => context.read<PosBloc>().add(CartAdded()),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              if (state.hasItems)
                IconButton(
                  icon: Icon(Icons.delete_sweep_outlined, color: AppColors.error, size: 20),
                  tooltip: 'Savatni tozalash',
                  onPressed: () => context.read<PosBloc>().add(CartCleared()),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartItemList extends StatelessWidget {
  final PosState state;
  const _CartItemList({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 60, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Savat bo\'sh', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 8),
            Text('Mahsulotni bosib qo\'shing', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.cartItems.length,
      separatorBuilder: (_, __) => Divider(color: AppColors.border, height: 1),
      itemBuilder: (context, index) {
        final item = state.cartItems[index];
        return Dismissible(
          key: Key('cart_${item.product.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: AppColors.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => context.read<PosBloc>().add(CartItemRemoved(item.product.id)),
          child: GestureDetector(
            onLongPress: () => _showContextMenu(context, item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${_fmt(item.unitPrice)} × ${item.quantity.toInt()}',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                            if (item.discountPercent > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '-${item.discountPercent.toInt()}%',
                                  style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            if (item.customPrice != null) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'O\'zg.',
                                  style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _QtyButton(
                        icon: Icons.remove,
                        onTap: () => context.read<PosBloc>().add(
                          CartItemQuantityChanged(item.product.id, item.quantity - 1),
                        ),
                      ),
                      Container(
                        width: 32,
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity.toInt()}',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      _QtyButton(
                        icon: Icons.add,
                        onTap: () => context.read<PosBloc>().add(
                          CartItemQuantityChanged(item.product.id, item.quantity + 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      _fmt(item.subtotal),
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmt(double v) {
    return v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }

  void _showContextMenu(BuildContext context, CartItemModel item) {
    final user = sl<HiveService>().getUser();
    final isManager = user != null &&
        (user.role == 'SUPER_ADMIN' ||
            user.role == 'ADMIN' ||
            user.role == 'MANAGER');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  item.product.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.discount_outlined, color: Colors.green),
                title: const Text('Chegirma berish',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: item.discountPercent > 0
                    ? Text(
                        'Hozirgi: ${item.discountPercent.toInt()}%',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _showDiscountDialog(context, item);
                },
              ),
              if (isManager)
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Colors.blue),
                  title: const Text('Narxni o\'zgartirish',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(
                    'Hozirgi: ${_fmt(item.unitPrice)} UZS',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPriceDialog(context, item);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('O\'chirish',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<PosBloc>().add(CartItemRemoved(item.product.id));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showDiscountDialog(BuildContext context, CartItemModel item) {
    final ctrl = TextEditingController(
        text: item.discountPercent > 0 ? item.discountPercent.toInt().toString() : '');
    final quickChips = [5, 10, 15, 20];
    final posCtx = context;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Chegirma berish',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 20),
                decoration: InputDecoration(
                  labelText: 'Chegirma (%)',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  suffixText: '%',
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: quickChips.map((pct) {
                  return ActionChip(
                    label: Text('$pct%',
                        style: const TextStyle(fontSize: 13)),
                    backgroundColor: AppColors.surfaceVariant,
                    onPressed: () {
                      setDialogState(() => ctrl.text = pct.toString());
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final pct = double.tryParse(ctrl.text.trim()) ?? 0;
                if (pct >= 0 && pct <= 100) {
                  posCtx.read<PosBloc>().add(
                        ItemDiscountApplied(item.product.id, pct),
                      );
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Qo\'llash'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceDialog(BuildContext context, CartItemModel item) {
    final ctrl = TextEditingController(
        text: item.unitPrice.toStringAsFixed(0));
    final posCtx = context;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Narxni o\'zgartirish',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Asl narx: ${_fmt(item.product.sellPrice)} UZS',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 20),
              decoration: InputDecoration(
                labelText: 'Yangi narx',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                suffixText: 'UZS',
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(ctrl.text.trim());
              if (newPrice != null && newPrice > 0) {
                posCtx.read<PosBloc>().add(
                      ItemPriceChanged(item.product.id, newPrice),
                    );
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }
}

class _CustomerChip extends StatelessWidget {
  final PosState state;
  const _CustomerChip({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.person, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(state.selectedCustomer!.name, style: TextStyle(color: AppColors.primary, fontSize: 12))),
          if (state.discountPercent > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
              child: Text('-${state.discountPercent.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => context.read<PosBloc>().add(CustomerSelected(null)),
            child: Icon(Icons.close, size: 16, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final PosState state;
  const _CartSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(top: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _SummaryRow('Jami:', _fmt(state.subtotal)),
          if (state.discountPercent > 0) ...[
            const SizedBox(height: 4),
            _SummaryRow('Chegirma (${state.discountPercent.toInt()}%):', '-${_fmt(state.discountAmount)}', valueColor: AppColors.success),
          ],
          const SizedBox(height: 8),
          _SummaryRow('TO\'LOV:', _fmt(state.netAmount), bold: true, valueColor: AppColors.primary, fontSize: 18),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final formatted = v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
    return '$formatted UZS';
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  final double fontSize;
  const _SummaryRow(this.label, this.value, {this.bold = false, this.valueColor, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          color: bold ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: fontSize,
        )),
        Text(value, style: TextStyle(
          color: valueColor ?? AppColors.textPrimary,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          fontSize: fontSize,
        )),
      ],
    );
  }
}

class _CartActions extends StatelessWidget {
  final PosState state;
  const _CartActions({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: state.hasItems
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<PosBloc>(),
                        child: const PaymentScreen(),
                      ),
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.payment, size: 20),
          label: const Text('TO\'LOV QILISH', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            disabledBackgroundColor: AppColors.border,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: AppColors.textPrimary),
      ),
    );
  }
}
