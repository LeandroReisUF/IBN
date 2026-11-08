import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/historico_clinico.dart';
import 'package:ibn/features/anamnese/data/anamnese_repository.dart';
import 'package:ibn/features/anamnese/domain/anamnese.dart';
import 'package:ibn/features/odontograma/data/odontograma_repository.dart';
import 'package:ibn/features/odontograma/domain/condicao_odonto.dart';
import 'package:ibn/features/odontograma/domain/odontograma.dart';
import 'package:ibn/features/ortodontia/domain/ortodontia.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/plano_tratamento/data/plano_repository.dart';
import 'package:ibn/features/plano_tratamento/domain/plano_tratamento.dart';

/// Paciente SEM profissionais vinculados: o único jeito de ter histórico é por
/// registros nos módulos (é o caso que antes escapava da trava).
Paciente semVinculo(String id) => Paciente(
      id: id,
      nome: 'Paciente $id',
      cpf: '52998224725',
      dataNascimento: DateTime(1990, 1, 1),
      telefone: '81999990000',
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 9, 1), versao: versaoTermoLgpd),
    );

void main() {
  late PacienteRepository repo;

  setUp(() {
    repo = PacienteRepository();
    registrarFontesDeHistorico(repo);
  });

  test('sem nenhum registro, o paciente não tem histórico', () {
    expect(repo.temHistorico(semVinculo('h-vazio')), isFalse);
  });

  test('anamnese (mesmo rascunho) conta como histórico', () {
    final p = semVinculo('h-anamnese');
    expect(repo.temHistorico(p), isFalse);
    final m = modelosAnamnesePadrao.first;
    expect(
      anamneseRepository.adicionarAnamnese(Anamnese(
        id: 'h-an1',
        pacienteId: p.id,
        profissionalId: '3',
        modeloId: m.id,
        titulo: m.nome,
        modeloVersao: m.versao,
        perguntas: m.perguntas,
        respostas: const {},
        criadaEm: DateTime(2030, 1, 7),
      )),
      isNull,
    );
    expect(repo.temHistorico(p), isTrue);
  });

  test('plano de tratamento conta como histórico', () {
    final p = semVinculo('h-plano');
    expect(repo.temHistorico(p), isFalse);
    expect(
      planoRepository.criarPlano(PlanoTratamento(
        id: 'h-pl1',
        pacienteId: p.id,
        criadorId: '3',
        titulo: 'Plano',
        criadoEm: DateTime(2030, 1, 7),
      )),
      isNull,
    );
    expect(repo.temHistorico(p), isTrue);
  });

  test('odontograma conta como histórico', () {
    final p = semVinculo('h-odonto');
    expect(repo.temHistorico(p), isFalse);
    expect(
      odontogramas.adicionar(RegistroDente(
        id: 'h-o1',
        pacienteId: p.id,
        numeroDente: 16,
        alvo: AlvoOdonto.dente,
        condicao: CondicaoOdonto.coroa,
        data: DateTime(2030, 1, 7),
        profissionalId: '3',
      )),
      isNull,
    );
    expect(repo.temHistorico(p), isTrue);
  });

  test('ortodontia conta como histórico', () {
    final p = semVinculo('h-orto');
    expect(repo.temHistorico(p), isFalse);
    expect(
      ortodontiaRepository.salvarFicha(FichaOrtodontica(
        id: 'h-f1',
        pacienteId: p.id,
        tipoAparelho: TipoAparelhoOrto.fixoMetalico,
        dataInstalacao: DateTime(2030, 1, 7),
        queixaPrincipal: 'Dentes tortos',
        objetivos: 'Alinhar',
        criadoEm: DateTime(2030, 1, 7),
        atualizadoEm: DateTime(2030, 1, 7),
        profissionalId: '3',
      )),
      isNull,
    );
    expect(repo.temHistorico(p), isTrue);
  });

  test('o Administrador não exclui paciente com histórico, mas exclui o cadastro vazio', () {
    final vazio = semVinculo('h-excluir-vazio');
    repo.salvar(vazio);
    expect(repo.excluirSemHistorico(vazio.id), isTrue);
    expect(repo.buscarPorId(vazio.id), isNull);

    final comDados = semVinculo('h-excluir-dados');
    repo.salvar(comDados);
    planoRepository.criarPlano(PlanoTratamento(
      id: 'h-pl2',
      pacienteId: comDados.id,
      criadorId: '3',
      titulo: 'Plano',
      criadoEm: DateTime(2030, 1, 7),
    ));
    expect(repo.excluirSemHistorico(comDados.id), isFalse);
    expect(repo.buscarPorId(comDados.id), isNotNull);
  });
}