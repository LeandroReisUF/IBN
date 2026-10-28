import 'perfil.dart';

/// Usuário autenticado no sistema.
class Usuario {
  final String id;
  final String nome;
  final String email;
  final Perfil perfil;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
  });
}