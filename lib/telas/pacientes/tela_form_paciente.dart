import 'package:flutter/material.dart';
import '../../core/auth_service.dart';
import '../../core/formadores.dart';
import '../../core/paciente.dart';
import '../../core/paciente_repository.dart';
import '../../core/politica_acesso_service.dart';

/// Cadastro / edição / visualização de paciente (RF03.1).
class TelaFormPaciente extends StatefulWidget {
  final Paciente? paciente; // null = novo cadastro
  final bool somenteLeitura;

  const TelaFormPaciente({
    super.key,
    this.paciente,
    this.somenteLeitura = false,
  });

  @override
  State<TelaFormPaciente> createState() => _TelaFormPacienteState();
}

class _TelaFormPacienteState extends State<TelaFormPaciente> {
  final _formKey = GlobalKey<FormState>();

  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _nascCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _whatsCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _respNomeCtrl = TextEditingController();
  final _respCpfCtrl = TextEditingController();
  final _respParentescoCtrl = TextEditingController();
  final _respTelCtrl = TextEditingController();

  bool _aceiteLgpd = false;
  bool _erroLgpd = false;
  bool _optOut = false;
  Set<String> _vinculos = {}; // IDs dos profissionais vinculados

  Paciente? get _original => widget.paciente;
  bool get _editando => _original != null;
  bool get _somenteLeitura => widget.somenteLeitura;

  List<TextEditingController> get _controladores => [
        _nomeCtrl, _cpfCtrl, _nascCtrl, _telCtrl, _whatsCtrl, _emailCtrl,
        _respNomeCtrl, _respCpfCtrl, _respParentescoCtrl, _respTelCtrl,
      ];

  /// A data digitada indica menor de 18 anos?
  bool get _menor {
    final nasc = lerData(_nascCtrl.text);
    return nasc != null && idadeEm(nasc) < 18;
  }

  @override
  void initState() {
    super.initState();
    final p = _original;
    if (p != null) {
      _nomeCtrl.text = p.nome;
      _cpfCtrl.text = formatarCpf(p.cpf);
      _nascCtrl.text = formatarData(p.dataNascimento);
      _telCtrl.text = formatarTelefone(p.telefone);
      _whatsCtrl.text = formatarTelefone(p.whatsapp);
      _emailCtrl.text = p.email;
      final r = p.responsavel;
      if (r != null) {
        _respNomeCtrl.text = r.nome;
        _respCpfCtrl.text = formatarCpf(r.cpf);
        _respParentescoCtrl.text = r.parentesco;
        _respTelCtrl.text = formatarTelefone(r.telefone);
      }
      _aceiteLgpd = true; // já aceito no cadastro original
      _optOut = p.optOutMarketing;
      _vinculos = {...p.profissionaisVinculados};
    }
    // Reconstrói a tela ao digitar a data (para mostrar/ocultar o responsável).
    _nascCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in _controladores) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- validações ----------

  String? _obrigatorio(String? v, String mensagem) =>
      (v == null || v.trim().isEmpty) ? mensagem : null;

  String? _validarTelefone(String? v, {required bool obrigatorio}) {
    final d = somenteDigitos(v ?? '');
    if (d.isEmpty) return obrigatorio ? 'Informe o telefone' : null;
    if (d.length < 10) return 'Telefone incompleto';
    return null;
  }

  String? _validarCpf(String? v, {String? ignorarId, bool checarDuplicado = false}) {
    if (v == null || v.trim().isEmpty) return 'Informe o CPF';
    if (!cpfValido(v)) return 'CPF inválido';
    if (checarDuplicado &&
        pacientes.cpfJaCadastrado(somenteDigitos(v), ignorarId: ignorarId)) {
      return 'CPF já cadastrado';
    }
    return null;
  }

  // ---------- salvar ----------

