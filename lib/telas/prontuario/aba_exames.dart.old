import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/auth_service.dart';
import '../../core/formadores.dart';
import '../../core/exames.dart';
import '../../core/log_acesso.dart';
import '../../core/paciente.dart';
import '../../core/politica_acesso_service.dart';

/// Aba de Exames: solicitação, upload resultado, alertas críticos.
class AbaExames extends StatefulWidget {
  final Paciente paciente;
  const AbaExames({super.key, required this.paciente});

  @override
  State<AbaExames> createState() => _AbaExamesState();
}

class _AbaExamesState extends State<AbaExames> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _imagePicker = ImagePicker();

  Paciente get _paciente => widget.paciente;
  Usuario get _usuario => auth.usuarioLogado!;
  bool get _podeEditar => politicaAcesso.podeEditarOdontograma(_usuario, _paciente) || 
      politicaAcesso.podeAcessarProntuario(_usuario, _paciente);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: examesRepository,
      builder: (context, _) {
        final exames = examesRepository.examesDoPaciente(_paciente.id);
        final alertas = examesRepository.alertasValoresCriticos(_paciente.id);
        
        return Column(
          children: [
            _buildHeader(exames, alertas),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Exames'),
                Tab(text: 'Alertas Críticos'),
                Tab(text: 'Arquivos'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildListaExames(exames),
                  _buildAlertas(alertas),
                  _buildArquivos(exames),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
Widget _buildHeader(List<Exame> exames, List<ResultadoLab> alertas) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exames', style: tema.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${exames.length} exame(s)  •  ${alertas.length} alerta(s) crítico(s)',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: alertas.isNotEmpty ? Colors.red : tema.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (_podeEditar)
              FilledButton.icon(
                onPressed: _solicitarExame,
                icon: const Icon(Icons.add),
Widget _buildListaExames(List<Exame> exames) {
    if (exames.isEmpty) {
      return const Center(child: Text('Nenhum exame solicitado'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: exames.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final e = exames[index];
        return _ExameCard(
          exame: e,
          podeEditar: _podeEditar,
          onUploadResultado: () => _uploadResultado(e),
          onVerArquivos: () => _verArquivos(e),
        );
      },
    );
  }

  Widget _buildAlertas(List<ResultadoLab> alertas) {
    if (alertas.isEmpty) {
      return const Center(child: Text('Nenhum valor crítico detectado'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: alertas.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final a = alertas[index];
        return Card(
          color: Colors.red.shade50,
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white)),
            title: Text('${a.analito}: ${a.valor} ${a.unidade}'),
            subtitle: Text('Ref: ${a.refMin?.toStringAsFixed(1) ?? "-"} - ${a.refMax?.toStringAsFixed(1) ?? "-"} ${a.unidade}'),
            trailing: Chip(label: Text(a.foraDoPadrao ? 'FORA DO PADRÃO' : 'OK'), backgroundColor: Colors.red.shade100),
          ),
        );
      },
    );
  }

  Widget _buildArquivos(List<Exame> exames) {
    final todosArquivos = <ArquivoClinico>[];
    for (final e in exames) {
      todosArquivos.addAll(examesRepository.arquivosDoExame(e.id));
    }
    if (todosArquivos.isEmpty) {
      return const Center(child: Text('Nenhum arquivo anexado'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1),
      itemCount: todosArquivos.length,
      itemBuilder: (context, index) {
        final a = todosArquivos[index];
        return _ArquivoCard(arquivo: a);
      },
    );
  }
                label: const Text('Solicitar Exame'),
              ),
          ],
        ),
      ),
    );
  }
