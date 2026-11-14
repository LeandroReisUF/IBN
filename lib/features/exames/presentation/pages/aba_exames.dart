import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/core/selecao_arquivo.dart';
import 'package:ibn/core/pdf_simples.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/exames/data/exames_repository.dart';
import 'package:ibn/features/exames/domain/exames.dart';
import 'package:ibn/features/exames/presentation/cubit/exames_cubit.dart';
import 'package:ibn/features/exames/presentation/cubit/exames_state.dart';
import 'package:ibn/features/exames/presentation/widgets/secao_resultados_lab.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

String _tamanho(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB'
    : '${(bytes / 1024).ceil()} KB';

/// Exames (RF04.3). Esta classe só **fornece** o Cubit.
class AbaExames extends StatelessWidget {
  final Paciente paciente;
  const AbaExames({super.key, required this.paciente});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExamesCubit(
        repositorio: examesRepository,
        prontuario: prontuarioRepository,
        usuario: auth.usuarioLogado!,
        paciente: paciente,
      )..carregar(),
      child: _ExamesView(paciente: paciente),
    );
  }
}

class _ExamesView extends StatefulWidget {
  final Paciente paciente;
  const _ExamesView({required this.paciente});

  @override
  State<_ExamesView> createState() => _ExamesViewState();
}

class _ExamesViewState extends State<_ExamesView> {
  bool get _podeEditar =>
      politicaAcesso.podeEditarExames(auth.usuarioLogado!, widget.paciente);

  final _justCtrl = TextEditingController();
  String? _substituindoId;

