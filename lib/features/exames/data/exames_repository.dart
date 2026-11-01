import 'package:flutter/foundation.dart';
import 'package:ibn/features/exames/domain/exames.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

/// Exames e arquivos clínicos em memória (PROVISÓRIO).
///
/// Regras:
/// - exame novo só dentro de um atendimento em aberto do mesmo profissional;
/// - status só avança (solicitado → realizado → resultado disponível) ou
///   cancela; exame com arquivo anexado não cancela;
/// - arquivos: só JPG, PNG e PDF, até 10 MB, só quem solicitou anexa, e o
///   resultado pode chegar depois do atendimento encerrado;
/// - RN05: não há excluir arquivo. Substituir = novo arquivo que retifica o
///   anterior, com justificativa.
///
/// ATENÇÃO: no servidor estas mesmas regras precisam ser repetidas.
class ExamesRepository extends ChangeNotifier {
  ExamesRepository({required ProntuarioRepository prontuario}) : _prontuario = prontuario;

  final ProntuarioRepository _prontuario;
  final List<Exame> _exames = [];
  final List<ArquivoClinico> _arquivos = [];
  int _contador = 0;

  String novoId() {
    _contador++;
    return 'ex${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  // ---------- consultas ----------

  /// Do mais recente para o mais antigo (ordem de inclusão).
  List<Exame> examesDoPaciente(String pacienteId, {String? profissionalId}) => _exames
      .where((e) =>
          e.pacienteId == pacienteId &&
          (profissionalId == null || e.profissionalId == profissionalId))
      .toList()
      .reversed
      .toList();

  Exame? examePorId(String id) {
    for (final e in _exames) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Arquivos do exame, do mais antigo para o mais recente.
  List<ArquivoClinico> arquivosDoExame(String exameId) =>
      _arquivos.where((a) => a.exameId == exameId).toList();

  /// Ids dos arquivos já substituídos por outro.
  Set<String> arquivosRetificados(String pacienteId) => {
        for (final a in _arquivos)
          if (a.pacienteId == pacienteId && a.retificaId != null) a.retificaId!,
      };

  bool temHistorico(String pacienteId) => _exames.any((e) => e.pacienteId == pacienteId);

  // ---------- exames ----------

  /// Devolve a mensagem de erro, ou null se solicitou.
  String? solicitarExame(Exame e) {
    if (examePorId(e.id) != null) return 'Exame duplicado.';
    if (e.nome.trim().isEmpty) return 'Informe o nome do exame.';
    if (e.status != StatusExame.solicitado) return 'Um exame novo começa como "Solicitado".';
    final a = _prontuario.atendimentoPorId(e.atendimentoId);
    if (a == null) return 'Atendimento não encontrado.';
    if (a.encerrado) return 'O atendimento está encerrado.';
    if (a.pacienteId != e.pacienteId) return 'Paciente diferente do atendimento.';
    if (a.profissionalId != e.profissionalId) {
      return 'Só o profissional do atendimento solicita exames nele.';
    }
    _exames.add(e);
    notifyListeners();
    return null;
  }

  String? mudarStatus(String id, String usuarioId, StatusExame novo, {DateTime? agora}) {
    final i = _exames.indexWhere((e) => e.id == id);
    if (i < 0) return 'Exame não encontrado.';
    final e = _exames[i];
    if (e.profissionalId != usuarioId) return 'Só quem solicitou o exame altera o status.';
    if (!e.status.proximos.contains(novo)) {
      return 'Não é possível passar de "${e.status.rotulo}" para "${novo.rotulo}".';
    }
    if (novo == StatusExame.cancelado && arquivosDoExame(id).isNotEmpty) {
      return 'Exame com arquivos anexados não pode ser cancelado.';
    }
    _exames[i] = e.copiarCom(status: novo, atualizadoEm: agora ?? DateTime.now());
    notifyListeners();
    return null;
  }

  // ---------- arquivos ----------

  String? adicionarArquivo(ArquivoClinico a) {
    final e = examePorId(a.exameId);
    if (e == null) return 'Exame não encontrado.';
    if (e.pacienteId != a.pacienteId) return 'Paciente diferente do exame.';
    if (e.profissionalId != a.profissionalId) return 'Só quem solicitou o exame anexa arquivos.';
    if (e.status == StatusExame.cancelado) return 'Exame cancelado não recebe arquivos.';
    if (_arquivos.any((x) => x.id == a.id)) return 'Arquivo duplicado.';

    final mime = mimeDoArquivo(a.nomeArquivo);
    if (mime == null || mime != a.mimeType) {
      return 'Formato não permitido. Use JPG, PNG ou PDF.';
    }
    if (a.bytes.isEmpty) return 'Arquivo vazio.';
    if (a.bytes.length > limiteArquivoBytes) return 'O arquivo tem mais de 10 MB.';

    final alvo = a.retificaId;
    if (alvo != null) {
      ArquivoClinico? anterior;
      for (final x in _arquivos) {
        if (x.id == alvo) anterior = x;
      }
      if (anterior == null || anterior.exameId != a.exameId) {
        return 'Arquivo a substituir não encontrado.';
      }
      if (_arquivos.any((x) => x.retificaId == alvo)) {
        return 'Este arquivo já foi substituído.';
      }
      if ((a.justificativa ?? '').trim().length < 3) {
        return 'Informe a justificativa da substituição.';
      }
    }

    _arquivos.add(a);
    notifyListeners();
    return null;
  }
}

final examesRepository = ExamesRepository(prontuario: prontuarioRepository);