import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/features/auth/presentation/register_page.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const double _horizontalPadding = 20;
  static const double _verticalPadding = 24;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _localAuth = LocalAuthentication();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _canUseBiometrics = false;
  String? _storedEmail;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      debugPrint('canCheckBiometrics: $canCheck, isDeviceSupported: $isDeviceSupported');
      if (!canCheck || !isDeviceSupported) {
        debugPrint('Biometrics not available on device');
        return;
      }
      if (!mounted) return;
      final controller = context.read<SessionController>();
      final storage = controller.apiClient.storage;
      final storedEmail = await storage.getUserEmail();
      if (storedEmail != null && storedEmail.isNotEmpty && mounted) {
        setState(() {
          _storedEmail = storedEmail;
          _canUseBiometrics = true;
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
                onFieldSubmitted: (_) => _submit(),
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
              if (_canUseBiometrics && _storedEmail != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _loginWithBiometrics,
                    icon: const Icon(Icons.face),
                    label: Text('Ingresar con: $_storedEmail'),
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

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isNotEmpty && text.length < 8) {
      return 'Mínimo 8 caracteres.';
    }
    return null;
  }

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

  Future<void> _loginWithBiometrics() async {
    if (_isSubmitting || _storedEmail == null) {
      return;
    }

    try {
      debugPrint('Starting biometric auth...');
      bool authenticated = false;
      try {
        authenticated = await _localAuth.authenticate(
          localizedReason: 'Inicia sesión con tu cuenta',
          persistAcrossBackgrounding: false,
        ).timeout(const Duration(seconds: 30));

        debugPrint('Auth result: $authenticated');
      } catch (authError) {
        debugPrint('Auth error: $authError');
        final errorStr = authError.toString().toLowerCase();
        if (errorStr.contains('usercanceled') || errorStr.contains('usercancel')) {
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
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
