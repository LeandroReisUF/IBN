import 'package:flutter/foundation.dart';
import 'package:ibn/features/hof/domain/hof.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

/// Procedimentos e fotos de HOF em memória (PROVISÓRIO).
///
/// Regras:
/// - procedimento novo só dentro de um atendimento em aberto do mesmo
///   profissional e paciente;
/// - RN06: toxina, preenchimento e bioestimulador exigem lote e validade;
///   lote vencido é recusado (qualquer insumo informado é validado);
/// - RN05: só inclusão. Corrigir = retificação (mesmo atendimento, mesmo autor,
///   com justificativa); anular = retificação sem conteúdo novo. Retificar não
///   exige atendimento aberto, e a validade do lote é conferida na data do
///   procedimento original.
///
/// ATENÇÃO: no servidor estas mesmas regras precisam ser repetidas.
class HofRepository extends ChangeNotifier {
  HofRepository({required ProntuarioRepository prontuario}) : _prontuario = prontuario;

  final ProntuarioRepository _prontuario;
  final List<ProcedimentoHOF> _procedimentos = [];
  final List<FotoComparativaHOF> _fotos = [];
  int _contador = 0;

  String novoId() {
    _contador++;
    return 'hof${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  // ---------- consultas ----------

  /// Do mais recente para o mais antigo (ordem de inclusão). [profissionalId]
  /// limita aos registros daquela pessoa.
  List<ProcedimentoHOF> procedimentosDoPaciente(String pacienteId, {String? profissionalId}) =>
      _procedimentos
          .where((p) =>
              p.pacienteId == pacienteId &&
              (profissionalId == null || p.profissionalId == profissionalId))
          .toList()
          .reversed
          .toList();

  ProcedimentoHOF? procedimentoPorId(String id) => _porId(id);

  /// Ids dos registros já corrigidos ou anulados por outro.
  Set<String> retificados(String pacienteId) => {
        for (final p in _procedimentos)
          if (p.pacienteId == pacienteId && p.retificaId != null) p.retificaId!,
      };

  /// Da mais antiga para a mais recente.
  List<FotoComparativaHOF> fotosDoPaciente(String pacienteId, {String? profissionalId}) =>
      _fotos
          .where((f) =>
              f.pacienteId == pacienteId &&
              (profissionalId == null || f.profissionalId == profissionalId))
          .toList()
        ..sort((a, b) => a.data.compareTo(b.data));

  bool temHistorico(String pacienteId) =>
      _procedimentos.any((p) => p.pacienteId == pacienteId) ||
      _fotos.any((f) => f.pacienteId == pacienteId);

  ProcedimentoHOF? _porId(String id) {
    for (final p in _procedimentos) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---------- procedimentos ----------

  /// Devolve a mensagem de erro, ou null se registrou.
  String? adicionarProcedimento(ProcedimentoHOF p) {
    if (_porId(p.id) != null) return 'Registro duplicado.';

    final atendimento = _prontuario.atendimentoPorId(p.atendimentoId);
    if (atendimento == null) return 'Atendimento não encontrado.';
    if (atendimento.pacienteId != p.pacienteId) return 'Paciente diferente do atendimento.';
    if (atendimento.profissionalId != p.profissionalId) {
      return 'Só o profissional do atendimento registra procedimentos nele.';
    }

    var dataReferencia = p.dataHora;
    final alvo = p.retificaId;
    if (alvo != null) {
      final anterior = _porId(alvo);
      if (anterior == null || anterior.pacienteId != p.pacienteId) {
        return 'Registro a retificar não encontrado.';
      }
      if (anterior.anulacao) return 'Uma anulação não pode ser retificada.';
      if (_procedimentos.any((x) => x.retificaId == alvo)) {
        return 'Este registro já foi retificado.';
      }
      if (anterior.profissionalId != p.profissionalId) {
        return 'Só o autor do registro pode retificá-lo.';
      }
      if (anterior.atendimentoId != p.atendimentoId) {
        return 'A retificação deve ficar no mesmo atendimento do registro original.';
      }
      if ((p.justificativa ?? '').trim().length < 3) {
        return 'Informe a justificativa da retificação.';
      }
      dataReferencia = anterior.dataHora;
    } else {
      if (p.anulacao) return 'A anulação precisa apontar o registro a anular.';
      if (atendimento.encerrado) {
        return 'O atendimento está encerrado. Use a retificação para corrigir.';
      }
    }

    if (!p.anulacao) {
      final erro = _validarConteudo(p, dataReferencia);
      if (erro != null) return erro;
    }

    _procedimentos.add(p);
    notifyListeners();
    return null;
  }

  String? _validarConteudo(ProcedimentoHOF p, DateTime dataReferencia) {
    if (p.tipo == TipoHOF.outro && (p.tipoOutro ?? '').trim().isEmpty) {
      return 'Descreva o tipo de procedimento.';
    }
    if (p.pontos.isEmpty) return 'Informe ao menos um ponto de aplicação.';
    if (p.pontos.any((x) => x.quantidade <= 0)) {
      return 'Informe a quantidade de cada ponto de aplicação.';
    }
    if (p.tipo.exigeLote && p.insumos.isEmpty) {
      return 'Informe o produto, o lote e a validade (RN06).';
    }
    for (final i in p.insumos) {
      final erro = i.validar(dataReferencia);
      if (erro != null) return erro;
    }
    return null;
  }

  // ---------- fotos ----------

  String? adicionarFoto(FotoComparativaHOF f) {
    if (f.descricao.trim().isEmpty) return 'Informe a descrição da foto.';
    if (f.bytes.isEmpty) return 'Arquivo de imagem vazio.';
    _fotos.add(f);
    notifyListeners();
    return null;
  }
}

final hofRepository = HofRepository(prontuario: prontuarioRepository);