import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/odontograma.dart';
import 'package:ibn/core/odontograma_repository.dart';
import 'package:ibn/core/ortodontia.dart';

// ATENÇÃO: troque "ibn" pelo nome do pacote que está no seu pubspec.yaml (campo "name:").

FichaOrtodontica ficha({
  String id = 'f1',
  String queixa = 'Dentes tortos',
  String objetivos = 'Alinhar',
  DateTime? instalacao,
  DateTime? previsao,
}) =>
    FichaOrtodontica(
      id: id,
      pacienteId: 'p1',
      tipoAparelho: TipoAparelhoOrto.fixoMetalico,
      dataInstalacao: instalacao ?? DateTime(2026, 10, 1),
      previsaoTermino: previsao,
      queixaPrincipal: queixa,
      objetivos: objetivos,
      criadoEm: DateTime(2026, 10, 1),
      atualizadoEm: DateTime(2026, 10, 1),
      profissionalId: '3',
    );

ManutencaoOrtodontica manut(
  String id, {
  DateTime? data,
  String ativacao = 'Troca de arco',
  DateTime? proxima,
  String? retifica,
  String? justificativa,
}) =>
    ManutencaoOrtodontica(
      id: id,
      pacienteId: 'p1',
      data: data ?? DateTime(2026, 10, 10),
      ativacaoRealizada: ativacao,
      proximaManutencao: proxima,
      profissionalId: '3',
      retificaId: retifica,
      justificativa: justificativa,
    );

