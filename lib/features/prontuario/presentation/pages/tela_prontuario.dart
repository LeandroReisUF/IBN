import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/pacientes/presentation/cubit/pacientes_cubit.dart';
import 'package:ibn/features/pacientes/presentation/cubit/pacientes_state.dart';
import 'tela_prontuario_paciente.dart';

/// Lista dos pacientes cujo prontuário o profissional pode abrir (RN03).
/// Reaproveita o [PacientesCubit] (que já entrega só os pacientes que o
/// perfil pode ver) e aplica a regra do prontuário por cima.
class TelaProntuario extends StatelessWidget {
  const TelaProntuario({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PacientesCubit(
        repositorio: pacientes,
        usuario: auth.usuarioLogado!,
      )..carregar(),
      child: const _ProntuarioView(),
    );
  }
}

class _ProntuarioView extends StatefulWidget {
  const _ProntuarioView();

  @override
  State<_ProntuarioView> createState() => _ProntuarioViewState();
}

class _ProntuarioViewState extends State<_ProntuarioView> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Widget _lista(List<Paciente> recebidos) {
    final usuario = auth.usuarioLogado!;
    final termo = _busca.trim().toLowerCase();
    final termoDigitos = somenteDigitos(_busca);
    final lista = recebidos.where((p) {
      if (!p.ativo || !politicaAcesso.podeAcessarProntuario(usuario, p)) return false;
      if (termo.isEmpty) return true;
      return p.nome.toLowerCase().contains(termo) ||
          (termoDigitos.isNotEmpty && p.cpf.contains(termoDigitos));
    }).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    if (lista.isEmpty) {
      return const Center(child: Text('Nenhum paciente encontrado.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: lista.length,
      itemBuilder: (context, i) {
        final p = lista[i];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(p.nome),
            subtitle: Text('${idadeEm(p.dataNascimento)} anos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TelaProntuarioPaciente(paciente: p),
              ),
            ),
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return BlocBuilder<PacientesCubit, PacientesState>(
      builder: (context, state) => Align(
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
                    hintText: 'Buscar paciente por nome ou CPF',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Card(
                  color: tema.colorScheme.secondaryContainer,
                  child: const ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text(
                      'Você vê apenas pacientes vinculados a você. Cada abertura de prontuário é registrada.',
                    ),
                  ),
                ),
              ),
              Expanded(
                child: switch (state) {
                  PacientesInitial() || PacientesLoading() =>
                    const Center(child: CircularProgressIndicator()),
                  PacientesError(:final mensagem) => _erro(mensagem),
                  PacientesSuccess(:final pacientes) => _lista(pacientes),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}