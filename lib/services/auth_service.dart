import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Função simples para deslogar e limpar a sessão
  Future<void> deslogar() async {
    await _auth.signOut();
  }
}