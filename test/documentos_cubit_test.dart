import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/documentos/data/documentos_repository.dart';
import 'package:ibn/features/documentos/domain/documentos.dart';
import 'package:ibn/features/documentos/presentation/cubit/documentos_cubit.dart';
import 'package:ibn/features/documentos/presentation/cubit/documentos_state.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';

const davi = Usuario(
  id: '3',
  nome: 'Dr. Davi',
  email: 'dentista@clinica.local',
  perfil: Perfil.dentista,
  conselho: 'CRO-PE',
  registroConselho: '12345',
);
// Vinculada ao paciente nos testes, mas sem registro de conselho cadastrado.
const lucia = Usuario(id: '10', nome: 'Dra. Lúcia', email: 'dentista2@clinica.local', perfil: Perfil.dentista);
const recepcao = Usuario(id: '2', nome: 'Rita', email: 'recepcao@clinica.local', perfil: Perfil.recepcionista);

Paciente maria({Set<String> vinculos = const {'3', '10'}}) => Paciente(
      id: 'p1',
      nome: 'Maria das Dores',
      cpf: '52998224725',
      dataNascimento: DateTime(1985, 3, 12),
      telefone: '81987654321',
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 9, 2), versao: versaoTermoLgpd),
      profissionaisVinculados: vinculos,
    );

class _RepoQuebrado extends DocumentosRepository {
  _RepoQuebrado(ProntuarioRepository pr) : super(prontuario: pr);

  @override
  List<DocumentoClinico> documentosDoPaciente(String pacienteId, {String? profissionalId}) =>
      throw StateError('falhou');
}

