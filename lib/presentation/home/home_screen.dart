import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/injection.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/providers/shift_provider.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/auth_repository.dart';
import '../../data/remote/sync_service.dart';
import '../../domain/models/user_model.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_event.dart';
import '../auth/bloc/auth_state.dart';
import '../common/pin_lock_screen.dart';

// ── Colors ────────────────────────────────────────────────────────────────────

const _bgColor = Color(0xFF0D1117);
const _surfaceColor = Color(0xFF161B22);
const _primaryColor = Color(0xFF2563EB);
const _borderColor = Color(0xFF30363D);

// ── Weekday / Month names ─────────────────────────────────────────────────────

const List<String> _weekdays = [
  'Dushanba',
  'Seshanba',
  'Chorshanba',
  'Payshanba',
  'Juma',
  'Shanba',
  'Yakshanba',
];

const List<String> _months = [
  'yanvar',
  'fevral',
  'mart',
  'aprel',
  'may',
  'iyun',
  'iyul',
  'avgust',
  'sentabr',
  'oktabr',
  'noyabr',
  'dekabr',
];

// ── Nav Menu items ────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

const List<_NavItem> _navItems = [
  _NavItem(
    icon: Icons.point_of_sale_rounded,
    label: 'POS Kassa',
    route: AppRoutes.pos,
  ),
  _NavItem(
    icon: Icons.history_rounded,
    label: 'Sotuv tarixi',
    route: AppRoutes.history,
  ),
  _NavItem(
    icon: Icons.access_time_rounded,
    label: 'Smena',
    route: AppRoutes.shift,
  ),
  _NavItem(
    icon: Icons.settings_outlined,
    label: 'Sozlamalar',
    route: AppRoutes.settings,
  ),
];

