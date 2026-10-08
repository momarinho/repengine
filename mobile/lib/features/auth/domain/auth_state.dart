import 'package:flutter/foundation.dart';

/// Status de autenticação do atleta no aplicativo mobile.
enum AuthStatus {
  /// Modo convidado / offline local (utiliza fallback e treinos cacheados).
  guest,

  /// Requisição de login em andamento.
  authenticating,

  /// Conectado à conta do RepEngine Web com JWT válido.
  authenticated,

  /// Falha na autenticação (credenciais inválidas ou erro de rede).
  error,
}

/// Estado imutável da sessão do atleta.
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

  /// Indica se o atleta está autenticado com token JWT válido.
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
