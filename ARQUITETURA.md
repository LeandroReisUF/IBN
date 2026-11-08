# Arquitetura do projeto ibn (Sistema Clínico)

**Atualizado:** 03/11/2026 (fechamento da Sprint 1) · Flutter (Windows, Android, Web) · estado com **Cubit** (`flutter_bloc`)

## 1. Princípios

- **Clean Architecture por features:** cada módulo da clínica é uma pasta em `lib/features/<feature>/`, com três camadas.
- **Cubit** para estado de dados; estado puramente visual (aba, filtro, campo digitado, "mostrar inativos") continua no `State` do widget.
- **Imports sempre `package:ibn/...`** em `lib/` e `test/`. Misturar caminho relativo e `package:` cria duas bibliotecas diferentes para o mesmo arquivo (tipos que "não batem", repositórios globais duplicados).
- **Regras de negócio no app são provisórias:** `PoliticaAcessoService`, as validações e as permissões repetidas nos Cubits só escondem/validam no cliente. Quando existir servidor, as mesmas regras (RN01–RN06) precisam ser repetidas nele.

## 2. Estrutura real (após a migração de 28/10/2026)

```
lib/
├── core/                         compartilhado: especialidade · formadores · log_acesso ·
│                                 politica_acesso_service · procedimento · lote_aplicado ·
│                                 selecao_arquivo · pdf_simples · widgets/dialogo_lote_aplicado
├── assets/odontograma/           dentes_vestibular.json (o pubspec aponta para ele)
├── features/
│   ├── auth/
│   │   ├── domain/               usuario · perfil
│   │   ├── data/                 auth_service
│   │   └── presentation/         tela_login   (cubit/ vazia)
│   ├── agenda/
│   │   ├── domain/               agendamento · sala
│   │   ├── data/                 agenda_service
│   │   └── presentation/         cubit/ (agendamento_cubit, agendamento_state) · pages/ (tela_agenda, tela_form_agendamento)
│   ├── pacientes/
│   │   ├── domain/               paciente
│   │   ├── data/                 paciente_repository
│   │   └── presentation/         cubit/ (pacientes_cubit, pacientes_state) · pages/ (tela_pacientes, tela_form_paciente)
│   ├── prontuario/
│   │   ├── domain/               prontuario            (Atendimento, Evolução, Adendo)
│   │   ├── data/                 prontuario_repository
│   │   └── presentation/         cubit/ (atendimentos_cubit, atendimentos_state) · pages/ (tela_prontuario, tela_prontuario_paciente, aba_prontuario) · abas_prontuario (registro das abas por perfil)
│   ├── odontograma/
│   │   ├── domain/               odontograma · condicao_odonto · anatomia_dente
│   │   ├── data/                 odontograma_repository · desenhos_dentes
│   │   └── presentation/         pages/ (aba_odontograma, dialogo_evolucao, menu_condicoes) · widgets/ (caixa_dente, desenho_dente)
│   ├── ortodontia/
│   │   ├── domain/               ortodontia            (modelos + repositório juntos, separar ao criar o Cubit)
│   │   └── presentation/         pages/ (aba_ortodontia) · widgets/ (aba_ortodontia_{ficha,arcos,fotos,manutencoes})
│   ├── hof/
│   │   ├── domain/               hof
│   │   ├── data/                 hof_repository
│   │   └── presentation/         cubit/ (hof_cubit, hof_state) · pages/ (aba_hof)
│   ├── exames/
│   │   ├── domain/               exames · resultado_exame
│   │   ├── data/                 exames_repository · resultados_lab_repository
│   │   └── presentation/         cubit/ (exames_cubit, exames_state, resultados_lab_cubit) · pages/ (aba_exames) · widgets/ (secao_resultados_lab)
│   ├── documentos/
│   │   ├── domain/               documentos
│   │   ├── data/                 documentos_repository
│   │   └── presentation/         cubit/ (documentos_cubit, documentos_state) · pages/ (aba_documentos)
│   ├── anamnese/
│   │   ├── domain/               anamnese
│   │   ├── data/                 anamnese_repository
│   │   └── presentation/         cubit/ (anamnese_cubit, anamnese_state) · pages/ (aba_anamnese) · widgets/ (formulario_anamnese)
│   ├── plano_tratamento/
│   │   ├── domain/               plano_tratamento · orcamento_visibilidade   (RN04: a guia do executante não tem campos de dinheiro)
│   │   ├── data/                 plano_repository
│   │   └── presentation/         cubit/ (plano_cubit, plano_state) · pages/ (aba_plano_tratamento)
│   ├── biomedicina/
│   │   ├── domain/               biomedicina
│   │   ├── data/                 biomedicina_repository
│   │   └── presentation/         cubit/ (biomedicina_cubit, biomedicina_state) · pages/ (aba_procedimentos_biomedicina)
│   └── home/
│       └── presentation/         modulos · pages/ (tela_principal, painel_inicial, tela_modulo_em_construcao)
└── main.dart
```

| Camada | O que entra | Pode depender de |
|---|---|---|
| `domain` | entidades, enums, regras puras | só Dart (e `core/`) |
| `data` | serviços/repositórios (memória hoje, API depois) | `domain` |
| `presentation` | Cubit, state, telas, widgets | `domain`, `data` (via Cubit) |

## 3. Convenções do Cubit