  void _salvar() {
    final formOk = _formKey.currentState!.validate();
    setState(() => _erroLgpd = !_aceiteLgpd);
    if (!formOk || !_aceiteLgpd) return;

    final novo = Paciente(
      id: _original?.id ?? pacientes.novoId(),
      nome: _nomeCtrl.text.trim(),
      cpf: somenteDigitos(_cpfCtrl.text),
      dataNascimento: lerData(_nascCtrl.text)!,
      telefone: somenteDigitos(_telCtrl.text),
      whatsapp: somenteDigitos(_whatsCtrl.text),
      email: _emailCtrl.text.trim(),
      responsavel: _menor
          ? ResponsavelLegal(
              nome: _respNomeCtrl.text.trim(),
              cpf: somenteDigitos(_respCpfCtrl.text),
              parentesco: _respParentescoCtrl.text.trim(),
              telefone: somenteDigitos(_respTelCtrl.text),
            )
          : null,
      // O aceite original nunca é sobrescrito.
      termoLgpd: _original?.termoLgpd ??
          TermoLGPD(aceitoEm: DateTime.now(), versao: versaoTermoLgpd),
      optOutMarketing: _optOut,
      profissionaisVinculados: _vinculos,
      ativo: _original?.ativo ?? true,
    );

    final mensagem = ScaffoldMessenger.of(context);
    final textoSucesso = _editando ? 'Paciente atualizado.' : 'Paciente cadastrado.';
    pacientes.salvar(novo);
    Navigator.of(context).pop();
    mensagem.showSnackBar(SnackBar(content: Text(textoSucesso)));
  }

  // ---------- vínculo com profissionais (RN03) ----------

  String _rotuloProfissional(String id) {
    final u = auth.buscarPorId(id);
    return u == null ? 'Profissional $id' : '${u.nome} • ${u.perfil.rotulo}';
  }

