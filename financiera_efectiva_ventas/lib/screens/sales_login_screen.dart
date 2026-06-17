import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../config/theme.dart';
import '../widgets/app_shell_widgets.dart';

class SalesLoginScreen extends StatefulWidget {
  const SalesLoginScreen({super.key, required this.onAuthenticated});

  static const demoEmail = 'asesor.demo@efectiva.pe';
  static const demoPassword = 'Ventas2026';

  final VoidCallback onAuthenticated;

  @override
  State<SalesLoginScreen> createState() => _SalesLoginScreenState();
}

class _SalesLoginScreenState extends State<SalesLoginScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;
    if (Firebase.apps.isEmpty) {
      if (email == SalesLoginScreen.demoEmail &&
          password == SalesLoginScreen.demoPassword) {
        widget.onAuthenticated();
        return;
      }
      _showLoginError('Credenciales de asesor no validas.');
      return;
    }

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(code: 'missing-user');
      }

      final advisorDoc = await FirebaseFirestore.instance
          .collection('sales_users')
          .doc(uid)
          .get();
      final data = advisorDoc.data();
      final role = (data?['role'] ?? data?['rol'] ?? '')
          .toString()
          .toLowerCase();
      final active =
          data?['active'] as bool? ?? data?['activo'] as bool? ?? true;

      if (!advisorDoc.exists || role != 'asesor' || !active) {
        await FirebaseAuth.instance.signOut();
        _showLoginError('La cuenta no tiene permisos de asesor.');
        return;
      }

      if (!mounted) return;
      widget.onAuthenticated();
    } on FirebaseAuthException catch (error) {
      _showLoginError(_messageForAuthError(error));
    } catch (error) {
      _showLoginError('No se pudo validar el rol de asesor: $error');
    }
  }

  void _showLoginError(String message) {
    if (!mounted) return;
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageForAuthError(FirebaseAuthException error) {
    return switch (error.code) {
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Correo o contrasena incorrectos.',
      'network-request-failed' => 'Revisa tu conexion a internet.',
      'too-many-requests' => 'Demasiados intentos. Intenta mas tarde.',
      _ => 'No se pudo iniciar sesion: ${error.code}',
    };
  }

  void _fillDemoUser() {
    emailController.text = SalesLoginScreen.demoEmail;
    passwordController.text = SalesLoginScreen.demoPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.brandInk,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            return Stack(
              children: [
                const Positioned.fill(child: _SalesLoginBackdrop()),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compact ? constraints.maxWidth : 980,
                      ),
                      child: compact
                          ? _LoginPanel(
                              formKey: formKey,
                              emailController: emailController,
                              passwordController: passwordController,
                              obscurePassword: obscurePassword,
                              isLoading: isLoading,
                              onLogin: _login,
                              onFillDemo: _fillDemoUser,
                              onTogglePassword: () => setState(
                                () => obscurePassword = !obscurePassword,
                              ),
                            )
                          : Row(
                              children: [
                                const Expanded(child: _FieldBriefing()),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _LoginPanel(
                                    formKey: formKey,
                                    emailController: emailController,
                                    passwordController: passwordController,
                                    obscurePassword: obscurePassword,
                                    isLoading: isLoading,
                                    onLogin: _login,
                                    onFillDemo: _fillDemoUser,
                                    onTogglePassword: () => setState(
                                      () => obscurePassword = !obscurePassword,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SalesLoginBackdrop extends StatelessWidget {
  const _SalesLoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.brandInk,
      child: CustomPaint(painter: _GridBackdropPainter()),
    );
  }
}

class _GridBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .055)
      ..strokeWidth = 1;
    const gap = 42.0;
    for (var x = 0.0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final routePaint = Paint()
      ..color = AppTheme.brandGold.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path()
      ..moveTo(size.width * .08, size.height * .76)
      ..quadraticBezierTo(
        size.width * .34,
        size.height * .54,
        size.width * .5,
        size.height * .66,
      )
      ..quadraticBezierTo(
        size.width * .67,
        size.height * .78,
        size.width * .9,
        size.height * .42,
      );
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FieldBriefing extends StatelessWidget {
  const _FieldBriefing();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: CompanyLogo(width: 210, height: 56),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Fuerza de Ventas',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Acceso operativo para asesores de campo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: .82),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _BriefingChip(Icons.route_outlined, 'Ruta diaria'),
              _BriefingChip(Icons.badge_outlined, 'Cartera asignada'),
              _BriefingChip(Icons.task_alt, 'Originacion'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onLogin,
    required this.onFillDemo,
    required this.onTogglePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onLogin;
  final VoidCallback onFillDemo;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Form(
        key: formKey,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: CompanyLogo(width: 184, height: 52),
              ),
              const SizedBox(height: 20),
              Text(
                'Ingreso asesor',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.brandNavy,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Valida tu acceso para iniciar la jornada.'),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Correo corporativo',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Ingresa tu correo';
                  if (!text.contains('@')) return 'Correo no valido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!isLoading) onLogin();
                },
                decoration: InputDecoration(
                  labelText: 'Contrasena',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: obscurePassword
                        ? 'Mostrar contrasena'
                        : 'Ocultar contrasena',
                    onPressed: onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Ingresa tu contrasena';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: isLoading ? null : onLogin,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(isLoading ? 'Validando...' : 'Ingresar'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isLoading ? null : onFillDemo,
                icon: const Icon(Icons.person_pin_outlined),
                label: const Text('Usar asesor demo'),
              ),
              const SizedBox(height: 14),
              const _DemoCredentials(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BriefingChip extends StatelessWidget {
  const _BriefingChip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, color: AppTheme.brandGold),
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: .1),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: Colors.white.withValues(alpha: .2)),
    );
  }
}

class _DemoCredentials extends StatelessWidget {
  const _DemoCredentials();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.brandSky,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usuario de prueba',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(SalesLoginScreen.demoEmail),
            Text(SalesLoginScreen.demoPassword),
          ],
        ),
      ),
    );
  }
}
