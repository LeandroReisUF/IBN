import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/prontuario/presentation/abas_prontuario.dart';

List<String> titulos(Perfil p) => [for (final a in abasDoPerfil(p)) a.titulo];

void main() {
  test('dentista tem as 8 abas, na ordem', () {
    expect(titulos(Perfil.dentista), [
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

  test('biomédico tem as 4 abas da Sala 4', () {
    expect(titulos(Perfil.biomedico), ['Atendimentos', 'Anamnese', 'Procedimentos', 'Exames e laudos']);
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
      expect(abasDoPerfil(p), isEmpty, reason: p.rotulo);
    }
  });

  test('os títulos de cada perfil não se repetem', () {
    for (final p in [Perfil.dentista, Perfil.biomedico]) {
      final t = titulos(p);
      expect(t.toSet().length, t.length, reason: p.rotulo);
    }
  });
}