// ── HomeScreen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // PIN dialog state
  bool _showPinDialog = false;
  String _pinDialogTarget = '';
  String _pin = '';
  String? _pinError;
  bool _pinLoading = false;

  // Selected user for PIN login
  String? _selectedUsername;

  // Currently selected nav item (for highlight, not routing)
  String _selectedRoute = AppRoutes.pos;

  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _authBloc = AuthBloc(
      authRepository: sl<AuthRepository>(),
      hiveService: sl<HiveService>(),
      syncService: sl<SyncService>(),
    );
    _selectedUsername = sl<HiveService>().getUser()?.username ?? '';
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _authBloc.close();
    super.dispose();
  }

  // ── PIN actions ─────────────────────────────────────────────────────────────

  void _navigateTo(String route) {
    setState(() => _selectedRoute = route);
    context.go(route);
  }

  void _openPinDialog(String route) {
    setState(() {
      _pinDialogTarget = route;
      _showPinDialog = true;
      _pin = '';
      _pinError = null;
      _pinLoading = false;
      _selectedRoute = route;
    });
  }

  void _closePinDialog() {
    setState(() {
      _showPinDialog = false;
      _pin = '';
      _pinError = null;
      _pinLoading = false;
    });
  }

  void _appendDigit(String digit) {
    if (_pinLoading || _pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _pinError = null;
    });
    if (_pin.length == 4) _submitPin();
  }

  void _deleteDigit() {
    if (_pinLoading || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = null;
    });
  }

  void _submitPin() {
    final username = _selectedUsername;
    if (username == null || username.isEmpty) {
      setState(() => _pinError = 'Foydalanuvchi aniqlanmadi');
      return;
    }
    setState(() => _pinLoading = true);
    _authBloc.add(PinLoginRequested(username, _pin));
  }

  // ── Keyboard ─────────────────────────────────────────────────────────────────

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !_showPinDialog) return;

    final logical = event.logicalKey;
    if (logical == LogicalKeyboardKey.escape) {
      _closePinDialog();
      return;
    }
    if (logical == LogicalKeyboardKey.backspace) {
      _deleteDigit();
      return;
    }

    final digitMap = {
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };

    final digit = digitMap[logical];
    if (digit != null) _appendDigit(digit);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: BlocListener<AuthBloc, AuthState>(
        bloc: _authBloc,
        listener: (context, state) {
          if (state is AuthAuthenticated && _showPinDialog) {
            final route = _pinDialogTarget;
            setState(() {
              _showPinDialog = false;
              _pin = '';
              _pinError = null;
              _pinLoading = false;
            });
            if (context.mounted) context.go(route);
          } else if (state is AuthError) {
            setState(() {
              _pinError = 'PIN noto\'g\'ri, qayta urinib ko\'ring';
              _pin = '';
              _pinLoading = false;
            });
          } else if (state is AuthLoading) {
            setState(() => _pinLoading = true);
          }
        },
        child: KeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Scaffold(
            backgroundColor: _bgColor,
            body: Stack(
              children: [
                Row(
                  children: [
                    // ── Left Nav Panel 240px ──────────────────────────
                    _NavPanel(
                      now: _now,
                      selectedRoute: _selectedRoute,
                      onItemTap: _openPinDialog,
                      onLogout: _handleLogout,
                      onLock: _handleLockScreen,
                    ),
                    // ── Right Content Area ────────────────────────────
                    Expanded(
                      child: _ContentArea(now: _now),
                    ),
                  ],
                ),

                // ── PIN Dialog Overlay ────────────────────────────────
                if (_showPinDialog)
                  _PinDialogOverlay(
                    pin: _pin,
                    pinError: _pinError,
                    pinLoading: _pinLoading,
                    onClose: _closePinDialog,
                    onDigit: _appendDigit,
                    onDelete: _deleteDigit,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLockScreen() {
    final user = sl<HiveService>().getUser();
    final name = (user?.fullName.isNotEmpty == true)
        ? user!.fullName
        : (user?.username ?? 'Kassir');
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PinLockScreen(
        onUnlocked: () => Navigator.of(context).pop(),
        cashierName: name,
      ),
      fullscreenDialog: true,
    ));
  }

  void _handleLogout() {
    final shift = context.read<ShiftProvider>();
    if (shift.isShiftOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Smena ochiq, oldin yoping'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chiqish', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Kassadan chiqmoqchimisiz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await sl<HiveService>().clearAuth();
              if (context.mounted) context.go(AppRoutes.login);
            },
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
  }
}

// ── Nav Panel ─────────────────────────────────────────────────────────────────

class _NavPanel extends StatelessWidget {
  final DateTime now;
  final String selectedRoute;
  final void Function(String route) onItemTap;
  final VoidCallback onLogout;
  final VoidCallback onLock;

  const _NavPanel({
    required this.now,
    required this.selectedRoute,
    required this.onItemTap,
    required this.onLogout,
    required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    final hive = sl<HiveService>();
    final shopName = hive.getShopName();
    final user = hive.getUser();
    final displayName = (user?.fullName.isNotEmpty == true)
        ? user!.fullName
        : (user?.username ?? 'Foydalanuvchi');
    final role = _roleLabel(user?.role ?? '');

    return Container(
      width: 240,
      color: _surfaceColor,
      child: Column(
        children: [
          // ── Logo & shop name ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    size: 20,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    shopName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Menu items ──────────────────────────────────────────────
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _navItems.map((item) {
                final isSelected = selectedRoute == item.route;
                return _NavMenuItem(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onItemTap(item.route),
                );
              }).toList(),
            ),
          ),

          // ── Online / offline indicator ──────────────────────────────
          _OnlineIndicator(),

          // ── User info & logout ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, size: 18, color: _primaryColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        role,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  tooltip: 'Ekranni qulflash',
                  onPressed: onLock,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
                IconButton(
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  tooltip: 'Chiqish',
                  onPressed: onLogout,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'SUPER_ADMIN':
        return 'Super Admin';
      case 'ADMIN':
        return 'Admin';
      case 'CASHIER':
        return 'Kassir';
      case 'MANAGER':
        return 'Menejer';
      default:
        return role;
    }
  }
}

// ── Nav Menu Item ─────────────────────────────────────────────────────────────

class _NavMenuItem extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavMenuItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavMenuItem> createState() => _NavMenuItemState();
}

class _NavMenuItemState extends State<_NavMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? _primaryColor
                : (_hovered
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: 18,
                color: widget.isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Text(
                widget.item.label,
                style: TextStyle(
                  color: widget.isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Online Indicator ──────────────────────────────────────────────────────────

class _OnlineIndicator extends StatefulWidget {
  const _OnlineIndicator();

  @override
  State<_OnlineIndicator> createState() => _OnlineIndicatorState();
}

class _OnlineIndicatorState extends State<_OnlineIndicator> {
  bool _isOnline = true;
  late Timer _checkTimer;

  @override
  void initState() {
    super.initState();
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      // Simple connectivity heuristic — replaced by NetworkInfo if needed
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _checkTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Content Area ─────────────────────────────────────────────────────────────

class _ContentArea extends StatelessWidget {
  final DateTime now;

  const _ContentArea({required this.now});

  @override
  Widget build(BuildContext context) {
    final hive = sl<HiveService>();
    final pendingCount = hive.pendingSalesCount;

    return Container(
      color: _bgColor,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────
          _ClockHeader(now: now),
          const SizedBox(height: 32),

          // ── Smena holati ────────────────────────────────────────────
          _ShiftStatusCard(),
          const SizedBox(height: 20),

          // ── POS ga o'tish ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _PosButton(),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(width: 16),
                _PendingBadgeCard(count: pendingCount),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ── Boshqa kassir ─────────────────────────────────────────────
          _SwitchCashierButton(),
        ],
      ),
    );
  }
}

// ── Clock Header ──────────────────────────────────────────────────────────────

class _ClockHeader extends StatelessWidget {
  final DateTime now;

  const _ClockHeader({required this.now});

  @override
  Widget build(BuildContext context) {
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final weekday = _weekdays[now.weekday - 1];
    final month = _months[now.month - 1];
    final dateStr = '$weekday, ${now.day} $month ${now.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$h:$m',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w200,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Shift Status Card ─────────────────────────────────────────────────────────

class _ShiftStatusCard extends StatelessWidget {
  const _ShiftStatusCard();

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<ShiftProvider>();
    final isOpen = shift.isShiftOpen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isOpen
            ? const Color(0xFF0D2818)
            : const Color(0xFF1A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpen
              ? const Color(0xFF1DB954).withValues(alpha: 0.4)
              : const Color(0xFFFF4B4B).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isOpen
                  ? const Color(0xFF1DB954).withValues(alpha: 0.15)
                  : const Color(0xFFFF4B4B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 28,
              color: isOpen ? const Color(0xFF1DB954) : const Color(0xFFFF4B4B),
            ),
          ),
          const SizedBox(width: 20),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'SMENA OCHIQ' : 'SMENA YOPIQ',
                  style: TextStyle(
                    color: isOpen
                        ? const Color(0xFF1DB954)
                        : const Color(0xFFFF4B4B),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (isOpen && shift.currentShift != null) ...[
                  Text(
                    'Ochilgan: ${_formatTime(shift.currentShift!.openedAt)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Sotuvlar: ${shift.currentShift!.totalSales}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                ] else
                  Text(
                    'Smena ochilmagan',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),

          // Quick action
          TextButton(
            onPressed: () => context.go(AppRoutes.shift),
            style: TextButton.styleFrom(
              foregroundColor: isOpen
                  ? const Color(0xFF1DB954)
                  : const Color(0xFFFF4B4B),
            ),
            child: Text(isOpen ? 'Yopish' : 'Ochish'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── POS Button ────────────────────────────────────────────────────────────────

class _PosButton extends StatefulWidget {
  const _PosButton();

  @override
  State<_PosButton> createState() => _PosButtonState();
}

class _PosButtonState extends State<_PosButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.pos),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                  : [
                      const Color(0xFF2563EB).withValues(alpha: 0.85),
                      const Color(0xFF1D4ED8).withValues(alpha: 0.85),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.point_of_sale_rounded,
                  color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Text(
                'POS GA O\'TISH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pending Badge Card ────────────────────────────────────────────────────────

class _PendingBadgeCard extends StatelessWidget {
  final int count;

  const _PendingBadgeCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.sync_problem_rounded, color: Colors.orange, size: 24),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Pending',
            style: TextStyle(
              color: Colors.orange.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Switch Cashier Button ─────────────────────────────────────────────────────

class _SwitchCashierButton extends StatelessWidget {
  const _SwitchCashierButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.switch_account_rounded, size: 18),
      label: const Text('Boshqa kassir'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: BorderSide(color: _borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => _showSwitchCashierDialog(context),
    );
  }

  Future<void> _showSwitchCashierDialog(BuildContext context) async {
    // Users list + PIN numpad
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _SwitchCashierDialog(),
    );
  }
}

// ── Switch Cashier Dialog ──────────────────────────────────────────────────────

class _SwitchCashierDialog extends StatefulWidget {
  const _SwitchCashierDialog();

  @override
  State<_SwitchCashierDialog> createState() => _SwitchCashierDialogState();
}

class _SwitchCashierDialogState extends State<_SwitchCashierDialog> {
  List<dynamic> _users = [];
  dynamic _selectedUser;
  String _pin = '';
  bool _loading = false;
  bool _pinError = false;
  String? _errorText;
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    // Local taniqli foydalanuvchilar
    final local = sl<HiveService>().getKnownUsers();
    setState(() {
      _users = local;
      _loadingUsers = false;
    });

    // Server dan yangilash
    try {
      final resp = await sl<ApiClient>().dio.get('/users/list');
      final List data = resp.data is List
          ? resp.data
          : (resp.data['data'] ?? resp.data['content'] ?? []);
      if (mounted) {
        setState(() => _users = data
            .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
            .toList());
      }
    } catch (_) {}
  }

  void _onPinKey(String key) {
    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _pinError = false;
        });
      }
      return;
    }
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _pinError = false;
    });
    if (_pin.length == 4) _submitPin();
  }

  Future<void> _submitPin() async {
    if (_selectedUser == null) return;
    setState(() => _loading = true);
    try {
      final repo = AuthRepository(sl<ApiClient>());
      final result = await repo.loginWithPin(
          (_selectedUser as UserModel).username, _pin);
      await sl<HiveService>().saveAuthData(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        user: result.user,
      );
      await sl<HiveService>().saveKnownUser(result.user);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _loading = false;
        _pinError = true;
        _errorText = 'Noto\'g\'ri PIN';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _selectedUser == null
              ? _buildUserList()
              : _buildPinInput(),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Kassirni tanlang',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingUsers)
          const Center(child: CircularProgressIndicator(color: _primaryColor))
        else if (_users.isEmpty)
          const Text('Foydalanuvchilar topilmadi',
              style: TextStyle(color: Colors.white54))
        else
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: _users.length,
              itemBuilder: (context, i) {
                final user = _users[i] as UserModel;
                final initials = _initials(
                    user.fullName.isNotEmpty ? user.fullName : user.username);
                return InkWell(
                  onTap: () => setState(() => _selectedUser = user),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _primaryColor.withValues(alpha: 0.2),
                          child: Text(initials,
                              style: const TextStyle(color: _primaryColor, fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          user.fullName.isNotEmpty ? user.fullName : user.username,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPinInput() {
    final user = _selectedUser as UserModel;
    final initials = _initials(user.fullName.isNotEmpty ? user.fullName : user.username);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: _primaryColor.withValues(alpha: 0.2),
          child: Text(initials,
              style: const TextStyle(color: _primaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        Text(user.fullName.isNotEmpty ? user.fullName : user.username,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final filled = i < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16, height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pinError ? Colors.red : (filled ? _primaryColor : Colors.transparent),
                border: Border.all(
                  color: _pinError ? Colors.red : (filled ? _primaryColor : Colors.white30),
                  width: 2,
                ),
              ),
            );
          }),
        ),
        if (_pinError && _errorText != null) ...[
          const SizedBox(height: 8),
          Text(_errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        const SizedBox(height: 20),
        if (_loading)
          const CircularProgressIndicator(color: _primaryColor)
        else
          _buildNumpad(),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() {
            _selectedUser = null;
            _pin = '';
            _pinError = false;
          }),
          child: const Text('Boshqa kassirni tanlash', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildNumpad() {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return SizedBox(
      width: 200,
      child: Wrap(
        spacing: 10, runSpacing: 10,
        children: keys.map((k) {
          if (k.isEmpty) return const SizedBox(width: 56, height: 48);
          return SizedBox(
            width: 56, height: 48,
            child: Material(
              color: k == '⌫' ? const Color(0xFF21262D) : _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _onPinKey(k),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  alignment: Alignment.center,
                  child: k == '⌫'
                      ? const Icon(Icons.backspace_rounded, size: 18, color: Colors.white54)
                      : Text(k, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── PIN Dialog Overlay ────────────────────────────────────────────────────────

class _PinDialogOverlay extends StatelessWidget {
  final String pin;
  final String? pinError;
  final bool pinLoading;
  final VoidCallback onClose;
  final void Function(String) onDigit;
  final VoidCallback onDelete;

  const _PinDialogOverlay({
    required this.pin,
    required this.pinError,
    required this.pinLoading,
    required this.onClose,
    required this.onDigit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PIN kiriting',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        onPressed: onClose,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kassa ga kirish uchun PIN kodni kiriting',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // PIN dots
                  _PinDots(pin: pin, loading: pinLoading),

                  // Error
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: pinError != null
                        ? Padding(
                            key: const ValueKey('err'),
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              pinError!,
                              style: const TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const SizedBox(key: ValueKey('no_err'), height: 12),
                  ),

                  const SizedBox(height: 20),

                  // Keypad
                  _Keypad(
                    onDigit: onDigit,
                    onDelete: onDelete,
                    enabled: !pinLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── PIN Dots ──────────────────────────────────────────────────────────────────

class _PinDots extends StatelessWidget {
  final String pin;
  final bool loading;

  const _PinDots({required this.pin, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 24,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(_primaryColor),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < pin.length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 16,
            height: 16,
            decoration: filled
                ? BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  )
                : BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
          ),
        );
      }),
    );
  }
}

// ── Keypad ────────────────────────────────────────────────────────────────────

class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final bool enabled;

  const _Keypad({
    required this.onDigit,
    required this.onDelete,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72 + 8),
            _KeypadButton(
              label: '0',
              onTap: enabled ? () => onDigit('0') : null,
            ),
            const SizedBox(width: 8),
            _KeypadButton(
              icon: Icons.backspace_outlined,
              isDelete: true,
              onTap: enabled ? onDelete : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _KeypadButton(
            label: d,
            onTap: enabled ? () => onDigit(d) : null,
          ),
        );
      }).toList(),
    );
  }
}

// ── Keypad Button ─────────────────────────────────────────────────────────────

class _KeypadButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isDelete;

  const _KeypadButton({
    this.label,
    this.icon,
    required this.onTap,
    this.isDelete = false,
  });

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: isDisabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _pressed
                ? _primaryColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: widget.icon != null
              ? Icon(
                  widget.icon,
                  color: Colors.white.withValues(alpha: isDisabled ? 0.2 : 0.6),
                  size: 18,
                )
              : Text(
                  widget.label ?? '',
                  style: TextStyle(
                    color: Colors.white
                        .withValues(alpha: isDisabled ? 0.2 : 0.9),
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                  ),
                ),
        ),
      ),
    );
  }
}
