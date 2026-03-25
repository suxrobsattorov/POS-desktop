import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/remote/auth_repository.dart';
import '../../../data/remote/sync_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final HiveService _hiveService;
  final SyncService _syncService;

  AuthBloc({
    required AuthRepository authRepository,
    required HiveService hiveService,
    required SyncService syncService,
  })  : _authRepository = authRepository,
        _hiveService = hiveService,
        _syncService = syncService,
        super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<PinLoginRequested>(_onPinLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  void _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) {
    if (_hiveService.isLoggedIn) {
      final user = _hiveService.getUser();
      if (user != null) {
        emit(AuthAuthenticated(user));
        _syncService.startBackgroundSync();
      } else {
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
      LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result =
          await _authRepository.login(event.username, event.password);
      await _hiveService.saveAuthData(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        user: result.user,
      );
      await _hiveService.saveKnownUser(result.user);
      // Sync all data from server
      await _syncService.syncAll();
      _syncService.startBackgroundSync();
      emit(AuthAuthenticated(result.user));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  Future<void> _onPinLoginRequested(
      PinLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result = await _authRepository.loginWithPin(event.username, event.pin);
      await _hiveService.saveAuthData(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        user: result.user,
      );
      await _hiveService.saveKnownUser(result.user);
      await _syncService.syncAll();
      _syncService.startBackgroundSync();
      emit(AuthAuthenticated(result.user));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<AuthState> emit) async {
    _syncService.stopBackgroundSync();
    await _syncService.forceSyncPendingSales();
    await _authRepository.logout();
    await _hiveService.clearAuth();
    emit(AuthUnauthenticated());
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Server javob bermayapti. Backend ishlamoqdami?';
        case DioExceptionType.connectionError:
          return 'Backend ga ulanib bo\'lmadi. localhost:8080 ishlamoqdami?';
        case DioExceptionType.badResponse:
          final status = e.response?.statusCode;
          if (status == 401) return 'Login yoki parol noto\'g\'ri';
          if (status == 403) return 'Ruxsat yo\'q';
          if (status == 404) return 'Server endpoint topilmadi';
          if (status != null && status >= 500) return 'Server xatosi ($status)';
          return 'Xato javob: $status';
        default:
          break;
      }
    }
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Login yoki parol noto\'g\'ri';
    } else if (msg.contains('connection') || msg.contains('SocketException') ||
        msg.contains('network') || msg.contains('refused')) {
      return 'Backend ga ulanib bo\'lmadi (localhost:8080)';
    }
    return 'Xatolik: $msg';
  }
}
