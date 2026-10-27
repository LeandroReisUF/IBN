import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Ortodontia — Fase F (ficha, manutenções e fotos).
/// Substitui o bloco "FASE F" que ficava dentro de `odontograma.dart`.

/// Tipo de aparelho ortodôntico.
enum TipoAparelhoOrto {
  fixoMetalico('Fixo metálico'),
  fixoEstetico('Fixo estético'),
  autoligado('Autoligado'),
  alinhadores('Alinhadores (ex.: Invisalign)'),
  removivel('Removível / Placa'),
  funcional('Funcional'),
  expansor('Expansor');

  final String rotulo;
  const TipoAparelhoOrto(this.rotulo);
}

/// Arco ortodôntico em uso (fio e calibre).
class ArcoOrtodontico {
  final String fio;
  final String calibre;

  const ArcoOrtodontico({required this.fio, required this.calibre});

  @override
  bool operator ==(Object other) =>
      other is ArcoOrtodontico && other.fio == fio && other.calibre == calibre;

  @override
  int get hashCode => Object.hash(fio, calibre);
}

/// Elásticos em uso.
class ElasticosOrtodonticos {
  final String descricao;

  const ElasticosOrtodonticos(this.descricao);

  @override
  bool operator ==(Object other) =>
      other is ElasticosOrtodonticos && other.descricao == descricao;

  @override
  int get hashCode => descricao.hashCode;
}

/// Ficha ortodôntica. Cada "Salvar" gera uma NOVA VERSÃO (o repositório guarda
/// todas); a ficha atual é a última versão. Assim nada se perde (RN05).
class FichaOrtodontica {
  final String id;
  final String pacienteId;
  final TipoAparelhoOrto tipoAparelho;
  final DateTime dataInstalacao;
  final DateTime? previsaoTermino;
  final String queixaPrincipal;
  final String objetivos;
  final String? observacoesGerais;
  final ArcoOrtodontico? arcoSuperior;
  final ArcoOrtodontico? arcoInferior;
  final ElasticosOrtodonticos? elasticosSuperior;
  final ElasticosOrtodonticos? elasticosInferior;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final String profissionalId;

  const FichaOrtodontica({
    required this.id,
    required this.pacienteId,
    required this.tipoAparelho,
    required this.dataInstalacao,
    this.previsaoTermino,
    required this.queixaPrincipal,
    required this.objetivos,
    this.observacoesGerais,
    this.arcoSuperior,
    this.arcoInferior,
    this.elasticosSuperior,
    this.elasticosInferior,
    required this.criadoEm,
    required this.atualizadoEm,
    required this.profissionalId,
  });
}

/// Uma manutenção ortodôntica. Só inclusão: para corrigir, cria-se outra
/// manutenção com [retificaId] apontando para a errada e uma [justificativa].
class ManutencaoOrtodontica {
  final String id;
  final String pacienteId;
  final DateTime data;
  final String ativacaoRealizada;
  final String? observacoes;
  final DateTime? proximaManutencao;
  final String profissionalId;
  final String? agendamentoId;
  final String? retificaId;
  final String? justificativa;

  const ManutencaoOrtodontica({
    required this.id,
    required this.pacienteId,
    required this.data,
    required this.ativacaoRealizada,
    this.observacoes,
    this.proximaManutencao,
    required this.profissionalId,
    this.agendamentoId,
    this.retificaId,
    this.justificativa,
  });
}

/// Foto comparativa (antes/depois). Os bytes ficam em memória por enquanto;
/// quando houver servidor, o arquivo será enviado e aqui ficará só a referência.
class FotoComparativaOrto {
  final String id;
  final String pacienteId;
  final DateTime data;
  final String descricao;
  final String nomeArquivo;
  final Uint8List bytes;
  final bool isAntes;
  final String profissionalId;

  const FotoComparativaOrto({
    required this.id,
    required this.pacienteId,
    required this.data,
    required this.descricao,
    required this.nomeArquivo,
    required this.bytes,
    this.isAntes = false,
    required this.profissionalId,
  });
}

