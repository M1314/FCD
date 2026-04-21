import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glow = Tween<double>(
      begin: 0.72,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF1E150F),
                  Color(0xFF3B2A1F),
                  Color(0xFF6C4A2E),
                ],
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: -120,
                  right: -80,
                  child: _Orb(
                    diameter: 260,
                    color: AppTheme.gold.withValues(alpha: 0.18 * _glow.value),
                  ),
                ),
                Positioned(
                  bottom: -140,
                  left: -90,
                  child: _Orb(
                    diameter: 300,
                    color: AppTheme.bronze.withValues(alpha: 0.2 * _glow.value),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 134,
                        height: 134,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.gold.withValues(
                              alpha: 0.85 * _glow.value,
                            ),
                            width: 2,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppTheme.gold.withValues(
                                alpha: 0.35 * _glow.value,
                              ),
                              blurRadius: 28,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                          child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.jpg',
                            width: 134,
                            height: 134,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Fraternidad del Círculo Dorado',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Estudio, práctica y guía espiritual',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: const Color(0xFFEEDFC8),
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 36),
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.8,
                          color: Color(0xFFE8C98D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: <Color>[color, Colors.transparent]),
      ),
    );
  }
}
