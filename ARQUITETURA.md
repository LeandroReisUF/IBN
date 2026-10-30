# Arquitetura do projeto ibn (Sistema Clínico)

**Atualizado:** 28/10/2026 · Flutter (Windows, Android, Web) · estado com **Cubit** (`flutter_bloc`)

## 1. Princípios

- **Clean Architecture por features:** cada módulo da clínica é uma pasta em `lib/features/<feature>/`, com três camadas.
- **Cubit** para estado de dados; estado puramente visual (aba, filtro, campo digitado, "mostrar inativos") continua no `State` do widget.
- **Imports sempre `package:ibn/...`** em `lib/` e `test/`. Misturar caminho relativo e `package:` cria duas bibliotecas diferentes para o mesmo arquivo (tipos que "não batem", repositórios globais duplicados).
- **Regras de negócio no app são provisórias:** `PoliticaAcessoService`, as validações e as permissões repetidas nos Cubits só escondem/validam no cliente. Quando existir servidor, as mesmas regras (RN01–RN06) precisam ser repetidas nele.

## 2. Estrutura real (após a migração de 28/10/2026)

```
lib/
├── core/                         compartilhado: especialidade · formadores · log_acesso ·
│                                 politica_acesso_service · procedimento
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
│   │   └── presentation/         cubit/ (atendimentos_cubit, atendimentos_state) · pages/ (tela_prontuario, tela_prontuario_paciente, aba_prontuario)
│   ├── odontograma/
│   │   ├── domain/               odontograma · condicao_odonto · anatomia_dente
│   │   ├── data/                 odontograma_repository · desenhos_dentes
│   │   └── presentation/         pages/ (aba_odontograma, dialogo_evolucao, menu_condicoes) · widgets/ (caixa_dente, desenho_dente)
│   ├── ortodontia/
│   │   ├── domain/               ortodontia            (modelos + repositório juntos, separar ao criar o Cubit)
│   │   └── presentation/         pages/ (aba_ortodontia) · widgets/ (aba_ortodontia_{ficha,arcos,fotos,manutencoes})
│   └── home/
│       └── presentation/         modulos · pages/ (tela_principal, painel_inicial, tela_modulo_em_construcao)
└── main.dart
_quarentena/                      *.dart.old (HOF, exames, documentos, anamnese) — reescrever como features
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
| Prontuário (atendimentos) | ✅ | 🟡 entregue, validar (`PRONTUARIO_APLICAR.md`) | ~17 |
| Odontograma | ✅ | ⬜ | — |
| Ortodontia | ✅ | ⬜ | — |
| Home / Painel | ✅ | ✅ (reusa `AgendamentoCubit`) | — |

Ordem sugerida das próximas migrações de estado: **Painel → Odontograma → Ortodontia → Auth**.
Novas features (HOF, Exames, Documentos, Anamnese) **já nascem** em `features/<nome>/{domain,data,presentation}` com Cubit.

## 5. Pontos de atenção e lições

- `core/politica_acesso_service.dart` importa tipos de features (Agenda, Pacientes). Quando Auth for refatorado, avaliar movê-lo para `features/auth/domain` ou criar um módulo de acesso.
- **Antes de mover arquivos, feche todas as abas do VS Code** (`Ctrl+K W`) e confira que não há arquivo "modificado". Na migração de 28/10, 14 arquivos reapareceram nos caminhos antigos (provavelmente abas abertas recriando o arquivo ao salvar) e formaram uma "cópia paralela" que compilava e escondia imports errados. O script `duplicados.ps1` compara e remove com segurança.
- Disco C: cheio derruba o `flutter test` (erro 112): usar `$env:TEMP = "F:\temp"` se faltar espaço.
- Imports relativos nos testes (`'../lib/...'`) geram bibliotecas duplicadas e testes que falham de forma enganosa.
- `ortodontia.dart` mistura modelos e repositório; separar em `domain/` e `data/` quando fizer o Cubit da Ortodontia.
