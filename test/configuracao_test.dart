import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/especialidade.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/agenda/domain/agendamento.dart';
import 'package:ibn/features/agenda/domain/sala.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/configuracoes/data/configuracao_repository.dart';
import 'package:ibn/features/configuracoes/domain/bloqueio_agenda.dart';
import 'package:ibn/features/configuracoes/presentation/cubit/configuracoes_cubit.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/configuracoes/domain/paleta_cores.dart';

const admin = Usuario(id: '1', nome: 'Ana', email: 'a@x', perfil: Perfil.administrador);
const recepcao = Usuario(id: '2', nome: 'Rita', email: 'r@x', perfil: Perfil.recepcionista);

Sala nova({int numero = 5, String nome = 'Sala 5', Set<Especialidade>? areas}) => Sala(
      numero: numero,
      nome: nome,
      exclusiva: false,
      especialidadesPermitidas: areas ?? {Especialidade.nutricao},
    );

BloqueioAgenda bloq({String id = 'b1', int sala = 3, int hIni = 9, int hFim = 12, String motivo = 'Manutenção'}) =>
    BloqueioAgenda(
      id: id,
      salaNumero: sala,
      inicio: DateTime(2030, 1, 7, hIni),
      fim: DateTime(2030, 1, 7, hFim),
      motivo: motivo,
    );

Agendamento ag(int hora, {int sala = 3}) {
  final ini = DateTime(2030, 1, 7, hora);
  return Agendamento(
    id: 'a$hora$sala',
    pacienteId: 'p1',
    profissionalId: '3',
    salaNumero: sala,
    procedimentoId: 'consulta-odontologica',
    inicio: ini,
    fim: ini.add(const Duration(minutes: 30)),
  );
}

