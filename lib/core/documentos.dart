import 'package:flutter/foundation.dart';

/// Tipo de documento clínico.
enum TipoDocumento {
  prescricao('Prescrição Médica/Odontológica'),
  atestado('Atestado'),
  tcle('Termo de Consentimento Livre e Esclarecido - TCLE'),
  declaracao('Declaração'),
  relatorio('Relatório'),
  encaminhamento('Encaminhamento'),
  outro('Outro');

  final String rotulo;
  const TipoDocumento(this.rotulo);
}

/// Tipo de receita (para prescrições).
enum TipoReceita {
  controleEspecial('Controle Especial (Amarela)'),
  antimicrobiano('Antimicrobiano (Branca 2 vias)'),
  comum('Comum (Branca 1 via)'),
  psicotropico('Psicotrópico (Azul)'),
  outro('Outro');

  final String rotulo;
  const TipoReceita(this.rotulo);
}

/// Modelo de documento com variáveis (placeholders).
class ModeloDocumento {
  final String id;
  final String nome;
  final TipoDocumento tipo;
  final String especialidade;
  final String corpoComVariaveis;
  final List<String> variaveisObrigatorias;
  final String versao;
  final DateTime criadoEm;
  final String profissionalId;

  const ModeloDocumento({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.especialidade,
    required this.corpoComVariaveis,
    required this.variaveisObrigatorias,
    required this.versao,
    required this.criadoEm,
    required this.profissionalId,
  });

