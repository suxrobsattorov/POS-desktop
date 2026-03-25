abstract class AuthEvent {}

class LoginRequested extends AuthEvent {
  final String username;
  final String password;
  LoginRequested(this.username, this.password);
}

class PinLoginRequested extends AuthEvent {
  final String username;
  final String pin;
  PinLoginRequested(this.username, this.pin);
}

class LogoutRequested extends AuthEvent {}

class CheckAuthStatus extends AuthEvent {}
