import 'package:flutter/foundation.dart';
import 'odontograma.dart';

/// Guarda os registros do odontograma em memória (PROVISÓRIO).
class OdontogramaRepository extends ChangeNotifier {
  final List<RegistroDente> _registros = [];
  int _contador = 0;

  OdontogramaRepository({bool comExemplos = true}) {
    if (comExemplos) _registros.addAll(_exemplos());
  }

  String novoId() {
    _contador++;
    return 'o${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  /// Estado atual de cada dente/face: vale o ÚLTIMO registro de cada chave.
  Map<String, RegistroDente> estadoAtual(String pacienteId) {
    final mapa = <String, RegistroDente>{};
    for (final r in _registros) {
      if (r.pacienteId == pacienteId) {
        mapa[RegistroDente.chave(r.numeroDente, r.face)] = r;
      }
    }
    return mapa;
  }

  /// Histórico completo, do mais recente para o mais antigo.
  List<RegistroDente> historicoDoPaciente(String pacienteId) =>
      _registros.where((r) => r.pacienteId == pacienteId).toList().reversed.toList();

  /// Só existe "adicionar": não há editar nem excluir (rastreabilidade, RN05).
  void adicionar(RegistroDente registro) {
    _registros.add(registro);
    notifyListeners();
  }

  List<RegistroDente> _exemplos() {
    // Registros de exemplo da Maria (p1), atendida pelo Dr. Davi (id 3).
    RegistroDente ex(String id, int dente, FaceDente? face, SituacaoDente s,
            {String? proc, String obs = '', required DateTime data}) =>
        RegistroDente(
          id: id,
          pacienteId: 'p1',
          numeroDente: dente,
          face: face,
          situacao: s,
          procedimentoId: proc,
          observacao: obs,
          data: data,
          profissionalId: '3',
        );
    return [
      ex('o1', 16, FaceDente.oclusal, SituacaoDente.existente,
          proc: 'restauracao', obs: 'Restauração antiga em resina', data: DateTime(2026, 9, 2)),
      ex('o2', 36, null, SituacaoDente.ausente, obs: 'Extraído há anos', data: DateTime(2026, 9, 2)),
      ex('o3', 26, FaceDente.oclusal, SituacaoDente.planejado,
          proc: 'restauracao', obs: 'Cárie identificada', data: DateTime(2026, 9, 2)),
      ex('o4', 11, FaceDente.vestibular, SituacaoDente.realizado,
          proc: 'restauracao', data: DateTime(2026, 10, 1)),
    ];
  }
}

final odontogramas = OdontogramaRepository();