  String preencher(Map<String, String> valores) {
    String resultado = corpoComVariaveis;
    for (final entry in valores.entries) {
      resultado = resultado.replaceAll('{{${entry.key}}}', entry.value);
    }
    for (final v in variaveisObrigatorias) {
/// Documento clínico base (abstrato).
abstract class DocumentoClinico {
  final String id;
  final String pacienteId;
  final String atendimentoId;
  final TipoDocumento tipo;
  final String titulo;
  final String conteudo;
  final DateTime emitidoEm;
  final String profissionalId;
  bool assinado;
  final String? assinaturaHash;
  final String? pdfUrl;

  DocumentoClinico({
    required this.id,
    required this.pacienteId,
    required this.atendimentoId,
    required this.tipo,
    required this.titulo,
    required this.conteudo,
    required this.emitidoEm,
    required this.profissionalId,
    this.assinado = false,
    this.assinaturaHash,
    this.pdfUrl,
  });

  DocumentoClinico copiarCom({
    bool? assinado,
    String? assinaturaHash,
    String? pdfUrl,
  });
}

/// Prescrição médica/odontológica.
class Prescricao extends DocumentoClinico {
  final TipoReceita tipoReceita;
  final String conteudoMedicamentos;
  final int? diasAfastamento;
  final String? cid;

  Prescricao({
    required super.id,
    required super.pacienteId,
    required super.atendimentoId,
    required super.titulo,
    required super.conteudo,
    required super.emitidoEm,
    required super.profissionalId,
    super.assinado,
    super.assinaturaHash,
    super.pdfUrl,
    required this.tipoReceita,
    required this.conteudoMedicamentos,
    this.diasAfastamento,
    this.cid,
  }) : super(
    id: id,
    pacienteId: '',
    atendimentoId: '',
    tipo: TipoDocumento.prescricao,
    titulo: titulo,
    conteudo: conteudo,
    emitidoEm: DateTime.now(),
    profissionalId: '',
  );

  @override
  Prescricao copiarCom({
    bool? assinado,
    String? assinaturaHash,
    String? pdfUrl,
  }) =>
      Prescricao(
        id: id,
        pacienteId: pacienteId,
        atendimentoId: atendimentoId,
        titulo: titulo,
        conteudo: conteudo,
        emitidoEm: emitidoEm,
        profissionalId: profissionalId,
        assinado: assinado ?? this.assinado,
        assinaturaHash: assinaturaHash ?? this.assinaturaHash,
        pdfUrl: pdfUrl ?? this.pdfUrl,
        tipoReceita: tipoReceita,
        conteudoMedicamentos: conteudoMedicamentos,
        diasAfastamento: diasAfastamento,
        cid: cid,
      );
}

/// Atestado médico/odontológico.
class Atestado extends DocumentoClinico {
  final String conteudoAtestado;
  final int diasAfastamento;
  final String? cid;
  final DateTime? dataInicioAfastamento;
  final DateTime? dataFimAfastamento;

  Atestado({
    required super.id,
    required super.pacienteId,
    required super.atendimentoId,
    required super.titulo,
    required super.conteudo,
    required super.emitidoEm,
    required super.profissionalId,
    super.assinado,
    super.assinaturaHash,
    super.pdfUrl,
    required this.conteudoAtestado,
    required this.diasAfastamento,
    this.cid,
    this.dataInicioAfastamento,
    this.dataFimAfastamento,
  }) : super(
    id: id,
    pacienteId: '',
    atendimentoId: '',
    tipo: TipoDocumento.atestado,
    titulo: titulo,
    conteudo: conteudo,
    emitidoEm: DateTime.now(),
    profissionalId: '',
  );

  @override
  Atestado copiarCom({
    bool? assinado,
    String? assinaturaHash,
    String? pdfUrl,
  }) =>
      Atestado(
        id: id,
        pacienteId: pacienteId,
        atendimentoId: atendimentoId,
        titulo: titulo,
        conteudo: conteudo,
        emitidoEm: emitidoEm,
        profissionalId: profissionalId,
        assinado: assinado ?? this.assinado,
        assinaturaHash: assinaturaHash ?? this.assinaturaHash,
        pdfUrl: pdfUrl ?? this.pdfUrl,
        conteudoAtestado: conteudoAtestado,
        diasAfastamento: diasAfastamento,
        cid: cid,
        dataInicioAfastamento: dataInicioAfastamento,
        dataFimAfastamento: dataFimAfastamento,
      );
}

/// TCLE - Termo de Consentimento Livre e Esclarecido.
class TCLE extends DocumentoClinico {
  final String procedimento;
  final String riscos;
  final String beneficios;
  final String alternativas;
  final String? testemunhaNome;
  final String? testemunhaCpf;

  TCLE({
    required super.id,
    required super.pacienteId,
    required super.atendimentoId,
    required super.titulo,
    required super.conteudo,
    required super.emitidoEm,
    required super.profissionalId,
    super.assinado,
    super.assinaturaHash,
    super.pdfUrl,
    required this.procedimento,
    required this.riscos,
    required this.beneficios,
    required this.alternativas,
    this.testemunhaNome,
    this.testemunhaCpf,
  }) : super(
    id: id,
    pacienteId: '',
    atendimentoId: '',
    tipo: TipoDocumento.tcle,
    titulo: titulo,
    conteudo: conteudo,
    emitidoEm: DateTime.now(),
    profissionalId: '',
  );

  @override
  TCLE copiarCom({
    bool? assinado,
    String? assinaturaHash,
    String? pdfUrl,
  }) =>
      TCLE(
        id: id,
        pacienteId: pacienteId,
        atendimentoId: atendimentoId,
        titulo: titulo,
        conteudo: conteudo,
        emitidoEm: emitidoEm,
        profissionalId: profissionalId,
/// Repository de Documentos (em memória, PROVISÓRIO).
class DocumentosRepository extends ChangeNotifier {
  final List<DocumentoClinico> _documentos = [];
  final List<ModeloDocumento> _modelos = [];
  int _contador = 0;

  DocumentosRepository({bool comExemplos = false}) {
    if (comExemplos) _carregarExemplos();
  }

  String novoId() {
    _contador++;
    return 'doc${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  // ---------- Documentos ----------

  List<DocumentoClinico> documentosDoPaciente(String pacienteId) =>
      _documentos.where((d) => d.pacienteId == pacienteId).toList()
        ..sort((a, b) => b.emitidoEm.compareTo(a.emitidoEm));

  List<DocumentoClinico> documentosDoAtendimento(String atendimentoId) =>
      _documentos.where((d) => d.atendimentoId == atendimentoId).toList()
        ..sort((a, b) => a.emitidoEm.compareTo(b.emitidoEm));

  String? adicionarDocumento(DocumentoClinico d) {
    _documentos.add(d);
    notifyListeners();
    return null;
  }

  String? assinarDocumento(String id, String profissionalId) {
    final idx = _documentos.indexWhere((d) => d.id == id);
    if (idx == -1) return 'Documento não encontrado';
    final d = _documentos[idx];
    if (d.assinado) return 'Documento já assinado';
    notifyListeners();
    return null;
  }

  // ---------- Modelos ----------

  List<ModeloDocumento> modelosPorEspecialidade(String especialidade) =>
      _modelos.where((m) => m.especialidade == especialidade).toList();

  ModeloDocumento? modeloPorId(String id) {
    try {
      return _modelos.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  String? salvarModelo(ModeloDocumento m) {
    final idx = _modelos.indexWhere((x) => x.id == m.id);
    if (idx >= 0) {
      _modelos[idx] = m;
    } else {
      _modelos.add(m);
    }
    notifyListeners();
    return null;
  }

  void _carregarExemplos() {
    _modelos.addAll([
      ModeloDocumento(
        id: 'modelo_prescricao_odonto',
        nome: 'Prescrição Odontológica Padrão',
        tipo: TipoDocumento.prescricao,
        especialidade: 'odontologia',
        versao: '1.0',
        criadoEm: DateTime(2026, 1, 1),
        profissionalId: 'system',
        variaveisObrigatorias: ['paciente_nome', 'medicamentos', 'posologia'],
        corpoComVariaveis:
            'PRESCRIÇÃO ODONTOLÓGICA\n\n'
            'Paciente: {{paciente_nome}}\n'
            'Data: {{data_emissao}}\n\n'
            'MEDICAMENTOS:\n{{medicamentos}}\n\n'
            'POSOLOGIA:\n{{posologia}}\n\n'
            'Observações: {{observacoes}}\n\n'
            'Profissional: {{profissional_nome}}\n'
            'CRO: {{profissional_cro}}',
      ),
      ModeloDocumento(
        id: 'modelo_atestado_odonto',
        nome: 'Atestado Odontológico Padrão',
        tipo: TipoDocumento.atestado,
        especialidade: 'odontologia',
        versao: '1.0',
        criadoEm: DateTime(2026, 1, 1),
        profissionalId: 'system',
        variaveisObrigatorias: ['paciente_nome', 'dias_afastamento', 'cid'],
        corpoComVariaveis:
            'ATESTADO ODONTOLÓGICO\n\n'
            'Atesto que o paciente {{paciente_nome}}, portador do CPF {{paciente_cpf}},\n'
            'necessita de afastamento de suas atividades por {{dias_afastamento}} dia(s),\n'
            'no período de {{data_inicio}} a {{data_fim}},\n'
            'em virtude de {{cid_descricao}} (CID-10: {{cid}}).\n\n'
            'Data: {{data_emissao}}\n\n'
            'Profissional: {{profissional_nome}}\n'
            'CRO: {{profissional_cro}}',
      ),
      ModeloDocumento(
        id: 'modelo_tcle_odonto',
        nome: 'TCLE Odontológico Padrão',
        tipo: TipoDocumento.tcle,
        especialidade: 'odontologia',
        versao: '1.0',
        criadoEm: DateTime(2026, 1, 1),
        profissionalId: 'system',
        variaveisObrigatorias: ['paciente_nome', 'procedimento', 'riscos'],
        corpoComVariaveis:
            'TERMO DE CONSENTIMENTO LIVRE E ESCLARECIDO\n\n'
            'Eu, {{paciente_nome}}, portador do CPF {{paciente_cpf}},\n'
            'declaro que fui informado(a) sobre o procedimento {{procedimento}},\n'
            'seus riscos ({{riscos}}), benefícios ({{beneficios}}) e alternativas ({{alternativas}}).\n\n'
            'Concordo com a realização do procedimento.\n\n'
            'Paciente: {{paciente_nome}}  Assinatura: ___________________\n'
            'Testemunha: {{testemunha_nome}}  CPF: {{testemunha_cpf}}  Assinatura: ___________________\n'
            'Profissional: {{profissional_nome}}  CRO: {{profissional_cro}}  Assinatura: ___________________\n'
            'Data: {{data_emissao}}',
      ),
    ]);
  }
}

final documentosRepository = DocumentosRepository();
        assinado: assinado ?? this.assinado,
        assinaturaHash: assinaturaHash ?? this.assinaturaHash,
        pdfUrl: pdfUrl ?? this.pdfUrl,
        procedimento: procedimento,
        riscos: riscos,
        beneficios: beneficios,
        alternativas: alternativas,
        testemunhaNome: testemunhaNome,
        testemunhaCpf: testemunhaCpf,
      );
}
      if (!valores.containsKey(v) || valores[v]!.isEmpty) {
        resultado = resultado.replaceAll('{{$v}}', '[{$v} NÃO PREENCHIDO]');
      }
    }
    return resultado;
  }
}
