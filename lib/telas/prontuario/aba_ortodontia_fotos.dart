import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/formadores.dart';
import '../../core/log_acesso.dart';
import '../../core/ortodontia.dart';
import '../../core/paciente.dart';
import '../../core/usuario.dart';

/// Seção **Fotos Comparativas**. Só inclusão (RN05): não há botão de excluir.
/// Usa só `file_picker` e bytes em memória, então funciona em Windows, Android e Web.
class SecaoFotos extends StatefulWidget {
  final Paciente paciente;
  final Usuario usuario;
  final List<FotoComparativaOrto> fotos;
  final bool podeEditar;

  const SecaoFotos({
    super.key,
    required this.paciente,
    required this.usuario,
    required this.fotos,
    required this.podeEditar,
  });

  @override
  State<SecaoFotos> createState() => _SecaoFotosState();
}

class _NovaFoto {
  final String descricao;
  final bool isAntes;
  final String nome;
  final Uint8List bytes;
  const _NovaFoto(this.descricao, this.isAntes, this.nome, this.bytes);
}

class _SecaoFotosState extends State<SecaoFotos> {
  Future<void> _adicionar() async {
    final r = await showDialog<_NovaFoto>(
      context: context,
      builder: (_) => const _DialogoFoto(),
    );
    if (r == null || !mounted) return;

    final mensagem = ScaffoldMessenger.of(context);
    final erro = ortodontiaRepository.adicionarFoto(FotoComparativaOrto(
      id: ortodontiaRepository.novoId(),
      pacienteId: widget.paciente.id,
      data: DateTime.now(),
      descricao: r.descricao,
      nomeArquivo: r.nome,
      bytes: r.bytes,
      isAntes: r.isAntes,
      profissionalId: widget.usuario.id,
    ));
    if (erro != null) {
      mensagem.showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    logsAcesso.registrar(
      usuarioId: widget.usuario.id,
      acao: 'adicionou_foto_orto',
      entidade: 'paciente',
      entidadeId: widget.paciente.id,
    );
    mensagem.showSnackBar(const SnackBar(content: Text('Foto adicionada.')));
  }

  void _ampliar(FotoComparativaOrto f) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(f.bytes, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text('${f.descricao} • ${formatarData(f.data)}')),
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartao(FotoComparativaOrto f) {
    final tema = Theme.of(context);
    return SizedBox(
      width: 180,
      child: InkWell(
        onTap: () => _ampliar(f),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  f.bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image_outlined, size: 40)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(f.descricao, style: tema.textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(formatarData(f.data), style: tema.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _grupo(String titulo, List<FotoComparativaOrto> lista) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(titulo, style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (lista.isEmpty)
          Text('Nenhuma foto.', style: tema.textTheme.bodySmall)
        else
          Wrap(spacing: 12, runSpacing: 12, children: [for (final f in lista) _cartao(f)]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final antes = widget.fotos.where((f) => f.isAntes).toList();
    final depois = widget.fotos.where((f) => !f.isAntes).toList();

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
                    Expanded(child: Text('Fotos comparativas', style: tema.textTheme.titleLarge)),
                    if (widget.podeEditar)
                      FilledButton.icon(
                        onPressed: _adicionar,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Adicionar foto'),
                      ),
                  ],
                ),
                _grupo('Antes (inicial)', antes),
                _grupo('Acompanhamento / depois', depois),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogoFoto extends StatefulWidget {
  const _DialogoFoto();

  @override
  State<_DialogoFoto> createState() => _DialogoFotoState();
}

class _DialogoFotoState extends State<_DialogoFoto> {
  final _descCtrl = TextEditingController();
  bool _antes = false;
  Uint8List? _bytes;
  String? _nome;
  String? _erro;

  static const _limiteBytes = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _descCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolherArquivo() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r == null || r.files.isEmpty) return;
    final arquivo = r.files.first;
    final bytes = arquivo.bytes;
    if (bytes == null) {
      setState(() => _erro = 'Não foi possível ler o arquivo.');
      return;
    }
    if (bytes.length > _limiteBytes) {
      setState(() => _erro = 'A imagem tem mais de 10 MB.');
      return;
    }
    setState(() {
      _bytes = bytes;
      _nome = arquivo.name;
      _erro = null;
    });
  }

  bool get _podeSalvar => _bytes != null && _descCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: const Text('Adicionar foto comparativa'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: _escolherArquivo,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_nome ?? 'Escolher imagem'),
              ),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_erro!, style: TextStyle(color: tema.colorScheme.error)),
                ),
              if (_bytes != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_bytes!, height: 140, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descrição (ex.: Inicial, 3 meses, Final) *',
                  border: OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Foto "ANTES" (inicial)'),
                value: _antes,
                onChanged: (v) => setState(() => _antes = v ?? false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _podeSalvar
              ? () => Navigator.of(context).pop(
                    _NovaFoto(_descCtrl.text.trim(), _antes, _nome!, _bytes!),
                  )
              : null,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}