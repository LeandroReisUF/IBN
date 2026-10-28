import 'package:flutter/material.dart';
import '../../features/auth/data/auth_service.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/paciente_repository.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'tela_prontuario_paciente.dart';

/// Lista dos pacientes cujo prontuário o profissional pode abrir (RN03).
class TelaProntuario extends StatefulWidget {
  const TelaProntuario({super.key});

  @override
  State<TelaProntuario> createState() => _TelaProntuarioState();
}

class _TelaProntuarioState extends State<TelaProntuario> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = auth.usuarioLogado!;
    final tema = Theme.of(context);

    return ListenableBuilder(
      listenable: pacientes,
      builder: (context, _) {
        final termo = _busca.trim().toLowerCase();
        final termoDigitos = somenteDigitos(_busca);
        final lista = pacientes.todos.where((p) {
          if (!p.ativo || !politicaAcesso.podeAcessarProntuario(usuario, p)) return false;
          if (termo.isEmpty) return true;
          return p.nome.toLowerCase().contains(termo) ||
              (termoDigitos.isNotEmpty && p.cpf.contains(termoDigitos));
        }).toList()
          ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

        return Align(
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
                  child: lista.isEmpty
                      ? const Center(child: Text('Nenhum paciente encontrado.'))
                      : ListView.builder(
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
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}