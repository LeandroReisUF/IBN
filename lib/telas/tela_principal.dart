import 'package:flutter/material.dart';
import '../features/auth/data/auth_service.dart';
import 'package:ibn/features/home/presentation/modulos.dart';
import '../features/auth/domain/perfil.dart';
import '../features/auth/domain/usuario.dart';
import 'package:ibn/features/agenda/presentation/pages/tela_agenda.dart';
import 'package:ibn/features/pacientes/presentation/pages/tela_pacientes.dart';
import 'package:ibn/features/prontuario/presentation/pages/tela_prontuario.dart';
import 'package:ibn/features/home/presentation/pages/painel_inicial.dart';
import 'package:ibn/features/home/presentation/pages/tela_modulo_em_construcao.dart';

/// Casca do sistema: menu lateral (Windows/Web) ou gaveta (celular).
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  String _moduloAtualId = 'painel';

  // O usuário vem da sessão (login). Esta tela só aparece com alguém logado.
  Usuario get _usuario => auth.usuarioLogado!;
  Perfil get _perfil => _usuario.perfil;

  List<Modulo> get _menu =>
      modulos.where((m) => m.permitidoPara(_perfil)).toList();

  Modulo get _moduloAtual => _menu.firstWhere(
        (m) => m.id == _moduloAtualId,
        orElse: () => _menu.first,
      );

  void _abrirModulo(Modulo modulo) {
    setState(() => _moduloAtualId = modulo.id);
  }

  Widget _conteudo() {
    final modulo = _moduloAtual;
    if (modulo.id == 'painel') {
      return PainelInicial(perfil: _perfil, nomeUsuario: _usuario.nome);
    }
    if (modulo.id == 'agenda') return const TelaAgenda();
    if (modulo.id == 'pacientes') return const TelaPacientes();
    if (modulo.id == 'prontuario') return const TelaProntuario();
    return TelaModuloEmConstrucao(modulo: modulo);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricoes) {
        final telaLarga = restricoes.maxWidth >= 800;
        final menuExpandido = restricoes.maxWidth >= 1100;
        final menu = _menu;
        final indice = menu.indexWhere((m) => m.id == _moduloAtual.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(_moduloAtual.titulo),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Conta',
                icon: const Icon(Icons.account_circle_outlined),
                onSelected: (valor) {
                  if (valor == 'sair') auth.sair();
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text('${_usuario.nome}\n${_perfil.rotulo}'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'sair',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Sair'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: telaLarga
              ? null
              : Drawer(
                  child: SafeArea(
                    child: ListView(
                      children: [
                        ListTile(
                          title: Text(_usuario.nome),
                          subtitle: Text(_perfil.rotulo),
                        ),
                        const Divider(),
                        for (final m in menu)
                          ListTile(
                            leading: Icon(m.icone),
                            title: Text(m.titulo),
                            selected: m.id == _moduloAtual.id,
                            onTap: () {
                              Navigator.of(context).pop(); // fecha a gaveta
                              _abrirModulo(m);
                            },
                          ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Sair'),
                          onTap: auth.sair,
                        ),
                      ],
                    ),
                  ),
                ),
          body: Row(
            children: [
              if (telaLarga)
                NavigationRail(
                  extended: menuExpandido,
                  selectedIndex: indice,
                  onDestinationSelected: (i) => _abrirModulo(menu[i]),
                  labelType: menuExpandido
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: [
                    for (final m in menu)
                      NavigationRailDestination(
                        icon: Icon(m.icone),
                        label: Text(m.titulo),
                      ),
                  ],
                ),
              if (telaLarga) const VerticalDivider(width: 1),
              Expanded(child: _conteudo()),
            ],
          ),
        );
      },
    );
  }
}