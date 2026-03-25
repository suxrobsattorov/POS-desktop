import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/injection.dart';
import '../../core/network/api_client.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/auth_repository.dart';
import '../../domain/models/user_model.dart';

/// Ekranni qulflash va PIN orqali ochish widget.
///
/// Ishlatish:
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => PinLockScreen(
///     onUnlocked: () => Navigator.of(context).pop(),
///     cashierName: 'Ali Valiyev',
///   ),
///   fullscreenDialog: true,
/// ));
/// ```
class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final String cashierName;

  const PinLockScreen({
    super.key,
    required this.onUnlocked,
    required this.cashierName,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  // State
  List<UserModel> _users = [];
  UserModel? _selectedUser;
  String _pin = '';
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorText;

  // Shake animation
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 12).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeCtrl);

    _loadUsers();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    // Avval local Hive dan taniqli foydalanuvchilar
    final local = sl<HiveService>().getKnownUsers();
    if (mounted) {
      setState(() => _users = local);
    }

    // Keyin server dan yangilash
    try {
      final response = await sl<ApiClient>().dio.get('/users/list');
      final List data = response.data is List
          ? response.data
          : (response.data['data'] ?? response.data['content'] ?? []);
      final users = data
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (mounted) {
        setState(() => _users = users);
      }
    } catch (_) {
      // Server xato — local ma'lumotlar ko'rsatildi
    }
  }

  void _onUserSelected(UserModel user) {
    setState(() {
      _selectedUser = user;
      _pin = '';
      _hasError = false;
      _errorText = null;
    });
  }

  void _onPinKey(String key) {
    HapticFeedback.lightImpact();
    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _hasError = false;
        });
      }
      return;
    }
    if (_pin.length >= 4) return;

    setState(() {
      _pin += key;
      _hasError = false;
    });

    if (_pin.length == 4) {
      _submitPin();
    }
  }

  Future<void> _submitPin() async {
    if (_selectedUser == null) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = AuthRepository(sl<ApiClient>());
      final result = await authRepo.loginWithPin(_selectedUser!.username, _pin);

      await sl<HiveService>().saveAuthData(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        user: result.user,
      );
      await sl<HiveService>().saveKnownUser(result.user);

      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onUnlocked();
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorText = 'Noto\'g\'ri PIN';
        _pin = '';
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _selectedUser == null ? _buildUserGrid() : _buildPinPad(),
    );
  }

  // ── User Selection Grid ───────────────────────────────────────────────────

  Widget _buildUserGrid() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Kassirni tanlang',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hozir: ${widget.cashierName}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              if (_users.isEmpty)
                const CircularProgressIndicator(color: AppColors.primary)
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return _UserAvatar(
                      user: user,
                      onTap: () => _onUserSelected(user),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PIN Pad ───────────────────────────────────────────────────────────────

  Widget _buildPinPad() {
    final initials = _getInitials(_selectedUser!.fullName.isNotEmpty
        ? _selectedUser!.fullName
        : _selectedUser!.username);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primary,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedUser!.fullName.isNotEmpty
                    ? _selectedUser!.fullName
                    : _selectedUser!.username,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedUser!.role,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 32),

              // PIN dots with shake animation
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _shakeCtrl.isAnimating
                          ? (_shakeAnim.value * (_shakeCtrl.value < 0.5 ? 1 : -1))
                          : 0,
                      0,
                    ),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: filled ? 18 : 15,
                      height: filled ? 18 : 15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasError
                            ? Colors.red
                            : filled
                                ? AppColors.primary
                                : Colors.transparent,
                        border: Border.all(
                          color: _hasError
                              ? Colors.red
                              : filled
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              if (_hasError && _errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],

              const SizedBox(height: 32),

              // Numpad
              if (_isLoading)
                const CircularProgressIndicator(color: AppColors.primary)
              else
                _buildNumpad(),

              const SizedBox(height: 20),

              // Back button
              TextButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, size: 16,
                    color: AppColors.textSecondary),
                label: const Text(
                  'Boshqa kassirni tanlash',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                onPressed: () {
                  setState(() {
                    _selectedUser = null;
                    _pin = '';
                    _hasError = false;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return SizedBox(
      width: 240,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: keys.map((k) {
          if (k.isEmpty) return const SizedBox(width: 64, height: 56);
          return SizedBox(
            width: 64,
            height: 56,
            child: Material(
              color: k == '⌫'
                  ? AppColors.surfaceVariant
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _onPinKey(k),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: k == '⌫'
                      ? const Icon(Icons.backspace_rounded, size: 20,
                          color: AppColors.textSecondary)
                      : Text(
                          k,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── User Avatar Card ─────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _UserAvatar({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(
        user.fullName.isNotEmpty ? user.fullName : user.username);
    final color = _colorForRole(user.role);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                initials,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.fullName.isNotEmpty ? user.fullName : user.username,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              _roleLabel(user.role),
              style: TextStyle(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _colorForRole(String role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return Colors.red;
      case 'ADMIN':
        return Colors.orange;
      case 'MANAGER':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return 'Super Admin';
      case 'ADMIN':
        return 'Admin';
      case 'MANAGER':
        return 'Menejer';
      case 'CASHIER':
        return 'Kassir';
      default:
        return role;
    }
  }
}
