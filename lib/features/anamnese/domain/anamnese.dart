import 'package:ibn/core/especialidade.dart';
import 'package:ibn/core/formadores.dart';

/// Anamnese configurável por especialidade (RF03.3). Modelos imutáveis.
/// Anamnese assinada nunca muda (RN05): atualizar = nova versão, e a anterior
/// continua no histórico.

enum TipoResposta {
  texto('Texto curto'),
  textoLongo('Texto longo'),
  simNao('Sim / Não'),
  escolhaUnica('Escolha única'),
  multiplaEscolha('Múltipla escolha'),
  escala('Escala de 0 a 10'),
  data('Data');

  final String rotulo;
  const TipoResposta(this.rotulo);
}

/// Valores guardados: texto livre; simNao = "sim"/"nao"; escolhaUnica = a opção;
/// multiplaEscolha = opções separadas por "|"; escala = inteiro de 0 a 10;
/// data = AAAA-MM-DD.
class PerguntaAnamnese {
  final String id;
  final String enunciado;
  final TipoResposta tipo;
  final bool obrigatoria;
  final List<String> opcoes; // escolhaUnica e multiplaEscolha (sem o caractere "|")
  final String? ajuda;

  const PerguntaAnamnese({
    required this.id,
    required this.enunciado,
    required this.tipo,
    this.obrigatoria = false,
    this.opcoes = const [],
    this.ajuda,
  });
}

/// Modelo de anamnese. [especialidade] nula = modelo geral, de todos os perfis.
class ModeloAnamnese {
  final String id;
  final String nome;
  final Especialidade? especialidade;
  final int versao;
  final List<PerguntaAnamnese> perguntas;

  const ModeloAnamnese({
    required this.id,
    required this.nome,
    this.especialidade,
    this.versao = 1,
    required this.perguntas,
  });
}

/// Anamnese preenchida. Guarda uma cópia das perguntas, então o histórico
/// continua legível mesmo que o modelo mude depois.
class Anamnese {
  final String id;
  final String pacienteId;
  final String? atendimentoId;
  final String profissionalId;
  final String modeloId;
  final String titulo;
  final int modeloVersao;
  final List<PerguntaAnamnese> perguntas;
  final Map<String, String> respostas;
  final DateTime criadaEm;
  final bool assinada;
  final DateTime? assinadaEm;

  /// PROVISÓRIO: selo de integridade simples. Não é assinatura digital.
  final String? selo;

  /// Versão anterior que esta atualiza.
  final String? anteriorId;

  const Anamnese({
    required this.id,
    required this.pacienteId,
    this.atendimentoId,
    required this.profissionalId,
    required this.modeloId,
    required this.titulo,
    required this.modeloVersao,
    required this.perguntas,
    required this.respostas,
    required this.criadaEm,
    this.assinada = false,
    this.assinadaEm,
    this.selo,
    this.anteriorId,
  });

  Anamnese copiarCom({
    Map<String, String>? respostas,
    bool? assinada,
    DateTime? assinadaEm,
    String? selo,
  }) =>
      Anamnese(
        id: id,
        pacienteId: pacienteId,
        atendimentoId: atendimentoId,
        profissionalId: profissionalId,
        modeloId: modeloId,
        titulo: titulo,
        modeloVersao: modeloVersao,
        perguntas: perguntas,
        respostas: respostas ?? this.respostas,
        criadaEm: criadaEm,
        assinada: assinada ?? this.assinada,
        assinadaEm: assinadaEm ?? this.assinadaEm,
        selo: selo ?? this.selo,
        anteriorId: anteriorId,
      );
}

// ---------- respostas ----------

String juntarMultipla(List<String> opcoes) => opcoes.join('|');

List<String> separarMultipla(String valor) =>
    valor.isEmpty ? const [] : valor.split('|').where((s) => s.isNotEmpty).toList();

bool _vazia(String? v) => (v ?? '').trim().isEmpty;

