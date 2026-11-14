import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/pdf_simples.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/documentos/data/documentos_repository.dart';
import 'package:ibn/features/documentos/domain/documentos.dart';
import 'package:ibn/features/documentos/presentation/cubit/documentos_cubit.dart';
import 'package:ibn/features/documentos/presentation/cubit/documentos_state.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

String _rotuloVariavel(String v) {
  final t = v.replaceAll('_', ' ');
  return t[0].toUpperCase() + t.substring(1);
}

/// Documentos clínicos (RF04.4), tudo inline. Esta classe só **fornece** o Cubit.
class AbaDocumentos extends StatelessWidget {
  final Paciente paciente;
  const AbaDocumentos({super.key, required this.paciente});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DocumentosCubit(
        repositorio: documentosRepository,
        prontuario: prontuarioRepository,
        usuario: auth.usuarioLogado!,
        paciente: paciente,
      )..carregar(),
      child: _DocumentosView(paciente: paciente),
    );
  }
}

class _DocumentosView extends StatefulWidget {
  final Paciente paciente;
  const _DocumentosView({required this.paciente});

  @override
  State<_DocumentosView> createState() => _DocumentosViewState();
}

class _DocumentosViewState extends State<_DocumentosView> {
  final _textoCtrl = TextEditingController();
  final _justCtrl = TextEditingController();
  String? _editandoId;
  String? _corrigindoId;

  bool get _podeEditar =>
      politicaAcesso.podeEditarDocumentos(auth.usuarioLogado!, widget.paciente);