- Estados em `sealed class` (o compilador exige tratar todos): `Initial`, `Loading`, `Success(dados)`, `Error(mensagem)`.
- **Erro de regra de negócio** (conflito de sala, CPF duplicado, sem permissão) **não é estado**: a ação devolve `Future<String?>` com a mensagem e a UI mostra um SnackBar. `Error` é só para falha ao carregar.
- O Cubit **escuta** o serviço/repositório (`addListener`) e remove o ouvinte no `close()`. Assim telas que ainda usam o serviço direto continuam consistentes durante a migração.
- Quem fornece o Cubit: `BlocProvider(create: ...)` na raiz da tela. Telas empilhadas que precisam do mesmo Cubit recebem `BlocProvider.value(value: cubit, ...)`. Se não há Cubit por perto, cria-se um com `BlocProvider(create: ...)`.
- Leitura na UI: `BlocBuilder`. `BlocConsumer`/`BlocListener` só se o Cubit passar a emitir eventos únicos.
- Testes: `bloc_test` (`blocTest`) em `test/<nome>_cubit_test.dart`; para provocar `Error`, use uma subclasse do serviço que lança no getter.

## 4. Situação da migração

| Módulo | Estrutura em features | Cubit | Testes do Cubit |
|---|---|---|---|
| Auth / Login | ✅ | ⬜ | — |
| Agenda | ✅ | ✅ | 13 |
| Pacientes | ✅ | ✅ | 16 |
| Prontuário (atendimentos) | ✅ | ✅ | ~17 |
| Odontograma | ✅ | ⬜ | — |
| Ortodontia | ✅ | ⬜ | — |
| Home / Painel | ✅ | ✅ (reusa `AgendamentoCubit`) | — |
| HOF | ✅ | ✅ | ✅ |
| Exames | ✅ | ✅ | ✅ |
| Documentos | ✅ | ✅ | ✅ |
| Anamnese | ✅ | ✅ | ✅ |
| Plano de tratamento | ✅ | ✅ | ✅ |
| Biomedicina | ✅ | ✅ | ✅ |

Ordem sugerida das próximas migrações de estado: **Odontograma → Ortodontia → Auth** (o Painel já usa o `AgendamentoCubit`).
As features novas (HOF, Exames, Documentos, Anamnese, Plano de tratamento e Biomedicina) já nasceram em `features/<nome>/{domain,data,presentation}` com Cubit.

## 5. Pontos de atenção e lições

- `core/politica_acesso_service.dart` importa tipos de features (Agenda, Pacientes). Quando Auth for refatorado, avaliar movê-lo para `features/auth/domain` ou criar um módulo de acesso.
- **Antes de mover arquivos, feche todas as abas do VS Code** (`Ctrl+K W`) e confira que não há arquivo "modificado". Na migração de 28/10, 14 arquivos reapareceram nos caminhos antigos (provavelmente abas abertas recriando o arquivo ao salvar) e formaram uma "cópia paralela" que compilava e escondia imports errados. O script `duplicados.ps1` compara e remove com segurança.
- Disco C: cheio derruba o `flutter test` (erro 112): usar `$env:TEMP = "F:\temp"` se faltar espaço.
- Imports relativos nos testes (`'../lib/...'`) geram bibliotecas duplicadas e testes que falham de forma enganosa.
- `ortodontia.dart` mistura modelos e repositório; separar em `domain/` e `data/` quando fizer o Cubit da Ortodontia.
- Dependências de PDF: `pdf` e `printing`, usadas só por `core/pdf_simples.dart` (gera o PDF e abre a pré-visualização/impressão, inclusive de PDFs anexados). A fonte Roboto em `lib/assets/fontes/` é opcional; sem ela o PDF usa Helvetica. O plugin `printing` baixa o PDFium na primeira compilação para Windows (precisa de internet).
- `MultiPage` (pacote `pdf`) só quebra a página entre widgets: um texto muito longo precisa ser dividido em linhas, senão dá `PdfException: Widget won't fit into the page`.
- `Usuario` ganhou `conselho` e `registroConselho` (opcionais) para os documentos; as contas de teste usam números fictícios.
- Todo `.dart` novo copiado precisa do `import` na tela que o usa; sem ele o `analyze` acusa `undefined_method`.
- **Abas do prontuário por perfil** ficam em `features/prontuario/presentation/abas_prontuario.dart` (`abasDoPerfil`). Para ligar uma aba nova, acrescente-a ali; `tela_prontuario_paciente.dart` não precisa mudar. Perfil sem abas = "em breve" (Sprint 2).
- **Bloqueio extra no encerramento do atendimento:** `ProntuarioRepository.registrarBloqueioEncerramento`. Cada módulo registra o seu (hoje, `DocumentosRepository` bloqueia com rascunho de documento pendente) sem que o prontuário dependa dele.
- **RN04 pela forma dos dados:** `GuiaProcedimentoExecutante` não tem nenhum campo de dinheiro, e o `PlanoCubit` de quem só executa carrega zero planos. Os testes varrem a guia atrás de valor, desconto, total, pagamento e "R$". Valores são guardados em **centavos inteiros**.
- **Visibilidade da Anamnese:** o profissional vê as suas (rascunhos inclusive) e as **assinadas** de colegas da mesma especialidade do modelo; rascunhos de colegas e o modelo geral não são compartilhados.
- **Pendência conhecida (antes do servidor):** `PacienteRepository.temHistorico` só conhece vínculos e atendimentos; precisa consultar todos os módulos (anamnese, plano, exames, documentos etc.), senão um paciente com dados e sem vínculo poderia ser excluído pelo Administrador.
