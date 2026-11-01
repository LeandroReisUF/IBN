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

/// Documentos clínicos (RF04.4). Esta classe só **fornece** o Cubit.
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
  bool get _podeEditar =>
      politicaAcesso.podeEditarDocumentos(auth.usuarioLogado!, widget.paciente);

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ---------- ações ----------

  Future<void> _gerar(ModeloDocumento modelo) async {
    final cubit = context.read<DocumentosCubit>();
    if (!cubit.temAtendimentoAberto) {
      _aviso('Inicie um atendimento na aba Atendimentos antes de emitir o documento.');
      return;
    }
    final valores = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _DialogoGerar(
        modelo: modelo,
        automaticas: cubit.valoresAutomaticosAgora(),
      ),
    );
    if (valores == null || !mounted) return;
    final erro = await cubit.gerar(modelo, valores);
    if (!mounted) return;
    _aviso(erro ?? 'Rascunho criado. Revise, gere o PDF e assine.');
  }

  Future<void> _escolherModelo(List<ModeloDocumento> modelos) async {
    final escolhido = await showDialog<ModeloDocumento>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Emitir documento'),
        children: [
          for (final m in modelos)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(m),
              child: Text('${m.nome} (${m.tipo.rotulo})'),
            ),
        ],
      ),
    );
    if (escolhido != null && mounted) await _gerar(escolhido);
  }

  Future<void> _editar(DocumentoClinico d) async {
    final cubit = context.read<DocumentosCubit>();
    final r = await showDialog<({String texto, String? justificativa})>(
      context: context,
      builder: (_) => _DialogoTexto(titulo: 'Editar rascunho', inicial: d.conteudo),
    );
    if (r == null || !mounted) return;
    final erro = await cubit.atualizarRascunho(d, r.texto);
    if (!mounted) return;
    if (erro != null) _aviso(erro);
  }

  Future<void> _assinar(DocumentoClinico d) async {
    final cubit = context.read<DocumentosCubit>();
    final erro = await cubit.assinar(d);
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

  Future<void> _retificar(DocumentoClinico d) async {
    final cubit = context.read<DocumentosCubit>();
    final r = await showDialog<({String texto, String? justificativa})>(
      context: context,
      builder: (_) => _DialogoTexto(
        titulo: 'Corrigir documento assinado',
        inicial: d.conteudo,
        pedeJustificativa: true,
      ),
    );
    if (r == null || !mounted) return;
    final erro = await cubit.retificar(d, r.texto, r.justificativa ?? '');
    if (!mounted) return;
    _aviso(erro ?? 'Rascunho de correção criado. O original continua no histórico.');
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

  Future<void> _modelos(List<ModeloDocumento> modelos) async {
    final cubit = context.read<DocumentosCubit>();
    await showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _DialogoModelos(modelos: modelos),
      ),
    );
  }

  // ---------- visual ----------

  String _dataHora(DateTime d) => '${formatarData(d)} ${formatarHora(d)}';

  Widget _cartao(DocumentoClinico d, bool retificado) {
    final tema = Theme.of(context);
    final riscado = retificado ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
    return Card(
      child: ExpansionTile(
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
                TextButton(onPressed: () => _editar(d), child: const Text('Editar')),
                TextButton(onPressed: () => _assinar(d), child: const Text('Assinar')),
                TextButton(onPressed: () => _descartar(d), child: const Text('Descartar')),
              ],
              if (_podeEditar && d.assinado && !retificado)
                TextButton(onPressed: () => _retificar(d), child: const Text('Corrigir')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conteudo(DocumentosSuccess s) {
    final tema = Theme.of(context);
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _escolherModelo(s.modelos),
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('Emitir documento'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _modelos(s.modelos),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Modelos'),
                      ),
                    ],
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

// ---------- diálogos ----------

/// Pede as variáveis manuais do modelo e mostra a pré-visualização ao vivo.
class _DialogoGerar extends StatefulWidget {
  final ModeloDocumento modelo;
  final Map<String, String> automaticas;
  const _DialogoGerar({required this.modelo, required this.automaticas});

  @override
  State<_DialogoGerar> createState() => _DialogoGerarState();
}

class _DialogoGerarState extends State<_DialogoGerar> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final v in variaveisManuais(widget.modelo.corpo)) v: TextEditingController(),
    };
    for (final c in _ctrls.values) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _manuais => {for (final e in _ctrls.entries) e.key: e.value.text.trim()};

  ResultadoPreenchimento get _previa =>
      preencherModelo(widget.modelo.corpo, {...widget.automaticas, ..._manuais});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final previa = _previa;
    final semRegistro = (widget.automaticas['profissional_registro'] ?? '').isEmpty &&
        variaveisDoCorpo(widget.modelo.corpo).contains('profissional_registro');
    return AlertDialog(
      title: Text(widget.modelo.nome),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (semRegistro)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Seu registro no conselho (ex.: CRO) não está cadastrado; o documento não poderá ser emitido.',
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                ),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: previa.faltando.isEmpty ? () => Navigator.of(context).pop(_manuais) : null,
          child: const Text('Criar rascunho'),
        ),
      ],
    );
  }
}

