import 'package:flutter/foundation.dart';

/// Tipo de procedimento HOF.
enum TipoHOF {
  toxinaBotulinica('Toxina Botulínica'),
  preenchimento('Preenchimento Facial'),
  bioestimulador('Bioestimulador de Colágeno'),
  fiosTensao('Fios de Sustentação/Tensão'),
  peelingQuimico('Peeling Químico'),
  microagulhamento('Microagulhamento'),
  laser('Laser Fracionado/CO2'),
  luzPulsada('Luz Pulsada (IPL)'),
  radiofrequencia('Radiofrequência'),
  ultrasomMicrofocado('Ultrassom Microfocado (HIFU)'),
  outro('Outro');

  final String rotulo;
  const TipoHOF(this.rotulo);
}

/// Área anatômica da face para aplicação.
enum AreaFaceHOF {
  testa('Testa'),
  glabela('Glabela'),
  periorbital('Periorbital / Pés de galinha'),
  nariz('Nariz'),
  malar('Malar / Maçã do rosto'),
  mandibular('Linha mandibular / Mandíbula'),
  mento('Mento / Queixo'),
  labial('Lábios / Vermelhão'),
  perioral('Perioral / Código de barras'),
  cervical('Região cervical / Papada'),
  outra('Outra');

  final String rotulo;
  const AreaFaceHOF(this.rotulo);
}

/// Lado da face.
enum LadoFaceHOF {
  esquerdo('Esquerdo'),
  direito('Direito'),
/// Ponto de aplicação individual.
class PontoAplicacaoHOF {
  final String id;
  final AreaFaceHOF area;
  final LadoFaceHOF lado;
  final String descricao;
  final double profundidadeMm;
  final String tecnica;

  const PontoAplicacaoHOF({
    required this.id,
    required this.area,
    required this.lado,
    required this.descricao,
    required this.profundidadeMm,
    required this.tecnica,
  });
}

/// Insumo utilizado no procedimento (com lote - RN06).
class InsumoHOF {
  final String id;
  final String nome;
  final String fabricante;
  final String lote;
  final DateTime validade;
  final double quantidadeUsada;
  final String unidade;

  const InsumoHOF({
    required this.id,
    required this.nome,
    required this.fabricante,
    required this.lote,
    required this.validade,
    required this.quantidadeUsada,
    required this.unidade,
  });

  bool get vencido => DateTime.now().isAfter(validade);
  bool venceEm(int dias) => DateTime.now().add(Duration(days: dias)).isAfter(validade);
}

/// Procedimento HOF realizado em um atendimento.
class ProcedimentoHOF {
  final String id;
  final String atendimentoId;
  final TipoHOF tipo;
  final String? tipoOutro;
  final List<PontoAplicacaoHOF> pontos;
  final List<InsumoHOF> insumos;
  final String tecnicaGeral;
  final String observacoes;
  final DateTime dataHora;
  final String profissionalId;
  final String? fotoAntesId;
  final String? fotoDepoisId;

  const ProcedimentoHOF({
    required this.id,
    required this.atendimentoId,
    required this.tipo,
    this.tipoOutro,
    required this.pontos,
    required this.insumos,
    required this.tecnicaGeral,
    this.observacoes = '',
/// Foto comparativa HOF (antes/depois).
class FotoComparativaHOF {
  final String id;
  final String pacienteId;
  final String procedimentoId;
  final DateTime data;
  final String descricao;
  final String caminhoArquivo;
  final bool isAntes;
  final String profissionalId;

  const FotoComparativaHOF({
    required this.id,
    required this.pacienteId,
    required this.procedimentoId,
    required this.data,
    required this.descricao,
    required this.caminhoArquivo,
    this.isAntes = false,
    required this.profissionalId,
  });
}

/// Ficha HOF do paciente (histórico de procedimentos).
class FichaHOF {
  final String id;
  final String pacienteId;
  final List<ProcedimentoHOF> procedimentos;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  const FichaHOF({
    required this.id,
    required this.pacienteId,
    required this.procedimentos,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  FichaHOF copiarCom({
    List<ProcedimentoHOF>? procedimentos,
    DateTime? atualizadoEm,
  }) =>
      FichaHOF(
        id: id,
        pacienteId: pacienteId,
        procedimentos: procedimentos ?? this.procedimentos,
        criadoEm: criadoEm,
        atualizadoEm: atualizadoEm,
      );
}

/// Repository HOF (em memória, PROVISÓRIO).
class HOFRepository extends ChangeNotifier {
  final List<FichaHOF> _fichas = [];
  final List<ProcedimentoHOF> _procedimentos = [];
  final List<FotoComparativaHOF> _fotos = [];
  int _contador = 0;

  HOFRepository({bool comExemplos = false}) {
    if (comExemplos) _carregarExemplos();
  }

  String novoId() {
    _contador++;
    return 'hof${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  // ---------- Ficha ----------

  FichaHOF? fichaDoPaciente(String pacienteId) {
    try {
      return _fichas.firstWhere((f) => f.pacienteId == pacienteId);
    } catch (_) {
      return null;
    }
  }

  String? salvarFicha(FichaHOF ficha) {
    final existente = fichaDoPaciente(ficha.pacienteId);
    if (existente != null) {
      final idx = _fichas.indexOf(existente);
      _fichas[idx] = ficha;
    } else {
      _fichas.add(ficha);
    }
    notifyListeners();
    return null;
  }

  // ---------- Procedimentos ----------

  List<ProcedimentoHOF> procedimentosDoAtendimento(String atendimentoId) =>
      _procedimentos
          .where((p) => p.atendimentoId == atendimentoId)
          .toList()
        ..sort((a, b) => a.dataHora.compareTo(b.dataHora));

  String? adicionarProcedimento(ProcedimentoHOF p) {
    _procedimentos.add(p);
    notifyListeners();
    return null;
  }

  // ---------- Fotos ----------

  List<FotoComparativaHOF> fotosDoProcedimento(String procedimentoId) =>
      _fotos
          .where((f) => f.procedimentoId == procedimentoId)
          .toList()
        ..sort((a, b) => a.data.compareTo(b.data));

  String? adicionarFoto(FotoComparativaHOF f) {
    _fotos.add(f);
    notifyListeners();
    return null;
  }

  void _carregarExemplos() {
    // Exemplos serão adicionados quando houver dados de teste
  }
}

final hofRepository = HOFRepository();
    required this.dataHora,
    required this.profissionalId,
    this.fotoAntesId,
    this.fotoDepoisId,
  });
}
  bilateral('Bilateral'),
  linhaMedia('Linha média');

  final String rotulo;
  const LadoFaceHOF(this.rotulo);
}
