import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _successMessage;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        actions: <Widget>[
          TextButton(
            onPressed: _openPrivacy,
            child: const Text('Privacidad'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text('Cuenta', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _textField(_firstName, 'Nombre(s)', minLength: 3),
              _textField(_lastName, 'Apellido(s)', minLength: 3),
              _textField(
                _email,
                'Correo electrónico',
                keyboardType: TextInputType.emailAddress,
                helper: 'Usa un correo real al que puedas acceder',
                validator: _validateEmail,
              ),
              _passwordField(
                _password,
                'Contraseña',
                _obscurePassword,
                () => setState(() => _obscurePassword = !_obscurePassword),
                helper: 'Minimo 8 caracteres',
                validator: _validatePassword,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : () => _submit(session),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Crear cuenta'),
              ),
              const SizedBox(height: 12),
              if (_successMessage != null)
                _SuccessBanner(message: _successMessage!),
              if (_successMessage != null) const SizedBox(height: 12),
              if (session.errorMessage != null)
                _ErrorBanner(message: session.errorMessage!),
              const SizedBox(height: 8),
              Text(
                'La cuenta se registra en el mismo endpoint que usa la web.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? helper,
    int? minLength,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, helperText: helper),
        validator: validator ?? (value) => _required(value, minLength: minLength),
      ),
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label,
    bool obscure,
    VoidCallback toggle, {
    String? helper,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          suffixIcon: IconButton(
            onPressed: toggle,
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          ),
        ),
        validator: validator,
      ),
    );
  }

  String? _required(String? value, {int? minLength}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Requerido';
    if (minLength != null && text.length < minLength) return 'Minimo $minLength caracteres';
    return null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Requerido';
    final ok = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(text);
    return ok ? null : 'Correo invalido';
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Requerido';
    if (text.length < 8) return 'Minimo 8 caracteres';
    return null;
  }

  Future<void> _submit(SessionController session) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final ok = await session.register(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      phone: '',
      profession: '',
      maritalStatus: '',
      address: '',
      city: '',
      zipCode: '',
      question1: '',
      question2: '',
      question3: false,
      question4: false,
      question5: '',
      question6: false,
      question7: false,
      question8: '',
      dateOfBirth: DateTime(2011, 4, 24, 1, 45),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      final message = session.errorMessage ?? 'No se pudo registrar.';
      if (mounted) {
        setState(() => _successMessage = null);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.contains('Error registerUser') ? 'El servidor rechazó el registro. Revisa los campos requeridos.' : message)),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _successMessage = session.errorMessage ?? 'Correo enviado';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correo enviado')),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openPrivacy() async {
    final uri = Uri.parse('https://circulo-dorado.org/aviso-de-privacidad');
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el aviso de privacidad.'),
        ),
      );
    }
  }

}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade700)),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.green.shade700)),
    );
  }
}
