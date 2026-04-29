import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/features/auth/presentation/register_page.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

/// Validates a login password for the manual login form.
///
/// Returns `null` (valid) when [value] is null or empty — empty passwords are
/// permitted so that users without a device passcode can still submit the form
/// and let the server reject invalid credentials. Returns an error message when
/// [value] is non-empty but shorter than 8 characters.
@visibleForTesting
String? validateLoginPassword(String? value) {
  final text = value ?? '';
  if (text.isNotEmpty && text.length < 8) {
    return 'Mínimo 8 caracteres.';
  }
  return null;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.localAuth});

  @visibleForTesting
  final LocalAuthentication? localAuth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const double _horizontalPadding = 20;
  static const double _verticalPadding = 24;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final LocalAuthentication _localAuth;

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _canUseBiometrics = false;
  bool _canUseDeviceAuth = false;
  String? _storedEmail;

  @override
  void initState() {
    super.initState();
    _localAuth = widget.localAuth ?? LocalAuthentication();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      // Load the stored email first — it is needed regardless of whether
      // biometrics are available, because the quick-login button is shown
      // whenever a stored account exists.
      final controller = context.read<SessionController>();
      final storage = controller.apiClient.storage;
      final storedEmail = await storage.getUserEmail();
      if (storedEmail == null || storedEmail.isEmpty) return;

      if (!mounted) return;

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      final canUseBiometrics = availableBiometrics.isNotEmpty;
      final canUseDeviceAuth = await _localAuth.isDeviceSupported();

      if (mounted) {
        setState(() {
          _storedEmail = storedEmail;
          _canUseBiometrics = canUseBiometrics;
          _canUseDeviceAuth = canUseDeviceAuth;
        });
      }
    } catch (e) {
      // Silently fail - button won't show
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    if (_storedEmail == null) {
      session.apiClient.storage.getUserEmail().then((email) {
        if (email != null && email.isNotEmpty && mounted) {
          setState(() {
            _storedEmail = email;
          });
        }
      });
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF8F2E8), Color(0xFFF2E4D1)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewInsets = MediaQuery.viewInsetsOf(context);
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  _verticalPadding,
                  _horizontalPadding,
                  _verticalPadding + viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (_verticalPadding * 2),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SizedBox(height: 24),
                        _buildHeader(),
                        const SizedBox(height: 28),
                        if (session.sessionExpired)
                          _buildSessionExpiredBanner(context),
                        _buildCard(context, session),
                        if (session.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Text(
                              session.errorMessage!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.red.shade700),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          'Conectado con circulo-dorado.org',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.mutedText),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSessionExpiredBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tu sesión expiró. Por favor, inicia sesión de nuevo.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: <Widget>[
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
        ),
        const SizedBox(height: 14),
        Text(
          'Bienvenido de nuevo',
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: AppTheme.deepBrown,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCard(BuildContext context, SessionController session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Acceso', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onFieldSubmitted: (_) {
                  // If both fields are empty and biometric quick-login is
                  // available, use the stored account flow.
                  if (_emailController.text.trim().isEmpty &&
                      _passwordController.text.isEmpty &&
                      _storedEmail != null &&
                      _canUseDeviceAuth) {
                    _loginWithStoredAccount();
                  } else {
                    _submit();
                  }
                },
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 18),
              if (_storedEmail != null && _canUseDeviceAuth)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _loginWithStoredAccount,
                    icon: Icon(
                      _canUseBiometrics ? Icons.face : Icons.lock_outline,
                    ),
                    label: Text('Ingresar como $_storedEmail'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.deepBrown,
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Ingresar'),
              ),
              const SizedBox(height: 8),
              Text(
                'Si no recuerdas tu clave, puedes recuperarla desde la web.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedText),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '¿No tienes cuenta?',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedText),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RegisterPage(),
                      ),
                    ),
                    child: const Text('Regístrate'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Ingresa tu correo.';
    }
    final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    if (!isValid) {
      return 'Correo inválido.';
    }
    return null;
  }

  String? _validatePassword(String? value) => validateLoginPassword(value);

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    final sessionController = context.read<SessionController>();
    sessionController.clearError();
    sessionController.clearSessionExpired();

    setState(() {
      _isSubmitting = true;
    });

    try {
      await sessionController.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  /// Logs in using the stored account.
  ///
  /// If the device supports biometric authentication, the user is asked to
  /// verify their identity first. Otherwise, stored credentials are used
  /// directly — the biometric check is only a security gate, not the source
  /// of the credentials themselves.
  Future<void> _loginWithStoredAccount() async {
    if (_isSubmitting || _storedEmail == null) return;
    if (!_canUseDeviceAuth) return;
    await _loginWithDeviceAuth();
  }

  Future<void> _loginWithDeviceAuth() async {
    if (_isSubmitting || _storedEmail == null) {
      return;
    }

    try {
      debugPrint('Starting device auth...');
      bool authenticated = false;
      try {
        authenticated = await _localAuth.authenticate(
          localizedReason: 'Inicia sesión con tu cuenta',
          persistAcrossBackgrounding: false,
        ).timeout(const Duration(seconds: 30));

        debugPrint('Auth result: $authenticated');
      } catch (authError) {
        debugPrint('Auth error: $authError');
        if (authError is LocalAuthException &&
            authError.code == LocalAuthExceptionCode.userCanceled) {
          // User intentionally dismissed the biometric prompt — no error needed.
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo autenticar. Inténtalo de nuevo.')),
          );
        }
        return;
      }

      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Autenticación cancelada o fallida')),
          );
        }
        return;
      }
      if (!mounted) return;

      setState(() {
        _isSubmitting = true;
      });

      final sessionController = context.read<SessionController>();
      sessionController.clearError();
      sessionController.clearSessionExpired();

      await sessionController.loginWithStoredCredentials();
    } catch (e) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted && _isSubmitting) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