  @override
  void initState() {
    super.initState();
    _justCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _justCtrl.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ---------- ações ----------

    Future<String?> _solicitar(TipoExame tipo, String nome, String? descricao) async {
    final erro = await context
        .read<ExamesCubit>()
        .solicitar(tipo: tipo, nome: nome, descricao: descricao);
    if (mounted) _aviso(erro ?? 'Exame solicitado.');
    return erro;
  }

  Future<void> _mudarStatus(Exame e, StatusExame novo) async {
    final cubit = context.read<ExamesCubit>();
    if (novo == StatusExame.cancelado) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancelar exame?'),
          content: const Text('O exame continua no histórico como "Cancelado".'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Voltar')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Cancelar exame')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final erro = await cubit.mudarStatus(e, novo);
    if (!mounted) return;
    if (erro != null) _aviso(erro);
  }

  Future<void> _anexar(Exame e) async {
    final cubit = context.read<ExamesCubit>();
    final r = await escolherArquivoClinico();
    if (r == null || !mounted) return;
    final arquivo = r.arquivo;
    if (arquivo == null) {
      _aviso(r.erro ?? 'Não foi possível ler o arquivo.');
      return;
    }
    final erro = await cubit.anexar(e, nomeArquivo: arquivo.nome, bytes: arquivo.bytes);
    if (!mounted) return;
    _aviso(erro ?? 'Arquivo anexado.');
  }

    Future<void> _substituir(Exame e, ArquivoClinico anterior) async {
    final cubit = context.read<ExamesCubit>();
    final justificativa = _justCtrl.text.trim();
    final r = await escolherArquivoClinico();
    if (r == null || !mounted) return;
    final arquivo = r.arquivo;
    if (arquivo == null) {
      _aviso(r.erro ?? 'Não foi possível ler o arquivo.');
      return;
    }
    final erro = await cubit.substituir(
      e,
      anterior,
      nomeArquivo: arquivo.nome,
      bytes: arquivo.bytes,
      justificativa: justificativa,
    );
    if (!mounted) return;
    _aviso(erro ?? 'Arquivo substituído. O anterior continua no histórico.');
    if (erro == null) {
      setState(() {
        _substituindoId = null;
        _justCtrl.clear();
      });
    }
  }

  void _abrir(ArquivoClinico a) {
        if (a.ehPdf) {
      imprimirPdf(a.bytes, a.nomeArquivo).catchError((_) {
        if (mounted) _aviso('Não foi possível abrir o PDF neste dispositivo.');
        return false;
      });
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                maxScale: 8,
                child: Image.memory(
                  a.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Padding(padding: EdgeInsets.all(32), child: Text('Imagem inválida.')),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text('${a.nomeArquivo} • ${formatarData(a.enviadoEm)}')),
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
    Future<void> _imprimirGuia(Exame e) async {
    final usuario = auth.usuarioLogado!;
    final p = widget.paciente;
    final corpo = [
      'Paciente: ${p.nome}',
      'CPF: ${formatarCpf(p.cpf)}',
      '',
      'Exame solicitado: ${e.nome}',
      'Tipo: ${e.tipo.rotulo}',
      if ((e.descricao ?? '').isNotEmpty) 'Indicação clínica: ${e.descricao}',
      '',
      'Data da solicitação: ${formatarData(e.solicitadoEm)}',
      '',
      usuario.nome,
      if (usuario.registroFormatado != null) usuario.registroFormatado!,
    ].join('\n');
    try {
      final bytes = await gerarPdfSimples(titulo: 'Guia de solicitação de exame', corpo: corpo);
      await imprimirPdf(bytes, 'Guia - ${e.nome}.pdf');
    } catch (_) {
      if (mounted) _aviso('Não foi possível gerar o PDF neste dispositivo.');
    }
  }

  // ---------- visual ----------

  String _rotuloAcao(StatusExame s) => switch (s) {
        StatusExame.realizado => 'Marcar como realizado',
        StatusExame.resultadoDisponivel => 'Resultado disponível',
        StatusExame.cancelado => 'Cancelar exame',
        StatusExame.solicitado => 'Solicitado',
      };

    Widget _linhaArquivo(Exame e, ArquivoClinico a, bool substituido) {
    final tema = Theme.of(context);
    final riscado = substituido ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
    final substituindo = _substituindoId == a.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: a.ehImagem
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Image.memory(
                      a.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 32),
          title: Text(a.nomeArquivo, style: riscado, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${_tamanho(a.tamanhoBytes)} • ${formatarData(a.enviadoEm)}'
            '${a.retificaId == null ? '' : ' • substitui um anterior: ${a.justificativa ?? ''}'}',
            style: tema.textTheme.bodySmall,
          ),
          onTap: () => _abrir(a),
          trailing: substituido
              ? const Chip(label: Text('Substituído'))
              : (_podeEditar && e.status != StatusExame.cancelado
                  ? TextButton(
                      onPressed: () => setState(() {
                        _substituindoId = substituindo ? null : a.id;
                        _justCtrl.clear();
                      }),
                      child: Text(substituindo ? 'Fechar' : 'Substituir'),
                    )
                  : null),
        ),
        if (substituindo)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('O arquivo anterior continua no histórico, riscado (RN05).',
                    style: tema.textTheme.bodySmall),
                const SizedBox(height: 6),
                TextField(
                  controller: _justCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Justificativa (obrigatória)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _justCtrl.text.trim().length >= 3 ? () => _substituir(e, a) : null,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Escolher novo arquivo e substituir'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cartaoExame(Exame e, List<ArquivoClinico> arquivos, Set<String> substituidos) {
    final tema = Theme.of(context);
    final cancelado = e.status == StatusExame.cancelado;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.nome,
                    style: tema.textTheme.titleSmall?.copyWith(
                      decoration: cancelado ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Chip(label: Text(e.status.rotulo)),
              ],
            ),
            Text(
              '${e.tipo.rotulo} • solicitado em ${formatarData(e.solicitadoEm)} ${formatarHora(e.solicitadoEm)}',
              style: tema.textTheme.bodySmall,
            ),
            if ((e.descricao ?? '').isNotEmpty) Text(e.descricao!),
            if (arquivos.isNotEmpty) ...[
              const Divider(),
              for (final a in arquivos) _linhaArquivo(e, a, substituidos.contains(a.id)),
            ],
            if (e.tipo == TipoExame.laboratorial)
              SecaoResultadosLab(exame: e, paciente: widget.paciente, podeEditar: _podeEditar),
            if (_podeEditar && !cancelado)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [                  OutlinedButton.icon(
                    onPressed: () => _anexar(e),
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Anexar arquivo'),
                  ),
                    OutlinedButton.icon(
                    onPressed: () => _imprimirGuia(e),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Imprimir guia'),
                  ),
                  for (final s in e.status.proximos)
                    TextButton(onPressed: () => _mudarStatus(e, s), child: Text(_rotuloAcao(s))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(ExamesSuccess s) {
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
                Text('Exames', style: tema.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Você vê apenas os exames solicitados por você. O exame é solicitado dentro de '
                  'um atendimento em aberto. Aceita JPG, PNG e PDF de até 10 MB. Arquivos não '
                  'são apagados: use Substituir (RN05).',
                  style: tema.textTheme.bodySmall,
                ),
                                if (_podeEditar) ...[
                  const Divider(height: 24),
                  _CompositorExame(
                    temAtendimento: context.read<ExamesCubit>().temAtendimentoAberto,
                    aoSolicitar: _solicitar,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (s.exames.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nenhum exame solicitado.')))
        else
          for (final e in s.exames) _cartaoExame(e, s.arquivos[e.id] ?? const [], s.substituidos),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExamesCubit, ExamesState>(
      builder: (context, state) => switch (state) {
        ExamesInitial() || ExamesLoading() => const Center(child: CircularProgressIndicator()),
        ExamesError(:final mensagem) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mensagem),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.read<ExamesCubit>().carregar(),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        final ExamesSuccess s => _conteudo(s),
      },
    );
  }
}

/// Solicitação de exame inline: guias prontas, tipo, nome e descrição em um só painel.
class _CompositorExame extends StatefulWidget {
  final bool temAtendimento;
  final Future<String?> Function(TipoExame tipo, String nome, String? descricao) aoSolicitar;

  const _CompositorExame({required this.temAtendimento, required this.aoSolicitar});

  @override
  State<_CompositorExame> createState() => _CompositorExameState();
}

class _CompositorExameState extends State<_CompositorExame> {
  final _nomeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TipoExame _tipo = TipoExame.imagem;

  @override
  void initState() {
    super.initState();
    _nomeCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _usarGuia(GuiaModelo g) {
    setState(() {
      _tipo = g.tipo;
      _nomeCtrl.text = g.nome;
      _descCtrl.text = g.descricao;
    });
  }

  Future<void> _solicitar() async {
    final d = _descCtrl.text.trim();
    final erro = await widget.aoSolicitar(_tipo, _nomeCtrl.text.trim(), d.isEmpty ? null : d);
    if (erro == null && mounted) {
      setState(() {
        _nomeCtrl.clear();
        _descCtrl.clear();
        _tipo = TipoExame.imagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Solicitar exame', style: tema.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final g in guiasExame)
              ActionChip(label: Text(g.nome), onPressed: () => _usarGuia(g)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<TipoExame>(
                key: ValueKey(_tipo),
                initialValue: _tipo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo *', border: OutlineInputBorder()),
                items: [
                  for (final t in TipoExame.values) DropdownMenuItem(value: t, child: Text(t.rotulo)),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? _tipo),
              ),
            ),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _nomeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nome do exame *', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Descrição / indicação clínica (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: widget.temAtendimento && _nomeCtrl.text.trim().isNotEmpty ? _solicitar : null,
          icon: const Icon(Icons.add),
          label: const Text('Solicitar exame'),
        ),
        if (!widget.temAtendimento)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Inicie um atendimento na aba Atendimentos para solicitar exames.',
              style: tema.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}