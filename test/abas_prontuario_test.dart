import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/configuracoes/data/configuracao_repository.dart';
import 'package:ibn/features/configuracoes/domain/area_dentista.dart';
import 'package:ibn/features/prontuario/presentation/abas_prontuario.dart';

Usuario u(String id, Perfil p) => Usuario(id: id, nome: 'U$id', email: 'u$id@x', perfil: p);

List<String> titulos(Usuario x) => [for (final a in abasDoUsuario(x)) a.titulo];

void main() {
  test('dentista com Ortodontia e HOF (Dr. Davi) tem as 8 abas, na ordem', () {
    expect(titulos(u('3', Perfil.dentista)), [
      'Odontograma',
      'Ortodontia',
      'Atendimentos',
      'Anamnese',
      'Plano de tratamento',
      'Harmonização (HOF)',
      'Exames',
      'Documentos',
    ]);
  });

  test('dentista sem área (Dra. Lúcia) não vê Ortodontia nem HOF', () {
    expect(titulos(u('10', Perfil.dentista)),
        ['Odontograma', 'Atendimentos', 'Anamnese', 'Plano de tratamento', 'Exames', 'Documentos']);
  });

  test('cada área liberada pelo Administrador aparece sozinha', () {
    final lucia = u('10', Perfil.dentista);
    addTearDown(() {
      configuracaoClinica.definirAreaDentista('10', AreaDentista.ortodontia, false);
      configuracaoClinica.definirAreaDentista('10', AreaDentista.hof, false);
    });
    configuracaoClinica.definirAreaDentista('10', AreaDentista.ortodontia, true);
    expect(titulos(lucia), contains('Ortodontia'));
    expect(titulos(lucia), isNot(contains('Harmonização (HOF)')));
    configuracaoClinica.definirAreaDentista('10', AreaDentista.hof, true);
    expect(titulos(lucia), contains('Harmonização (HOF)'));
  });

  test('biomédico tem as 4 abas da Sala 4', () {
    expect(titulos(u('4', Perfil.biomedico)),
        ['Atendimentos', 'Anamnese', 'Procedimentos', 'Exames e laudos']);
  });

  test('perfis sem prontuário ainda (Sprint 2) não têm abas', () {
    for (final p in [
      Perfil.administrador,
      Perfil.recepcionista,
      Perfil.medico,
      Perfil.enfermeiro,
      Perfil.fisioterapeuta,
      Perfil.nutricionista,
      Perfil.psicologo,
    ]) {
      expect(abasDoUsuario(u('x', p)), isEmpty, reason: p.rotulo);
    }
  });

  test('os títulos de cada dentista não se repetem', () {
    final t = titulos(u('3', Perfil.dentista));
    expect(t.toSet().length, t.length);
  });
}