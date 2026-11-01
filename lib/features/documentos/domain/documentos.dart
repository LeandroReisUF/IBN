import 'package:ibn/core/formadores.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';

/// Documentos clínicos (RF04.4). Modelos imutáveis.
/// Documento assinado nunca muda (RN05): correção = novo documento que o
/// retifica, com justificativa.

enum TipoDocumento {
  prescricaoSimples('Receituário simples'),
  controleEspecial('Receituário de controle especial'),
  atestado('Atestado'),
  tcle('Termo de consentimento (TCLE)'),
  declaracao('Declaração');

  final String rotulo;
  const TipoDocumento(this.rotulo);
}

/// Variáveis preenchidas sozinhas (paciente, data e profissional).
const variaveisAutomaticas = [
  'paciente_nome',
  'paciente_cpf',
  'paciente_responsavel',
  'data_emissao',
  'profissional_nome',
  'profissional_registro',
];

/// Aparece no lugar de uma variável sem valor.
const marcadorNaoPreenchido = 'NÃO PREENCHIDO';

final _regexVariavel = RegExp(r'\{\{\s*([a-z0-9_]+)\s*\}\}');

/// Variáveis `{{nome}}` do corpo, sem repetição, na ordem em que aparecem.
List<String> variaveisDoCorpo(String corpo) {
  final nomes = <String>[];
  for (final m in _regexVariavel.allMatches(corpo)) {
    final nome = m.group(1)!;
    if (!nomes.contains(nome)) nomes.add(nome);
  }
  return nomes;
}

/// Variáveis que o profissional precisa digitar (as que não são automáticas).
List<String> variaveisManuais(String corpo) =>
    variaveisDoCorpo(corpo).where((v) => !variaveisAutomaticas.contains(v)).toList();

class ResultadoPreenchimento {
  final String texto;
  final List<String> faltando;
  const ResultadoPreenchimento(this.texto, this.faltando);
}

/// Troca cada `{{variavel}}` pelo valor. Variável sem valor fica sinalizada no
/// texto e aparece em [ResultadoPreenchimento.faltando].
ResultadoPreenchimento preencherModelo(String corpo, Map<String, String> valores) {
  final faltando = <String>[];
  final texto = corpo.replaceAllMapped(_regexVariavel, (m) {
    final nome = m.group(1)!;
    final valor = (valores[nome] ?? '').trim();
    if (valor.isEmpty) {
      if (!faltando.contains(nome)) faltando.add(nome);
      return '[$nome $marcadorNaoPreenchido]';
    }
    return valor;
  });
  return ResultadoPreenchimento(texto, faltando);
}

/// Valores das variáveis automáticas. O registro do conselho fica vazio se o
/// profissional não o tiver cadastrado (o preenchimento então o sinaliza).
Map<String, String> valoresAutomaticos({
  required Paciente paciente,
  required Usuario usuario,
  required DateTime agora,
}) {
  final r = paciente.responsavel;
  return {
    'paciente_nome': paciente.nome,
    'paciente_cpf': formatarCpf(paciente.cpf),
    'paciente_responsavel': r == null ? 'não se aplica' : '${r.nome} (${r.parentesco})',
    'data_emissao': formatarData(agora),
    'profissional_nome': usuario.nome,
    'profissional_registro': usuario.registroFormatado ?? '',
  };
}

/// Modelo de documento com variáveis. Editar um modelo cria uma nova [versao];
/// documentos já emitidos guardam o texto pronto e não mudam.
class ModeloDocumento {
  final String id;
  final String nome;
  final TipoDocumento tipo;
  final String corpo;
  final int versao;

  const ModeloDocumento({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.corpo,
    this.versao = 1,
  });
}

/// Documento emitido a partir de um modelo. Nasce como rascunho (pode editar
/// ou descartar); assinado, fica imutável.
class DocumentoClinico {
  final String id;
  final String pacienteId;
  final String atendimentoId;
  final String profissionalId;
  final TipoDocumento tipo;
  final String titulo;
  final String conteudo; // já preenchido
  final String modeloId;
  final int modeloVersao;
  final DateTime emitidoEm;
  final bool assinado;
  final DateTime? assinadoEm;

  /// PROVISÓRIO: selo de integridade simples. Não é assinatura digital.
  final String? selo;
  final String? retificaId;
  final String? justificativa;

