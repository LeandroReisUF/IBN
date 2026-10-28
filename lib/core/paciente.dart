import 'package:ibn/core/formadores.dart';

/// Versão atual do termo de consentimento (LGPD).
const versaoTermoLgpd = 'v1.0';

class ResponsavelLegal {
  final String nome;
  final String cpf; // só dígitos
  final String parentesco;
  final String telefone; // só dígitos

  const ResponsavelLegal({
    required this.nome,
    required this.cpf,
    required this.parentesco,
    required this.telefone,
  });
}

class TermoLGPD {
  final DateTime aceitoEm;
  final String versao;

  const TermoLGPD({required this.aceitoEm, required this.versao});
}

class Paciente {
  final String id;
  final String nome;
  final String cpf; // só dígitos
  final DateTime dataNascimento;
  final String telefone; // só dígitos
  final String whatsapp; // só dígitos (pode ser vazio)
  final String email;
  final ResponsavelLegal? responsavel;
  final TermoLGPD termoLgpd;
  final bool optOutMarketing;

  /// IDs dos profissionais com vínculo (RN03). Hoje é preenchido à mão nos
  /// dados de teste; depois virá dos agendamentos/atendimentos.
  final Set<String> profissionaisVinculados;

  /// Paciente inativo some da lista padrão, mas o histórico é preservado (RN05).
  final bool ativo;

  const Paciente({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.dataNascimento,
    required this.telefone,
    this.whatsapp = '',
    this.email = '',
    this.responsavel,
    required this.termoLgpd,
    this.optOutMarketing = false,
    this.profissionaisVinculados = const {},
    this.ativo = true,
  });

  bool get menorDeIdade => idadeEm(dataNascimento) < 18;

  Paciente copiarCom({bool? ativo, Set<String>? profissionaisVinculados}) {
    return Paciente(
      id: id,
      nome: nome,
      cpf: cpf,
      dataNascimento: dataNascimento,
      telefone: telefone,
      whatsapp: whatsapp,
      email: email,
      responsavel: responsavel,
      termoLgpd: termoLgpd,
      optOutMarketing: optOutMarketing,
      profissionaisVinculados:
          profissionaisVinculados ?? this.profissionaisVinculados,
      ativo: ativo ?? this.ativo,
    );
  }
}