/// Enunciados das perguntas obrigatórias que ainda não foram respondidas.
List<String> faltandoObrigatorias(
  List<PerguntaAnamnese> perguntas,
  Map<String, String> respostas,
) =>
    [
      for (final p in perguntas)
        if (p.obrigatoria && _vazia(respostas[p.id])) p.enunciado,
    ];

/// Confere o formato das respostas dadas (as vazias são ignoradas).
/// Devolve a mensagem de erro, ou null se está tudo certo.
String? validarRespostas(List<PerguntaAnamnese> perguntas, Map<String, String> respostas) {
  final porId = {for (final p in perguntas) p.id: p};
  for (final e in respostas.entries) {
    final p = porId[e.key];
    if (p == null) return 'Pergunta desconhecida: ${e.key}.';
    final v = e.value.trim();
    if (v.isEmpty) continue;
    final erro = 'Resposta inválida para "${p.enunciado}".';
    switch (p.tipo) {
      case TipoResposta.texto || TipoResposta.textoLongo:
        break;
      case TipoResposta.simNao:
        if (v != 'sim' && v != 'nao') return erro;
      case TipoResposta.escolhaUnica:
        if (!p.opcoes.contains(v)) return erro;
      case TipoResposta.multiplaEscolha:
        if (separarMultipla(v).any((o) => !p.opcoes.contains(o))) return erro;
      case TipoResposta.escala:
        final n = int.tryParse(v);
        if (n == null || n < 0 || n > 10) return erro;
      case TipoResposta.data:
        if (DateTime.tryParse(v) == null) return erro;
    }
  }
  return null;
}

/// Resposta em texto para mostrar na tela, ou null se não foi respondida.
String? respostaLegivel(PerguntaAnamnese p, String? valor) {
  final v = (valor ?? '').trim();
  if (v.isEmpty) return null;
  switch (p.tipo) {
    case TipoResposta.simNao:
      return v == 'sim' ? 'Sim' : 'Não';
    case TipoResposta.multiplaEscolha:
      return separarMultipla(v).join(', ');
    case TipoResposta.escala:
      return '$v/10';
    case TipoResposta.data:
      final d = DateTime.tryParse(v);
      return d == null ? v : formatarData(d);
    case TipoResposta.texto || TipoResposta.textoLongo || TipoResposta.escolhaUnica:
      return v;
  }
}

// ---------- modelos de partida ----------

const _doencas = [
  'Hipertensão',
  'Diabetes',
  'Cardiopatia',
  'Hepatite',
  'Problemas de coagulação',
  'Asma ou problema respiratório',
  'Epilepsia',
  'Nenhuma',
];