void main() {
  group('Salas', () {
    test('começa com as 4 salas padrão', () {
      expect(ConfiguracaoRepository().todasAsSalas.length, 4);
    });

    test('cria sala com o próximo número', () {
      final r = ConfiguracaoRepository();
      expect(r.proximoNumeroSala, 5);
      expect(r.salvarSala(nova()), isNull);
      expect(r.todasAsSalas.length, 5);
      expect(r.salaPorNumero(5)!.nome, 'Sala 5');
    });

    test('recusa nome vazio, nome repetido e sala sem área', () {
      final r = ConfiguracaoRepository();
      expect(r.salvarSala(nova(nome: ' ')), contains('nome'));
      expect(r.salvarSala(nova(nome: 'sala 1')), contains('Já existe'));
      expect(r.salvarSala(nova(areas: {})), contains('área'));
      expect(r.todasAsSalas.length, 4);
    });

    test('editar a própria sala mantendo o nome é permitido', () {
      final r = ConfiguracaoRepository();
      final s1 = r.salaPorNumero(1)!;
      expect(r.salvarSala(s1.copiarCom(exclusiva: true)), isNull);
      expect(r.salaPorNumero(1)!.exclusiva, isTrue);
    });

    test('excluir: em uso é recusado; livre remove a sala e os bloqueios dela', () {
      final r = ConfiguracaoRepository();
      r.salvarSala(nova());
      r.salvarBloqueio(bloq(sala: 5));
      expect(r.excluirSala(5, emUso: true), contains('Desative'));
      expect(r.excluirSala(5, emUso: false), isNull);
      expect(r.salaPorNumero(5), isNull);
      expect(r.bloqueios, isEmpty);
      expect(r.excluirSala(5, emUso: false), contains('não encontrada'));
    });

    test('desativar tira das ativas, mas a sala continua encontrável', () {
      final r = ConfiguracaoRepository();
      expect(r.definirSalaAtiva(3, false), isNull);
      expect(r.salasAtivas.length, 3);
      expect(r.salaPorNumero(3)!.ativa, isFalse);
    });
  });

  group('Bloqueios', () {
    test('valida sala, período e motivo', () {
      final r = ConfiguracaoRepository();
      expect(r.salvarBloqueio(bloq(sala: 99)), contains('Sala não encontrada'));
      expect(r.salvarBloqueio(bloq(hIni: 12, hFim: 9)), contains('fim'));
      expect(r.salvarBloqueio(bloq(motivo: 'ab')), contains('motivo'));
      expect(r.bloqueios, isEmpty);
    });

    test('bloqueioNoPeriodo: sobrepor conta, só encostar não', () {
      final r = ConfiguracaoRepository();
      r.salvarBloqueio(bloq()); // 09:00-12:00 na Sala 3
      DateTime h(int hora, [int min = 0]) => DateTime(2030, 1, 7, hora, min);
      expect(r.bloqueioNoPeriodo(3, h(11), h(11, 30)), isNotNull);
      expect(r.bloqueioNoPeriodo(3, h(8, 30), h(9)), isNull);
      expect(r.bloqueioNoPeriodo(3, h(12), h(12, 30)), isNull);
      expect(r.bloqueioNoPeriodo(4, h(10), h(11)), isNull);
    });

    test('desbloquear exclui; id inexistente devolve erro', () {
      final r = ConfiguracaoRepository();
      r.salvarBloqueio(bloq());
      expect(r.excluirBloqueio('b1'), isNull);
      expect(r.excluirBloqueio('b1'), contains('não encontrado'));
    });
  });

  group('Agenda', () {
    test('sala bloqueada recusa; fora do bloqueio vale', () {
      final cfg = ConfiguracaoRepository()..salvarBloqueio(bloq());
      final svc = AgendaService(comExemplos: false, configuracao: cfg);
      expect(svc.criar(ag(10)), contains('bloqueada'));
      expect(svc.criar(ag(13)), isNull);
    });

    test('sala desativada não recebe agendamento', () {
      final cfg = ConfiguracaoRepository()..definirSalaAtiva(3, false);
      final svc = AgendaService(comExemplos: false, configuracao: cfg);
      expect(svc.criar(ag(10)), contains('desativada'));
    });

    test('sala nova valida a área (RN01)', () {
      final cfg = ConfiguracaoRepository()..salvarSala(nova(areas: {Especialidade.nutricao}));
      final svc = AgendaService(comExemplos: false, configuracao: cfg);
      expect(svc.criar(ag(10, sala: 5)), contains('RN01'));
    });
  });

  group('Cubit', () {
    test('Administrador salva sala; Recepção não tem permissão', () async {
      final cfg = ConfiguracaoRepository();
      final svc = AgendaService(comExemplos: false, configuracao: cfg);
      final a = ConfiguracoesCubit(repositorio: cfg, agendaService: svc, usuario: admin);
      expect(await a.salvarSala(nova(numero: a.proximoNumeroSala)), isNull);
      expect(cfg.todasAsSalas.length, 5);
      await a.close();

      final r = ConfiguracoesCubit(repositorio: cfg, agendaService: svc, usuario: recepcao);
      expect(await r.salvarSala(nova(numero: 6, nome: 'Sala 6')), contains('Administrador'));
      expect(await r.salvarBloqueio(bloq()), contains('Administrador'));
      expect(cfg.todasAsSalas.length, 5);
      await r.close();
    });

    test('sala com agendamento não exclui, mas desativa; bloqueio avisa os afetados', () async {
      final cfg = ConfiguracaoRepository();
      final svc = AgendaService(comExemplos: false, configuracao: cfg);
      svc.criar(ag(10));
      final c = ConfiguracoesCubit(repositorio: cfg, agendaService: svc, usuario: admin);
      expect(await c.excluirSala(3), contains('Desative'));
      expect(c.agendamentosAfetados(bloq()), 1);
      expect(c.agendamentosAfetados(bloq(hIni: 14, hFim: 16)), 0);
      expect(await c.definirSalaAtiva(3, false), isNull);
      expect(cfg.salaPorNumero(3)!.ativa, isFalse);
      await c.close();
    });
  });
    group('Procedimentos', () {
    Procedimento proc({String id = 'x1', String nome = 'Avaliação', int dur = 30, Set<Especialidade>? areas}) =>
        Procedimento(
          id: id,
          nome: nome,
          especialidades: areas ?? {Especialidade.odontologia, Especialidade.biomedicina},
          duracaoMinutos: dur,
        );

    test('cria procedimento com duas áreas', () {
      final r = ConfiguracaoRepository();
      expect(r.salvarProcedimento(proc()), isNull);
      final p = r.procedimentoPorId('x1')!;
      expect(p.especialidades.length, 2);
      expect(p.aceitaAlgumaDe({Especialidade.biomedicina}), isTrue);
      expect(p.aceitaAlgumaDe({Especialidade.medicina}), isFalse);
    });

    test('valida nome, áreas, duração e nome repetido', () {
      final r = ConfiguracaoRepository();
      expect(r.salvarProcedimento(proc(nome: ' ')), contains('nome'));
      expect(r.salvarProcedimento(proc(areas: {})), contains('área'));
      expect(r.salvarProcedimento(proc(dur: 4)), contains('duração'));
      expect(r.salvarProcedimento(proc(dur: 481)), contains('duração'));
      expect(r.salvarProcedimento(proc(nome: 'consulta médica')), contains('Já existe'));
    });

    test('desativar tira dos ativos, mas o procedimento continua encontrável', () {
      final r = ConfiguracaoRepository()..salvarProcedimento(proc());
      final ativos = r.procedimentosAtivos.length;
      expect(r.definirProcedimentoAtivo('x1', false), isNull);
      expect(r.procedimentosAtivos.length, ativos - 1);
      expect(r.procedimentoPorId('x1')!.ativo, isFalse);
    });

    test('excluir: em uso recusa; livre remove; do sistema é protegido', () {
      final r = ConfiguracaoRepository()..salvarProcedimento(proc());
      expect(r.excluirProcedimento('x1', emUso: true), contains('Desative'));
      expect(r.excluirProcedimento('x1', emUso: false), isNull);
      expect(r.procedimentoPorId('x1'), isNull);
      expect(r.excluirProcedimento('manutencao-ortodontica', emUso: false), contains('sistema'));
      expect(r.definirProcedimentoAtivo('manutencao-ortodontica', false), contains('sistema'));
    });

    test('agenda: procedimento de duas áreas vale nas salas das duas; desativado é recusado', () {
      final cfg = ConfiguracaoRepository()..salvarProcedimento(proc());
      final svc = AgendaService(comExemplos: false, configuracao: cfg);
      Agendamento ag2(String prof, int sala, int hora) {
        final ini = DateTime(2030, 1, 7, hora);
        return Agendamento(
          id: 'g$prof$sala$hora',
          pacienteId: 'p1',
          profissionalId: prof,
          salaNumero: sala,
          procedimentoId: 'x1',
          inicio: ini,
          fim: ini.add(const Duration(minutes: 30)),
        );
      }

      expect(svc.criar(ag2('3', 3, 9)), isNull); // dentista, Sala 3
      expect(svc.criar(ag2('4', 4, 9)), isNull); // biomédica, Sala 4
      expect(svc.criar(ag2('3', 1, 11)), contains('RN01')); // Sala 1 não atende as duas áreas
      expect(svc.criar(ag2('5', 3, 13)), contains('não realiza')); // médica não faz
      cfg.definirProcedimentoAtivo('x1', false);
      expect(svc.criar(ag2('3', 3, 15)), contains('desativado'));
    });

    test('Cubit: procedimento usado na agenda não exclui; um novo sem uso exclui', () async {
      final cfg = ConfiguracaoRepository();
      final svc = AgendaService(comExemplos: false, configuracao: cfg);
      svc.criar(ag(10)); // usa consulta-odontologica
      final c = ConfiguracoesCubit(repositorio: cfg, agendaService: svc, usuario: admin);
      expect(await c.excluirProcedimento('consulta-odontologica'), contains('Desative'));
      expect(await c.salvarProcedimento(proc(id: c.novoId(), nome: 'Teste')), isNull);
      final novo = cfg.todosProcedimentos.last;
      expect(await c.excluirProcedimento(novo.id), isNull);
      await c.close();

      final r = ConfiguracoesCubit(repositorio: cfg, agendaService: svc, usuario: recepcao);
      expect(await r.salvarProcedimento(proc(id: 'z', nome: 'Z')), contains('Administrador'));
      await r.close();
    });
  });
    group('Cores', () {
    test('cada tipo de saúde começa com cor própria e diferente', () {
      final r = ConfiguracaoRepository();
      final cores = r.coresPerfil.values.toList();
      expect(r.coresPerfil.length, 7);
      expect(cores.toSet().length, cores.length);
      expect(r.corDoPerfil(Perfil.recepcionista), ConfiguracaoRepository.corNeutra);
    });

    test('troca a cor; recusa repetida, fora da paleta e tipo sem prontuário', () {
      final r = ConfiguracaoRepository();
      final livre = paletaCoresTag.firstWhere((c) => !r.coresPerfil.values.contains(c));
      expect(r.definirCorPerfil(Perfil.dentista, livre), isNull);
      expect(r.corDoPerfil(Perfil.dentista), livre);
      expect(r.definirCorPerfil(Perfil.medico, livre), contains('já é usada'));
      expect(r.definirCorPerfil(Perfil.medico, 0xFF000000), contains('paleta'));
      expect(r.definirCorPerfil(Perfil.recepcionista, livre), contains('saúde'));
    });

    test('restaurar volta às cores padrão', () {
      final r = ConfiguracaoRepository();
      final original = r.corDoPerfil(Perfil.dentista);
      final livre = paletaCoresTag.firstWhere((c) => !r.coresPerfil.values.contains(c));
      r.definirCorPerfil(Perfil.dentista, livre);
      r.restaurarCoresPadrao();
      expect(r.corDoPerfil(Perfil.dentista), original);
    });

    test('Cubit: só o Administrador muda cor', () async {
      final cfg = ConfiguracaoRepository();
      final svc = AgendaService(comExemplos: false, configuracao: cfg);
      final livre = paletaCoresTag.firstWhere((c) => !cfg.coresPerfil.values.contains(c));

      final a = ConfiguracoesCubit(repositorio: cfg, agendaService: svc, usuario: admin);
      expect(await a.definirCorPerfil(Perfil.dentista, livre), isNull);
      await a.close();

      final r = ConfiguracoesCubit(repositorio: cfg, agendaService: svc, usuario: recepcao);
      expect(await r.definirCorPerfil(Perfil.medico, livre), contains('Administrador'));
      expect(await r.restaurarCores(), contains('Administrador'));
      await r.close();
    });
  });
}