import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/auth_repository.dart';
import '../../data/remote/sync_service.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_event.dart';
import '../auth/bloc/auth_state.dart';

/// Show PIN dialog. Returns true if authenticated, false/null if cancelled.
Future<bool?> showPinDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _PinDialog(),
  );
}

class _PinDialog extends StatelessWidget {
  const _PinDialog();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(
        authRepository: sl<AuthRepository>(),
        hiveService: sl<HiveService>(),
        syncService: sl<SyncService>(),
      ),
      child: const _PinDialogContent(),
    );
  }
}

class _PinDialogContent extends StatefulWidget {
  const _PinDialogContent();

  @override
  State<_PinDialogContent> createState() => _PinDialogContentState();
}

class _PinDialogContentState extends State<_PinDialogContent> {
  String _pin = '';
  String? _errorMessage;
  bool _loading = false;

  String get _displayName {
    final user = sl<HiveService>().getUser();
    if (user == null) return 'Kassir';
    return user.fullName.isNotEmpty ? user.fullName : user.username;
  }

  String get _savedUsername {
    return sl<HiveService>().getUser()?.username ?? '';
  }

  void _onDigit(String d) {
    if (_pin.length >= 4 || _loading) return;
    setState(() {
      _pin += d;
      _errorMessage = null;
    });
    if (_pin.length == 4) {
      _submit();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty || _loading) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  void _submit() {
    final username = _savedUsername;
    if (username.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    context.read<AuthBloc>().add(PinLoginRequested(username, _pin));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).pop(true);
        } else if (state is AuthError) {
          setState(() {
            _errorMessage = state.message;
            _pin = '';
            _loading = false;
          });
        } else if (state is AuthLoading) {
          setState(() => _loading = true);
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
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop(false);
          }
        },
        child: Center(
          child: Container(
            width: 380,
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 48,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3557).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFF1A3557),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Parol kiriting',
                              style: TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _displayName,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close button
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF9CA3AF),
                          size: 22,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F4F6),
                          minimumSize: const Size(38, 38),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── PIN dots ────────────────────────────────────────
                _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Color(0xFF1A3557),
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final filled = i < _pin.length;
                          final dotColor = _errorMessage != null
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF1A3557);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? dotColor : Colors.transparent,
                              border: Border.all(
                                color: filled
                                    ? dotColor
                                    : const Color(0xFFD1D5DB),
                                width: 2,
                              ),
                              boxShadow: filled
                                  ? [
                                      BoxShadow(
                                        color: dotColor.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                          );
                        }),
                      ),

                // ── Error message ───────────────────────────────────
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFCA5A5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── Keypad ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: _PinKeypad(
                    onDigit: _onDigit,
                    onDelete: _onDelete,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
                return const SizedBox(width: 88, height: 58);
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _KeyButton(
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

class _KeyButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDelete;

  const _KeyButton({
    required this.label,
    required this.onTap,
    this.isDelete = false,
  });

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: 88,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isDelete
              ? const Icon(
                  Icons.backspace_outlined,
                  color: Color(0xFF6B7280),
                  size: 22,
                )
              : Text(
                  widget.label,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}