/// PROVISÓRIO: perguntas e opções devem ser validadas pelos profissionais da clínica.
const modelosAnamnesePadrao = [
  ModeloAnamnese(
    id: 'anamnese-odontologica',
    nome: 'Anamnese odontológica',
    especialidade: Especialidade.odontologia,
    perguntas: [
      PerguntaAnamnese(
        id: 'queixa',
        enunciado: 'Queixa principal',
        tipo: TipoResposta.textoLongo,
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'tratamento_medico',
        enunciado: 'Está em tratamento médico?',
        tipo: TipoResposta.simNao,
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'tratamento_qual',
        enunciado: 'Se sim, qual tratamento?',
        tipo: TipoResposta.texto,
      ),
      PerguntaAnamnese(
        id: 'medicamentos',
        enunciado: 'Medicamentos em uso',
        tipo: TipoResposta.textoLongo,
        ajuda: 'Escreva "nenhum" se não usa.',
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'doencas',
        enunciado: 'Doenças ou condições',
        tipo: TipoResposta.multiplaEscolha,
        opcoes: _doencas,
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'alergias',
        enunciado: 'Alergias',
        tipo: TipoResposta.multiplaEscolha,
        opcoes: ['Penicilina', 'Anestésicos', 'Látex', 'Dipirona', 'Outras', 'Nenhuma'],
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'gestante',
        enunciado: 'Gestante ou lactante?',
        tipo: TipoResposta.simNao,
      ),
      PerguntaAnamnese(
        id: 'fumante',
        enunciado: 'Fumante?',
        tipo: TipoResposta.simNao,
      ),
      PerguntaAnamnese(
        id: 'escovacao',
        enunciado: 'Quantas vezes escova os dentes por dia?',
        tipo: TipoResposta.escolhaUnica,
        opcoes: ['1 vez', '2 vezes', '3 vezes ou mais'],
      ),
      PerguntaAnamnese(
        id: 'ultima_consulta',
        enunciado: 'Data da última consulta odontológica',
        tipo: TipoResposta.data,
      ),
      PerguntaAnamnese(
        id: 'dor',
        enunciado: 'Intensidade da dor hoje',
        tipo: TipoResposta.escala,
        ajuda: '0 = sem dor, 10 = dor máxima.',
      ),
    ],
  ),
  ModeloAnamnese(
    id: 'anamnese-estetica',
    nome: 'Anamnese estética',
    especialidade: Especialidade.biomedicina,
    perguntas: [
      PerguntaAnamnese(
        id: 'fototipo',
        enunciado: 'Fototipo (Fitzpatrick)',
        tipo: TipoResposta.escolhaUnica,
        opcoes: [
          'I - sempre queima, nunca bronzeia',
          'II - queima fácil, bronzeia pouco',
          'III - queima moderadamente, bronzeia',
          'IV - queima pouco, bronzeia fácil',
          'V - raramente queima, pele morena',
          'VI - nunca queima, pele negra',
        ],
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'contraindicacoes',
        enunciado: 'Contraindicações conhecidas',
        tipo: TipoResposta.textoLongo,
        ajuda: 'Escreva "nenhuma" se não houver.',
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'alergico',
        enunciado: 'Tem histórico alérgico?',
        tipo: TipoResposta.simNao,
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'alergico_qual',
        enunciado: 'Se sim, a quê?',
        tipo: TipoResposta.texto,
      ),
      PerguntaAnamnese(
        id: 'patologias',
        enunciado: 'Patologias',
        tipo: TipoResposta.multiplaEscolha,
        opcoes: [
          'Hipertensão',
          'Diabetes',
          'Doença autoimune',
          'Distúrbio de tireoide',
          'Herpes recorrente',
          'Nenhuma',
        ],
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'gestante',
        enunciado: 'Gestante ou lactante?',
        tipo: TipoResposta.simNao,
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'isotretinoina',
        enunciado: 'Usou isotretinoína nos últimos 6 meses?',
        tipo: TipoResposta.simNao,
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'anticoagulante',
        enunciado: 'Usa anticoagulantes?',
        tipo: TipoResposta.simNao,
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'queloide',
        enunciado: 'Tem tendência a queloide?',
        tipo: TipoResposta.simNao,
      ),
      PerguntaAnamnese(
        id: 'observacoes',
        enunciado: 'Observações',
        tipo: TipoResposta.textoLongo,
      ),
    ],
  ),
  ModeloAnamnese(
    id: 'anamnese-geral',
    nome: 'Anamnese geral',
    perguntas: [
      PerguntaAnamnese(
        id: 'queixa',
        enunciado: 'Queixa principal',
        tipo: TipoResposta.textoLongo,
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'doencas',
        enunciado: 'Doenças ou condições',
        tipo: TipoResposta.multiplaEscolha,
        opcoes: _doencas,
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'medicamentos',
        enunciado: 'Medicamentos em uso',
        tipo: TipoResposta.textoLongo,
        ajuda: 'Escreva "nenhum" se não usa.',
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'alergias',
        enunciado: 'Alergias',
        tipo: TipoResposta.textoLongo,
        ajuda: 'Escreva "nenhuma" se não houver.',
        obrigatoria: true,
      ),
      PerguntaAnamnese(
        id: 'cirurgias',
        enunciado: 'Cirurgias anteriores',
        tipo: TipoResposta.textoLongo,
      ),
      PerguntaAnamnese(
        id: 'habitos',
        enunciado: 'Hábitos (fumo, álcool, atividade física)',
        tipo: TipoResposta.textoLongo,
      ),
    ],
  ),
];