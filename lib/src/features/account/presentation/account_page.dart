import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _checkingAi = true;
  bool _hasAiAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAiPlan();
  }

  Future<void> _checkAiPlan() async {
    final session = context.read<SessionController>();
    final user = session.user;
    if (user == null) {
      setState(() {
        _checkingAi = false;
      });
      return;
    }

    try {
      final access = await session.aiChatRepository.hasAiAccess(user.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasAiAccess = access;
        _checkingAi = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingAi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final initials = _initials(user.name, user.lastName);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      children: <Widget>[
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: AppTheme.deepBrown,
            child: Text(
              initials,
              style: GoogleFonts.cormorantGaramond(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            '${user.name} ${user.lastName}'.trim(),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            user.email,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedText),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Informacion de cuenta',
          children: <Widget>[
            _InfoRow(
              label: 'Tipo de cuenta',
              value: _accountTypeLabel(user.type),
            ),
            if (user.phone.isNotEmpty)
              _InfoRow(label: 'Telefono', value: user.phone),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Acceso a IA',
          children: <Widget>[
            _AiStatusRow(checking: _checkingAi, hasAccess: _hasAiAccess),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Portal web',
          children: <Widget>[
            _LinkRow(
              icon: Icons.language_rounded,
              label: 'Ir a circulo-dorado.org',
              onTap: () => _openWeb('https://circulo-dorado.org'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Redes sociales',
          children: <Widget>[
            _LinkRow(
              icon: Icons.facebook_rounded,
              label: 'Facebook',
              onTap: () =>
                  _openWeb('https://www.facebook.com/FraternidadDelCirculoDorado'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: () => context.read<SessionController>().logout(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesion'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade200),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String name, String lastName) {
    final first = name.isNotEmpty ? name[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    final combined = first + last;
    return combined.isNotEmpty ? combined : 'U';
  }

  String _accountTypeLabel(String type) {
    if (type == 'administrator') {
      return 'Administrador';
    }
    return 'Miembro';
  }

  Future<void> _openWeb(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el navegador.')),
      );
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = const Divider(height: 1, indent: 16, endIndent: 16);
    final separated = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      separated.add(children[i]);
      if (i < children.length - 1) {
        separated.add(divider);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.mutedText,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Card(child: Column(children: separated)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedText),
          ),
        ],
      ),
    );
  }
}

class _AiStatusRow extends StatelessWidget {
  const _AiStatusRow({required this.checking, required this.hasAccess});

  final bool checking;
  final bool hasAccess;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: <Widget>[
          Text('Plan de IA', style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          if (checking)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: hasAccess ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                hasAccess ? 'Activo' : 'Sin acceso',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: hasAccess
                      ? Colors.green.shade700
                      : AppTheme.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: AppTheme.deepBrown),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedText),
          ],
        ),
      ),
    );
  }
}
