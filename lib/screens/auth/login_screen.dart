import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../operador/painel_operador.dart'; // Certifique-se de que o import do operador está correto
import '../motorista/painel_motorista.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    
    try {
      // 1. Efetua o login no Firebase
      await _authService.signIn(_emailCtrl.text.trim(), _passCtrl.text);
      
      // 2. Captura o usuário que acabou de logar
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null && mounted) {
        String email = user.email?.toLowerCase() ?? '';
        
        // 3. ROTEAMENTO: Verifica se contém "operador" ou "docas" no e-mail
        if (email.contains('operador') || email.contains('docas')) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PainelOperador()), // Abre painel do chefe
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PainelMotorista()), // Abre painel do caminhoneiro
          );
        }
      }
    } catch (e) {
      setState(() => _error = 'Email ou senha inválidos');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Logo
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text('Dock Flow',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.primary)),
                const SizedBox(height: 4),
                Text('Sistema de Gestão de Docas',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                const SizedBox(height: 40),

                // Form card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_error!, style: TextStyle(color: cs.error)),
                            ),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.isEmpty ? 'Informe o email' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: Icon(Icons.lock_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _loading ? null : _login,
                            icon: _loading
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.login),
                            label: Text(_loading ? 'Entrando...' : 'Entrar'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Operador: use email com "operador" ou "docas" no domínio.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}