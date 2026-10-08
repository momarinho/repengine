import 'package:flutter/foundation.dart';

/// Athlete authentication status in the mobile application.
enum AuthStatus {
  /// Guest mode / local offline (uses fallback and cached routines).
  guest,

  /// Login request in progress.
  authenticating,

  /// Connected to RepEngine Web account with valid JWT token.
  authenticated,

  /// Authentication failure (invalid credentials or network error).
  error,
}

/// Immutable state of the athlete's session.
@immutable
class AuthState {
  final AuthStatus status;
  final String? token;
  final int? userId;
  final String? email;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.guest,
    this.token,
    this.userId,
    this.email,
    this.errorMessage,
  });

  /// Indicates whether the athlete is authenticated with a valid JWT token.
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && token != null && token!.isNotEmpty;

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    int? userId,
    String? email,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      errorMessage: errorMessage,
    );
  }
}
