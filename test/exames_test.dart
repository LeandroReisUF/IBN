import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/features/exames/data/exames_repository.dart';
import 'package:ibn/features/exames/domain/exames.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';

final _dia = DateTime(2030, 1, 7, 9);

Exame exame({
  String id = 'e1',
  String nome = 'Radiografia panorâmica',
  String atendimento = 'a1',
  String prof = '3',
  String paciente = 'p1',
  StatusExame status = StatusExame.solicitado,
}) =>
    Exame(
      id: id,
      pacienteId: paciente,
      atendimentoId: atendimento,
      profissionalId: prof,
      tipo: TipoExame.imagem,
      nome: nome,
      status: status,
      solicitadoEm: _dia,
      atualizadoEm: _dia,
    );

ArquivoClinico arquivo({
  String id = 'f1',
  String exameId = 'e1',
  String nome = 'pan.jpg',
  String? mime,
  String prof = '3',
  Uint8List? bytes,
  String? retifica,
  String? justificativa,
}) =>
    ArquivoClinico(
      id: id,
      exameId: exameId,
      pacienteId: 'p1',
      nomeArquivo: nome,
      mimeType: mime ?? mimeDoArquivo(nome) ?? 'x/x',
      bytes: bytes ?? Uint8List.fromList([1, 2, 3]),
      enviadoEm: _dia,
      profissionalId: prof,
      retificaId: retifica,
      justificativa: justificativa,
    );

({ExamesRepository ex, ProntuarioRepository pr}) montar() {
  final pr = ProntuarioRepository();
  expect(
    pr.iniciarAtendimento(Atendimento(
        id: 'a1', pacienteId: 'p1', profissionalId: '3', inicio: DateTime(2030, 1, 7, 8))),
    isNull,
  );
  return (ex: ExamesRepository(prontuario: pr), pr: pr);
}

