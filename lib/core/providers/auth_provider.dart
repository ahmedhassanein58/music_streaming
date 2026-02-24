import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/user_model.dart';
import '../network/auth_service.dart';
import '../network/user_repository.dart';
import '../storage/token_storage.dart';
import '../models/auth_models.dart';

enum AuthStatus { initial, loading, authenticated, guest, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(User user) =>
      AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.guest() => AuthState(status: AuthStatus.guest);
  factory AuthState.error(String message) =>
      AuthState(status: AuthStatus.error, errorMessage: message);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final UserRepository _userRepository;
  final TokenStorage _storage;

  AuthNotifier(this._authService, this._userRepository, this._storage)
      : super(AuthState.initial()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = AuthState.loading();
    try {
      final token = await _storage.getToken();
      if (token == null) {
        state = AuthState.guest();
        print('Guest mode');
        return;
      }

      final user = await _userRepository.getCurrentUser();
      print('Auth status check success. User: ${user.username}');
      state = AuthState.authenticated(user);
    } catch (e) {
      print('Auth status check error: $e');
      state = AuthState.guest();
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthState.loading();
    try {
      await _authService.login(LoginRequest(email: email, password: password));
      final user = await _userRepository.getCurrentUser();
      print('Login success. User: ${user.username}, ${user.email}');
      state = AuthState.authenticated(user);
    } catch (e) {
      print('Login error: $e');
      state = AuthState.error(e.toString());
    }
  }

  Future<void> signup(String username, String email, String password) async {
    state = AuthState.loading();
    try {
      await _authService.signup(SignupRequest(
        username: username,
        email: email,
        password: password,
      ));
      final user = await _userRepository.getCurrentUser();
      print('Signup success. User: ${user.username}, ${user.email}');
      state = AuthState.authenticated(user);
    } catch (e) {
      print('Signup error: $e');
      state = AuthState.error(e.toString());
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = AuthState.guest();
  }

  Future<void> updateUser(UpdateMeRequest request) async {
    if (state.user == null) return;
    try {
      final updatedUser = await _userRepository.updateUser(request);
      state = AuthState.authenticated(updatedUser);
    } catch (e) {
      // Handle error (maybe show snackbar in UI)
    }
  }
}

final authServiceProvider = Provider((ref) => AuthService());
final userRepositoryProvider = Provider((ref) => UserRepository());
final tokenStorageProvider = Provider((ref) => TokenStorage());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
    ref.watch(userRepositoryProvider),
    ref.watch(tokenStorageProvider),
  );
});