  const DocumentoClinico({
    required this.id,
    required this.pacienteId,
    required this.atendimentoId,
    required this.profissionalId,
    required this.tipo,
    required this.titulo,
    required this.conteudo,
    required this.modeloId,
    required this.modeloVersao,
    required this.emitidoEm,
    this.assinado = false,
    this.assinadoEm,
    this.selo,
    this.retificaId,
    this.justificativa,
  });

  DocumentoClinico copiarCom({
    String? conteudo,
    bool? assinado,
    DateTime? assinadoEm,
    String? selo,
  }) =>
      DocumentoClinico(
        id: id,
        pacienteId: pacienteId,
        atendimentoId: atendimentoId,
        profissionalId: profissionalId,
        tipo: tipo,
        titulo: titulo,
        conteudo: conteudo ?? this.conteudo,
        modeloId: modeloId,
        modeloVersao: modeloVersao,
        emitidoEm: emitidoEm,
        assinado: assinado ?? this.assinado,
        assinadoEm: assinadoEm ?? this.assinadoEm,
        selo: selo ?? this.selo,
        retificaId: retificaId,
        justificativa: justificativa,
      );
}

/// Modelos iniciais. PROVISÓRIO: os textos e as exigências de receituário de
/// controle especial seguem normas dos conselhos e da vigilância sanitária;
/// devem ser validados pelos profissionais da clínica antes do uso real.
const modelosPadrao = [
  ModeloDocumento(
    id: 'receituario-simples',
    nome: 'Receituário simples',
    tipo: TipoDocumento.prescricaoSimples,
    corpo: 'Paciente: {{paciente_nome}}\n'
        'CPF: {{paciente_cpf}}\n\n'
        '{{prescricao}}\n\n'
        'Data: {{data_emissao}}\n\n'
        '{{profissional_nome}}\n'
        '{{profissional_registro}}',
  ),
  ModeloDocumento(
    id: 'receituario-controle-especial',
    nome: 'Receituário de controle especial',
    tipo: TipoDocumento.controleEspecial,
    corpo: 'Paciente: {{paciente_nome}}\n'
        'CPF: {{paciente_cpf}}\n\n'
        '{{prescricao}}\n\n'
        'Data: {{data_emissao}}\n\n'
        '{{profissional_nome}}\n'
        '{{profissional_registro}}',
  ),
  ModeloDocumento(
    id: 'atestado',
    nome: 'Atestado odontológico',
    tipo: TipoDocumento.atestado,
    corpo: 'Atesto, para os devidos fins, que {{paciente_nome}}, CPF {{paciente_cpf}}, '
        'esteve em atendimento odontológico em {{data_emissao}} e necessita de '
        'afastamento de suas atividades por {{dias_afastamento}} dia(s), a contar desta data.\n\n'
        '{{profissional_nome}}\n'
        '{{profissional_registro}}',
  ),
  ModeloDocumento(
    id: 'declaracao-comparecimento',
    nome: 'Declaração de comparecimento',
    tipo: TipoDocumento.declaracao,
    corpo: 'Declaro, para os devidos fins, que {{paciente_nome}}, CPF {{paciente_cpf}}, '
        'compareceu a atendimento nesta clínica em {{data_emissao}}, no período de {{horario}}.\n\n'
        '{{profissional_nome}}\n'
        '{{profissional_registro}}',
  ),
  ModeloDocumento(
    id: 'tcle-odontologico',
    nome: 'TCLE odontológico',
    tipo: TipoDocumento.tcle,
    corpo: 'Eu, {{paciente_nome}}, CPF {{paciente_cpf}}, declaro que fui informado(a) por '
        '{{profissional_nome}} ({{profissional_registro}}) sobre o procedimento: {{procedimento}}, '
        'seus benefícios ({{beneficios}}), riscos ({{riscos}}) e alternativas ({{alternativas}}), '
        'e concordo com a sua realização.\n\n'
        'Responsável legal: {{paciente_responsavel}}\n'
        'Data: {{data_emissao}}\n\n'
        '______________________________\n'
        'Paciente ou responsável legal\n\n'
        '______________________________\n'
        '{{profissional_nome}} - {{profissional_registro}}',
  ),
];