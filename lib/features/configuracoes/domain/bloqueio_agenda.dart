/// Período em que uma sala não aceita agendamentos (manutenção, reforma etc.).
class BloqueioAgenda {
  final String id;
  final int salaNumero;
  final DateTime inicio;
  final DateTime fim;
  final String motivo;

  const BloqueioAgenda({
    required this.id,
    required this.salaNumero,
    required this.inicio,
    required this.fim,
    required this.motivo,
  });
}