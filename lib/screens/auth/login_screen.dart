import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../operador/painel_operador.dart';
import '../motorista/painel_motorista.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;
  String _mensagemErro = '';

  Future<void> _fazerLogin() async {
    setState(() {
      _carregando = true;
      _mensagemErro = '';
    });

    try {
      // 1. Tenta autenticar no Firebase
      UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );

      // 2. Lógica de Roteamento (RBAC - Role Based Access Control)
      // Como estamos num MVP, vamos usar uma regra simples:
      // Se o e-mail contiver "@docas", ele é Operador. Se não, é Motorista.
      if (credential.user != null) {
        String email = credential.user!.email ?? '';
        
        if (email.contains('@docas')) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PainelOperadorScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PainelMotoristaScreen()));
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _mensagemErro = 'E-mail ou senha incorretos.';
        } else {
          _mensagemErro = 'Erro de autenticação: ${e.message}';
        }
      });
    } finally {
      setState(() {
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900], // Fundo escuro profissional
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_boat_filled, size: 80, color: Colors.blueGrey),
                const SizedBox(height: 16),
                const Text('Dock Flow', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const Text('Acesso Operacional', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 16),
                
                if (_mensagemErro.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_mensagemErro, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                  
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _carregando ? null : _fazerLogin,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                    child: _carregando 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text('ENTRAR', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}