void main() {
  group('Solicitação', () {
    test('solicita dentro de um atendimento em aberto', () {
      final c = montar();
      expect(c.ex.solicitarExame(exame()), isNull);
      expect(c.ex.examesDoPaciente('p1').single.status, StatusExame.solicitado);
      expect(c.ex.temHistorico('p1'), isTrue);
      expect(c.ex.temHistorico('p2'), isFalse);
    });

    test('recusa nome vazio, status que não é inicial, duplicado e atendimento inválido', () {
      final c = montar();
      expect(c.ex.solicitarExame(exame(nome: ' ')), contains('nome'));
      expect(c.ex.solicitarExame(exame(status: StatusExame.realizado)), contains('Solicitado'));
      expect(c.ex.solicitarExame(exame(atendimento: 'zzz')), contains('não encontrado'));
      expect(c.ex.solicitarExame(exame(prof: '10')), contains('profissional do atendimento'));
      expect(c.ex.solicitarExame(exame(paciente: 'p2')), contains('Paciente diferente'));
      expect(c.ex.solicitarExame(exame()), isNull);
      expect(c.ex.solicitarExame(exame()), contains('duplicado'));
    });

    test('recusa atendimento encerrado', () {
      final c = montar();
      c.pr.encerrarAtendimento('a1', '3');
      expect(c.ex.solicitarExame(exame()), contains('encerrado'));
    });
  });

  group('Status', () {
    test('avança solicitado → realizado → resultado disponível', () {
      final c = montar();
      c.ex.solicitarExame(exame());
      expect(c.ex.mudarStatus('e1', '3', StatusExame.realizado), isNull);
      expect(c.ex.mudarStatus('e1', '3', StatusExame.resultadoDisponivel), isNull);
      expect(c.ex.examePorId('e1')!.status, StatusExame.resultadoDisponivel);
    });

    test('não pula etapa, não volta e não sai de estado final', () {
      final c = montar();
      c.ex.solicitarExame(exame());
      expect(c.ex.mudarStatus('e1', '3', StatusExame.resultadoDisponivel), contains('Não é possível'));
      c.ex.mudarStatus('e1', '3', StatusExame.realizado);
      expect(c.ex.mudarStatus('e1', '3', StatusExame.solicitado), contains('Não é possível'));
      c.ex.mudarStatus('e1', '3', StatusExame.cancelado);
      expect(c.ex.mudarStatus('e1', '3', StatusExame.realizado), contains('Não é possível'));
    });

    test('só quem solicitou muda o status; exame inexistente devolve erro', () {
      final c = montar();
      c.ex.solicitarExame(exame());
      expect(c.ex.mudarStatus('e1', '10', StatusExame.realizado), contains('Só quem solicitou'));
      expect(c.ex.mudarStatus('zzz', '3', StatusExame.realizado), contains('não encontrado'));
    });

    test('exame com arquivo não pode ser cancelado', () {
      final c = montar();
      c.ex.solicitarExame(exame());
      c.ex.adicionarArquivo(arquivo());
      expect(c.ex.mudarStatus('e1', '3', StatusExame.cancelado), contains('arquivos'));
    });
  });

  group('Arquivos (RN05)', () {
    test('mimeDoArquivo aceita só JPG, PNG e PDF', () {
      expect(mimeDoArquivo('a.JPG'), 'image/jpeg');
      expect(mimeDoArquivo('a.jpeg'), 'image/jpeg');
      expect(mimeDoArquivo('a.png'), 'image/png');
      expect(mimeDoArquivo('laudo.pdf'), 'application/pdf');
      expect(mimeDoArquivo('a.exe'), isNull);
      expect(mimeDoArquivo('semextensao'), isNull);
      expect(mimeDoArquivo('termina.'), isNull);
    });

    test('anexa radiografia e PDF', () {
      final c = montar();
      c.ex.solicitarExame(exame());
      expect(c.ex.adicionarArquivo(arquivo()), isNull);
      expect(c.ex.adicionarArquivo(arquivo(id: 'f2', nome: 'laudo.pdf')), isNull);
      expect(c.ex.arquivosDoExame('e1').map((a) => a.id), ['f1', 'f2']);
      expect(c.ex.arquivosDoExame('e1').last.ehPdf, isTrue);
    });

    test('recusa formato, vazio, acima do limite e tipo MIME que não bate', () {
      final c = montar();
      c.ex.solicitarExame(exame());
      expect(c.ex.adicionarArquivo(arquivo(nome: 'a.exe', mime: 'application/x-msdownload')),
          contains('Formato'));
      expect(c.ex.adicionarArquivo(arquivo(mime: 'application/pdf')), contains('Formato'));
      expect(c.ex.adicionarArquivo(arquivo(bytes: Uint8List(0))), contains('vazio'));
      expect(c.ex.adicionarArquivo(arquivo(bytes: Uint8List(limiteArquivoBytes + 1))),
          contains('10 MB'));
      expect(c.ex.arquivosDoExame('e1'), isEmpty);
    });

    test('só quem solicitou anexa; exame cancelado ou inexistente não recebe', () {
      final c = montar();
      c.ex.solicitarExame(exame());
      expect(c.ex.adicionarArquivo(arquivo(prof: '10')), contains('Só quem solicitou'));
      expect(c.ex.adicionarArquivo(arquivo(exameId: 'zzz')), contains('não encontrado'));
      c.ex.mudarStatus('e1', '3', StatusExame.cancelado);
      expect(c.ex.adicionarArquivo(arquivo()), contains('cancelado'));
    });

    test('o resultado pode chegar depois do atendimento encerrado', () {
      final c = montar();
      c.ex.solicitarExame(exame());
      c.pr.encerrarAtendimento('a1', '3');
      expect(c.ex.adicionarArquivo(arquivo()), isNull);
    });

    test('substituir mantém o original e marca como substituído', () {
      final c = montar();
      c.ex.solicitarExame(exame());
      c.ex.adicionarArquivo(arquivo());
      final erro = c.ex.adicionarArquivo(
          arquivo(id: 'f2', nome: 'pan2.png', retifica: 'f1', justificativa: 'Imagem borrada'));
      expect(erro, isNull);
      expect(c.ex.arquivosDoExame('e1').length, 2);
      expect(c.ex.arquivosRetificados('p1'), {'f1'});
    });

    test('substituição exige justificativa, arquivo existente e só vale uma vez', () {
      final c = montar();
      c.ex.solicitarExame(exame());
      c.ex.adicionarArquivo(arquivo());
      expect(c.ex.adicionarArquivo(arquivo(id: 'f2', retifica: 'f1')), contains('justificativa'));
      expect(c.ex.adicionarArquivo(arquivo(id: 'f2', retifica: 'x', justificativa: 'abc')),
          contains('não encontrado'));
      expect(c.ex.adicionarArquivo(arquivo(id: 'f2', retifica: 'f1', justificativa: 'abc')), isNull);
      expect(c.ex.adicionarArquivo(arquivo(id: 'f3', retifica: 'f1', justificativa: 'abc')),
          contains('já foi substituído'));
    });

    test('avisa os ouvintes só quando grava', () {
      final c = montar();
      var chamadas = 0;
      c.ex.addListener(() => chamadas++);
      c.ex.solicitarExame(exame());
      c.ex.adicionarArquivo(arquivo());
      c.ex.adicionarArquivo(arquivo(nome: 'a.exe')); // erro
      expect(chamadas, 2);
    });
  });

  group('ResultadoLab', () {
    test('foraDoPadrao compara com a referência mínima e máxima', () {
      const dentro = ResultadoLab(analito: 'Hb', valor: 13, unidade: 'g/dL', refMin: 12, refMax: 16);
      const baixo = ResultadoLab(analito: 'Hb', valor: 10, unidade: 'g/dL', refMin: 12, refMax: 16);
      const alto = ResultadoLab(analito: 'Hb', valor: 18, unidade: 'g/dL', refMin: 12, refMax: 16);
      const semRef = ResultadoLab(analito: 'X', valor: 99, unidade: 'u');
      expect(dentro.foraDoPadrao, isFalse);
      expect(baixo.foraDoPadrao, isTrue);
      expect(alto.foraDoPadrao, isTrue);
      expect(semRef.foraDoPadrao, isFalse);
    });
  });
}