  Future<void> _adicionarVinculo() async {
    final disponiveis = auth.profissionaisSaude
        .where((u) => !_vinculos.contains(u.id))
        .toList();
    final escolhido = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Vincular profissional'),
        children: [
          if (disponiveis.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Todos os profissionais já estão vinculados.'),
            ),
          for (final u in disponiveis)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(u.id),
              child: Text('${u.nome} • ${u.perfil.rotulo}'),
            ),
        ],
      ),
    );
    if (escolhido != null) setState(() => _vinculos.add(escolhido));
  }

  /// Só Recepção/Admin enxergam esta seção: mostrar a um profissional quais
  /// OUTROS profissionais atendem o paciente vazaria informação (RN03).
  List<Widget> _secaoVinculos() {
    if (!politicaAcesso.podeVincularProfissional(auth.usuarioLogado!)) {
      return const [];
    }
    return [
      _titulo('Profissionais vinculados'),
      Text(
        'O vínculo é com a PESSOA (ex.: Dr. Davi), não com a especialidade. '
        'Cada profissional só vê este paciente se estiver vinculado a ele. '
        'Clique em Salvar para aplicar.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final id in _vinculos)
            InputChip(
              label: Text(_rotuloProfissional(id)),
              onDeleted: _somenteLeitura
                  ? null
                  : () => setState(() => _vinculos.remove(id)),
            ),
          if (_vinculos.isEmpty) const Text('Nenhum profissional vinculado.'),
        ],
      ),
      if (!_somenteLeitura) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _adicionarVinculo,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Vincular profissional'),
        ),
      ],
    ];
  }

  // ---------- inativar / excluir ----------

  Future<bool> _confirmar(String titulo, String texto, String botao) async {
    final resposta = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(botao),
          ),
        ],
      ),
    );
    return resposta ?? false;
  }

  Future<void> _alterarAtivo(bool novoAtivo) async {
    final confirmado = await _confirmar(
      novoAtivo ? 'Reativar paciente?' : 'Inativar paciente?',
      novoAtivo
          ? 'O paciente volta a aparecer na lista normal.'
          : 'O paciente sai da lista padrão, mas todo o histórico é mantido.',
      novoAtivo ? 'Reativar' : 'Inativar',
    );
    if (!confirmado || !mounted) return;
    final mensagem = ScaffoldMessenger.of(context);
    pacientes.definirAtivo(_original!.id, novoAtivo);
    Navigator.of(context).pop();
    mensagem.showSnackBar(
      SnackBar(content: Text(novoAtivo ? 'Paciente reativado.' : 'Paciente inativado.')),
    );
  }

  Future<void> _excluir() async {
    final confirmado = await _confirmar(
      'Excluir definitivamente?',
      'Esta ação não pode ser desfeita. Use apenas para cadastro feito por '
          'engano. Pacientes com histórico não podem ser excluídos.',
      'Excluir',
    );
    if (!confirmado || !mounted) return;
    final mensagem = ScaffoldMessenger.of(context);
    final excluiu = pacientes.excluirSemHistorico(_original!.id);
    if (excluiu) {
      Navigator.of(context).pop();
      mensagem.showSnackBar(const SnackBar(content: Text('Paciente excluído.')));
    } else {
      mensagem.showSnackBar(const SnackBar(
        content: Text('Este paciente tem histórico e não pode ser excluído. Use Inativar.'),
      ));
    }
  }

  List<Widget> _secaoAcoes() {
    if (!_editando) return const [];
    final usuario = auth.usuarioLogado!;
    final podeInativar = politicaAcesso.podeInativarPaciente(usuario);
    final podeExcluir = politicaAcesso.podeExcluirPaciente(usuario);
    if (!podeInativar && !podeExcluir) return const [];
    final paciente = _original!;
    final tema = Theme.of(context);
    return [
      _titulo('Situação do cadastro'),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (podeInativar)
            OutlinedButton.icon(
              onPressed: () => _alterarAtivo(!paciente.ativo),
              icon: Icon(paciente.ativo
                  ? Icons.archive_outlined
                  : Icons.unarchive_outlined),
              label: Text(paciente.ativo ? 'Inativar paciente' : 'Reativar paciente'),
            ),
          if (podeExcluir)
            OutlinedButton.icon(
              onPressed: _excluir,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir definitivamente'),
              style: OutlinedButton.styleFrom(
                foregroundColor: tema.colorScheme.error,
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Inativar mantém todo o histórico. A exclusão definitiva só vale para '
        'cadastro feito por engano, sem nenhum histórico.',
        style: tema.textTheme.bodySmall,
      ),
    ];
  }

  // ---------- visual ----------

  InputDecoration _decoracao(String rotulo, IconData icone) => InputDecoration(
        labelText: rotulo,
        prefixIcon: Icon(icone),
        border: const OutlineInputBorder(),
      );

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
      );

  /// Coloca os campos lado a lado em telas largas, empilhados em telas estreitas.
  Widget _linha(List<Widget> campos, double largura) {
    final duasColunas = largura >= 600 && campos.length > 1;
    final larguraCampo = duasColunas ? (largura - 16) / 2 : largura;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final c in campos) SizedBox(width: larguraCampo, child: c),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final titulo = _somenteLeitura
        ? 'Paciente'
        : (_editando ? 'Editar paciente' : 'Novo paciente');

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          if (!_somenteLeitura)
            TextButton.icon(
              onPressed: _salvar,
              icon: const Icon(Icons.check),
              label: const Text('Salvar'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, restricoes) {
          final largura = (restricoes.maxWidth - 48).clamp(0.0, 800.0).toDouble();
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: largura,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dados pessoais', style: tema.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _linha([
                        TextFormField(
                          controller: _nomeCtrl,
                          readOnly: _somenteLeitura,
                          textCapitalization: TextCapitalization.words,
                          decoration: _decoracao('Nome completo', Icons.person_outline),
                          validator: (v) => _obrigatorio(v, 'Informe o nome'),
                        ),
                      ], largura),
                      const SizedBox(height: 16),
                      _linha([
                        TextFormField(
                          controller: _cpfCtrl,
                          readOnly: _somenteLeitura,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [MascaraFormatter('###.###.###-##')],
                          decoration: _decoracao('CPF', Icons.badge_outlined),
                          validator: (v) => _validarCpf(
                            v,
                            ignorarId: _original?.id,
                            checarDuplicado: true,
                          ),
                        ),
                        TextFormField(
                          controller: _nascCtrl,
                          readOnly: _somenteLeitura,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [MascaraFormatter('##/##/####')],
                          decoration: _decoracao('Nascimento (dd/mm/aaaa)', Icons.cake_outlined),
                          validator: (v) {
                            final d = lerData(v ?? '');
                            if (d == null) return 'Data inválida';
                            if (d.isAfter(DateTime.now()) || d.year < 1900) {
                              return 'Data inválida';
                            }
                            return null;
                          },
                        ),
                      ], largura),

                      _titulo('Contato'),
                      _linha([
                        TextFormField(
                          controller: _telCtrl,
                          readOnly: _somenteLeitura,
                          keyboardType: TextInputType.phone,
                          inputFormatters: const [
                            MascaraFormatter('(##) #####-####',
                                mascaraCurta: '(##) ####-####', digitosCurta: 10),
                          ],
                          decoration: _decoracao('Telefone', Icons.phone_outlined),
                          validator: (v) => _validarTelefone(v, obrigatorio: true),
                        ),
                        TextFormField(
                          controller: _whatsCtrl,
                          readOnly: _somenteLeitura,
                          keyboardType: TextInputType.phone,
                          inputFormatters: const [
                            MascaraFormatter('(##) #####-####',
                                mascaraCurta: '(##) ####-####', digitosCurta: 10),
                          ],
                          decoration: _decoracao('WhatsApp (opcional)', Icons.chat_outlined),
                          validator: (v) => _validarTelefone(v, obrigatorio: false),
                        ),
                      ], largura),
                      const SizedBox(height: 16),
                      _linha([
                        TextFormField(
                          controller: _emailCtrl,
                          readOnly: _somenteLeitura,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _decoracao('E-mail (opcional)', Icons.mail_outline),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return null;
                            return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                                ? null
                                : 'E-mail inválido';
                          },
                        ),
                      ], largura),

                      if (_menor) ...[
                        _titulo('Responsável legal (paciente menor de 18 anos)'),
                        _linha([
                          TextFormField(
                            controller: _respNomeCtrl,
                            readOnly: _somenteLeitura,
                            textCapitalization: TextCapitalization.words,
                            decoration: _decoracao('Nome do responsável', Icons.family_restroom_outlined),
                            validator: (v) => _obrigatorio(v, 'Informe o responsável'),
                          ),
                          TextFormField(
                            controller: _respParentescoCtrl,
                            readOnly: _somenteLeitura,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _decoracao('Parentesco', Icons.diversity_1_outlined),
                            validator: (v) => _obrigatorio(v, 'Informe o parentesco'),
                          ),
                        ], largura),
                        const SizedBox(height: 16),
                        _linha([
                          TextFormField(
                            controller: _respCpfCtrl,
                            readOnly: _somenteLeitura,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [MascaraFormatter('###.###.###-##')],
                            decoration: _decoracao('CPF do responsável', Icons.badge_outlined),
                            validator: (v) => _validarCpf(v),
                          ),
                          TextFormField(
                            controller: _respTelCtrl,
                            readOnly: _somenteLeitura,
                            keyboardType: TextInputType.phone,
                            inputFormatters: const [
                              MascaraFormatter('(##) #####-####',
                                  mascaraCurta: '(##) ####-####', digitosCurta: 10),
                            ],
                            decoration: _decoracao('Telefone do responsável', Icons.phone_outlined),
                            validator: (v) => _validarTelefone(v, obrigatorio: true),
                          ),
                        ], largura),
                      ],

                      ..._secaoVinculos(),
                      _titulo('LGPD e comunicação'),
                      if (_editando)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_user_outlined),
                          title: const Text('Termo LGPD aceito'),
                          subtitle: Text(
                            'Em ${formatarData(_original!.termoLgpd.aceitoEm)} '
                            '(versão ${_original!.termoLgpd.versao})',
                          ),
                        )
                      else ...[
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _aceiteLgpd,
                          onChanged: (v) => setState(() {
                            _aceiteLgpd = v ?? false;
                            _erroLgpd = false;
                          }),
                          title: const Text(
                            'O paciente (ou responsável) leu e aceitou o termo de '
                            'tratamento de dados pessoais (LGPD).',
                          ),
                        ),
                        if (_erroLgpd)
                          Text(
                            'O aceite do termo é obrigatório para cadastrar.',
                            style: TextStyle(color: tema.colorScheme.error),
                          ),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _optOut,
                        onChanged: _somenteLeitura
                            ? null
                            : (v) => setState(() => _optOut = v),
                        title: const Text('Não receber mensagens de marketing'),
                        subtitle: const Text(
                          'Opt-out: o paciente não entra em campanhas de WhatsApp.',
                        ),
                      ),
                      ..._secaoAcoes(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}