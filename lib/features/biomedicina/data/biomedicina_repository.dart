import 'package:flutter/foundation.dart';
import 'package:ibn/features/biomedicina/domain/biomedicina.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

/// Procedimentos estéticos da Biomedicina em memória (PROVISÓRIO).
///
/// Regras:
/// - procedimento novo só dentro de um atendimento em aberto do mesmo
///   profissional e paciente;
/// - RN06: todo procedimento exige ao menos um produto com lote e validade;
///   lote vencido é recusado;
/// - RN05: só inclusão. Corrigir = retificação (mesmo atendimento, mesmo autor,
///   com justificativa); anular = retificação sem conteúdo novo. Retificar não
///   exige atendimento aberto, e a validade do lote é conferida na data do
///   procedimento original.
///
/// ATENÇÃO: no servidor estas mesmas regras precisam ser repetidas.
class BiomedicinaRepository extends ChangeNotifier {
  BiomedicinaRepository({required ProntuarioRepository prontuario}) : _prontuario = prontuario;

  final ProntuarioRepository _prontuario;
  final List<ProcedimentoEstetico> _procedimentos = [];
  int _contador = 0;

  String novoId() {
    _contador++;
    return 'bio${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  // ---------- consultas ----------

  /// Do mais recente para o mais antigo (ordem de inclusão).
  List<ProcedimentoEstetico> procedimentosDoPaciente(String pacienteId, {String? profissionalId}) =>
      _procedimentos
          .where((p) =>
              p.pacienteId == pacienteId &&
              (profissionalId == null || p.profissionalId == profissionalId))
          .toList()
          .reversed
          .toList();

  ProcedimentoEstetico? procedimentoPorId(String id) => _porId(id);

  /// Ids dos registros já corrigidos ou anulados por outro.
  Set<String> retificados(String pacienteId) => {
        for (final p in _procedimentos)
          if (p.pacienteId == pacienteId && p.retificaId != null) p.retificaId!,
      };

  bool temHistorico(String pacienteId) => _procedimentos.any((p) => p.pacienteId == pacienteId);

  ProcedimentoEstetico? _porId(String id) {
    for (final p in _procedimentos) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---------- procedimentos ----------

  /// Devolve a mensagem de erro, ou null se registrou.
  String? adicionarProcedimento(ProcedimentoEstetico p) {
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

  String? _validarConteudo(ProcedimentoEstetico p, DateTime dataReferencia) {
    if (p.protocolo == TipoProtocolo.outro && (p.protocoloOutro ?? '').trim().isEmpty) {
      return 'Descreva o protocolo.';
    }
    if (p.regiaoTratada.trim().isEmpty) return 'Informe a região tratada.';
    if (p.insumos.isEmpty) return 'Informe o produto, o lote e a validade (RN06).';
    for (final i in p.insumos) {
      final erro = i.validar(dataReferencia);
      if (erro != null) return erro;
    }
    return null;
  }
}

final biomedicinaRepository = BiomedicinaRepository(prontuario: prontuarioRepository);