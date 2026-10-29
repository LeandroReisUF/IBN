import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/pacientes/presentation/cubit/pacientes_cubit.dart';
import 'package:ibn/features/pacientes/presentation/cubit/pacientes_state.dart';
import 'tela_form_paciente.dart';

/// Lista de pacientes com busca (RF03.1 + RN03). Esta classe só **fornece** o
/// Cubit; o desenho da tela está em [_PacientesView].
class TelaPacientes extends StatelessWidget {
  const TelaPacientes({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PacientesCubit(
        repositorio: pacientes,
        usuario: auth.usuarioLogado!,
      )..carregar(),
      child: const _PacientesView(),
    );
  }
}

class _PacientesView extends StatefulWidget {
  const _PacientesView();

  @override
  State<_PacientesView> createState() => _PacientesViewState();
}

/// Estado **de tela**: texto da busca e "mostrar inativos". Os dados vêm do Cubit.
class _PacientesViewState extends State<_PacientesView> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';
  bool _mostrarInativos = false;

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  void _abrir({Paciente? paciente}) {
    final podeEditar = politicaAcesso.podeEditarPaciente(auth.usuarioLogado!);
    // O formulário reaproveita o MESMO Cubit (lista e formulário compartilham o estado).
    final cubit = context.read<PacientesCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: TelaFormPaciente(
            paciente: paciente,
            somenteLeitura: !podeEditar,
          ),
        ),
      ),
    );
  }

  String _iniciais(String nome) {
    final partes =
        nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  Widget _erro(String mensagem) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(mensagem),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.read<PacientesCubit>().carregar(),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }

  /// Aplica a busca e o filtro de inativos sobre os pacientes que o Cubit
  /// já entregou filtrados pelo perfil (RN03).
  Widget _sucesso(List<Paciente> visiveis) {
    final termo = _busca.trim().toLowerCase();
    final termoDigitos = somenteDigitos(_busca);
    final filtrados = visiveis.where((p) {
      if (!p.ativo && !_mostrarInativos) return false;
      if (termo.isEmpty) return true;
      return p.nome.toLowerCase().contains(termo) ||
          (termoDigitos.isNotEmpty && p.cpf.contains(termoDigitos));
    }).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    if (filtrados.isEmpty) {
      return const Center(child: Text('Nenhum paciente encontrado.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      itemCount: filtrados.length,
      itemBuilder: (context, i) {
        final p = filtrados[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(_iniciais(p.nome))),
            title: Text(p.nome),
            subtitle: Text('${formatarCpf(p.cpf)}  •  ${formatarTelefone(p.telefone)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!p.ativo) const Chip(label: Text('Inativo')),
                if (p.menorDeIdade) const Chip(label: Text('Menor')),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _abrir(paciente: p),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = auth.usuarioLogado!;
    final podeEditar = politicaAcesso.podeEditarPaciente(usuario);
    final listaGlobal = politicaAcesso.podeVerListaGlobal(usuario);
    final tema = Theme.of(context);

    return BlocBuilder<PacientesCubit, PacientesState>(
      builder: (context, state) => Scaffold(
        floatingActionButton: podeEditar
            ? FloatingActionButton.extended(
                onPressed: () => _abrir(),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Novo paciente'),
              )
            : null,
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _buscaCtrl,
                    onChanged: (v) => setState(() => _busca = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nome ou CPF',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                if (podeEditar)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilterChip(
                        label: const Text('Mostrar inativos'),
                        selected: _mostrarInativos,
                        onSelected: (v) => setState(() => _mostrarInativos = v),
                      ),
                    ),
                  ),
                if (!listaGlobal)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Card(
                      color: tema.colorScheme.secondaryContainer,
                      child: const ListTile(
                        leading: Icon(Icons.lock_outline),
                        title: Text(
                          'Você vê apenas os pacientes com atendimento vinculado a você.',
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: switch (state) {
                    PacientesInitial() || PacientesLoading() =>
                      const Center(child: CircularProgressIndicator()),
                    PacientesError(:final mensagem) => _erro(mensagem),
                    PacientesSuccess(:final pacientes) => _sucesso(pacientes),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}