import 'package:flutter/widgets.dart';
import 'package:ibn/features/anamnese/presentation/pages/aba_anamnese.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/biomedicina/presentation/pages/aba_procedimentos_biomedicina.dart';
import 'package:ibn/features/documentos/presentation/pages/aba_documentos.dart';
import 'package:ibn/features/exames/presentation/pages/aba_exames.dart';
import 'package:ibn/features/hof/presentation/pages/aba_hof.dart';
import 'package:ibn/features/ortodontia/presentation/pages/aba_ortodontia.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/plano_tratamento/presentation/pages/aba_plano_tratamento.dart';
import 'package:ibn/features/prontuario/presentation/pages/aba_prontuario.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/configuracoes/data/configuracao_repository.dart';
import 'package:ibn/features/configuracoes/domain/area_dentista.dart';
import 'package:ibn/core/widgets/manter_vivo.dart';
import 'package:ibn/features/prontuario/presentation/pages/aba_anamnese_odontograma.dart';

/// Uma aba do prontuário: título e como construir a tela para o paciente.
class AbaProntuarioDef {
  final String titulo;
  final Widget Function(Paciente paciente) construir;
  const AbaProntuarioDef(this.titulo, this.construir);
}

/// Abas do prontuário de cada perfil (RF03.2). Lista vazia = o perfil ainda não
/// tem prontuário (Sprint 2); a tela mostra o aviso "em breve".
///
/// Para ligar uma aba nova, acrescente-a aqui: a tela não precisa mudar.
/// Abas do prontuário de cada usuário (RF03.2). Lista vazia = o perfil ainda não
/// tem prontuário (Sprint 2). No dentista, Ortodontia e HOF só aparecem se o
/// Administrador o marcou como especialista na área.
List<AbaProntuarioDef> abasDoUsuario(Usuario usuario) => switch (usuario.perfil) {
            Perfil.dentista => [
          AbaProntuarioDef(
              'Anamnese e odontograma',
              (p) => ManterVivo(child: AbaAnamneseOdontograma(paciente: p))),
          if (configuracaoClinica.dentistaTem(usuario.id, AreaDentista.ortodontia))
            AbaProntuarioDef('Ortodontia', (p) => AbaOrtodontia(paciente: p)),
          AbaProntuarioDef('Atendimentos', (p) => AbaProntuario(paciente: p)),
          AbaProntuarioDef('Plano de tratamento', (p) => AbaPlanoTratamento(paciente: p)),
          if (configuracaoClinica.dentistaTem(usuario.id, AreaDentista.hof))
            AbaProntuarioDef('Harmonização (HOF)', (p) => AbaHof(paciente: p)),
          AbaProntuarioDef('Exames', (p) => AbaExames(paciente: p)),
          AbaProntuarioDef('Documentos', (p) => AbaDocumentos(paciente: p)),
        ],
      Perfil.biomedico => [
          AbaProntuarioDef('Atendimentos', (p) => AbaProntuario(paciente: p)),
          AbaProntuarioDef('Anamnese', (p) => ManterVivo(child: AbaAnamnese(paciente: p))),
          AbaProntuarioDef('Procedimentos', (p) => AbaProcedimentosBiomedicina(paciente: p)),
          AbaProntuarioDef('Exames e laudos', (p) => AbaExames(paciente: p)),
        ],
      _ => const [],
    };