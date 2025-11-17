import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gomoku_multiplayer/providers/game_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isSignUp = false;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    // Проверяем статус аутентификации при запуске
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthStatus();
    });
  }

  void _checkAuthStatus() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    await gameProvider.checkAuthStatus();
  }

  @override
  void dispose() {
    _isMounted = false;
    _emailController.dispose();
    _usernameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (_emailController.text.isEmpty) {
      _showError('Please enter your email');
      return;
    }

    if (_isSignUp && _usernameController.text.isEmpty) {
      _showError('Please enter username');
      return;
    }

    try {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      await gameProvider.sendOTP(_emailController.text.trim(), username: _isSignUp ? _usernameController.text.trim() : null);

      if (_isMounted) {
        _showSuccess('OTP sent to your email!');
      }
    } catch (e) {
      if (_isMounted) {
        _showError('Failed to send OTP: ${e.toString()}');
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.isEmpty) {
      _showError('Please enter OTP code');
      return;
    }

    try {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      await gameProvider.verifyOTP(_otpController.text.trim());

      if (_isMounted) {
        _showSuccess('Successfully authenticated!');
      }
    } catch (e) {
      if (_isMounted) {
        _showError('Invalid OTP code: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    if (!_isMounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
  }

  void _showSuccess(String message) {
    if (!_isMounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
  }

  void _resetAuth() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    gameProvider.resetAuthState();
    _otpController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        // Если пользователь аутентифицирован, показываем сообщение
        if (gameProvider.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSuccess('Welcome back!');
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Gomoku Authentication'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            actions: gameProvider.isAuthenticated ? [IconButton(icon: const Icon(Icons.logout), onPressed: () => gameProvider.signOut())] : null,
          ),
          body: Padding(padding: const EdgeInsets.all(24.0), child: _buildContent(gameProvider)),
        );
      },
    );
  }

  Widget _buildContent(GameProvider gameProvider) {
    if (gameProvider.isLoading) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Processing...')]),
      );
    }

    // Если пользователь уже аутентифицирован
    if (gameProvider.isAuthenticated) {
      return _buildAuthenticatedState(gameProvider);
    }

    switch (gameProvider.authState) {
      case AuthState.initial:
        return _buildEmailForm(gameProvider);
      case AuthState.otpSent:
        return _buildOTPForm(gameProvider);
      case AuthState.authenticated:
        return _buildAuthenticatedState(gameProvider);
      case AuthState.error:
        return _buildErrorState(gameProvider);
    }
  }

  Widget _buildEmailForm(GameProvider gameProvider) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gamepad, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          Text(_isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_isSignUp ? 'Join the Gomoku community' : 'Welcome to Gomoku', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 32),

          if (_isSignUp)
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
            ),

          if (_isSignUp) const SizedBox(height: 16),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
          ),
          const SizedBox(height: 24),

          if (gameProvider.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(gameProvider.errorMessage!, style: const TextStyle(color: Colors.red)),
            ),

          if (gameProvider.errorMessage != null) const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _sendOTP,
              child: Text(_isSignUp ? 'Sign Up with OTP' : 'Sign In with OTP', style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () {
              setState(() {
                _isSignUp = !_isSignUp;
              });
            },
            child: Text(_isSignUp ? 'Already have an account? Sign In' : 'Need an account? Sign Up'),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPForm(GameProvider gameProvider) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.email, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          const Text('Check Your Email', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to ${gameProvider.email}',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Enter OTP Code', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock), counterText: ''),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
          ),
          const SizedBox(height: 24),

          if (gameProvider.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(gameProvider.errorMessage!, style: const TextStyle(color: Colors.red)),
            ),

          if (gameProvider.errorMessage != null) const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _verifyOTP,
              child: const Text('Verify OTP', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),

          TextButton(onPressed: _resetAuth, child: const Text('Use different email')),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedState(GameProvider gameProvider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 80, color: Colors.green),
        const SizedBox(height: 24),
        const Text('Welcome to Gomoku!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('You are signed in as ${gameProvider.email}', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              // Переход в лобби будет автоматическим через навигацию
            },
            child: const Text('Continue to Game', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),

        TextButton(onPressed: () => gameProvider.signOut(), child: const Text('Sign Out')),
      ],
    );
  }

  Widget _buildErrorState(GameProvider gameProvider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error, size: 80, color: Colors.red),
        const SizedBox(height: 24),
        const Text('Authentication Failed', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          gameProvider.errorMessage ?? 'Something went wrong',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _resetAuth,
            child: const Text('Try Again', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
