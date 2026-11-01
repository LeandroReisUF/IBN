import 'package:ibn/features/auth/domain/perfil.dart';

/// Usuário autenticado no sistema.
class Usuario {
  final String id;
  final String nome;
  final String email;
  final Perfil perfil;

  /// Conselho e número de registro (ex.: "CRO-PE" e "12345"), usados nos documentos.
  final String? conselho;
  final String? registroConselho;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    this.conselho,
    this.registroConselho,
  });

  /// Ex.: "CRO-PE 12345", ou null se o registro não está cadastrado.
  String? get registroFormatado {
    final c = (conselho ?? '').trim();
    final r = (registroConselho ?? '').trim();
    return (c.isEmpty || r.isEmpty) ? null : '$c $r';
  }
}