void main() {
  group('Ficha', () {
    test('salva e carrega a versão atual', () {
      final repo = OrtodontiaRepository();
      expect(repo.salvarFicha(ficha()), isNull);
      expect(repo.fichaDoPaciente('p1')!.queixaPrincipal, 'Dentes tortos');
      expect(repo.fichaDoPaciente('p2'), isNull);
    });

    test('recusa queixa e objetivos vazios', () {
      final repo = OrtodontiaRepository();
      expect(repo.salvarFicha(ficha(queixa: ' ')), isNotNull);
      expect(repo.salvarFicha(ficha(objetivos: '')), isNotNull);
      expect(repo.fichaDoPaciente('p1'), isNull);
    });

    test('recusa previsão antes da instalação', () {
      final repo = OrtodontiaRepository();
      final erro = repo.salvarFicha(
          ficha(instalacao: DateTime(2026, 10, 10), previsao: DateTime(2026, 10, 1)));
      expect(erro, isNotNull);
    });

    test('cada salvar cria nova versão e guarda as anteriores', () {
      final repo = OrtodontiaRepository();
      repo.salvarFicha(ficha(objetivos: 'Primeiro'));
      repo.salvarFicha(ficha(objetivos: 'Segundo'));
      expect(repo.fichaDoPaciente('p1')!.objetivos, 'Segundo');
      expect(repo.historicoFicha('p1').length, 2);
    });
  });

  group('Manutenções', () {
    test('lista da mais recente para a mais antiga', () {
      final repo = OrtodontiaRepository();
      repo.adicionarManutencao(manut('m1', data: DateTime(2026, 9, 1)));
      repo.adicionarManutencao(manut('m2', data: DateTime(2026, 10, 1)));
      expect(repo.manutencoesDoPaciente('p1').map((m) => m.id), ['m2', 'm1']);
    });

    test('recusa ativação vazia e próxima antes da data', () {
      final repo = OrtodontiaRepository();
      expect(repo.adicionarManutencao(manut('m1', ativacao: ' ')), isNotNull);
      expect(
        repo.adicionarManutencao(
            manut('m2', data: DateTime(2026, 10, 10), proxima: DateTime(2026, 10, 1))),
        isNotNull,
      );
    });

    test('retificar marca o original como retificado e não apaga nada', () {
      final repo = OrtodontiaRepository();
      repo.adicionarManutencao(manut('m1'));
      final erro = repo.adicionarManutencao(
          manut('m2', ativacao: 'Corrigido', retifica: 'm1', justificativa: 'Erro de digitação'));
      expect(erro, isNull);
      expect(repo.manutencoesDoPaciente('p1').length, 2);
      expect(repo.retificadas('p1'), {'m1'});
    });

    test('retificação exige justificativa e não pode repetir', () {
      final repo = OrtodontiaRepository();
      repo.adicionarManutencao(manut('m1'));
      expect(repo.adicionarManutencao(manut('m2', retifica: 'm1')), isNotNull);
      expect(repo.adicionarManutencao(manut('m3', retifica: 'm1', justificativa: 'Motivo A')), isNull);
      expect(repo.adicionarManutencao(manut('m4', retifica: 'm1', justificativa: 'Motivo B')), isNotNull);
    });

    test('recusa retificar registro inexistente e id duplicado', () {
      final repo = OrtodontiaRepository();
      expect(repo.adicionarManutencao(manut('m1', retifica: 'x', justificativa: 'abc')), isNotNull);
      repo.adicionarManutencao(manut('m2'));
      expect(repo.adicionarManutencao(manut('m2')), isNotNull);
    });
  });

  group('Fotos e notificação', () {
    FotoComparativaOrto foto(String id, DateTime data, {Uint8List? bytes, String desc = 'Inicial'}) =>
        FotoComparativaOrto(
          id: id,
          pacienteId: 'p1',
          data: data,
          descricao: desc,
          nomeArquivo: '$id.jpg',
          bytes: bytes ?? Uint8List.fromList([1, 2, 3]),
          profissionalId: '3',
        );

    test('adiciona e lista da mais antiga para a mais recente', () {
      final repo = OrtodontiaRepository();
      repo.adicionarFoto(foto('b', DateTime(2026, 10, 5)));
      repo.adicionarFoto(foto('a', DateTime(2026, 10, 1)));
      expect(repo.fotosDoPaciente('p1').map((f) => f.id), ['a', 'b']);
    });

    test('recusa foto sem descrição ou sem bytes', () {
      final repo = OrtodontiaRepository();
      expect(repo.adicionarFoto(foto('a', DateTime(2026, 10, 1), desc: ' ')), isNotNull);
      expect(repo.adicionarFoto(foto('b', DateTime(2026, 10, 1), bytes: Uint8List(0))), isNotNull);
    });

    test('notifica os ouvintes ao salvar', () {
      final repo = OrtodontiaRepository();
      var chamadas = 0;
      repo.addListener(() => chamadas++);
      repo.salvarFicha(ficha());
      repo.adicionarManutencao(manut('m1'));
      expect(chamadas, 2);
    });
  });

  group('Marcas de arcada (Fase E)', () {
    MarcaArcada marca(String id, {String? retifica}) => MarcaArcada(
          id: id,
          pacienteId: 'p1',
          arcada: ArcadaOdonto.superior,
          tipo: TipoMarcaArcada.aparelhoFixo,
          data: DateTime(2026, 10, 1),
          profissionalId: '3',
          retificaId: retifica,
        );

    test('marcar, desmarcar e marcar de novo', () {
      final repo = OdontogramaRepository(comExemplos: false);
      repo.adicionarMarcaArcada(marca('a'));
      expect(repo.marcasArcadaAtivas('p1')[ArcadaOdonto.superior], [TipoMarcaArcada.aparelhoFixo]);

      repo.adicionarMarcaArcada(marca('b', retifica: 'a')); // desmarcou
      expect(repo.marcasArcadaAtivas('p1')[ArcadaOdonto.superior], isEmpty);

      repo.adicionarMarcaArcada(marca('c')); // marcou de novo
      expect(repo.marcasArcadaAtivas('p1')[ArcadaOdonto.superior], [TipoMarcaArcada.aparelhoFixo]);
    });
  });
}