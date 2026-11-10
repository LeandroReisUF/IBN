import 'package:flutter/material.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/ortodontia/domain/ortodontia.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';

/// Aba **Ficha**: dois painéis compactos, sem janela. "Ficha" e "Arcos e
/// elásticos" gravam cada um só o que é seu; cada clique é uma nova versão (RN05).
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
  final _fichaKey = GlobalKey<FormState>();

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
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    for (final c in _controladores) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- ações ----------

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

  void _gravar(FichaOrtodontica nova, String acaoLog, String sucesso) {
    final mensagem = ScaffoldMessenger.of(context);
    final erro = ortodontiaRepository.salvarFicha(nova);
    if (erro != null) {
      mensagem.showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    // RNF03: toda alteração no prontuário gera registro de acesso.
    logsAcesso.registrar(
      usuarioId: widget.usuario.id,
      acao: acaoLog,
      entidade: 'paciente',
      entidadeId: widget.paciente.id,
    );
    mensagem.showSnackBar(SnackBar(content: Text(sucesso)));
  }

  void _salvarFicha() {
    if (!_fichaKey.currentState!.validate()) return;
    final anterior = widget.ficha;
    final agora = DateTime.now();
    final obs = _obsCtrl.text.trim();
    final queixa = _queixaCtrl.text.trim();
    final objetivos = _objetivosCtrl.text.trim();

    if (anterior == null) {
      _gravar(
        FichaOrtodontica(
          id: ortodontiaRepository.novoId(),
          pacienteId: widget.paciente.id,
          tipoAparelho: _tipo!,
          dataInstalacao: _instalacao!,
          previsaoTermino: _previsao,
          queixaPrincipal: queixa,
          objetivos: objetivos,
          observacoesGerais: obs.isEmpty ? null : obs,
          criadoEm: agora,
          atualizadoEm: agora,
          profissionalId: widget.usuario.id,
        ),
        'criou_ficha_orto',
        'Ficha criada.',
      );
      return;
    }
    _gravar(
      anterior.comDados(
        tipoAparelho: _tipo!,
        dataInstalacao: _instalacao!,
        previsaoTermino: _previsao,
        queixaPrincipal: queixa,
        objetivos: objetivos,
        observacoesGerais: obs.isEmpty ? null : obs,
        agora: agora,
        profissionalId: widget.usuario.id,
      ),
      'atualizou_ficha_orto',
      'Ficha salva (nova versão).',
    );
  }

  void _salvarArcos() {
    final f = widget.ficha;
    if (f == null) return;
    _gravar(
      f.comArcos(
        arcoSuperior: _arco(_arcoSupFioCtrl, _arcoSupCalibreCtrl),
        arcoInferior: _arco(_arcoInfFioCtrl, _arcoInfCalibreCtrl),
        elasticosSuperior: _elasticos(_elastSupCtrl),
        elasticosInferior: _elasticos(_elastInfCtrl),
        agora: DateTime.now(),
        profissionalId: widget.usuario.id,
      ),
      'atualizou_arcos_orto',
      'Arcos e elásticos salvos (nova versão).',
    );
  }

  // ---------- visual ----------

  InputDecoration _decoracao(String rotulo, {IconData? icone}) => InputDecoration(
        labelText: rotulo,
        prefixIcon: icone == null ? null : Icon(icone),
        border: const OutlineInputBorder(),
      );

  String? _obrigatorio(String? v, String msg) => (v == null || v.trim().isEmpty) ? msg : null;

  /// Painel compacto e centralizado (a "calculadora").
  Widget _painel(Widget filho) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(child: Padding(padding: const EdgeInsets.all(16), child: filho)),
        ),
      );

  Widget _campo(TextEditingController c, String rotulo, {int linhas = 1, bool obrigatorio = false}) =>
      TextFormField(
        controller: c,
        enabled: widget.podeEditar,
        maxLines: linhas,
        decoration: _decoracao(rotulo),
        validator: obrigatorio ? (v) => _obrigatorio(v, 'Campo obrigatório') : null,
      );

  Widget _painelFicha() {
    final tema = Theme.of(context);
    final f = widget.ficha;
    final pode = widget.podeEditar;
    return _painel(
      Form(
        key: _fichaKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ficha ortodôntica', style: tema.textTheme.titleMedium),
            Text(
              f == null
                  ? 'Nenhuma ficha criada para este paciente.'
                  : 'Atualizada em ${formatarData(f.atualizadoEm)} ${formatarHora(f.atualizadoEm)}',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TipoAparelhoOrto>(
              initialValue: _tipo,
              isExpanded: true,
              decoration: _decoracao('Tipo de aparelho *'),
              items: [
                for (final t in TipoAparelhoOrto.values)
                  DropdownMenuItem(value: t, child: Text(t.rotulo)),
              ],
              onChanged: pode ? (v) => setState(() => _tipo = v) : null,
              validator: (v) => v == null ? 'Selecione o tipo de aparelho' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _instalacaoCtrl,
                    readOnly: true,
                    enabled: pode,
                    onTap: () => _escolherData(instalacao: true),
                    decoration: _decoracao('Instalação *', icone: Icons.event_outlined),
                    validator: (v) => _obrigatorio(v, 'Escolha a data'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _previsaoCtrl,
                    readOnly: true,
                    enabled: pode,
                    onTap: () => _escolherData(instalacao: false),
                    decoration: _decoracao('Término previsto', icone: Icons.event_available_outlined),
                    validator: (v) {
                      if (_previsao != null && _instalacao != null && _previsao!.isBefore(_instalacao!)) {
                        return 'Depois da instalação';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _campo(_queixaCtrl, 'Queixa principal *', linhas: 2, obrigatorio: true),
            const SizedBox(height: 12),
            _campo(_objetivosCtrl, 'Objetivos do tratamento *', linhas: 3, obrigatorio: true),
            const SizedBox(height: 12),
            _campo(_obsCtrl, 'Observações gerais', linhas: 2),
            if (pode) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _salvarFicha,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(f == null ? 'Criar ficha' : 'Salvar ficha'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _painelArcos() {
    final tema = Theme.of(context);
    final pode = widget.podeEditar;
    final temFicha = widget.ficha != null;

    Widget linha(String titulo, TextEditingController fio, TextEditingController calibre,
            TextEditingController elasticos) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: tema.textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _campo(fio, 'Fio')),
                const SizedBox(width: 12),
                Expanded(child: _campo(calibre, 'Calibre')),
              ],
            ),
            const SizedBox(height: 12),
            _campo(elasticos, 'Elásticos'),
          ],
        );

    return _painel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Arcos e elásticos', style: tema.textTheme.titleMedium),
          if (pode && !temFicha)
            Text('Crie a ficha antes de registrar arcos e elásticos.', style: tema.textTheme.bodySmall),
          const SizedBox(height: 12),
          linha('Superior', _arcoSupFioCtrl, _arcoSupCalibreCtrl, _elastSupCtrl),
          const SizedBox(height: 16),
          linha('Inferior', _arcoInfFioCtrl, _arcoInfCalibreCtrl, _elastInfCtrl),
          if (pode) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: temFicha ? _salvarArcos : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar arcos'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _painelFicha(),
        const SizedBox(height: 8),
        _painelArcos(),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Cada alteração salva gera uma nova versão; as anteriores são mantidas (RN05).',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}