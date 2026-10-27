import 'package:flutter/material.dart';
import '../../core/formadores.dart';
import '../../core/log_acesso.dart';
import '../../core/ortodontia.dart';
import '../../core/paciente.dart';
import '../../core/usuario.dart';

/// Seção **Ficha Ortodôntica**: visualização e edição (cada salvar = nova versão).
class SecaoFichaOrtodontica extends StatefulWidget {
  final Paciente paciente;
  final Usuario usuario;
  final FichaOrtodontica? ficha;
  final bool podeEditar;

  const SecaoFichaOrtodontica({
    super.key,
    required this.paciente,
    required this.usuario,
    required this.ficha,
    required this.podeEditar,
  });

  @override
  State<SecaoFichaOrtodontica> createState() => _SecaoFichaOrtodonticaState();
}

class _SecaoFichaOrtodonticaState extends State<SecaoFichaOrtodontica> {
  final _formKey = GlobalKey<FormState>();
  bool _editando = false;

  final _queixaCtrl = TextEditingController();
  final _objetivosCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _instalacaoCtrl = TextEditingController();
  final _previsaoCtrl = TextEditingController();
  final _arcoSupFioCtrl = TextEditingController();
  final _arcoSupCalibreCtrl = TextEditingController();
  final _arcoInfFioCtrl = TextEditingController();
  final _arcoInfCalibreCtrl = TextEditingController();
  final _elastSupCtrl = TextEditingController();
  final _elastInfCtrl = TextEditingController();

  TipoAparelhoOrto? _tipo;
  DateTime? _instalacao;
  DateTime? _previsao;

  List<TextEditingController> get _controladores => [
        _queixaCtrl, _objetivosCtrl, _obsCtrl, _instalacaoCtrl, _previsaoCtrl,
        _arcoSupFioCtrl, _arcoSupCalibreCtrl, _arcoInfFioCtrl, _arcoInfCalibreCtrl,
        _elastSupCtrl, _elastInfCtrl,
      ];

