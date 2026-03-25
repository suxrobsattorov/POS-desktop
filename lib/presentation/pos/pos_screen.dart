import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/di/injection.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/customer_repository.dart';
import '../../data/remote/sale_repository.dart';
import '../../data/remote/sync_service.dart';
import 'bloc/pos_bloc.dart';
import 'bloc/pos_event.dart';
import 'bloc/pos_state.dart';
import 'widgets/product_grid.dart';
import 'widgets/cart_panel.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PosBloc(
        hiveService: sl<HiveService>(),
        saleRepository: sl<SaleRepository>(),
        syncService: sl<SyncService>(),
        customerRepository: CustomerRepository(sl<ApiClient>()),
      )..add(PosInitialized()),
      child: const _PosView(),
    );
  }
}

class _PosView extends StatefulWidget {
  const _PosView();

  @override
  State<_PosView> createState() => _PosViewState();
}

class _PosViewState extends State<_PosView> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  // ── Hardware barcode scanner listener ────────────────────────────────────────
  // USB barcode scanner klaviatura kabi ishlaydi:
  // Harflarni tez jo'natadi (<50ms interval), oxirida Enter bosadi.
  final StringBuffer _barcodeBuffer = StringBuffer();
  Timer? _barcodeTimer;
  DateTime? _lastKeyTime;

  // Periodic sync (har 5 daqiqada)
  Timer? _syncTimer;

  // Belgilar orasidagi maksimal vaqt: scanner juda tez yozadi (<100ms)
  static const _scannerMaxInterval = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final bloc = context.read<PosBloc>();
      bloc.add(SyncStarted());
      try {
        final syncService = sl<SyncService>();
        await syncService.forceSyncPendingSales();
        final pending = sl<HiveService>().pendingSalesCount;
        if (mounted) {
          bloc.add(SyncCompleted(synced: 0, failed: 0));
          if (pending == 0) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Sotuvlar serverga yuborildi'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ));
          }
        }
      } catch (_) {
        if (mounted) {
          bloc.add(SyncCompleted(synced: 0, failed: 1));
        }
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _barcodeTimer?.cancel();
    _syncTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    // Faqat KeyDownEvent ni qayta ishlaymiz
    if (event is! KeyDownEvent) return false;

    // Agar search field focused bo'lsa — barcode listenerga tegmaymiz
    if (_searchFocus.hasFocus) return false;

    final now = DateTime.now();

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      // Enter = barcode tugadi
      _barcodeTimer?.cancel();
      final barcode = _barcodeBuffer.toString().trim();
      _barcodeBuffer.clear();
      _lastKeyTime = null;

      if (barcode.length >= 4 && mounted) {
        context.read<PosBloc>().add(BarcodeScanned(barcode));
      }
      return barcode.isNotEmpty;
    }

    // Belgilar orasidagi vaqtni tekshiramiz
    final isScanner = _lastKeyTime == null ||
        now.difference(_lastKeyTime!) <= _scannerMaxInterval;

    if (!isScanner) {
      _barcodeBuffer.clear();
    }

    _lastKeyTime = now;

    final char = event.character;
    if (char != null && char.isNotEmpty) {
      _barcodeBuffer.write(char);
    }

    _barcodeTimer?.cancel();
    _barcodeTimer = Timer(const Duration(milliseconds: 200), () {
      _barcodeBuffer.clear();
      _lastKeyTime = null;
    });

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PosBloc, PosState>(
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.successMessage!),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            _TopBar(
              searchCtrl: _searchCtrl,
              searchFocus: _searchFocus,
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _CategoryBar(),
                        const Expanded(child: ProductGrid()),
                      ],
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: CartPanel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TOP BAR ───────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  const _TopBar({
    required this.searchCtrl,
    required this.searchFocus,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        final cs = Theme.of(context).colorScheme;
        final surfaceColor = Theme.of(context).cardColor;

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).dividerTheme.color ??
                        Colors.grey.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              // Shop name
              Row(children: [
                Icon(Icons.point_of_sale_rounded, color: cs.primary, size: 22),
                const SizedBox(width: 6),
                Text(
                  sl<HiveService>().getShopName(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ]),

              const SizedBox(width: 16),

              // Search
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  focusNode: searchFocus,
                  decoration: InputDecoration(
                    hintText: 'search_products'.tr(),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                    suffixIcon: searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              searchCtrl.clear();
                              context
                                  .read<PosBloc>()
                                  .add(ProductSearchChanged(''));
                            },
                          )
                        : null,
                  ),
                  onChanged: (q) =>
                      context.read<PosBloc>().add(ProductSearchChanged(q)),
                ),
              ),

              const SizedBox(width: 8),

              // Barcode scan button
              IconButton(
                icon: Icon(Icons.qr_code_scanner, color: cs.primary),
                tooltip: 'barcode_scan'.tr(),
                onPressed: () => _showBarcodeScanner(context),
              ),

              // Customer by phone button
              IconButton(
                icon: Icon(Icons.person_add_alt_1_rounded, color: cs.primary),
                tooltip: 'Mijoz qo\'shish (telefon orqali)',
                onPressed: () => _showCustomerByPhoneDialog(context),
              ),

              // Sync indicator
              if (state.isSyncing) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Sync...',
                        style: TextStyle(color: Colors.blue, fontSize: 11)),
                  ]),
                ),
              ] else if (state.pendingSalesCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.sync_problem_rounded, size: 13, color: Colors.orange),
                    const SizedBox(width: 3),
                    Text('${state.pendingSalesCount} pending',
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 11)),
                  ]),
                ),
              ],

              const SizedBox(width: 8),

              // Online/Offline label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: state.isOnline
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.isOnline ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    state.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: state.isOnline ? Colors.green : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
              ),

              const SizedBox(width: 8),

              // History
              IconButton(
                icon: const Icon(Icons.history, size: 20),
                tooltip: 'history'.tr(),
                onPressed: () => context.push(AppRoutes.history),
              ),

              // Settings
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                tooltip: 'settings'.tr(),
                onPressed: () => context.push(AppRoutes.settings),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomerByPhoneDialog(BuildContext context) {
    final phoneCtrl = TextEditingController();
    final posCtx = context;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mijoz qidirish',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                autofocus: true,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Telefon raqam',
                  labelStyle: const TextStyle(color: Colors.grey),
                  hintText: '+998 90 000 00 00',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF374151),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.phone, color: Colors.grey, size: 18),
                ),
                onSubmitted: (_) {
                  final phone = phoneCtrl.text.trim();
                  if (phone.isEmpty) return;
                  posCtx.read<PosBloc>().add(CustomerSearchByPhone(phone));
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) return;
              posCtx.read<PosBloc>().add(CustomerSearchByPhone(phone));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Qidirish'),
          ),
        ],
      ),
    );
  }

  void _showBarcodeScanner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: 320,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('scan_barcode'.tr(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcode = capture.barcodes.first.rawValue;
                    if (barcode != null) {
                      Navigator.pop(context);
                      try {
                        final product =
                            sl<HiveService>().getProductByBarcode(barcode);
                        context
                            .read<PosBloc>()
                            .add(ProductAddedToCart(product));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${product.name} savatga qo\'shildi'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ));
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('product_not_found'.tr()),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CATEGORY BAR ──────────────────────────────────────────────────────────────
class _CategoryBar extends StatelessWidget {
  const _CategoryBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        final categories = state.categories;
        if (categories.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 44,
          color: Theme.of(context).cardColor,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _CategoryChip(
                label: 'all_categories'.tr(),
                selected: state.selectedCategoryId == null,
                onTap: () =>
                    context.read<PosBloc>().add(CategorySelected(null)),
              ),
              ...categories.map((cat) => _CategoryChip(
                    label: cat.name,
                    selected: state.selectedCategoryId == cat.id,
                    onTap: () =>
                        context.read<PosBloc>().add(CategorySelected(cat.id)),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : cs.onSurface.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