/// Ficha, manutenções e fotos em memória (PROVISÓRIO).
class OrtodontiaRepository extends ChangeNotifier {
  final List<FichaOrtodontica> _versoesFicha = [];
  final List<ManutencaoOrtodontica> _manutencoes = [];
  final List<FotoComparativaOrto> _fotos = [];
  int _contador = 0;

  String novoId() {
    _contador++;
    return 'orto${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  // ---------- Ficha ----------

  /// Versão atual da ficha (a última salva), ou null.
  FichaOrtodontica? fichaDoPaciente(String pacienteId) {
    for (var i = _versoesFicha.length - 1; i >= 0; i--) {
      if (_versoesFicha[i].pacienteId == pacienteId) return _versoesFicha[i];
    }
    return null;
  }

  /// Todas as versões, da mais recente para a mais antiga.
  List<FichaOrtodontica> historicoFicha(String pacienteId) =>
      _versoesFicha.where((f) => f.pacienteId == pacienteId).toList().reversed.toList();

  /// Devolve a mensagem de erro, ou null se salvou.
  String? salvarFicha(FichaOrtodontica f) {
    if (f.queixaPrincipal.trim().isEmpty) return 'Informe a queixa principal.';
    if (f.objetivos.trim().isEmpty) return 'Informe os objetivos do tratamento.';
    final previsao = f.previsaoTermino;
    if (previsao != null && previsao.isBefore(f.dataInstalacao)) {
      return 'A previsão de término deve ser depois da instalação.';
    }
    _versoesFicha.add(f);
    notifyListeners();
    return null;
  }

  // ---------- Manutenções ----------

  /// Todas as manutenções (inclusive as retificadas), da mais recente para a mais antiga.
  List<ManutencaoOrtodontica> manutencoesDoPaciente(String pacienteId) =>
      _manutencoes.where((m) => m.pacienteId == pacienteId).toList()
        ..sort((a, b) => b.data.compareTo(a.data));

  /// Ids das manutenções que já foram corrigidas por outra.
  Set<String> retificadas(String pacienteId) => {
        for (final m in _manutencoes)
          if (m.pacienteId == pacienteId && m.retificaId != null) m.retificaId!,
      };

  ManutencaoOrtodontica? _porId(String id) {
    for (final m in _manutencoes) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Inclui uma manutenção nova ou uma retificação. Devolve o erro, ou null.
  String? adicionarManutencao(ManutencaoOrtodontica m) {
    if (m.ativacaoRealizada.trim().isEmpty) return 'Informe a ativação realizada.';
    final proxima = m.proximaManutencao;
    if (proxima != null && proxima.isBefore(m.data)) {
      return 'A próxima manutenção deve ser depois da data da manutenção.';
    }

    final alvo = m.retificaId;
    if (alvo != null) {
      final anterior = _porId(alvo);
      if (anterior == null || anterior.pacienteId != m.pacienteId) {
        return 'Registro a retificar não encontrado.';
      }
      if (_manutencoes.any((x) => x.retificaId == alvo)) {
        return 'Este registro já foi retificado.';
      }
      if ((m.justificativa ?? '').trim().length < 3) {
        return 'Informe a justificativa da retificação.';
      }
    } else if (_porId(m.id) != null) {
      return 'Registro duplicado.';
    }

    _manutencoes.add(m);
    notifyListeners();
    return null;
  }

  // ---------- Fotos ----------

  /// Da mais antiga para a mais recente.
  List<FotoComparativaOrto> fotosDoPaciente(String pacienteId) =>
      _fotos.where((f) => f.pacienteId == pacienteId).toList()
        ..sort((a, b) => a.data.compareTo(b.data));

  String? adicionarFoto(FotoComparativaOrto f) {
    if (f.descricao.trim().isEmpty) return 'Informe a descrição da foto.';
    if (f.bytes.isEmpty) return 'Arquivo de imagem vazio.';
    _fotos.add(f);
    notifyListeners();
    return null;
  }
}

final ortodontiaRepository = OrtodontiaRepository();