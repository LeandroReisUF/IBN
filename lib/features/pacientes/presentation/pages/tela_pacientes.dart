import 'package:flutter/material.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/pacientes/presentation/pages/tela_form_paciente.dart';

/// Lista de pacientes com busca (RF03.1 + RN03).
class TelaPacientes extends StatefulWidget {
  const TelaPacientes({super.key});

  @override
  State<TelaPacientes> createState() => _TelaPacientesState();
}

class _TelaPacientesState extends State<TelaPacientes> {
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaFormPaciente(
          paciente: paciente,
          somenteLeitura: !podeEditar,
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

  @override
  Widget build(BuildContext context) {
    final usuario = auth.usuarioLogado!;
    final podeEditar = politicaAcesso.podeEditarPaciente(usuario);
    final listaGlobal = politicaAcesso.podeVerListaGlobal(usuario);
    final tema = Theme.of(context);

    return ListenableBuilder(
      listenable: pacientes,
      builder: (context, _) {
        // RN03: cada perfil só recebe os pacientes que pode ver.
        final visiveis =
            politicaAcesso.filtrarPacientes(usuario, pacientes.todos);

        final termo = _busca.trim().toLowerCase();
        final termoDigitos = somenteDigitos(_busca);
        final filtrados = visiveis.where((p) {
          if (!p.ativo && !_mostrarInativos) return false;
          if (termo.isEmpty) return true;
          return p.nome.toLowerCase().contains(termo) ||
              (termoDigitos.isNotEmpty && p.cpf.contains(termoDigitos));
        }).toList()
          ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

        return Scaffold(
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
                    child: filtrados.isEmpty
                        ? const Center(child: Text('Nenhum paciente encontrado.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            itemCount: filtrados.length,
                            itemBuilder: (context, i) {
                              final p = filtrados[i];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(_iniciais(p.nome)),
                                  ),
                                  title: Text(p.nome),
                                  subtitle: Text(
                                    '${formatarCpf(p.cpf)}  •  ${formatarTelefone(p.telefone)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!p.ativo)
                                        const Chip(label: Text('Inativo')),
                                      if (p.menorDeIdade)
                                        const Chip(label: Text('Menor')),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: () => _abrir(paciente: p),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}