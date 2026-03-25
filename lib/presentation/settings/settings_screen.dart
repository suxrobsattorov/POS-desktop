import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/injection.dart';
import '../../core/network/api_client.dart';
import '../../core/providers/app_settings_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/services/receipt_service.dart';
import '../../data/local/hive_service.dart';
import '../../data/local/pin_service.dart';
import '../../data/remote/sync_service.dart';
// ── SettingsScreen ─────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // ── AppBar ──────────────────────────────────────────────────
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border:
                    Border(bottom: BorderSide(color: AppColors.border)),
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
                  const Icon(Icons.settings_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Text(
                    'Sozlamalar',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab Bar ─────────────────────────────────────────────────
            Container(
              color: AppColors.surface,
              child: TabBar(
                tabAlignment: TabAlignment.start,
                isScrollable: true,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorWeight: 2,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.storefront_outlined, size: 16),
                    text: 'Do\'kon',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.print_outlined, size: 16),
                    text: 'Printer',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.tune_outlined, size: 16),
                    text: 'Tizim',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.storage_outlined, size: 16),
                    text: 'Ma\'lumotlar',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                ],
              ),
            ),

            // ── Tab Views ───────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Do'kon sozlamalari
                  const _ShopTab(),
                  // Tab 2: Printer sozlamalari
                  const _PrinterTab(),
                  // Tab 3: Tizim sozlamalari
                  const _SystemTab(),
                  // Tab 4: Ma'lumotlar
                  const _DataTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Do'kon Sozlamalari ─────────────────────────────────────────────────

class _ShopTab extends StatefulWidget {
  const _ShopTab();

  @override
  State<_ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<_ShopTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _headerCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  bool _loading = false;
  bool _saving = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _taxCtrl.dispose();
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    final hive = sl<HiveService>();
    _nameCtrl.text = hive.getSetting('shop_name') ?? '';
    _addressCtrl.text = hive.getSetting('shop_address') ?? '';
    _phoneCtrl.text = hive.getSetting('shop_phone') ?? '';
    _taxCtrl.text = hive.getTaxRate();
    _headerCtrl.text = hive.getSetting('receipt_header') ?? '';
    _footerCtrl.text = hive.getReceiptFooter();

