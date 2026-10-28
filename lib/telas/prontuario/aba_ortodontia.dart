import 'package:flutter/material.dart';
import '../../features/auth/data/auth_service.dart';
import 'package:ibn/core/ortodontia.dart';
import 'package:ibn/core/paciente.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'aba_ortodontia_arcos.dart';
import 'aba_ortodontia_ficha.dart';
import 'aba_ortodontia_fotos.dart';
import 'aba_ortodontia_manutencoes.dart';

/// Ortodontia (Fase F): ficha, arcos/elásticos, fotos e manutenções.
/// Escuta o repositório: qualquer inclusão atualiza as quatro sub-abas na hora.
class AbaOrtodontia extends StatelessWidget {
  final Paciente paciente;
  const AbaOrtodontia({super.key, required this.paciente});

  @override
  Widget build(BuildContext context) {
    final usuario = auth.usuarioLogado!;
    final podeEditar = politicaAcesso.podeEditarOdontograma(usuario, paciente);

    return ListenableBuilder(
      listenable: ortodontiaRepository,
      builder: (context, _) {
        final ficha = ortodontiaRepository.fichaDoPaciente(paciente.id);
        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Ficha'),
                  Tab(text: 'Arcos/Elásticos'),
                  Tab(text: 'Fotos'),
                  Tab(text: 'Manutenções'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  // Sem deslizar: evita brigar com as abas de fora do prontuário.
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SecaoFichaOrtodontica(
                      paciente: paciente,
                      usuario: usuario,
                      ficha: ficha,
                      podeEditar: podeEditar,
                    ),
                    SecaoArcosElasticos(ficha: ficha, podeEditar: podeEditar),
                    SecaoFotos(
                      paciente: paciente,
                      usuario: usuario,
                      fotos: ortodontiaRepository.fotosDoPaciente(paciente.id),
                      podeEditar: podeEditar,
                    ),
                    SecaoManutencoes(
                      paciente: paciente,
                      usuario: usuario,
                      manutencoes: ortodontiaRepository.manutencoesDoPaciente(paciente.id),
                      retificadas: ortodontiaRepository.retificadas(paciente.id),
                      podeEditar: podeEditar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}