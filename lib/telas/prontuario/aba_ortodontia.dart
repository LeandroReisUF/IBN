import 'package:flutter/material.dart';
import '../../core/auth_service.dart';
import '../../core/formadores.dart';
import '../../core/odontograma.dart';
import '../../core/paciente.dart';
import '../../core/politica_acesso_service.dart';
import 'aba_ortodontia_ficha.dart';
import 'aba_ortodontia_arcos.dart';
import 'aba_ortodontia_fotos.dart';
import 'aba_ortodontia_manutencoes.dart';

class AbaOrtodontia extends StatelessWidget {
  final Paciente paciente;
  const AbaOrtodontia({super.key, required this.paciente});

  @override
  Widget build(BuildContext context) {
    final usuario = auth.usuarioLogado!;
    final podeEditar = politicaAcesso.podeEditarOdontograma(usuario, paciente);
    final ficha = ortodontiaRepository.fichaDoPaciente(paciente.id);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ortodontia'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Ficha'),
              Tab(text: 'Arcos/Elásticos'),
              Tab(text: 'Fotos'),
              Tab(text: 'Manutenções'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AbaFichaWidget(paciente: paciente, ficha: ficha),
            SecaoArcosElasticos(
              ficha: ficha,
              podeEditar: podeEditar,
              onEditarFicha: () {},
            ),
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
              podeEditar: podeEditar,
            ),
          ],
        ),
      ),
    );
  }
}

class _AbaFichaWidget extends StatefulWidget {
  final Paciente paciente;
  final FichaOrtodontica? ficha;
  const _AbaFichaWidget({required this.paciente, this.ficha});

  @override
  State<_AbaFichaWidget> createState() => _AbaFichaWidgetState();
}

class _AbaFichaWidgetState extends State<_AbaFichaWidget> {
  late bool _editando;
  late TextEditingController _queixaCtrl;
  late TextEditingController _objetivosCtrl;
  late TextEditingController _obsGeraisCtrl;
  late TipoAparelhoOrto? _tipoAparelho;
  late DateTime? _dataInstalacao;
  late DateTime? _previsaoTermino;

  @override
  void initState() {
    super.initState();
    _editando = false;
    _queixaCtrl = TextEditingController(text: widget.ficha?.objetivos ?? '');
    _objetivosCtrl = TextEditingController(text: widget.ficha?.objetivos ?? '');
    _obsGeraisCtrl = TextEditingController(text: widget.ficha?.observacoesGerais ?? '');
    _tipoAparelho = widget.ficha?.tipoAparelho;
    _dataInstalacao = widget.ficha?.dataInstalacao;
    _previsaoTermino = widget.ficha?.previsaoTermino;
  }

  @override
  void dispose() {
    _queixaCtrl.dispose();
    _objetivosCtrl.dispose();
    _obsGeraisCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = auth.usuarioLogado!;
    return SecaoFichaOrtodontica(
      paciente: widget.paciente,
      usuario: usuario,
      ficha: widget.ficha,
      editandoFicha: _editando,
      onToggleEdicao: () => setState(() => _editando = !_editando),
      onSalvar: () {},
      queixaCtrl: _queixaCtrl,
      objetivosCtrl: _objetivosCtrl,
      obsGeraisCtrl: _obsGeraisCtrl,
      arcoSupFioCtrl: TextEditingController(),
      arcoSupCalibreCtrl: TextEditingController(),
      arcoInfFioCtrl: TextEditingController(),
      arcoInfCalibreCtrl: TextEditingController(),
      elastSupCtrl: TextEditingController(),
      elastInfCtrl: TextEditingController(),
      tipoAparelho: _tipoAparelho,
      dataInstalacao: _dataInstalacao,
      previsaoTermino: _previsaoTermino,
      onTipoAparelhoChanged: (v) => setState(() => _tipoAparelho = v),
      onEscolherDataInstalacao: () {},
      onEscolherPrevisaoTermino: () {},
    );
  }
}