  @override
  void initState() {
    super.initState();
    _textoCtrl.addListener(() => setState(() {}));
    _justCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    _justCtrl.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ---------- ações ----------

  Future<String?> _gerar(ModeloDocumento modelo, Map<String, String> manuais) async {
    final erro = await context.read<DocumentosCubit>().gerar(modelo, manuais);
    if (mounted) _aviso(erro ?? 'Rascunho criado. Revise, gere o PDF e assine.');
    return erro;
  }

  void _abrirEdicao(DocumentoClinico d) => setState(() {
        _editandoId = d.id;
        _corrigindoId = null;
        _textoCtrl.text = d.conteudo;
        _justCtrl.clear();
      });

  void _abrirCorrecao(DocumentoClinico d) => setState(() {
        _corrigindoId = d.id;
        _editandoId = null;
        _textoCtrl.text = d.conteudo;
        _justCtrl.clear();
      });

  void _fechar() => setState(() {
        _editandoId = null;
        _corrigindoId = null;
        _textoCtrl.clear();
        _justCtrl.clear();
      });

  Future<void> _salvarEdicao(DocumentoClinico d) async {
    final erro = await context.read<DocumentosCubit>().atualizarRascunho(d, _textoCtrl.text.trim());
    if (!mounted) return;
    if (erro != null) {
      _aviso(erro);
      return;
    }
    _fechar();
  }

  Future<void> _salvarCorrecao(DocumentoClinico d) async {
    final erro = await context
        .read<DocumentosCubit>()
        .retificar(d, _textoCtrl.text.trim(), _justCtrl.text.trim());
    if (!mounted) return;
    _aviso(erro ?? 'Rascunho de correção criado. O original continua no histórico.');
    if (erro == null) _fechar();
  }

  Future<void> _assinar(DocumentoClinico d) async {
    final erro = await context.read<DocumentosCubit>().assinar(d);
    if (!mounted) return;
    _aviso(erro ?? 'Documento assinado. Ele não pode mais ser alterado.');
  }

  Future<void> _descartar(DocumentoClinico d) async {
    final cubit = context.read<DocumentosCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar rascunho?'),
        content: const Text('Só rascunhos podem ser descartados. Documentos assinados nunca são apagados.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Descartar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final erro = await cubit.descartarRascunho(d);
    if (!mounted) return;
    if (erro != null) _aviso(erro);
  }

  Future<void> _pdf(DocumentoClinico d) async {
    final rodape = d.assinado
        ? 'Assinado eletronicamente em ${formatarData(d.assinadoEm!)} ${formatarHora(d.assinadoEm!)} '
            '• selo provisório ${d.selo}'
        : 'RASCUNHO - documento ainda não assinado';
    try {
      final bytes = await gerarPdfSimples(titulo: d.titulo, corpo: d.conteudo, rodape: rodape);
      await imprimirPdf(bytes, '${d.titulo}.pdf');
    } catch (_) {
      if (mounted) _aviso('Não foi possível gerar o PDF neste dispositivo.');
    }
  }

  Future<String?> _salvarModelo(ModeloDocumento m) async {
    final erro = await context.read<DocumentosCubit>().salvarModelo(m);
    if (mounted) _aviso(erro ?? 'Modelo salvo (nova versão).');
    return erro;
  }

  // ---------- visual ----------

  String _dataHora(DateTime d) => '${formatarData(d)} ${formatarHora(d)}';

  /// Texto do rascunho ou da correção, dentro do próprio cartão.
  Widget _editor(DocumentoClinico d, {required bool correcao}) {
    final tema = Theme.of(context);
    final ok = _textoCtrl.text.trim().isNotEmpty &&
        (!correcao || _justCtrl.text.trim().length >= 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (correcao)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'O documento original continua no histórico; a correção nasce como rascunho.',
              style: tema.textTheme.bodySmall,
            ),
          ),
        TextField(
          controller: _textoCtrl,
          minLines: 6,
          maxLines: 14,
          decoration: const InputDecoration(
            labelText: 'Texto do documento *',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        if (correcao) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _justCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Justificativa da correção (obrigatória)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: ok ? () => correcao ? _salvarCorrecao(d) : _salvarEdicao(d) : null,
              child: Text(correcao ? 'Criar correção' : 'Salvar texto'),
            ),
            TextButton(onPressed: _fechar, child: const Text('Cancelar')),
          ],
        ),
      ],
    );
  }

  Widget _cartao(DocumentoClinico d, bool retificado) {
    final tema = Theme.of(context);
    final riscado = retificado ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
    final editando = _editandoId == d.id;
    final corrigindo = _corrigindoId == d.id;
    return Card(
      child: ExpansionTile(
        key: ValueKey('doc-${d.id}'),
        initiallyExpanded: !d.assinado,
        title: Text(d.titulo, style: riscado),
        subtitle: Text(
          '${d.tipo.rotulo} • ${_dataHora(d.emitidoEm)}'
          '${d.assinado ? ' • assinado • selo ${d.selo}' : ' • rascunho'}',
        ),
        trailing: retificado ? const Chip(label: Text('Corrigido')) : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.retificaId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Corrige um documento anterior. Motivo: ${d.justificativa ?? ''}',
                  style: tema.textTheme.bodySmall),
            ),
          if (editando || corrigindo)
            _editor(d, correcao: corrigindo)
          else ...[
            SelectableText(d.conteudo, style: riscado),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pdf(d),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF / imprimir'),
                ),
                if (_podeEditar && !d.assinado) ...[
                  TextButton(onPressed: () => _abrirEdicao(d), child: const Text('Editar')),
                  TextButton(onPressed: () => _assinar(d), child: const Text('Assinar')),
                  TextButton(onPressed: () => _descartar(d), child: const Text('Descartar')),
                ],
                if (_podeEditar && d.assinado && !retificado)
                  TextButton(onPressed: () => _abrirCorrecao(d), child: const Text('Corrigir')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _modelosPainel(List<ModeloDocumento> modelos) {
    final podeEditar = context.read<DocumentosCubit>().podeEditarModelos;
    return Card(
      child: ExpansionTile(
        key: const ValueKey('modelos-documento'),
        title: const Text('Modelos de documento'),
        subtitle: Text(podeEditar
            ? 'Cada salvamento cria uma nova versão; documentos já emitidos não mudam.'
            : 'Só dentistas editam os modelos.'),
        childrenPadding: const EdgeInsets.only(left: 8),
        children: [
          for (final m in modelos)
            _EditorModelo(
              key: ValueKey('${m.id}-${m.versao}'),
              modelo: m,
              podeEditar: podeEditar,
              aoSalvar: _salvarModelo,
            ),
        ],
      ),
    );
  }

  Widget _conteudo(DocumentosSuccess s) {
    final tema = Theme.of(context);
    final cubit = context.read<DocumentosCubit>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Documentos', style: tema.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Você vê apenas os documentos emitidos por você. O documento nasce como rascunho '
                  'dentro de um atendimento em aberto; depois de assinado não pode ser alterado '
                  '(RN05): use Corrigir. Atenção: os modelos de texto e as exigências do receituário '
                  'de controle especial devem ser validados pelos profissionais da clínica.',
                  style: tema.textTheme.bodySmall,
                ),
                if (_podeEditar) ...[
                  const Divider(height: 24),
                  _CompositorDocumento(
                    modelos: s.modelos,
                    automaticas: cubit.valoresAutomaticosAgora(),
                    temAtendimento: cubit.temAtendimentoAberto,
                    aoGerar: _gerar,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (s.documentos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nenhum documento emitido.')),
          )
        else
          for (final d in s.documentos) _cartao(d, s.retificados.contains(d.id)),
        const SizedBox(height: 16),
        _modelosPainel(s.modelos),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentosCubit, DocumentosState>(
      builder: (context, state) => switch (state) {
        DocumentosInitial() || DocumentosLoading() => const Center(child: CircularProgressIndicator()),
        DocumentosError(:final mensagem) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mensagem),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.read<DocumentosCubit>().carregar(),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        final DocumentosSuccess s => _conteudo(s),
      },
    );
  }
}

// ---------- painéis inline ----------

/// Novo documento: escolhe o modelo por chips e preenche os campos e a
/// pré-visualização logo abaixo, sem janela.
class _CompositorDocumento extends StatefulWidget {
  final List<ModeloDocumento> modelos;
  final Map<String, String> automaticas;
  final bool temAtendimento;
  final Future<String?> Function(ModeloDocumento modelo, Map<String, String> manuais) aoGerar;

  const _CompositorDocumento({
    required this.modelos,
    required this.automaticas,
    required this.temAtendimento,
    required this.aoGerar,
  });

  @override
  State<_CompositorDocumento> createState() => _CompositorDocumentoState();
}

class _CompositorDocumentoState extends State<_CompositorDocumento> {
  String? _modeloId;
  Map<String, TextEditingController> _ctrls = {};

  ModeloDocumento? get _modelo => widget.modelos.where((m) => m.id == _modeloId).firstOrNull;

  Map<String, String> get _manuais =>
      {for (final e in _ctrls.entries) e.key: e.value.text.trim()};

  /// Descarta depois do quadro, para os campos antigos saírem da tela antes.
  void _descartar(Map<String, TextEditingController> antigos) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in antigos.values) {
        c.dispose();
      }
    });
  }

  void _escolher(ModeloDocumento m) {
    final antigos = _ctrls;
    setState(() {
      _modeloId = m.id;
      _ctrls = {
        for (final v in variaveisManuais(m.corpo))
          v: TextEditingController()..addListener(() => setState(() {})),
      };
    });
    _descartar(antigos);
  }

  void _limpar() {
    final antigos = _ctrls;
    setState(() {
      _modeloId = null;
      _ctrls = {};
    });
    _descartar(antigos);
  }

  Future<void> _criar(ModeloDocumento m) async {
    final erro = await widget.aoGerar(m, _manuais);
    if (erro == null && mounted) _limpar();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final m = _modelo;
    final previa = m == null
        ? null
        : preencherModelo(m.corpo, {...widget.automaticas, ..._manuais});
    final semRegistro = m != null &&
        (widget.automaticas['profissional_registro'] ?? '').isEmpty &&
        variaveisDoCorpo(m.corpo).contains('profissional_registro');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Novo documento', style: tema.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final mo in widget.modelos)
              ChoiceChip(
                label: Text(mo.nome),
                selected: m?.id == mo.id,
                onSelected: (sel) => sel ? _escolher(mo) : _limpar(),
              ),
          ],
        ),
        if (m != null && previa != null) ...[
          if (semRegistro)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Seu registro no conselho (ex.: CRO) não está cadastrado; o documento não poderá ser emitido.',
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          for (final e in _ctrls.entries) ...[
            TextField(
              controller: e.value,
              maxLines: e.key == 'prescricao' ? 6 : 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: '${_rotuloVariavel(e.key)} *',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text('Pré-visualização', style: tema.textTheme.labelLarge),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: tema.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(previa.texto, style: tema.textTheme.bodySmall),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: previa.faltando.isEmpty && widget.temAtendimento ? () => _criar(m) : null,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Criar rascunho'),
          ),
          if (!widget.temAtendimento)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Inicie um atendimento na aba Atendimentos para emitir o documento.',
                style: tema.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

/// Um modelo editável dentro da lista (cada salvamento cria uma nova versão).
class _EditorModelo extends StatefulWidget {
  final ModeloDocumento modelo;
  final bool podeEditar;
  final Future<String?> Function(ModeloDocumento) aoSalvar;

  const _EditorModelo({
    super.key,
    required this.modelo,
    required this.podeEditar,
    required this.aoSalvar,
  });

  @override
  State<_EditorModelo> createState() => _EditorModeloState();
}

class _EditorModeloState extends State<_EditorModelo> {
  late final TextEditingController _nomeCtrl = TextEditingController(text: widget.modelo.nome);
  late final TextEditingController _corpoCtrl = TextEditingController(text: widget.modelo.corpo);

  @override
  void initState() {
    super.initState();
    _nomeCtrl.addListener(() => setState(() {}));
    _corpoCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _corpoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final m = widget.modelo;
    final ok = _nomeCtrl.text.trim().isNotEmpty && _corpoCtrl.text.trim().isNotEmpty;
    return ExpansionTile(
      title: Text(m.nome),
      subtitle: Text('${m.tipo.rotulo} • versão ${m.versao}'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Use {{variavel}} para campos. Automáticas: ${variaveisAutomaticas.join(', ')}. '
          'Qualquer outra vira um campo para o profissional preencher.',
          style: tema.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nomeCtrl,
          enabled: widget.podeEditar,
          decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _corpoCtrl,
          enabled: widget.podeEditar,
          minLines: 6,
          maxLines: 14,
          decoration: const InputDecoration(
            labelText: 'Texto do modelo *',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        if (widget.podeEditar) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: ok
                  ? () => widget.aoSalvar(ModeloDocumento(
                        id: m.id,
                        nome: _nomeCtrl.text.trim(),
                        tipo: m.tipo,
                        corpo: _corpoCtrl.text,
                      ))
                  : null,
              child: const Text('Salvar nova versão'),
            ),
          ),
        ],
      ],
    );
  }
}