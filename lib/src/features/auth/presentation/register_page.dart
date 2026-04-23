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
  final _confirmPassword = TextEditingController();
  final _address = TextEditingController();
  final _location = TextEditingController();
  final _zipCode = TextEditingController();
  final _phone = TextEditingController();
  final _profession = TextEditingController();
  final _maritalStatus = TextEditingController();
  final _question1 = TextEditingController();
  final _question2 = TextEditingController();
  final _question5 = TextEditingController();
  final _question8 = TextEditingController();

  DateTime _dateOfBirth = DateTime.now().subtract(const Duration(days: 365 * 15));
  TimeOfDay _dateOfBirthTime = const TimeOfDay(hour: 1, minute: 45);
  bool _q3 = false;
  bool _q4 = false;
  bool _q6 = false;
  bool _q7 = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _address.dispose();
    _location.dispose();
    _zipCode.dispose();
    _phone.dispose();
    _profession.dispose();
    _maritalStatus.dispose();
    _question1.dispose();
    _question2.dispose();
    _question5.dispose();
    _question8.dispose();
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
              _passwordField(
                _confirmPassword,
                'Repetir contraseña',
                _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm),
                helper: 'Debe coincidir con la contraseña',
                validator: _validateConfirmPassword,
              ),
              const SizedBox(height: 20),
              Text('Dirección', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _textField(_address, 'Dirección', helper: 'Opcional'),
              _textField(_location, 'Ciudad', helper: 'Opcional'),
              _textField(_zipCode, 'Código postal', keyboardType: TextInputType.number, helper: 'Opcional'),
              _textField(_phone, 'Teléfono', keyboardType: TextInputType.phone, helper: 'Opcional'),
              const SizedBox(height: 20),
              Text('Datos personales', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _textField(_profession, 'Profesión', helper: 'Opcional'),
              _textField(_maritalStatus, 'Estado civil', helper: 'Opcional'),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickDate,
                      child: Text('Nacimiento: ${_formatDate(_dateOfBirth)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickTime,
                      child: Text('Hora: ${_formatTime(_dateOfBirthTime)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Cuestionario', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _textField(_question1, 'Pregunta 1', helper: 'Opcional'),
              _textField(_question2, 'Pregunta 2', helper: 'Opcional'),
              SwitchListTile(value: _q3, onChanged: (value) => setState(() => _q3 = value), title: const Text('Pregunta 3')),
              SwitchListTile(value: _q4, onChanged: (value) => setState(() => _q4 = value), title: const Text('Pregunta 4')),
              _textField(_question5, 'Pregunta 5', helper: 'Opcional'),
              SwitchListTile(value: _q6, onChanged: (value) => setState(() => _q6 = value), title: const Text('Pregunta 6')),
              SwitchListTile(value: _q7, onChanged: (value) => setState(() => _q7 = value), title: const Text('Pregunta 7')),
              _textField(_question8, 'Pregunta 8', helper: 'Opcional'),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDate: _dateOfBirth,
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dateOfBirthTime,
    );
    if (picked != null) {
      setState(() => _dateOfBirthTime = picked);
    }
  }

  Future<void> _submit(SessionController session) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final ok = await session.register(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      phone: _phone.text.trim(),
      profession: _profession.text.trim(),
      maritalStatus: _maritalStatus.text.trim(),
      address: _address.text.trim(),
      city: _location.text.trim(),
      zipCode: _zipCode.text.trim().isEmpty ? '' : _zipCode.text.trim(),
      question1: _question1.text.trim(),
      question2: _question2.text.trim(),
      question3: _q3,
      question4: _q4,
      question5: _question5.text.trim(),
      question6: _q6,
      question7: _q7,
      question8: _question8.text.trim(),
      dateOfBirth: DateTime(
        _dateOfBirth.year,
        _dateOfBirth.month,
        _dateOfBirth.day,
        _dateOfBirthTime.hour,
        _dateOfBirthTime.minute,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      final message = session.errorMessage ?? 'No se pudo registrar.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.contains('Error registerUser') ? 'El servidor rechazó el registro. Revisa los campos requeridos.' : message)),
      );
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _openPrivacy() async {
    final uri = Uri.parse('https://circulo-dorado.org/aviso-de-privacidad');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
