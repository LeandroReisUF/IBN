import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/auth_service.dart';
import '../../core/formadores.dart';
import '../../core/odontograma.dart';
import '../../core/paciente.dart';
import '../../core/politica_acesso_service.dart';
import '../../core/usuario.dart';

/// Widgets da seção **Fotos Comparativas** (Fase F).
class SecaoFotos extends StatefulWidget {
  final Paciente paciente;
  final Usuario usuario;
  final List<FotoComparativaOrto> fotos;
  final bool podeEditar;

  const SecaoFotos({
    required this.paciente,
    required this.usuario,
    required this.fotos,
    required this.podeEditar,
  });

  @override
  State<SecaoFotos> createState() => _SecaoFotosState();
}

class _SecaoFotosState extends State<SecaoFotos> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fotos Comparativas (Antes/Depois)', style: tema.textTheme.titleLarge),
                if (widget.podeEditar)
                  FilledButton.icon(
                    onPressed: _adicionarFoto,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Adicionar foto'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.fotos.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Nenhuma foto adicionada')))
            else
              Wrap(spacing: 12, runSpacing: 12, children: [for (final f in widget.fotos) _cardFoto(f)]),
          ],
        ),
      ),
    );
  }

  Widget _cardFoto(FotoComparativaOrto f) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
                image: f.caminhoArquivo.startsWith('http')
                    ? DecorationImage(image: NetworkImage(f.caminhoArquivo), fit: BoxFit.cover)
                    : null,
              ),
              child: f.caminhoArquivo.startsWith('http') ? null : const Center(child: Icon(Icons.image, size: 48)),
            ),
          ),
          const SizedBox(height: 4),
          Text(f.descricao, style: Theme.of(context).textTheme.labelLarge),
          Text('${formatarData(f.data)}${f.isAntes ? ' • ANTES' : ''}', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Future<void> _adicionarFoto() async {
    final descCtrl = TextEditingController();
    bool isAntes = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Adicionar foto comparativa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrição (ex.: Inicial, 3 meses, Final)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              CheckboxListTile(title: const Text('É foto "ANTES" (inicial)'), value: isAntes, onChanged: (v) => setState(() => isAntes = v ?? false)),
              const SizedBox(height: 8),
              const Text('Integração com galeria/câmera será implementada.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (descCtrl.text.trim().isEmpty) return;
              final foto = FotoComparativaOrto(
                id: ortodontiaRepository.novoId(),
                pacienteId: widget.paciente.id,
                data: DateTime.now(),
                descricao: descCtrl.text.trim(),
                caminhoArquivo: 'https://via.placeholder.com/300x225?text=${Uri.encodeComponent(descCtrl.text.trim())}',
                isAntes: isAntes,
                profissionalId: widget.usuario.id,
              );
              ortodontiaRepository.adicionarFoto(foto);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto adicionada (placeholder)')));
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    ),
  );
  }
}