void main() {
  late ProntuarioRepository pr;
  late DocumentosRepository repo;
  const espera = Duration(milliseconds: 10);

  setUp(() {
    pr = ProntuarioRepository();
    repo = DocumentosRepository(prontuario: pr);
  });

  DocumentosCubit cubit(Usuario u, {Paciente? paciente}) => DocumentosCubit(
      repositorio: repo, prontuario: pr, usuario: u, paciente: paciente ?? maria());

  void iniciarAtendimento(String prof) {
    expect(
      pr.iniciarAtendimento(Atendimento(
          id: 'a-$prof', pacienteId: 'p1', profissionalId: prof, inicio: DateTime.now())),
      isNull,
    );
  }

  ModeloDocumento atestado() => repo.modeloPorId('atestado')!;

  test('começa em Initial', () async {
    final c = cubit(davi);
    expect(c.state, isA<DocumentosInitial>());
    await c.close();
  });

  group('carregar', () {
    blocTest<DocumentosCubit, DocumentosState>(
      'emite Loading e depois Success com os modelos',
      build: () => cubit(davi),
      act: (c) => c.carregar(),
      expect: () => [
        isA<DocumentosLoading>(),
        isA<DocumentosSuccess>()
            .having((s) => s.documentos, 'documentos', isEmpty)
            .having((s) => s.modelos.length, 'modelos', modelosPadrao.length),
      ],
    );

    blocTest<DocumentosCubit, DocumentosState>(
      'falha ao listar emite Error',
      build: () => DocumentosCubit(
          repositorio: _RepoQuebrado(pr), prontuario: pr, usuario: davi, paciente: maria()),
      act: (c) => c.carregar(),
      expect: () => [
        isA<DocumentosLoading>(),
        isA<DocumentosError>().having((e) => e.mensagem, 'mensagem', isNotEmpty),
      ],
    );

    blocTest<DocumentosCubit, DocumentosState>(
      'recarrega sozinho quando um documento é criado',
      build: () {
        iniciarAtendimento('3');
        return cubit(davi);
      },
      act: (c) async {
        await c.carregar();
        expect(await c.gerar(atestado(), {'dias_afastamento': '2'}), isNull);
      },
      wait: espera,
      expect: () => [
        isA<DocumentosLoading>(),
        isA<DocumentosSuccess>().having((s) => s.documentos, 'documentos', isEmpty),
        isA<DocumentosSuccess>().having((s) => s.documentos.length, 'quantidade', 1),
      ],
    );
  });

  group('gerar', () {
    test('sem atendimento em aberto devolve erro e não grava', () async {
      final c = cubit(davi);
      expect(c.temAtendimentoAberto, isFalse);
      expect(await c.gerar(atestado(), {'dias_afastamento': '2'}), contains('atendimento'));
      expect(repo.documentosDoPaciente('p1'), isEmpty);
      await c.close();
    });

    test('sem vínculo e recepção não têm permissão', () async {
      iniciarAtendimento('10');
      for (final u in [lucia, recepcao]) {
        final c = cubit(u, paciente: maria(vinculos: {'3'}));
        expect(await c.gerar(atestado(), {'dias_afastamento': '2'}), contains('permissão'),
            reason: u.nome);
        await c.close();
      }
    });

    test('variável manual faltando é recusada e nomeada', () async {
      iniciarAtendimento('3');
      final c = cubit(davi);
      final erro = await c.gerar(atestado(), {});
      expect(erro, contains('dias_afastamento'));
      expect(repo.documentosDoPaciente('p1'), isEmpty);
      await c.close();
    });

    test('sem registro de conselho o documento não é emitido', () async {
      iniciarAtendimento('10');
      final c = cubit(lucia);
      expect(await c.gerar(atestado(), {'dias_afastamento': '2'}), contains('registro'));
      await c.close();
    });

    test('preenche automaticamente paciente, data e profissional', () async {
      iniciarAtendimento('3');
      final c = cubit(davi);
      expect(await c.gerar(atestado(), {'dias_afastamento': '2'}), isNull);
      final d = repo.documentosDoPaciente('p1').single;
      expect(d.conteudo, contains('Maria das Dores'));
      expect(d.conteudo, contains('529.982.247-25'));
      expect(d.conteudo, contains('Dr. Davi'));
      expect(d.conteudo, contains('CRO-PE 12345'));
      expect(d.conteudo, contains('2 dia(s)'));
      expect(d.conteudo, isNot(contains(marcadorNaoPreenchido)));
      expect(d.modeloVersao, 1);
      expect(d.assinado, isFalse);
      expect(logsAcesso.todos.any((l) => l.acao == 'emitiu_documento' && l.entidadeId == 'p1'), isTrue);
      await c.close();
    });
  });

  group('fluxo', () {
    test('gerar, editar, assinar e corrigir mantêm o histórico', () async {
      iniciarAtendimento('3');
      final c = cubit(davi);
      await c.gerar(atestado(), {'dias_afastamento': '2'});
      final rascunho = repo.documentosDoPaciente('p1').single;

      expect(await c.atualizarRascunho(rascunho, 'Texto editado'), isNull);
      final editado = repo.documentoPorId(rascunho.id)!;
      expect(await c.assinar(editado), isNull);
      final assinado = repo.documentoPorId(rascunho.id)!;
      expect(assinado.assinado, isTrue);
      expect(await c.atualizarRascunho(assinado, 'Tentativa'), contains('RN05'));
      expect(await c.descartarRascunho(assinado), contains('RN05'));

      expect(await c.retificar(assinado, 'Texto corrigido', ''), contains('justificativa'));
      expect(await c.retificar(assinado, 'Texto corrigido', 'Erro de data'), isNull);
      expect(repo.documentosDoPaciente('p1').length, 2);
      expect(repo.retificados('p1'), {assinado.id});
      expect(logsAcesso.todos.any((l) => l.acao == 'assinou_documento'), isTrue);
      expect(logsAcesso.todos.any((l) => l.acao == 'corrigiu_documento'), isTrue);
      await c.close();
    });

    test('rascunho pode ser descartado', () async {
      iniciarAtendimento('3');
      final c = cubit(davi);
      await c.gerar(atestado(), {'dias_afastamento': '1'});
      expect(await c.descartarRascunho(repo.documentosDoPaciente('p1').single), isNull);
      expect(repo.documentosDoPaciente('p1'), isEmpty);
      await c.close();
    });
  });

  group('modelos', () {
    test('dentista salva nova versão e recepção não edita modelos', () async {
      final base = atestado();
      final novo = ModeloDocumento(id: base.id, nome: base.nome, tipo: base.tipo, corpo: 'Novo {{paciente_nome}}');

      final r = cubit(recepcao);
      expect(r.podeEditarModelos, isFalse);
      expect(await r.salvarModelo(novo), contains('dentistas'));
      await r.close();

      final d = cubit(davi);
      expect(d.podeEditarModelos, isTrue);
      expect(await d.salvarModelo(novo), isNull);
      expect(repo.modeloPorId('atestado')!.versao, 2);
      await d.close();
    });
  });
}