  @override
  void dispose() {
    for (final c in _controladores) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- edição ----------

  /// Carrega a ficha atual (ou campos vazios) nos controladores e abre o formulário.
  void _iniciarEdicao() {
    final f = widget.ficha;
    _tipo = f?.tipoAparelho;
    _instalacao = f?.dataInstalacao;
    _previsao = f?.previsaoTermino;
    _instalacaoCtrl.text = _instalacao == null ? '' : formatarData(_instalacao!);
    _previsaoCtrl.text = _previsao == null ? '' : formatarData(_previsao!);
    _queixaCtrl.text = f?.queixaPrincipal ?? '';
    _objetivosCtrl.text = f?.objetivos ?? '';
    _obsCtrl.text = f?.observacoesGerais ?? '';
    _arcoSupFioCtrl.text = f?.arcoSuperior?.fio ?? '';
    _arcoSupCalibreCtrl.text = f?.arcoSuperior?.calibre ?? '';
    _arcoInfFioCtrl.text = f?.arcoInferior?.fio ?? '';
    _arcoInfCalibreCtrl.text = f?.arcoInferior?.calibre ?? '';
    _elastSupCtrl.text = f?.elasticosSuperior?.descricao ?? '';
    _elastInfCtrl.text = f?.elasticosInferior?.descricao ?? '';
    setState(() => _editando = true);
  }

  Future<void> _escolherData({required bool instalacao}) async {
    final atual = instalacao ? _instalacao : _previsao;
    final nova = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (nova == null || !mounted) return;
    setState(() {
      final dia = soData(nova);
      if (instalacao) {
        _instalacao = dia;
        _instalacaoCtrl.text = formatarData(dia);
      } else {
        _previsao = dia;
        _previsaoCtrl.text = formatarData(dia);
      }
    });
  }

  ArcoOrtodontico? _arco(TextEditingController fio, TextEditingController calibre) {
    final f = fio.text.trim();
    final c = calibre.text.trim();
    return (f.isEmpty && c.isEmpty) ? null : ArcoOrtodontico(fio: f, calibre: c);
  }

  ElasticosOrtodonticos? _elasticos(TextEditingController ctrl) {
    final t = ctrl.text.trim();
    return t.isEmpty ? null : ElasticosOrtodonticos(t);
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;
    final anterior = widget.ficha;
    final agora = DateTime.now();
    final obs = _obsCtrl.text.trim();

    final nova = FichaOrtodontica(
      id: anterior?.id ?? ortodontiaRepository.novoId(),
      pacienteId: widget.paciente.id,
      tipoAparelho: _tipo!,
      dataInstalacao: _instalacao!,
      previsaoTermino: _previsao,
      queixaPrincipal: _queixaCtrl.text.trim(),
      objetivos: _objetivosCtrl.text.trim(),
      observacoesGerais: obs.isEmpty ? null : obs,
      arcoSuperior: _arco(_arcoSupFioCtrl, _arcoSupCalibreCtrl),
      arcoInferior: _arco(_arcoInfFioCtrl, _arcoInfCalibreCtrl),
      elasticosSuperior: _elasticos(_elastSupCtrl),
      elasticosInferior: _elasticos(_elastInfCtrl),
      criadoEm: anterior?.criadoEm ?? agora,
      atualizadoEm: agora,
      profissionalId: widget.usuario.id,
    );

    final mensagem = ScaffoldMessenger.of(context);
    final erro = ortodontiaRepository.salvarFicha(nova);
    if (erro != null) {
      mensagem.showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    // RNF03: toda alteração no prontuário gera registro de acesso.
    logsAcesso.registrar(
      usuarioId: widget.usuario.id,
      acao: anterior == null ? 'criou_ficha_orto' : 'atualizou_ficha_orto',
      entidade: 'paciente',
      entidadeId: widget.paciente.id,
    );
    setState(() => _editando = false);
    mensagem.showSnackBar(const SnackBar(content: Text('Ficha ortodôntica salva.')));
  }

  // ---------- visual ----------

  InputDecoration _decoracao(String rotulo, {IconData? icone}) => InputDecoration(
        labelText: rotulo,
        prefixIcon: icone == null ? null : Icon(icone),
        border: const OutlineInputBorder(),
      );

  String? _obrigatorio(String? v, String msg) =>
      (v == null || v.trim().isEmpty) ? msg : null;

  Widget _formulario() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<TipoAparelhoOrto>(
            initialValue: _tipo,
            isExpanded: true,
            decoration: _decoracao('Tipo de aparelho *'),
            items: [
              for (final t in TipoAparelhoOrto.values)
                DropdownMenuItem(value: t, child: Text(t.rotulo)),
            ],
            onChanged: (v) => setState(() => _tipo = v),
            validator: (v) => v == null ? 'Selecione o tipo de aparelho' : null,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 260,
                child: TextFormField(
                  controller: _instalacaoCtrl,
                  readOnly: true,
                  onTap: () => _escolherData(instalacao: true),
                  decoration: _decoracao('Data de instalação *', icone: Icons.event_outlined),
                  validator: (v) => _obrigatorio(v, 'Escolha a data de instalação'),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextFormField(
                  controller: _previsaoCtrl,
                  readOnly: true,
                  onTap: () => _escolherData(instalacao: false),
                  decoration: _decoracao('Previsão de término', icone: Icons.event_available_outlined),
                  validator: (v) {
                    if (_previsao != null &&
                        _instalacao != null &&
                        _previsao!.isBefore(_instalacao!)) {
                      return 'Deve ser depois da instalação';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _queixaCtrl,
            maxLines: 2,
            decoration: _decoracao('Queixa principal *'),
            validator: (v) => _obrigatorio(v, 'Informe a queixa principal'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _objetivosCtrl,
            maxLines: 3,
            decoration: _decoracao('Objetivos do tratamento *'),
            validator: (v) => _obrigatorio(v, 'Informe os objetivos'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _obsCtrl,
            maxLines: 2,
            decoration: _decoracao('Observações gerais'),
          ),
          const SizedBox(height: 24),
          Text('Arcos e elásticos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(width: 200, child: TextFormField(controller: _arcoSupFioCtrl, decoration: _decoracao('Arco superior — fio'))),
              SizedBox(width: 200, child: TextFormField(controller: _arcoSupCalibreCtrl, decoration: _decoracao('Arco superior — calibre'))),
              SizedBox(width: 200, child: TextFormField(controller: _arcoInfFioCtrl, decoration: _decoracao('Arco inferior — fio'))),
              SizedBox(width: 200, child: TextFormField(controller: _arcoInfCalibreCtrl, decoration: _decoracao('Arco inferior — calibre'))),
              SizedBox(width: 416, child: TextFormField(controller: _elastSupCtrl, decoration: _decoracao('Elásticos superiores'))),
              SizedBox(width: 416, child: TextFormField(controller: _elastInfCtrl, decoration: _decoracao('Elásticos inferiores'))),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _salvar,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar ficha'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _editando = false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linha(String rotulo, String valor) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 160, child: Text(rotulo, style: tema.textTheme.labelLarge)),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }

  Widget _visualizacao(FichaOrtodontica f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _linha('Tipo de aparelho', f.tipoAparelho.rotulo),
        _linha('Instalação', formatarData(f.dataInstalacao)),
        _linha('Previsão de término',
            f.previsaoTermino == null ? '—' : formatarData(f.previsaoTermino!)),
        _linha('Queixa principal', f.queixaPrincipal),
        _linha('Objetivos', f.objetivos),
        if ((f.observacoesGerais ?? '').isNotEmpty) _linha('Observações', f.observacoesGerais!),
        _linha('Criada em', formatarData(f.criadoEm)),
        _linha('Última atualização', formatarData(f.atualizadoEm)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ficha = widget.ficha;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Ficha ortodôntica', style: tema.textTheme.titleLarge)),
                    if (widget.podeEditar && !_editando)
                      FilledButton.tonalIcon(
                        onPressed: _iniciarEdicao,
                        icon: Icon(ficha == null ? Icons.add : Icons.edit_outlined),
                        label: Text(ficha == null ? 'Criar ficha' : 'Editar'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_editando)
                  _formulario()
                else if (ficha == null)
                  const Text('Nenhuma ficha ortodôntica criada para este paciente.')
                else
                  _visualizacao(ficha),
              ],
            ),
          ),
        ),
        if (!_editando && ficha != null) ...[
          const SizedBox(height: 4),
          Text(
            'Cada alteração salva gera uma nova versão; as anteriores são mantidas (RN05).',
            style: tema.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}