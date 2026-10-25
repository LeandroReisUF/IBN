import 'package:flutter/material.dart';
import 'perfil.dart';

/// Um item do menu principal. Se [perfis] for vazio, todos podem ver.
class Modulo {
  final String id;
  final String titulo;
  final IconData icone;
  final Set<Perfil> perfis;

  const Modulo({
    required this.id,
    required this.titulo,
    required this.icone,
    this.perfis = const {},
  });

  bool permitidoPara(Perfil perfil) => perfis.isEmpty || perfis.contains(perfil);
}

const _profissionaisSaude = {
  Perfil.dentista,
  Perfil.biomedico,
  Perfil.medico,
  Perfil.enfermeiro,
  Perfil.fisioterapeuta,
  Perfil.nutricionista,
  Perfil.psicologo,
};

// Permissões PROVISÓRIAS: ajustaremos quando implementarmos o RBAC (RF01.2).
final List<Modulo> modulos = [
  const Modulo(id: 'painel', titulo: 'Painel', icone: Icons.dashboard_outlined),
  const Modulo(id: 'agenda', titulo: 'Agenda', icone: Icons.calendar_month_outlined),
  const Modulo(id: 'pacientes', titulo: 'Pacientes', icone: Icons.people_outline),
  Modulo(
    id: 'prontuario',
    titulo: 'Prontuário',
    icone: Icons.medical_information_outlined,
    perfis: _profissionaisSaude,
  ),
  const Modulo(
    id: 'estoque',
    titulo: 'Estoque',
    icone: Icons.inventory_2_outlined,
    perfis: {
      Perfil.administrador,
      Perfil.recepcionista,
      Perfil.dentista,
      Perfil.biomedico,
      Perfil.enfermeiro,
    },
  ),
  const Modulo(
    id: 'financeiro',
    titulo: 'Financeiro',
    icone: Icons.payments_outlined,
    perfis: {Perfil.administrador, Perfil.recepcionista},
  ),
  const Modulo(
    id: 'whatsapp',
    titulo: 'WhatsApp',
    icone: Icons.chat_outlined,
    perfis: {Perfil.administrador, Perfil.recepcionista},
  ),
  const Modulo(
    id: 'relatorios',
    titulo: 'Relatórios',
    icone: Icons.bar_chart_outlined,
    perfis: {Perfil.administrador},
  ),
];