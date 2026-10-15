import 'package:flutter/material.dart';

import 'api.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false, _ocultar = true;
  String? _error;

  Future<void> _entrar() async {
    if (_usuario.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Completa usuario y contraseña.');
      return;
    }
    setState(() { _cargando = true; _error = null; });
    try {
      await ApiClient.instance.login(_usuario.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() { _usuario.dispose(); _password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Iniciar sesión', style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Accede con tu usuario', style: TextStyle(color: tema.hintColor)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _usuario,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Usuario'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: _ocultar,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _entrar(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        suffixIcon: IconButton(
                          icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _ocultar = !_ocultar),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          border: Border.all(color: const Color(0xFFEF4444)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _cargando ? null : _entrar,
                      child: _cargando
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Iniciar Sesión'),
                    ),
                    const SizedBox(height: 18),
                    Text('¿No tienes cuenta? Solicítala a un administrador.',
                        textAlign: TextAlign.center, style: TextStyle(color: tema.hintColor, fontSize: 13)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