    try {
      final resp = await sl<ApiClient>().dio.get(ApiConfig.settings);
      final List data = resp.data is List ? resp.data : [];
      final map = <String, String>{};
      for (final item in data) {
        map[item['key'].toString()] = item['value']?.toString() ?? '';
      }
      if (mounted) {
        setState(() {
          if (map['shop_name'] != null) _nameCtrl.text = map['shop_name']!;
          if (map['shop_address'] != null)
            _addressCtrl.text = map['shop_address']!;
          if (map['shop_phone'] != null) _phoneCtrl.text = map['shop_phone']!;
          if (map['tax_rate'] != null) _taxCtrl.text = map['tax_rate']!;
          if (map['receipt_header'] != null)
            _headerCtrl.text = map['receipt_header']!;
          if (map['receipt_footer'] != null)
            _footerCtrl.text = map['receipt_footer']!;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final payload = [
        {'key': 'shop_name', 'value': _nameCtrl.text.trim()},
        {'key': 'shop_address', 'value': _addressCtrl.text.trim()},
        {'key': 'shop_phone', 'value': _phoneCtrl.text.trim()},
        {'key': 'tax_rate', 'value': _taxCtrl.text.trim()},
        {'key': 'receipt_header', 'value': _headerCtrl.text.trim()},
        {'key': 'receipt_footer', 'value': _footerCtrl.text.trim()},
      ];
      await sl<ApiClient>().dio.post('/settings/bulk', data: payload);
      await sl<HiveService>().saveSettings({
        'shop_name': _nameCtrl.text.trim(),
        'shop_address': _addressCtrl.text.trim(),
        'shop_phone': _phoneCtrl.text.trim(),
        'tax_rate': _taxCtrl.text.trim(),
        'receipt_header': _headerCtrl.text.trim(),
        'receipt_footer': _footerCtrl.text.trim(),
      });
      if (mounted) {
        setState(() {
          _message = 'Sozlamalar saqlandi';
          _messageIsError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Saqlashda xato yuz berdi';
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TabSectionTitle('Do\'kon ma\'lumotlari'),
              const SizedBox(height: 16),
              _SettingsField(
                controller: _nameCtrl,
                label: 'Do\'kon nomi',
                icon: Icons.store_outlined,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Do\'kon nomini kiriting' : null,
              ),
              const SizedBox(height: 12),
              _SettingsField(
                controller: _addressCtrl,
                label: 'Manzil',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              _SettingsField(
                controller: _phoneCtrl,
                label: 'Telefon',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _SettingsField(
                controller: _taxCtrl,
                label: 'Soliq (%)',
                icon: Icons.percent_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 24),
              _TabSectionTitle('Chek sozlamalari'),
              const SizedBox(height: 16),
              _SettingsField(
                controller: _headerCtrl,
                label: 'Chek yuqori matni',
                icon: Icons.title_outlined,
                maxLines: 3,
                hint: 'Chek yuqorisida chiqadigan matn',
              ),
              const SizedBox(height: 12),
              _SettingsField(
                controller: _footerCtrl,
                label: 'Chek pastki matni',
                icon: Icons.text_snippet_outlined,
                maxLines: 3,
                hint: 'Rahmat! Yana keling. / Xaridingiz uchun rahmat.',
              ),
              const SizedBox(height: 24),
              if (_message != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _messageIsError
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _messageIsError
                          ? AppColors.error.withValues(alpha: 0.4)
                          : AppColors.success.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _messageIsError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: _messageIsError
                            ? AppColors.error
                            : AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _message!,
                        style: TextStyle(
                          color: _messageIsError
                              ? AppColors.error
                              : AppColors.success,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? 'Saqlanmoqda...' : 'Saqlash'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab 2: Printer Sozlamalari ────────────────────────────────────────────────

class _PrinterTab extends StatelessWidget {
  const _PrinterTab();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TabSectionTitle('Printer ulanish sozlamalari'),
            const SizedBox(height: 16),
            _SettingsCard(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.print, color: AppColors.primary),
                  title: const Text('Printerni yoqish',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('ESC/POS, USB, Network printer',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  value: settings.printerEnabled,
                  onChanged: settings.setPrinterEnabled,
                  activeColor: AppColors.primary,
                ),
                Divider(color: AppColors.border, height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.picture_as_pdf,
                      color: AppColors.primary),
                  title: const Text('PDF saqlash',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Chekni PDF faylga saqlash',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  value: settings.pdfEnabled,
                  onChanged: settings.setPdfEnabled,
                  activeColor: AppColors.primary,
                ),
                Divider(color: AppColors.border, height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.auto_fix_high,
                      color: AppColors.primary),
                  title: const Text('Avtomatik chiqarish',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('To\'lovdan keyin avtomatik bosish',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  value: settings.autoPrint,
                  onChanged: (settings.printerEnabled || settings.pdfEnabled)
                      ? settings.setAutoPrint
                      : null,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _TabSectionTitle('Test chek'),
            const SizedBox(height: 16),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined,
                      color: AppColors.primary),
                  title: const Text('Test chek chiqarish',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text(
                      'Printer sozlamalarini tekshirish uchun',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  trailing: ElevatedButton.icon(
                    onPressed: () => _printTest(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Test bosish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printTest(BuildContext context) async {
    final service = sl<ReceiptService>();
    final hive = sl<HiveService>();
    try {
      final pdf = await service.buildReceiptPdf(
        shopName: hive.getShopName(),
        shopAddress: hive.getSetting('shop_address') ?? '',
        shopPhone: hive.getSetting('shop_phone') ?? '',
        receiptFooter: hive.getReceiptFooter(),
        receiptNo: 'TEST-001',
        date: DateTime.now(),
        items: [
          {
            'name': 'Test mahsulot',
            'price': 15000.0,
            'qty': 2,
            'total': 30000.0
          },
          {
            'name': 'Namuna tovar',
            'price': 8500.0,
            'qty': 1,
            'total': 8500.0
          },
        ],
        total: 38500,
        paid: 50000,
        change: 11500,
        paymentMethod: 'Naqd',
        cashierName: hive.getUser()?.fullName ?? 'Kassir',
      );
      final ok = await service.printReceipt(pdf);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Test chek muvaffaqiyatli chiqarildi' : 'Printer xatosi'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Printer xatosi: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ── Tab 3: Tizim Sozlamalari ──────────────────────────────────────────────────

class _SystemTab extends StatefulWidget {
  const _SystemTab();

  @override
  State<_SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<_SystemTab> {
  final _urlCtrl = TextEditingController(text: ApiConfig.baseUrl);
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final response = await sl<ApiClient>().dio.get('/actuator/health');
      if (mounted) {
        setState(() {
          _testOk = response.statusCode == 200;
          _testResult = _testOk
              ? 'Ulanish muvaffaqiyatli'
              : 'Server javob berdi: ${response.statusCode}';
          _testing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testOk = false;
          _testResult = 'Ulanib bo\'lmadi';
          _testing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final isDark = settings.themeMode == ThemeMode.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API URL
            _TabSectionTitle('Tarmoq sozlamalari'),
            const SizedBox(height: 16),
            _SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _urlCtrl,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'API URL',
                          labelStyle: const TextStyle(
                              color: AppColors.textSecondary),
                          prefixIcon: const Icon(Icons.link_outlined,
                              size: 18),
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.inputBg,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_testResult != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _testOk
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _testOk
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: _testOk
                                    ? AppColors.success
                                    : AppColors.error,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _testResult!,
                                style: TextStyle(
                                  color: _testOk
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton.icon(
                        onPressed: _testing ? null : _testConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.network_check, size: 16),
                        label: Text(_testing
                            ? 'Tekshirilmoqda...'
                            : 'Ulanishni tekshirish'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Tema va Til
            _TabSectionTitle('Ko\'rinish va til'),
            const SizedBox(height: 16),
            _SettingsCard(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    isDark ? 'Qorong\'i tema' : 'Yorug\' tema',
                    style:
                        const TextStyle(color: AppColors.textPrimary),
                  ),
                  value: isDark,
                  onChanged: (v) =>
                      settings.setTheme(v ? ThemeMode.dark : ThemeMode.light),
                  activeColor: AppColors.primary,
                ),
                Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.language,
                      color: AppColors.primary),
                  title: const Text('Til',
                      style: TextStyle(color: AppColors.textPrimary)),
                  trailing: _LanguageDropdown(current: settings.language),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Versiya
            _TabSectionTitle('Versiya'),
            const SizedBox(height: 16),
            _SettingsCard(
              children: [
                const ListTile(
                  leading: Icon(Icons.phone_android, color: AppColors.primary),
                  title: Text('Ilova versiyasi',
                      style: TextStyle(color: AppColors.textPrimary)),
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.computer, color: AppColors.primary),
                  title: const Text('Backend versiyasi',
                      style: TextStyle(color: AppColors.textPrimary)),
                  trailing: _BackendVersion(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 4: Ma'lumotlar ────────────────────────────────────────────────────────

class _DataTab extends StatelessWidget {
  const _DataTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TabSectionTitle('Ma\'lumotlarni boshqarish'),
            const SizedBox(height: 16),
            _SettingsCard(
              children: [
                // Force Sync
                ListTile(
                  leading: const Icon(Icons.sync_rounded,
                      color: AppColors.primary),
                  title: const Text('Barcha ma\'lumotlarni qayta yuklash',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text(
                      'Mahsulotlar, kategoriyalar, to\'lov usullari',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  trailing: TextButton(
                    onPressed: () => _forceSync(context),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary),
                    child: const Text('Yangilash'),
                  ),
                ),
                Divider(color: AppColors.border, height: 1),

                // Pending sales sync
                ListTile(
                  leading: const Icon(Icons.upload_rounded,
                      color: AppColors.warning),
                  title: const Text('Pending sotuvlarni yuborish',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(
                    'Offline saqlangan: ${sl<HiveService>().pendingSalesCount} ta',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: TextButton(
                    onPressed: () => _syncPending(context),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.warning),
                    child: const Text('Yuborish'),
                  ),
                ),
                Divider(color: AppColors.border, height: 1),

                // Clear cache
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined,
                      color: AppColors.error),
                  title: const Text('Hive keshni tozalash',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text(
                      'Barcha lokal ma\'lumotlar o\'chiriladi',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  trailing: TextButton(
                    onPressed: () => _clearCache(context),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.error),
                    child: const Text('Tozalash'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Chiqish
            _TabSectionTitle('Chiqish'),
            const SizedBox(height: 16),
            _SettingsCard(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: const Text('Kassadan chiqish',
                      style: TextStyle(color: AppColors.error)),
                  subtitle: const Text('Hisob ma\'lumotlari o\'chiriladi',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  trailing: ElevatedButton(
                    onPressed: () => _handleLogout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Chiqish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forceSync(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Yangilanmoqda...'),
      backgroundColor: AppColors.info,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 1),
    ));
    try {
      await sl<SyncService>().syncAll();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Barcha ma\'lumotlar yangilandi'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Yangilashda xato'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _syncPending(BuildContext context) async {
    try {
      await sl<SyncService>().forceSyncPendingSales();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pending sotuvlar yuborildi'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Yuborishda xato'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _clearCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Keshni tozalash',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Mahsulot, kategoriya va to\'lov usullari ma\'lumotlari o\'chiriladi. '
          'Keyin qayta yuklanadi. Davom etasizmi?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              await sl<SyncService>().syncAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Kesh tozalandi va yangilandi'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: const Text('Tozalash'),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    final shift = context.read<ShiftProvider>();
    if (shift.isShiftOpen) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Smena ochiq, oldin yoping'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Chiqish',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Kassadan chiqmoqchimisiz?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await sl<HiveService>().clearAuth();
              sl<PinService>().clearPin();
              if (context.mounted) context.go(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _TabSectionTitle extends StatelessWidget {
  final String title;
  const _TabSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final String? hint;
  final String? Function(String?)? validator;

  const _SettingsField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintText: hint,
        hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.5),
            fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        isDense: true,
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  final String current;
  const _LanguageDropdown({required this.current});

  static const _langs = [
    {'code': 'uz', 'label': "O'zbek"},
    {'code': 'en', 'label': 'English'},
    {'code': 'ru', 'label': 'Русский'},
    {'code': 'uz_CY', 'label': 'Ўзбек'},
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppSettingsProvider>();
    return DropdownButton<String>(
      value: current,
      underline: const SizedBox(),
      dropdownColor: AppColors.surfaceVariant,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      items: _langs
          .map((l) => DropdownMenuItem(
                value: l['code'],
                child: Text(l['label']!),
              ))
          .toList(),
      onChanged: (val) async {
        if (val == null) return;
        await settings.setLanguage(val);
        if (context.mounted) {
          Locale locale;
          if (val == 'uz_CY') {
            locale = const Locale('uz', 'CY');
          } else {
            locale = Locale(val);
          }
          context.setLocale(locale);
        }
      },
    );
  }
}

class _BackendVersion extends StatefulWidget {
  const _BackendVersion();

  @override
  State<_BackendVersion> createState() => _BackendVersionState();
}

class _BackendVersionState extends State<_BackendVersion> {
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _fetchVersion();
  }

  Future<void> _fetchVersion() async {
    try {
      final response = await sl<ApiClient>().dio.get('/actuator/info');
      final build = response.data['build'] ?? {};
      final version =
          build['version'] ?? response.data['version'] ?? '1.0';
      if (mounted) setState(() => _version = '$version');
    } catch (_) {
      if (mounted) setState(() => _version = 'N/A');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _version,
      style: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── Backward compat: Sections ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ShiftStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textPrimary)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