/// Texto do documento (edição de rascunho ou correção, com justificativa).
class _DialogoTexto extends StatefulWidget {
  final String titulo;
  final String inicial;
  final bool pedeJustificativa;
  const _DialogoTexto({
    required this.titulo,
    required this.inicial,
    this.pedeJustificativa = false,
  });

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  late final TextEditingController _textoCtrl;
  final _justCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textoCtrl = TextEditingController(text: widget.inicial);
    _textoCtrl.addListener(() => setState(() {}));
    _justCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    _justCtrl.dispose();
    super.dispose();
  }

  bool get _ok =>
      _textoCtrl.text.trim().isNotEmpty &&
      (!widget.pedeJustificativa || _justCtrl.text.trim().length >= 3);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.pedeJustificativa) ...[
                const Text('O documento original continua no histórico; a correção nasce como rascunho.'),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _textoCtrl,
                maxLines: 14,
                minLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Texto do documento *',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.pedeJustificativa) ...[
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _ok
              ? () => Navigator.of(context).pop((
                    texto: _textoCtrl.text.trim(),
                    justificativa: widget.pedeJustificativa ? _justCtrl.text.trim() : null,
                  ))
              : null,
          child: Text(widget.pedeJustificativa ? 'Criar correção' : 'Salvar'),
        ),
      ],
    );
  }
}

/// Lista de modelos com edição (cada salvar cria uma nova versão).
class _DialogoModelos extends StatelessWidget {
  final List<ModeloDocumento> modelos;
  const _DialogoModelos({required this.modelos});

  Future<void> _editar(BuildContext context, ModeloDocumento m) async {
    final cubit = context.read<DocumentosCubit>();
    final mensagem = ScaffoldMessenger.of(context);
    final novo = await showDialog<ModeloDocumento>(
      context: context,
      builder: (_) => _DialogoModelo(modelo: m),
    );
    if (novo == null) return;
    final erro = await cubit.salvarModelo(novo);
    mensagem.showSnackBar(SnackBar(content: Text(erro ?? 'Modelo salvo (nova versão).')));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DocumentosCubit>();
    return AlertDialog(
      title: const Text('Modelos de documento'),
      content: SizedBox(
        width: 480,
        child: BlocBuilder<DocumentosCubit, DocumentosState>(
          builder: (context, state) {
            final lista = state is DocumentosSuccess ? state.modelos : modelos;
            return ListView(
              shrinkWrap: true,
              children: [
                for (final m in lista)
                  ListTile(
                    title: Text(m.nome),
                    subtitle: Text('${m.tipo.rotulo} • versão ${m.versao}'),
                    trailing: cubit.podeEditarModelos
                        ? TextButton(onPressed: () => _editar(context, m), child: const Text('Editar'))
                        : null,
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
      ],
    );
  }
}

class _DialogoModelo extends StatefulWidget {
  final ModeloDocumento modelo;
  const _DialogoModelo({required this.modelo});

  @override
  State<_DialogoModelo> createState() => _DialogoModeloState();
}

class _DialogoModeloState extends State<_DialogoModelo> {
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _corpoCtrl;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.modelo.nome);
    _corpoCtrl = TextEditingController(text: widget.modelo.corpo);
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
    final ok = _nomeCtrl.text.trim().isNotEmpty && _corpoCtrl.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text('Editar modelo • versão ${widget.modelo.versao}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use {{variavel}} para campos. Automáticas: ${variaveisAutomaticas.join(', ')}. '
                'Qualquer outra vira um campo para o profissional preencher. '
                'Documentos já emitidos não mudam.',
                style: tema.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _corpoCtrl,
                maxLines: 14,
                minLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Texto do modelo *',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: ok
              ? () => Navigator.of(context).pop(ModeloDocumento(
                    id: widget.modelo.id,
                    nome: _nomeCtrl.text.trim(),
                    tipo: widget.modelo.tipo,
                    corpo: _corpoCtrl.text,
                  ))
              : null,
          child: const Text('Salvar nova versão'),
        ),
      ],
    );
  }
}