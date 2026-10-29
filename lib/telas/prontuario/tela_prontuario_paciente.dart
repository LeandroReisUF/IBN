import 'package:flutter/material.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/prontuario/presentation/pages/aba_prontuario.dart';
import 'package:ibn/features/odontograma/presentation/pages/aba_odontograma.dart';
import 'package:ibn/features/ortodontia/presentation/pages/aba_ortodontia.dart';

/// Prontuário de um paciente, com abas conforme o perfil logado (RF03.2).
class TelaProntuarioPaciente extends StatefulWidget {
  final Paciente paciente;
  const TelaProntuarioPaciente({super.key, required this.paciente});

  @override
  State<TelaProntuarioPaciente> createState() => _TelaProntuarioPacienteState();
}

class _TelaProntuarioPacienteState extends State<TelaProntuarioPaciente> {
  @override
  void initState() {
    super.initState();
    final usuario = auth.usuarioLogado!;
    if (politicaAcesso.podeAcessarProntuario(usuario, widget.paciente)) {
      // RNF03: toda abertura de prontuário gera um registro de acesso.
      logsAcesso.registrar(
        usuarioId: usuario.id,
        acao: 'abriu_prontuario',
        entidade: 'paciente',
        entidadeId: widget.paciente.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = auth.usuarioLogado!;
    final paciente = widget.paciente;

    if (!politicaAcesso.podeAcessarProntuario(usuario, paciente)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prontuário')),
        body: const Center(
          child: Text('Você não tem acesso ao prontuário deste paciente.'),
        ),
      );
    }

    final ehDentista = usuario.perfil == Perfil.dentista;
    final titulos = ehDentista
        ? ['Odontograma', 'Ortodontia', 'Atendimentos', 'Harmonização (HOF)', 'Exames', 'Documentos']
        : ['Prontuário'];
    final corpos = <Widget>[
      if (ehDentista) ...[
        AbaOdontograma(paciente: paciente),
        AbaOrtodontia(paciente: paciente),
        AbaProntuario(paciente: paciente),
        const _EmBreve('Ficha de Harmonização Orofacial (próxima etapa)'),
        const _EmBreve('Solicitação e upload de exames (próxima etapa)'),
        const _EmBreve('Prescrições, atestados e termos (próxima etapa)'),
      ] else
        _EmBreve('O prontuário de ${usuario.perfil.rotulo} será construído na Sprint 2.'),
    ];

    return DefaultTabController(
      length: titulos.length,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(paciente.nome),
              Text(
                '${idadeEm(paciente.dataNascimento)} anos',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in titulos) Tab(text: t)],
          ),
        ),
        body: TabBarView(children: corpos),
      ),
    );
  }
}

class _EmBreve extends StatelessWidget {
  final String texto;
  const _EmBreve(this.texto);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction_outlined, size: 56, color: tema.colorScheme.outline),
          const SizedBox(height: 12),
          Text(texto, style: tema.textTheme.titleMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}