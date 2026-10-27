import 'package:flutter/material.dart';
import '../../core/auth_service.dart';
import '../../core/formadores.dart';
import '../../core/odontograma.dart';
import '../../core/paciente.dart';
import '../../core/politica_acesso_service.dart';
import '../../core/usuario.dart';

/// Widgets da seção **Ficha Ortodôntica** (Fase F).
class SecaoFichaOrtodontica extends StatelessWidget {
  final Paciente paciente;
  final Usuario usuario;
  final FichaOrtodontica? ficha;
  final bool editandoFicha;
  final VoidCallback onToggleEdicao;
  final VoidCallback onSalvar;
  final TextEditingController queixaCtrl;
  final TextEditingController objetivosCtrl;
  final TextEditingController obsGeraisCtrl;
  final TextEditingController arcoSupFioCtrl;
  final TextEditingController arcoSupCalibreCtrl;
  final TextEditingController arcoInfFioCtrl;
  final TextEditingController arcoInfCalibreCtrl;
  final TextEditingController elastSupCtrl;
  final TextEditingController elastInfCtrl;
  final TipoAparelhoOrto? tipoAparelho;
  final DateTime? dataInstalacao;
  final DateTime? previsaoTermino;
  final ValueChanged<TipoAparelhoOrto?> onTipoAparelhoChanged;
  final VoidCallback onEscolherDataInstalacao;
  final VoidCallback onEscolherPrevisaoTermino;

  const SecaoFichaOrtodontica({
    required this.paciente,
    required this.usuario,
    required this.ficha,
    required this.editandoFicha,
    required this.onToggleEdicao,
    required this.onSalvar,
    required this.queixaCtrl,
    required this.objetivosCtrl,
    required this.obsGeraisCtrl,
    required this.arcoSupFioCtrl,
    required this.arcoSupCalibreCtrl,
    required this.arcoInfFioCtrl,
    required this.arcoInfCalibreCtrl,
    required this.elastSupCtrl,
    required this.elastInfCtrl,
    required this.tipoAparelho,
    required this.dataInstalacao,
    required this.previsaoTermino,
    required this.onTipoAparelhoChanged,
    required this.onEscolherDataInstalacao,
    required this.onEscolherPrevisaoTermino,
  });

  bool get _podeEditar => politicaAcesso.podeEditarOdontograma(usuario, paciente);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final existeFicha = ficha != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ficha Ortodôntica', style: tema.textTheme.titleLarge),
                if (_podeEditar)
                  TextButton.icon(
                    onPressed: onToggleEdicao,
                    icon: Icon(editandoFicha ? Icons.close : Icons.edit),
                    label: Text(editandoFicha ? 'Cancelar' : (existeFicha ? 'Editar' : 'Criar')),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (editandoFicha || !existeFicha)
              _formulario()
            else
              _visualizacao(context, ficha!),
          ],
        ),
      ),
    );
  }

  Widget _formulario() {
    return Column(
      children: [
        DropdownButtonFormField<TipoAparelhoOrto>(
          initialValue: tipoAparelho,
          decoration: const InputDecoration(labelText: 'Tipo de aparelho *', border: OutlineInputBorder()),
          items: [for (final t in TipoAparelhoOrto.values) DropdownMenuItem(value: t, child: Text(t.rotulo))],
          onChanged: _podeEditar ? onTipoAparelhoChanged : null,
          validator: (v) => v == null ? 'Selecione o tipo de aparelho' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _campoData('Data instalação *', dataInstalacao, _podeEditar ? onEscolherDataInstalacao : null)),
            const SizedBox(width: 12),
            Expanded(child: _campoData('Previsão término', previsaoTermino, _podeEditar ? onEscolherPrevisaoTermino : null)),
          ],
        ),
        const SizedBox(height: 12),
        _campoTexto(queixaCtrl, 'Queixa principal *', maxLines: 2, obrigatorio: true),
        const SizedBox(height: 12),
        _campoTexto(objetivosCtrl, 'Objetivos do tratamento *', maxLines: 3, obrigatorio: true),
        const SizedBox(height: 12),
        _campoTexto(obsGeraisCtrl, 'Observações gerais', maxLines: 2),
        const SizedBox(height: 16),
        if (_podeEditar)
          FilledButton.icon(onPressed: onSalvar, icon: const Icon(Icons.save), label: const Text('Salvar ficha')),
      ],
    );
  }

  Widget _visualizacao(BuildContext context, FichaOrtodontica f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _linha(context, 'Tipo de aparelho', f.tipoAparelho.rotulo),
        _linha(context, 'Data instalação', formatarData(f.dataInstalacao)),
        if (f.previsaoTermino != null) _linha(context, 'Previsão término', formatarData(f.previsaoTermino!)),
        _linha(context, 'Queixa principal', f.objetivos),
        if (f.observacoesGerais?.isNotEmpty == true) _linha(context, 'Observações', f.observacoesGerais!),
        _linha(context, 'Criada em', formatarData(f.criadoEm)),
        _linha(context, 'Atualizada em', formatarData(f.atualizadoEm)),
      ],
    );
  }

  Widget _linha(BuildContext context, String label, String valor) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: tema.textTheme.labelMedium)),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }

  Widget _campoData(String label, DateTime? valor, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(valor != null ? formatarData(valor) : 'Toque para escolher'),
      ),
    );
  }

  Widget _campoTexto(TextEditingController ctrl, String label, {int maxLines = 1, bool obrigatorio = false}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label + (obrigatorio ? ' *' : ''), border: const OutlineInputBorder()),
      maxLines: maxLines,
      enabled: _podeEditar,
      validator: obrigatorio ? (v) => v == null || v.trim().isEmpty ? 'Informe $label' : null : null,
    );
  }
}