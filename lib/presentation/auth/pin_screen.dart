import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/auth_repository.dart';
import '../../data/remote/sync_service.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/auth_event.dart';
import 'bloc/auth_state.dart';

class PinScreen extends StatelessWidget {
  const PinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(
        authRepository: sl<AuthRepository>(),
        hiveService: sl<HiveService>(),
        syncService: sl<SyncService>(),
      ),
      child: const _PinView(),
    );
  }
}

class _PinView extends StatefulWidget {
  const _PinView();

  @override
  State<_PinView> createState() => _PinViewState();
}

class _PinViewState extends State<_PinView> {
  final _hiveService = sl<HiveService>();
  String _pin = '';
  String? _errorMessage;

  String get _savedUsername {
    final user = _hiveService.getUser();
    return user?.username ?? '';
  }

  String get _displayName {
    final user = _hiveService.getUser();
    if (user == null) return 'Kassir';
    return user.fullName.isNotEmpty ? user.fullName : user.username;
  }

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _errorMessage = null;
    });
    if (_pin.length == 4) {
      _submitPin();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  void _submitPin() {
    final username = _savedUsername;
    if (username.isEmpty) {
      _clearAndGoLogin();
      return;
    }
    context.read<AuthBloc>().add(PinLoginRequested(username, _pin));
  }

  Future<void> _clearAndGoLogin() async {
    await _hiveService.clearAuth();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(AppRoutes.home);
        } else if (state is AuthError) {
          setState(() {
            _errorMessage = state.message;
            _pin = '';
          });
        } else if (state is AuthLoading) {
          setState(() => _errorMessage = null);
        }
      },
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          final label = event.logicalKey.keyLabel;
          if (label.length == 1 && RegExp(r'\d').hasMatch(label)) {
            _onDigit(label);
          } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
            _onDelete();
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              // Left decorative panel
              Expanded(
                flex: 4,
                child: _LeftPanel(displayName: _displayName),
              ),

              // Right PIN panel
              Expanded(
                flex: 5,
                child: Container(
                  color: AppColors.background,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'PIN kiriting',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '4 xonali PIN kodingizni kiriting',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // PIN dots
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) {
                              final loading = state is AuthLoading;
                              return _PinDots(
                                pin: _pin,
                                loading: loading,
                                hasError: _errorMessage != null,
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Error message
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _errorMessage != null
                                ? Container(
                                    key: ValueKey(_errorMessage),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.error
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.error
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline,
                                            color: AppColors.error, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: TextStyle(
                                              color: AppColors.error,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          const SizedBox(height: 24),

                          // Keypad
                          _PinKeypad(
                            onDigit: _onDigit,
                            onDelete: _onDelete,
                          ),

                          const SizedBox(height: 24),

                          // Switch user button
                          TextButton.icon(
                            icon: Icon(
                              Icons.swap_horiz,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            label: Text(
                              'Boshqa foydalanuvchi',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: _clearAndGoLogin,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Left branding panel — shows user name
class _LeftPanel extends StatelessWidget {
  final String displayName;
  const _LeftPanel({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.92),
            AppColors.primaryDark,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'POS Kassa',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// PIN dots indicator
class _PinDots extends StatelessWidget {
  final String pin;
  final bool loading;
  final bool hasError;

  const _PinDots({
    required this.pin,
    required this.loading,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          ),
        ] else ...[
          ...List.generate(4, (i) {
            final filled = i < pin.length;
            final dotColor = hasError ? AppColors.error : AppColors.primary;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? dotColor : Colors.transparent,
                border: Border.all(
                  color: filled ? dotColor : AppColors.border,
                  width: 2,
                ),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                        )
                      ]
                    : [],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// PIN keypad
class _PinKeypad extends StatelessWidget {
  final Function(String) onDigit;
  final VoidCallback onDelete;

  const _PinKeypad({required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 76, height: 56);
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _PinButton(
                  label: key,
                  isDelete: key == 'del',
                  onTap: () => key == 'del' ? onDelete() : onDigit(key),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _PinButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDelete;

  const _PinButton({
    required this.label,
    required this.onTap,
    this.isDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 76,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: isDelete
              ? Icon(Icons.backspace_outlined,
                  color: AppColors.textSecondary, size: 22)
              : Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}
