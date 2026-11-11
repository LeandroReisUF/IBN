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

  /// Seção que o profissional abre e minimiza. "Grupo|Seção" cria dois níveis
  /// (ex.: "Exame físico|Geral"); sem "|", só a seção.
  final String? secao;

  /// A pergunta só aparece quando [dependeDe] tem a resposta [dependeValor]
  /// (padrão "sim"). Vários valores separados por "|": vale qualquer um.
  final String? dependeDe;
  final String? dependeValor;

  /// Texto que pode ser preenchido de uma vez com "Sem alterações" (exame físico).
  final bool aceitaSemAlteracao;

  const PerguntaAnamnese({
    required this.id,
    required this.enunciado,
    required this.tipo,
    this.obrigatoria = false,
    this.opcoes = const [],
    this.ajuda,
    this.secao,
    this.dependeDe,
    this.dependeValor,
    this.aceitaSemAlteracao = false,
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
/// A pergunta está visível com estas respostas? (perguntas condicionais)
bool perguntaVisivel(PerguntaAnamnese p, Map<String, String> respostas) {
  final mae = p.dependeDe;
  if (mae == null) return true;
  final v = (respostas[mae] ?? '').trim();
  if (v.isEmpty) return false;
  final marcadas = separarMultipla(v);
  return (p.dependeValor ?? 'sim').split('|').any((e) => e == v || marcadas.contains(e));
}

/// Enunciados das perguntas obrigatórias VISÍVEIS que ainda não foram respondidas.
List<String> faltandoObrigatorias(
  List<PerguntaAnamnese> perguntas,
  Map<String, String> respostas,
) =>
    [
      for (final p in perguntas)
        if (p.obrigatoria && perguntaVisivel(p, respostas) && _vazia(respostas[p.id]))
          p.enunciado,
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

const _sQueixa = 'Anamnese|Queixa e história';
const _sSaude = 'Anamnese|Saúde geral';
const _sHabitos = 'Anamnese|Hábitos';
const _sOdonto = 'Anamnese|Histórico odontológico';
const _sFisico = 'Exame físico|Geral';
const _sExtra = 'Exame físico|Extra oral';
const _sIntra = 'Exame físico|Intra oral';
const _sConduta = 'Exame físico|Diagnóstico e conduta';

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

const _doencasOdonto = [
  'Febre reumática',
  'Problemas cardíacos',
  'Problemas renais',
  'Problemas gástricos',
  'Problemas respiratórios',
  'Anemia',
  'Problemas articulares ou reumatismo',
  'Diabetes',
  'Hipertensão arterial',
  'Problema neurológico',
  'Problemas de coagulação',
  'Nenhuma',
];

/// PROVISÓRIO: perguntas e opções devem ser validadas pelos profissionais da clínica.
const modelosAnamnesePadrao = [
    ModeloAnamnese(
    id: 'anamnese-odontologica',
    nome: 'Anamnese odontológica',
    especialidade: Especialidade.odontologia,
    versao: 2,
    perguntas: [
      // ---- Queixa e história ----
      PerguntaAnamnese(id: 'queixa', enunciado: 'Queixa principal', tipo: TipoResposta.textoLongo, secao: _sQueixa),
      PerguntaAnamnese(id: 'historia', enunciado: 'História da doença atual', tipo: TipoResposta.textoLongo, secao: _sQueixa),

      // ---- Saúde geral ----
      PerguntaAnamnese(id: 'tratamento_medico', enunciado: 'Está em tratamento médico?', tipo: TipoResposta.simNao, secao: _sSaude),
      PerguntaAnamnese(id: 'tratamento_qual', enunciado: 'Para quê?', tipo: TipoResposta.texto, secao: _sSaude, dependeDe: 'tratamento_medico'),
      PerguntaAnamnese(id: 'medico_assistente', enunciado: 'Médico assistente / telefone', tipo: TipoResposta.texto, secao: _sSaude, dependeDe: 'tratamento_medico'),
      PerguntaAnamnese(id: 'recomendacao', enunciado: 'Recomendação médica', tipo: TipoResposta.texto, secao: _sSaude, dependeDe: 'tratamento_medico'),
      PerguntaAnamnese(id: 'usa_medicacao', enunciado: 'Usa alguma medicação?', tipo: TipoResposta.simNao, secao: _sSaude),
      PerguntaAnamnese(id: 'medicamentos', enunciado: 'Quais medicamentos?', tipo: TipoResposta.textoLongo, secao: _sSaude, dependeDe: 'usa_medicacao'),
      PerguntaAnamnese(id: 'doencas', enunciado: 'Doenças ou condições', tipo: TipoResposta.multiplaEscolha, opcoes: _doencasOdonto, secao: _sSaude),
      PerguntaAnamnese(id: 'infecciosas', enunciado: 'Doenças infectocontagiosas', tipo: TipoResposta.multiplaEscolha, opcoes: ['Hepatite', 'Sífilis', 'HIV+', 'Tuberculose', 'Nenhuma'], secao: _sSaude),
      PerguntaAnamnese(id: 'hepatite_tipo', enunciado: 'Tipo da hepatite', tipo: TipoResposta.texto, secao: _sSaude, dependeDe: 'infecciosas', dependeValor: 'Hepatite'),
      PerguntaAnamnese(id: 'outra_doenca', enunciado: 'Outra doença não listada', tipo: TipoResposta.texto, secao: _sSaude),
      PerguntaAnamnese(id: 'quimio_radio', enunciado: 'Fez quimioterapia ou radioterapia?', tipo: TipoResposta.simNao, secao: _sSaude),
      PerguntaAnamnese(id: 'alergias', enunciado: 'Alergias', tipo: TipoResposta.multiplaEscolha, opcoes: ['Penicilina', 'Anestésicos', 'Látex', 'Dipirona', 'Outras', 'Nenhuma'], secao: _sSaude),
      PerguntaAnamnese(id: 'alergia_outra', enunciado: 'Qual outra alergia?', tipo: TipoResposta.texto, secao: _sSaude, dependeDe: 'alergias', dependeValor: 'Outras'),
      PerguntaAnamnese(id: 'cirurgia', enunciado: 'Já fez cirurgia?', tipo: TipoResposta.simNao, secao: _sSaude),
      PerguntaAnamnese(id: 'cirurgia_qual', enunciado: 'Qual cirurgia?', tipo: TipoResposta.texto, secao: _sSaude, dependeDe: 'cirurgia'),
      PerguntaAnamnese(id: 'problemas_previos', enunciado: 'Já teve problema com', tipo: TipoResposta.multiplaEscolha, opcoes: ['Cicatrização', 'Anestesia', 'Hemorragia'], secao: _sSaude),
      PerguntaAnamnese(id: 'problemas_situacao', enunciado: 'Em que situação?', tipo: TipoResposta.texto, secao: _sSaude, dependeDe: 'problemas_previos', dependeValor: 'Cicatrização|Anestesia|Hemorragia'),
      PerguntaAnamnese(id: 'gestante', enunciado: 'Gestante?', tipo: TipoResposta.simNao, secao: _sSaude),
      PerguntaAnamnese(id: 'gestante_meses', enunciado: 'Quantos meses?', tipo: TipoResposta.texto, secao: _sSaude, dependeDe: 'gestante'),
      PerguntaAnamnese(id: 'prenatal', enunciado: 'Pré-natal em dia?', tipo: TipoResposta.simNao, secao: _sSaude, dependeDe: 'gestante'),
      PerguntaAnamnese(id: 'amamentando', enunciado: 'Amamentando?', tipo: TipoResposta.simNao, secao: _sSaude),
      PerguntaAnamnese(id: 'familiares', enunciado: 'Antecedentes familiares', tipo: TipoResposta.multiplaEscolha, opcoes: ['Diabetes', 'Hipertensão arterial', 'Câncer', 'Outras'], secao: _sSaude),
      PerguntaAnamnese(id: 'familiares_outras', enunciado: 'Quais outras?', tipo: TipoResposta.texto, secao: _sSaude, dependeDe: 'familiares', dependeValor: 'Outras'),

      // ---- Hábitos ----
      PerguntaAnamnese(id: 'habitos', enunciado: 'Hábitos', tipo: TipoResposta.multiplaEscolha, opcoes: ['Onicofagia', 'Respirador bucal', 'Bruxismo'], secao: _sHabitos),
      PerguntaAnamnese(id: 'tabagismo', enunciado: 'Tabagismo', tipo: TipoResposta.escolhaUnica, opcoes: ['Não', 'Sim', 'Ex-fumante'], secao: _sHabitos),
      PerguntaAnamnese(id: 'tabaco_detalhe', enunciado: 'Tipo, quantidade e tempo', tipo: TipoResposta.texto, secao: _sHabitos, dependeDe: 'tabagismo', dependeValor: 'Sim|Ex-fumante'),
      PerguntaAnamnese(id: 'alcoolismo', enunciado: 'Alcoolismo', tipo: TipoResposta.escolhaUnica, opcoes: ['Não', 'Sim', 'Ex-etilista'], secao: _sHabitos),
      PerguntaAnamnese(id: 'alcool_detalhe', enunciado: 'Tipo, quantidade e tempo', tipo: TipoResposta.texto, secao: _sHabitos, dependeDe: 'alcoolismo', dependeValor: 'Sim|Ex-etilista'),
      PerguntaAnamnese(id: 'outros_habitos', enunciado: 'Outros hábitos', tipo: TipoResposta.texto, secao: _sHabitos),
      PerguntaAnamnese(id: 'ansioso', enunciado: 'Ansioso(a), tenso(a) ou estressado(a)?', tipo: TipoResposta.simNao, secao: _sHabitos),

      // ---- Histórico odontológico ----
      PerguntaAnamnese(id: 'trat_odonto_atual', enunciado: 'Em tratamento odontológico?', tipo: TipoResposta.simNao, secao: _sOdonto),
      PerguntaAnamnese(id: 'ultima_consulta', enunciado: 'Última visita ao dentista', tipo: TipoResposta.data, secao: _sOdonto),
      PerguntaAnamnese(id: 'experiencia_negativa', enunciado: 'Experiência negativa no tratamento?', tipo: TipoResposta.simNao, secao: _sOdonto),
      PerguntaAnamnese(id: 'experiencia_qual', enunciado: 'Qual experiência?', tipo: TipoResposta.texto, secao: _sOdonto, dependeDe: 'experiencia_negativa'),
      PerguntaAnamnese(id: 'tratamento_realizado', enunciado: 'Que tipo de tratamento realizou?', tipo: TipoResposta.texto, secao: _sOdonto),
      PerguntaAnamnese(id: 'escovacao', enunciado: 'Escovações por dia', tipo: TipoResposta.escolhaUnica, opcoes: ['1 vez', '2 vezes', '3 vezes ou mais'], secao: _sOdonto),
      PerguntaAnamnese(id: 'escova_tipo', enunciado: 'Tipo da escova', tipo: TipoResposta.escolhaUnica, opcoes: ['Macia', 'Média', 'Dura', 'Elétrica'], secao: _sOdonto),
      PerguntaAnamnese(id: 'fio_dental', enunciado: 'Usa fio dental?', tipo: TipoResposta.simNao, secao: _sOdonto),
      PerguntaAnamnese(id: 'boca_seca', enunciado: 'Sensação de boca seca?', tipo: TipoResposta.simNao, secao: _sOdonto),
      PerguntaAnamnese(id: 'ardor', enunciado: 'Ardor em alguma região da boca?', tipo: TipoResposta.simNao, secao: _sOdonto),
      PerguntaAnamnese(id: 'ardor_qual', enunciado: 'Qual região?', tipo: TipoResposta.texto, secao: _sOdonto, dependeDe: 'ardor'),
      PerguntaAnamnese(id: 'dor', enunciado: 'Intensidade da dor hoje', tipo: TipoResposta.escala, ajuda: '0 = sem dor, 10 = dor máxima.', secao: _sOdonto),
      PerguntaAnamnese(id: 'outras_info', enunciado: 'Outras informações importantes', tipo: TipoResposta.texto, secao: _sOdonto),

      // ---- Exame físico geral ----
      PerguntaAnamnese(id: 'estado_geral', enunciado: 'Estado geral', tipo: TipoResposta.escolhaUnica, opcoes: ['Bom', 'Regular', 'Ruim'], secao: _sFisico),
      PerguntaAnamnese(id: 'peso', enunciado: 'Peso (kg)', tipo: TipoResposta.texto, secao: _sFisico),
      PerguntaAnamnese(id: 'altura', enunciado: 'Altura (m)', tipo: TipoResposta.texto, secao: _sFisico),
      PerguntaAnamnese(id: 'temperatura', enunciado: 'Temperatura (°C)', tipo: TipoResposta.texto, secao: _sFisico),
      PerguntaAnamnese(id: 'pressao', enunciado: 'Pressão arterial', tipo: TipoResposta.texto, secao: _sFisico),
      PerguntaAnamnese(id: 'pulsacao', enunciado: 'Pulsação', tipo: TipoResposta.texto, secao: _sFisico),
      PerguntaAnamnese(id: 'respiracao', enunciado: 'Respiração', tipo: TipoResposta.texto, secao: _sFisico),
      PerguntaAnamnese(id: 'fisico_obs', enunciado: 'Outras observações importantes', tipo: TipoResposta.texto, secao: _sFisico),

      // ---- Exame extra-oral ----
      PerguntaAnamnese(id: 'pele_cor', enunciado: 'Coloração da pele', tipo: TipoResposta.texto, secao: _sExtra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'pele_textura', enunciado: 'Textura da pele', tipo: TipoResposta.texto, secao: _sExtra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'olhos', enunciado: 'Olhos', tipo: TipoResposta.texto, secao: _sExtra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'cabelo', enunciado: 'Pelos / cabelo', tipo: TipoResposta.texto, secao: _sExtra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'assimetria', enunciado: 'Assimetria', tipo: TipoResposta.escolhaUnica, opcoes: ['Ausente', 'Presente'], secao: _sExtra),
      PerguntaAnamnese(id: 'ganglios', enunciado: 'Cadeias ganglionares', tipo: TipoResposta.escolhaUnica, opcoes: ['Sem alteração', 'Alteradas'], secao: _sExtra),
      PerguntaAnamnese(id: 'ganglio_superficie', enunciado: 'Superfície', tipo: TipoResposta.escolhaUnica, opcoes: ['Lisa', 'Rugosa'], secao: _sExtra, dependeDe: 'ganglios', dependeValor: 'Alteradas'),
      PerguntaAnamnese(id: 'ganglio_mobilidade', enunciado: 'Mobilidade', tipo: TipoResposta.escolhaUnica, opcoes: ['Ausente', 'Presente'], secao: _sExtra, dependeDe: 'ganglios', dependeValor: 'Alteradas'),
      PerguntaAnamnese(id: 'ganglio_sensibilidade', enunciado: 'Sensibilidade', tipo: TipoResposta.escolhaUnica, opcoes: ['Ausente', 'Presente'], secao: _sExtra, dependeDe: 'ganglios', dependeValor: 'Alteradas'),
      PerguntaAnamnese(id: 'ganglio_consistencia', enunciado: 'Consistência', tipo: TipoResposta.texto, secao: _sExtra, dependeDe: 'ganglios', dependeValor: 'Alteradas'),
      PerguntaAnamnese(id: 'atm', enunciado: 'ATM: marque o que houver', tipo: TipoResposta.multiplaEscolha, opcoes: ['Sensibilidade', 'Estalido', 'Crepitação'], secao: _sExtra),
      PerguntaAnamnese(id: 'glandulas', enunciado: 'Glândulas salivares', tipo: TipoResposta.texto, secao: _sExtra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'extra_obs', enunciado: 'Outras observações importantes', tipo: TipoResposta.texto, secao: _sExtra),

      // ---- Exame intra-oral ----
      PerguntaAnamnese(id: 'labio', enunciado: 'Lábio (pele, semi-mucosa, comissura e mucosa)', tipo: TipoResposta.texto, secao: _sIntra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'mucosa_jugal', enunciado: 'Mucosa jugal', tipo: TipoResposta.texto, secao: _sIntra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'gengiva', enunciado: 'Gengiva (cor, aspecto, consistência, margem)', tipo: TipoResposta.texto, secao: _sIntra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'rebordo', enunciado: 'Rebordo alveolar', tipo: TipoResposta.texto, secao: _sIntra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'trigono', enunciado: 'Trígono retromolar', tipo: TipoResposta.texto, secao: _sIntra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'lingua', enunciado: 'Língua (dorso, ventre, bordas e ápice)', tipo: TipoResposta.texto, secao: _sIntra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'assoalho', enunciado: 'Assoalho da boca', tipo: TipoResposta.texto, secao: _sIntra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'palato', enunciado: 'Palato mole e duro', tipo: TipoResposta.texto, secao: _sIntra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'pilares', enunciado: 'Pilares e amígdala', tipo: TipoResposta.texto, secao: _sIntra, aceitaSemAlteracao: true),
      PerguntaAnamnese(id: 'variacao', enunciado: 'Variação da normalidade', tipo: TipoResposta.escolhaUnica, opcoes: ['Ausente', 'Presente'], secao: _sIntra),
      PerguntaAnamnese(id: 'variacao_qual', enunciado: 'Qual(is)?', tipo: TipoResposta.texto, secao: _sIntra, dependeDe: 'variacao', dependeValor: 'Presente'),

      // ---- Diagnóstico e conduta ----
      PerguntaAnamnese(id: 'lesao', enunciado: 'Presença de lesão?', tipo: TipoResposta.simNao, secao: _sConduta),
      PerguntaAnamnese(id: 'lesao_descricao', enunciado: 'Descrição da lesão', tipo: TipoResposta.textoLongo, secao: _sConduta, dependeDe: 'lesao'),
      PerguntaAnamnese(id: 'hipotese', enunciado: 'Hipótese diagnóstica', tipo: TipoResposta.texto, secao: _sConduta),
      PerguntaAnamnese(id: 'exames_compl', enunciado: 'Exames complementares?', tipo: TipoResposta.simNao, secao: _sConduta),
      PerguntaAnamnese(id: 'exames_qual', enunciado: 'Quais exames?', tipo: TipoResposta.texto, secao: _sConduta, dependeDe: 'exames_compl'),
      PerguntaAnamnese(id: 'diagnostico', enunciado: 'Diagnóstico definitivo', tipo: TipoResposta.texto, secao: _sConduta),
      PerguntaAnamnese(id: 'conduta', enunciado: 'Conduta', tipo: TipoResposta.textoLongo, secao: _sConduta),
      PerguntaAnamnese(id: 'obs_oclusao', enunciado: 'Oclusão, cáries, próteses mal adaptadas ou outras', tipo: TipoResposta.textoLongo, secao: _sConduta),
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