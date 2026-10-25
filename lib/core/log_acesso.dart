/// Registro de acesso a dados sensíveis (RNF03 - LGPD).
class LogAcesso {
  final DateTime dataHora;
  final String usuarioId;
  final String acao; // ex.: abriu_prontuario, registrou_odontograma
  final String entidade; // ex.: paciente
  final String entidadeId;

  const LogAcesso({
    required this.dataHora,
    required this.usuarioId,
    required this.acao,
    required this.entidade,
    required this.entidadeId,
  });
}

/// PROVISÓRIO: guarda em memória. No servidor, o log será gravado no banco
/// (com IP e dispositivo) e não poderá ser alterado nem apagado.
class LogAcessoService {
  final List<LogAcesso> _logs = [];

  List<LogAcesso> get todos => List.unmodifiable(_logs);

  void registrar({
    required String usuarioId,
    required String acao,
    required String entidade,
    required String entidadeId,
  }) {
    _logs.add(LogAcesso(
      dataHora: DateTime.now(),
      usuarioId: usuarioId,
      acao: acao,
      entidade: entidade,
      entidadeId: entidadeId,
    ));
  }
}

final logsAcesso = LogAcessoService();