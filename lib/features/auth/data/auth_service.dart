import 'package:flutter/foundation.dart';
import '../domain/perfil.dart';
import '../domain/usuario.dart';

/// Controla quem está logado (RF01.1).
///
/// PROVISÓRIO: as contas abaixo são só para teste. Quando criarmos o
/// servidor (API), o login passará a consultar o banco, com senha
/// criptografada (hash) e 2FA opcional (RNF02).
class AuthService extends ChangeNotifier {
  static const senhaTeste = '123456';

  final List<Usuario> contasTeste = const [
    Usuario(id: '1', nome: 'Ana Admin', email: 'admin@clinica.local', perfil: Perfil.administrador),
    Usuario(id: '2', nome: 'Rita Recepção', email: 'recepcao@clinica.local', perfil: Perfil.recepcionista),
    Usuario(id: '3', nome: 'Dr. Davi', email: 'dentista@clinica.local', perfil: Perfil.dentista),
    Usuario(id: '10', nome: 'Dra. Lúcia', email: 'dentista2@clinica.local', perfil: Perfil.dentista),
    Usuario(id: '4', nome: 'Bia Biomédica', email: 'biomedico@clinica.local', perfil: Perfil.biomedico),
    Usuario(id: '5', nome: 'Dra. Marta', email: 'medico@clinica.local', perfil: Perfil.medico),
    Usuario(id: '6', nome: 'Enf. Eva', email: 'enfermeiro@clinica.local', perfil: Perfil.enfermeiro),
    Usuario(id: '7', nome: 'Fábio Fisio', email: 'fisio@clinica.local', perfil: Perfil.fisioterapeuta),
    Usuario(id: '8', nome: 'Nina Nutri', email: 'nutri@clinica.local', perfil: Perfil.nutricionista),
    Usuario(id: '9', nome: 'Paulo Psicólogo', email: 'psicologo@clinica.local', perfil: Perfil.psicologo),
  ];

  /// Profissionais de saúde (quem pode ser vinculado a pacientes).
  List<Usuario> get profissionaisSaude =>
      contasTeste.where((u) => !u.perfil.veClinicaInteira).toList();

  Usuario? buscarPorId(String id) {
    for (final u in contasTeste) {
      if (u.id == id) return u;
    }
    return null;
  }

  Usuario? _usuarioLogado;
  Usuario? get usuarioLogado => _usuarioLogado;
  bool get logado => _usuarioLogado != null;

  /// Retorna null se deu certo, ou a mensagem de erro.
  Future<String?> entrar(String email, String senha) async {
    await Future.delayed(const Duration(milliseconds: 600)); // simula a rede
    final emailLimpo = email.trim().toLowerCase();
    for (final conta in contasTeste) {
      if (conta.email == emailLimpo && senha == senhaTeste) {
        _usuarioLogado = conta;
        notifyListeners();
        return null;
      }
    }
    return 'E-mail ou senha incorretos.';
  }

  void sair() {
    _usuarioLogado = null;
    notifyListeners();
  }
}

/// Instância única usada pelo app inteiro (por enquanto).
final auth = AuthService();