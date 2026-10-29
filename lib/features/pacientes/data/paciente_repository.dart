import 'package:flutter/foundation.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

/// Guarda os pacientes em memória (PROVISÓRIO).
/// Quando criarmos a API, esta classe passará a conversar com o servidor.
class PacienteRepository extends ChangeNotifier {
  final List<Paciente> _lista = [
    Paciente(
      id: 'p1',
      nome: 'Maria das Dores Silva',
      cpf: '52998224725',
      dataNascimento: DateTime(1985, 3, 12),
      telefone: '81987654321',
      whatsapp: '81987654321',
      email: 'maria@email.com',
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 9, 2), versao: versaoTermoLgpd),
      profissionaisVinculados: {'3', '8'}, // dentista, nutricionista
    ),
    Paciente(
      id: 'p2',
      nome: 'João Pedro Santos',
      cpf: '11144477735',
      dataNascimento: DateTime(2014, 6, 20),
      telefone: '81988887777',
      responsavel: const ResponsavelLegal(
        nome: 'Carla Santos',
        cpf: '39053344705',
        parentesco: 'Mãe',
        telefone: '81988887777',
      ),
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 9, 10), versao: versaoTermoLgpd),
      profissionaisVinculados: {'5', '3'}, // médico, dentista
    ),
    Paciente(
      id: 'p3',
      nome: 'Ana Beatriz Lima',
      cpf: '12345678909',
      dataNascimento: DateTime(1992, 11, 2),
      telefone: '81991112222',
      whatsapp: '81991112222',
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 8, 15), versao: versaoTermoLgpd),
      profissionaisVinculados: {'4', '9'}, // biomédica, psicólogo
    ),
    Paciente(
      id: 'p4',
      nome: 'Carlos Eduardo Pereira',
      cpf: '16899535009',
      dataNascimento: DateTime(1970, 1, 30),
      telefone: '8133334444',
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 7, 21), versao: versaoTermoLgpd),
      optOutMarketing: true,
      profissionaisVinculados: {'3', '7'}, // dentista, fisioterapeuta
    ),
  ];

  List<Paciente> get todos => List.unmodifiable(_lista);

  bool cpfJaCadastrado(String cpfDigitos, {String? ignorarId}) =>
      _lista.any((p) => p.cpf == cpfDigitos && p.id != ignorarId);

  String novoId() => DateTime.now().microsecondsSinceEpoch.toString();

  Paciente? buscarPorId(String id) {
    for (final p in _lista) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Tem histórico = tem profissional vinculado OU algum atendimento registrado.
  /// (Quando existirem lançamentos financeiros e exames, entram aqui também.)
  bool temHistorico(Paciente paciente) =>
      paciente.profissionaisVinculados.isNotEmpty ||
      prontuarioRepository.temHistorico(paciente.id);
  /// Inativar / reativar: o cadastro e o histórico continuam guardados.
  void definirAtivo(String id, bool ativo) {
    final i = _lista.indexWhere((p) => p.id == id);
    if (i < 0) return;
    _lista[i] = _lista[i].copiarCom(ativo: ativo);
    notifyListeners();
  }

  /// Exclusão definitiva: só para cadastro feito por engano, sem histórico.
  /// Retorna false (e não apaga nada) se houver histórico.
  bool excluirSemHistorico(String id) {
    final i = _lista.indexWhere((p) => p.id == id);
    if (i < 0) return false;
    if (temHistorico(_lista[i])) return false;
    _lista.removeAt(i);
    notifyListeners();
    return true;
  }

  void salvar(Paciente paciente) {
    final i = _lista.indexWhere((p) => p.id == paciente.id);
    if (i >= 0) {
      _lista[i] = paciente;
    } else {
      _lista.add(paciente);
    }
    notifyListeners();
  }
}

final pacientes = PacienteRepository();