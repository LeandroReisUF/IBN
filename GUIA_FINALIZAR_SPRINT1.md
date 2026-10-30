# Guia para concluir a Sprint 1 — ibn (Sistema Clínico)

**Data do guia:** 29/10/2026 · **Uso:** documento de passagem de contexto para uma nova conversa. A nova conversa **não** tem o histórico nem o código; tudo o que ela precisa saber está aqui, mais os arquivos que o usuário anexar (lista na seção 11).

---

## 0. Como usar este guia na nova aba

1. O usuário anexa este arquivo, o PDF de requisitos (`0 - Sistema Clinico.pdf`), `ARQUITETURA.md`, `STATUS_PROJETO.md` e os arquivos de referência do passo atual (seção 11).
2. Primeira mensagem sugerida:
   > "Leia o GUIA_FINALIZAR_SPRINT1.md. Vamos executar a seção 6, **um passo por vez**, começando pelo Passo 0. Siga o protocolo da seção 4."
3. A conversa deve avançar **um passo de cada vez**, esperando o resultado de `flutter analyze`, `flutter test` e do roteiro manual antes do próximo.

---

## 1. O projeto

- **Sistema clínico** para uma clínica multidisciplinar com 4 salas físicas. Meta: rodar **local**, na **rede wifi** da clínica e na **web**; multitelas; **Windows (foco atual), Android e Web** com a mesma base Flutter.
- Especialidades: Medicina, Enfermagem, Fisioterapia, Nutrição, Psicologia (Salas 1 e 2, revezamento), **Odontologia + Harmonização Orofacial** (Sala 3, exclusiva), **Biomedicina** (Sala 4, exclusiva).
- **Fase atual:** somente front-end Flutter, dados **em memória** (somem ao fechar). Servidor/API/PostgreSQL entram no "marco do servidor", **depois** da Sprint 1 e **antes** da Sprint 2.
- Requisitos completos no PDF (RN01–RN06, RF01–RF09, RNF01–RNF05). Diagramas de classe (Mermaid) em `diagramas_de_classe_sistema_clinico.md`.

### Regras de negócio que mais pesam na Sprint 1

| Regra | Resumo |
|---|---|
| RN01 | Salas 1 e 2 em revezamento (Medicina, Enfermagem, Fisio, Nutrição, Psicologia); Sala 3 só Odontologia/HOF; Sala 4 só Biomedicina |
| RN02 | Sem choque de sala nem de profissional |
| RN03 | Profissional só vê dados dos pacientes **vinculados a ele** (vínculo por **pessoa**, não por especialidade); lista global só Recepção/Admin |
| RN04 | Dentista executante recebe só a especificação clínica do procedimento encaminhado; **valores, totais, pagamento e descontos ficam ocultos** (visíveis ao criador do plano e ao Admin) |
| RN05 | Evolução assinada, laudo assinado, prescrição emitida e atestado salvo **não se alteram nem se excluem** após o encerramento da sessão; correção só por **adendo datado e assinado** |
| RN06 | Baixa de toxina, preenchedores, anestésicos e reagentes exige **lote e validade** vinculados ao atendimento/prontuário (o estoque completo é Sprint 2, mas lote e validade já são registrados na Sprint 1) |
| RNF03 | Logs de acesso auditáveis a prontuários (LGPD); conformidade com conselhos (CFM, CFO, CRBM, CFF, CFP, CREFITO) |

### Escopo da Sprint 1 (conforme o PDF)

Infra/segurança base (RBAC, RN03, **RN04**) · cadastro de pacientes · agenda multissala · **Odontologia** (anamnese, odontograma, mapeamento/ficha de HOF, exames: solicitação + upload de radiografias/PDF, prescrição/atestados/TCLE com modelos e impressão) · **Biomedicina** (anamnese estética, ficha de procedimentos estéticos com lotes, inclusão de exames e laudos em PDF com alerta de valores fora do padrão).

---

## 2. Ambiente e preferências do usuário

- **Windows**, VS Code, PowerShell. Projeto em `F:\UAST\Projetos\ibn`. O disco **C: costuma encher** → se `flutter test` falhar com `errno 112 / Espaço insuficiente`, rodar antes: `$env:TEMP = "F:\temp"; $env:TMP = "F:\temp"`.
- Idioma: **português do Brasil**. Prefere instruções **claras e procedimentais**, passo a passo; faz as alterações manualmente no VS Code.
- A IA **não executa código** no ambiente do usuário. Tudo que for entregue deve ser dito como *"não compilado"* até o usuário confirmar `analyze`/`test`.
- Nunca usar `>>`, `echo` ou `Set-Content` do PowerShell para gerar código (corrompeu arquivos com UTF‑16). Edição no VS Code ou, em scripts, `[System.IO.File]::WriteAllText(..., UTF8 sem BOM)`.
- **Fechar todas as abas do VS Code antes de mover/colar arquivos** (abas abertas recriaram 14 arquivos nos caminhos antigos numa migração anterior).

---

## 3. Arquitetura e convenções (resumo; detalhes em `ARQUITETURA.md`)

- **Clean Architecture por features:** `lib/features/<feature>/{domain,data,presentation}`; `presentation/cubit/`, `pages/`, `widgets/`. Estado com **Cubit** (`flutter_bloc`; testes com `bloc_test`). Compartilhado em `lib/core/`.
- **Pacote chama-se `ibn`. Em `lib/` e `test/`, SEMPRE `import 'package:ibn/...'`.** Misturar caminho relativo cria bibliotecas duplicadas (tipos "que não batem", repositórios globais duplicados e testes que falham de forma enganosa).
- Dart 3 / Flutter recente: `sealed class`, records, pattern matching, `DropdownButtonFormField(initialValue: ...)`, `Color.withValues(alpha:)`.
- Modelos **imutáveis** (`final`, construtor `const`, `copiarCom`). Repositórios em memória: `class XRepository extends ChangeNotifier` + instância global (`final x = XRepository();`). Regras retornam **`String?`** (mensagem de erro ou `null` se deu certo).
- Identificadores sem acento; textos de interface em português **com** acento.

### Padrão de Cubit (copiar o estilo)

```dart
sealed class XState { const XState(); }
final class XInitial extends XState { const XInitial(); }
final class XLoading extends XState { const XLoading(); }
final class XSuccess extends XState { final List<Algo> itens; const XSuccess(this.itens); }
final class XError extends XState { final String mensagem; const XError(this.mensagem); }

class XCubit extends Cubit<XState> {
  XCubit({required XRepository repositorio, required Usuario usuario})
      : _repo = repositorio, _usuario = usuario, super(const XInitial()) {
    _repo.addListener(_aoMudar);            // outras telas mexem no repositório
  }
  Future<void> carregar() async { emit(const XLoading()); try { emit(XSuccess(await _buscar())); } catch (_) { emit(const XError('...')); } }
  void _aoMudar() { if (state is XSuccess) _atualizarSemLoading(); }   // não "ressuscita" Error
  Future<String?> acao(...) async { /* trava de permissão + repo + log */ return null; }
  @override Future<void> close() { _repo.removeListener(_aoMudar); return super.close(); }
}
```

Regras do padrão:
1. **Erro de regra de negócio (conflito, CPF duplicado, sem permissão) NÃO é estado**: a ação devolve `Future<String?>` e a UI mostra SnackBar. `Error` é só para falha ao carregar.
2. O Cubit **escuta** o repositório (`addListener`) e remove no `close()`.
3. UI: `BlocProvider(create: ... ..carregar())` na raiz da tela + `BlocBuilder` com `switch (state)`. Telas empilhadas que precisam do **mesmo** Cubit: `BlocProvider.value(value: cubit, ...)`; sem Cubit por perto: criar um com `BlocProvider(create: ...)`.
4. Pegar `context.read<Cubit>()` **antes** de `await`; checar `mounted` depois.
5. Filtros puramente visuais (busca, período, "mostrar inativos") ficam no `State` do widget.
6. Ações do Cubit repetem a trava de acesso (`politicaAcesso`) e registram `logsAcesso` (RNF03). Isso é só 2ª trava: **a regra real tem que existir no servidor depois**.
7. Testes de Cubit: `blocTest`; para provocar `Error`, subclasse do repositório que lança no getter; para estados após ações encadeadas, `await Future<void>.delayed(Duration.zero)` ("pump").

---

## 4. Protocolo de entrega por passo (como a IA deve trabalhar)

Para **cada** passo da seção 6:

1. **Antes de escrever:** confirmar quais arquivos de referência o usuário anexou (seção 11). Se faltar algum que o passo precisa, **pedir** em vez de adivinhar nomes de classes.
2. Entregar **arquivos completos** (não fragmentos soltos) em `features/<nome>/...` + `test/<nome>_test.dart`. Para arquivos existentes que mudam, entregar o arquivo inteiro quando for curto; quando longo, dar **substituições exatas** (método inteiro para colar) num `<PASSO>_APLICAR.md`.
3. `<PASSO>_APLICAR.md` com: tabela origem→destino dos arquivos; edições manuais numeradas (A, B, C…); **roteiro manual** em checkboxes com as contas de teste; critérios de aceite.
4. Dizer que o código **não foi compilado**. Pedir o resultado de `flutter analyze`, `flutter test` e do roteiro.
5. Só depois de o usuário confirmar, **atualizar** `STATUS_PROJETO.md`, `ARQUITETURA.md` (tabela de migração) e `diagramas_de_classe_sistema_clinico.md` (mapa de arquivos, seção 13). Marcar ✅ **só o que foi validado**.
6. Pontos de decisão do negócio: perguntar **uma** pergunta objetiva, com opções e uma sugestão.

Padrões de integridade (RN05) já usados — manter a coerência:
- **Evolução/documento assinado = imutável** (correção por adendo).
- **Registro só de inclusão + retificação** (`retificaId` aponta para o registro corrigido; o errado aparece riscado; "anular" = registro que retifica sem substituir) — usado no odontograma e nas manutenções ortodônticas. **Não existe botão excluir** para dado clínico.
- Rascunho (não assinado) pode ser editado/descartado.

---

## 5. Estado atual (29/10/2026) — o que está pronto e validado

`flutter analyze`: sem erros · `flutter test`: todos passando (≈154) · roteiros manuais OK.

| Módulo | Estrutura em features/ | Cubit | Observações |
|---|---|---|---|
| Auth / Login (RF01.1) | ✅ | ⬜ | contas de teste; sem hash/2FA (servidor) |
| Pacientes (RF03.1) | ✅ | ✅ `PacientesCubit` | LGPD, responsável legal, inativar/excluir, vínculos |
| Agenda (RF02, RN01, RN02) | ✅ | ✅ `AgendamentoCubit` | dia/semana/mês, por sala/profissional, status, conflitos |
| Prontuário base (RF03, RN05) | ✅ | ✅ `AtendimentosCubit` | Atendimento → Evolução (rascunho→assinada, selo) → Adendo → Encerrar; ligado à Agenda e ao `LogAcesso` |
| Odontograma (RF04.1) | ✅ | ⬜ | Fases A–E: desenho 2D, caixa dividida, condições/status/retificação, raízes, decíduos, marcas ortodônticas |
| Ortodontia (extra) | ✅ | ⬜ | ficha (versões), arcos/elásticos, manutenções (retificação), fotos com upload real |
| Home / Painel | ✅ | ⬜ | `PainelInicial` ainda lê `AgendaService` direto |

### O que ainda falta na Sprint 1

| Item | Requisito | Situação |
|---|---|---|
| Painel inicial usando o Cubit da Agenda | refatoração | ⬜ (pequeno) |
| **HOF** (ficha, pontos, lote/validade, fotos antes/depois) | RF04.2, RN06 | ⬜ só aba "em breve" |
| **Exames** (solicitação/guia + upload JPG/PNG/PDF) | RF04.3 | ⬜ só aba "em breve" |
| **Documentos** (prescrição, atestado, TCLE; modelos; PDF) | RF04.4 | ⬜ só aba "em breve" |
| **Anamnese** configurável por área | RF03.3 | ⬜ |
| **Plano de tratamento/orçamento com sigilo ao executante** | RF04.5, **RN04** | ⬜ (está na Sprint 1 do PDF) |
| **Biomedicina** (anamnese estética, ficha de procedimentos com lote, laudos/exames com alerta) | RF05 | ⬜ não iniciada |
| Fechamento: abas ligadas, builds, docs | — | ⬜ |

### Arquivos em quarentena (`_quarentena/*.dart.old`) — NÃO reaproveitar o código, só as ideias

Tentativas anteriores, corrompidas e que não compilam: `hof`, `exames`, `documentos`, `aba_hof*`, `aba_exames`, `aba_documentos`, `aba_anamnese`. As ideias de modelo que valem aproveitar estão resumidas nos passos da seção 6. **Reescrever do zero**, já em `features/`.

---

## 6. Plano de passos (ordem recomendada)

Cada passo termina com **analyze limpo + testes + roteiro manual**. Faça **um** por vez.

### Passo 0 — Painel inicial consumindo o `AgendamentoCubit` (pequeno)

- Hoje: `features/home/presentation/pages/painel_inicial.dart` usa `ListenableBuilder(listenable: agenda)` + `politicaAcesso.filtrarAgenda` + `agenda.salaOcupadaAgora`.
- Fazer: `BlocProvider(AgendamentoCubit ..carregar())` + `switch` por estado; contar "agendamentos de hoje", "na recepção", "em atendimento" a partir de `AgendamentoSuccess.consultas`; para o cartão de salas, expor no Cubit algo como `bool salaOcupadaAgora(int sala, DateTime agora)` (delegando ao serviço) **ou** calcular a partir de `consultas` (só para Recepção/Admin, que recebem a lista completa).
- Aceite: números idênticos aos de antes; muda sozinho ao mudar status na Agenda/Prontuário.
- Atualizar `ARQUITETURA.md` (Home ✅ Cubit).

### Passo 1 — HOF (`features/hof`) — RF04.2, RN06

**Domain** (imutável): `TipoHOF` (toxinaBotulinica, preenchimento, bioestimulador, fiosSustentacao, outro), `AreaFace` (testa, glabela, periorbital, malar, nariz, labios, mento, mandibula, perioral, cervical…), `LadoFace` (esquerdo, direito, bilateral, linhaMedia), `PontoAplicacao` (área, lado, quantidade, profundidade opcional, técnica), **`LoteAplicado`/`InsumoHOF`** (produto, marca, **lote**, **validade**, quantidade, unidade UI/ml; `vencido`), `ProcedimentoHOF` (tipo, pontos, insumos, observações, data/hora, profissionalId, pacienteId, `atendimentoId`, `retificaId`), `FotoComparativaHOF` (reusar o padrão das fotos da Ortodontia: bytes em memória + `file_picker`).
- Colocar a classe de **lote aplicado em local compartilhado** (ex.: `lib/core/lote_aplicado.dart`) — será reutilizada na Biomedicina e no Estoque (Sprint 2).

**Regras (no repositório e no Cubit):** só dentista **vinculado** (`podeEditarOdontograma`/`podeAcessarProntuario`); procedimento registrado **dentro de um atendimento em aberto**; **RN06:** lote e validade obrigatórios para toxina/preenchimento/bioestimulador; **validade vencida é recusada**; registro só de inclusão + **retificação** (sem excluir); `LogAcesso` em cada ação.

**Mapeamento facial:** fase 1 = lista de pontos por região/lado (dropdowns); fase 2 (opcional) = diagrama facial desenhado com `CustomPainter` (desenho **próprio**, sem copiar imagens de terceiros) com pontos normalizados (x,y de 0 a 1).

**UI:** aba "Harmonização (HOF)" no prontuário do dentista: lista de procedimentos, diálogo de novo procedimento (tipo, pontos, insumos com lote), galeria antes/depois.
**Testes:** lote vencido recusado; lote obrigatório; só vinculado registra; retificar mantém o original; exige atendimento aberto; Cubit (carregar/erro/reação/ações).
**Aceite:** registrar toxina com 3 pontos e lote → aparece; lote vencido → erro; Dra. Lúcia (sem vínculo) não acessa.

### Passo 2 — Exames e arquivos clínicos (`features/exames`) — RF04.3

**Domain:** `Exame` (tipo: imagem/laboratorial/…; nome; status: solicitado→realizado→resultadoDisponível/cancelado; datas; solicitante), `ArquivoClinico` (nome, mimeType, bytes, tamanho, enviadoEm, enviadoPor), `GuiaSolicitacao` (modelos prontos: periapical, panorâmica, tomografia, exames de sangue pré-operatórios).
**Funcional:**
- Solicitar exame (vinculado ao atendimento) e **imprimir a guia** em PDF (usa a mesma infraestrutura de PDF do Passo 3 — se o Passo 3 ainda não existir, deixar a guia como tela imprimível ou adiar a impressão para o Passo 3).
- Upload **JPG, PNG, PDF** (`file_picker`, `withData: true`, limite ~10 MB, bytes em memória — funciona em Windows/Android/Web). Imagens: visualizador com zoom (`InteractiveViewer` + `Image.memory`). PDF: nome/tamanho + abrir/imprimir via `printing` (`Printing.layoutPdf` com os bytes) — **confirmar no ambiente**.
- **Extrair um widget/serviço de seleção de arquivo reutilizável** a partir de `features/ortodontia/.../aba_ortodontia_fotos.dart` (diálogo de escolher arquivo + preview), para HOF, Exames e Biomedicina reutilizarem.
- Laudo anexado é **imutável** (RN05): sem excluir; substituir = novo arquivo + justificativa (retificação).
- `ResultadoLab` (analito, valor, unidade, refMin, refMax, `foraDoPadrao`) fica pronto aqui para a Biomedicina (Passo 6).

**Testes:** upload aceita só tipos permitidos; arquivo > limite recusado; status do exame; RN03. **Aceite:** solicitar, anexar radiografia e PDF, ver/zoom.

### Passo 3 — Documentos clínicos (`features/documentos`) — RF04.4

- Dependências: `flutter pub add pdf printing`. Cuidado com fontes: usar fonte **embutida** (asset TTF, ex.: Open Sans/Roboto) para acentuação correta em PDF.
- **Pré-requisito de dados:** o `Usuario` **não tem registro de conselho** (CRO/CRM/CRBM…). Acrescentar `conselho` e `registroConselho` (opcionais) em `Usuario`, preenchidos nas contas de teste (ex.: Dr. Davi "CRO-PE 12345"), para o auto-preenchimento.
- **Domain:** `TipoDocumento` (prescricaoSimples, controleEspecial, atestado, tcle, declaracao…), `ModeloDocumento` (nome, tipo, especialidade, corpo com `{{variaveis}}`, variáveis obrigatórias, versão; `preencher(valores)`), `DocumentoClinico` (paciente, atendimento, profissional, conteúdo **já preenchido**, emitidoEm, assinado, selo, tipo; subtipos opcionais Prescricao/Atestado/TCLE com campos próprios). **Documento assinado = imutável** (RN05); correção = novo documento/adendo.
- **Funcional:** biblioteca de modelos **editáveis** (seed: receituário simples, controle especial, atestado, TCLE odontológico); auto-fill de paciente (nome, CPF), data e profissional (nome + registro); pré-visualização; gerar PDF pronto para assinatura; histórico de documentos emitidos; assinar (selo) bloqueia edição.
- Aviso ao usuário: os modelos e exigências de receituário de controle especial seguem normas dos conselhos/vigilância — **validar os textos com os profissionais da clínica**.
- **Testes:** `preencher` (variável faltando é sinalizada), imutabilidade após assinar, auto-fill, RN03. **Aceite:** gerar atestado a partir do modelo e ver o PDF.
- Se o Passo 2 deixou a guia de exame sem PDF, ligar agora.

### Passo 4 — Anamnese configurável (`features/anamnese`) — RF03.3

**Domain:** `TipoResposta` (texto, textoLongo, simNao, escolhaUnica, multiplaEscolha, escala, data), `PerguntaAnamnese` (enunciado, tipo, obrigatória, opções, ajuda), `ModeloAnamnese` (nome, **especialidade**, versão, perguntas), `Anamnese` (paciente, atendimento opcional, `modeloId` + **versão**, respostas `Map<perguntaId, String>`, profissional, preenchidaEm, assinada).
- **Seed de modelos:** Odontologia (histórico médico, alergias, medicações, hábitos, queixa), Biomedicina estética (**fototipo Fitzpatrick I–VI**, contraindicações, histórico alérgico, patologias, gestação/lactação, uso de isotretinoína…), Geral.
- **UI:** renderizador **dinâmico** de formulário a partir do modelo (validando obrigatórias); lista do histórico; anamnese assinada é imutável (nova anamnese = nova versão, histórico mantido).
- **Testes:** validação de obrigatórias, serialização de respostas, imutabilidade. **Aceite:** preencher a anamnese odontológica da Maria e reabrir.

### Passo 5 — Plano de tratamento e orçamento com sigilo ao executante (`features/plano_tratamento`) — RF04.5, **RN04**

**Domain:** `PlanoTratamento` (paciente, **criador**, status, itens), `ItemPlano` (procedimentoId, dente, **valor**, **desconto**, status, `executanteId` opcional), `Orcamento` (total, forma de pagamento, parcelas), `Encaminhamento` (item → outro dentista, instruções clínicas), **`GuiaProcedimentoExecutante` (view model SEM nenhum campo de valor)**.
**Regra central:** o executante recebe **somente** a `GuiaProcedimentoExecutante` (procedimento, dente, instruções clínicas). Valores/descontos/pagamento ficam visíveis só ao **criador do plano** e ao **Administrador**. Garantir **pela forma dos dados** (a classe da guia não tem campo de dinheiro) e por `OrcamentoVisibilidadeService.podeVerValores(usuario, plano)`, além de testes que varrem a guia.
**Funcional:** criar plano a partir do odontograma/procedimentos; encaminhar item para a Dra. Lúcia; ela vê a guia sem valores e marca "realizado"; o Dr. Davi/Admin veem tudo.
**Testes:** `podeVerValores` (criador/admin sim; executante/outros não); a guia não expõe valores; encaminhar e executar. **Aceite:** como Dra. Lúcia, abrir a guia e **não encontrar nenhum valor** na tela nem na árvore de estado.
- Observação: o módulo financeiro completo (contas a receber, repasses) é Sprint 2; aqui entram só os valores do plano.

### Passo 6 — Biomedicina (`features/biomedicina`) — RF05 (Sala 4)

- **Prontuário do biomédico:** hoje, para perfis não-dentistas, `tela_prontuario_paciente.dart` mostra "em breve". Criar o conjunto de abas do **Biomédico** (conta de teste **Bia Biomédica**, `biomedico@clinica.local`, id 4): **Atendimentos** (reutilizar `AbaProntuario`), **Anamnese estética** (Passo 4), **Procedimentos**, **Exames/Laudos**. Perfis como **Psicologia continuam "em breve"** (exige sigilo reforçado/criptografia, RF06.3, Sprint 2).
- **Anamnese estética (RF05.1):** modelo do Passo 4 (contraindicações, histórico alérgico, fototipo, patologias).
- **Ficha de procedimentos estéticos (RF05.2):** `TipoProtocolo` (peeling, microagulhamento, intradermoterapia, outro), região tratada, parâmetros, data, atendimento, **insumos aplicados com lote e validade (RN06)** usando o `LoteAplicado` compartilhado; só inclusão + retificação.
- **Exames e laudos (RF05.3):** reutilizar `Exame`/`ArquivoClinico` do Passo 2; incluir **resultados estruturados** (`ResultadoLab`) com **sinalização visual de valores fora do padrão** e upload de laudo PDF vinculado à ficha.
- Procedimentos do catálogo já existentes para a Sala 4: `peeling`, `microagulhamento`, `coleta-exames`.
- **Testes:** `foraDoPadrao`, lote/validade obrigatórios, RN03 (só o biomédico vinculado), retificação. **Aceite:** registrar peeling com lote, incluir hemograma com um valor alto → alerta visível.

### Passo 7 — Fechamento da Sprint 1

1. **Ligar as abas** em `tela_prontuario_paciente.dart` (dentista: Odontograma, Ortodontia, Atendimentos, Anamnese, HOF, Exames, Documentos, Plano; biomédico: conjunto do Passo 6). Considerar um pequeno "registro de abas por perfil" para evitar `if` espalhado.
2. Remover `_quarentena/` quando nada mais for consultado.
3. `flutter analyze` limpo; `flutter test` completo (meta ≥ 200 testes).
4. Builds: `flutter build windows --debug`, `flutter build apk --debug`, `flutter build web`; conferir telas em largura de celular (< 600 px).
5. Atualizar `STATUS_PROJETO.md`, `ARQUITETURA.md`, `diagramas_de_classe_sistema_clinico.md`, `CHECKLIST_SPRINT1.md`, `PROXIMOS_PASSOS_SPRINT1.md`.
6. **Revisão final de RN03/RN04/RN05/RN06** com um roteiro manual por perfil (Admin, Recepção, Dr. Davi, Dra. Lúcia, Bia).
7. Listar pendências para o **marco do servidor** (seção 9).

---

## 7. Critérios de aceite da Sprint 1 (checklist final)

- [ ] Todos os módulos do escopo acessíveis por perfil, sem nenhuma aba "em breve" para Dentista e Biomédico
- [ ] RN03: nenhuma tela de profissional lista paciente sem vínculo
- [ ] RN04: executante nunca recebe valores (guia sem campos de valor + testes)
- [ ] RN05: evolução, documento, anamnese e laudo assinados não podem ser editados/excluídos; correção por adendo/retificação
- [ ] RN06: toda baixa de insumo controlado (HOF/Biomedicina) exige lote e validade; vencido recusado
- [ ] Todo acesso/alteração em prontuário gera `LogAcesso`
- [ ] `flutter analyze` sem erros · `flutter test` verde · builds Windows/Android/Web
- [ ] Documentação atualizada e honesta (✅ só para o validado)

---

## 8. Referência rápida do código atual

### Pacote e globais (instâncias únicas)

`auth` (`AuthService`) · `agenda` (`AgendaService`) · `pacientes` (`PacienteRepository`) · `prontuarioRepository` · `odontogramas` · `ortodontiaRepository` · `politicaAcesso` (`PoliticaAcessoService`) · `logsAcesso` (`LogAcessoService`) · `desenhosDentes`.

### Mapa de pastas (resumo)

```
lib/core/            especialidade · formadores · log_acesso · politica_acesso_service · procedimento
lib/assets/odontograma/dentes_vestibular.json   (o pubspec aponta para ele; não mover)
lib/features/auth/        domain: usuario, perfil · data: auth_service · presentation: tela_login
lib/features/agenda/      domain: agendamento, sala · data: agenda_service · presentation: cubit, pages(tela_agenda, tela_form_agendamento)
lib/features/pacientes/   domain: paciente · data: paciente_repository · presentation: cubit, pages(tela_pacientes, tela_form_paciente)
lib/features/prontuario/  domain: prontuario · data: prontuario_repository · presentation: cubit(atendimentos_*), pages(tela_prontuario, tela_prontuario_paciente, aba_prontuario)
lib/features/odontograma/ domain: odontograma, condicao_odonto, anatomia_dente · data: odontograma_repository, desenhos_dentes · presentation: pages, widgets
lib/features/ortodontia/  domain: ortodontia (modelos + repositório juntos) · presentation: pages(aba_ortodontia), widgets(aba_ortodontia_*)
lib/features/home/        presentation: modulos, pages(tela_principal, painel_inicial, tela_modulo_em_construcao)
test/                     *_test.dart (agenda, anatomia, caixa, desenho, odontograma, ortodontia, prontuario, cubits)
tool/gerar_dentes_json.dart
```

### Contas de teste (senha `123456`)

| Perfil | E-mail | ID |
|---|---|---|
| Administrador (Ana) | `admin@clinica.local` | 1 |
| Recepcionista (Rita) | `recepcao@clinica.local` | 2 |
| Dentista Dr. Davi | `dentista@clinica.local` | 3 |
| Dentista Dra. Lúcia | `dentista2@clinica.local` | 10 |
| Biomédica (Bia) | `biomedico@clinica.local` | 4 |
| Médica Dra. Marta | `medico@clinica.local` | 5 |
| Enfermeiro Eva | `enfermeiro@clinica.local` | 6 |
| Fisioterapeuta Fábio | `fisio@clinica.local` | 7 |
| Nutricionista Nina | `nutri@clinica.local` | 8 |
| Psicólogo Paulo | `psicologo@clinica.local` | 9 |

### Pacientes de exemplo (vínculos)

p1 Maria das Dores Silva {3, 8} · p2 João Pedro Santos, 12 anos {5, 3} · p3 Ana Beatriz Lima {4, 9} · p4 Carlos Eduardo Pereira {3, 7}.

### Política de acesso (`PoliticaAcessoService`) — métodos existentes

`podeVerListaGlobal` · `podeEditarPaciente` · `podeInativarPaciente` · `podeExcluirPaciente` · `podeVincularProfissional` · `podeAgendar` · **`podeAgendarRetorno`** (dentista vinculado, para si mesmo) · `podeVerAgendaGlobal` · `filtrarAgenda` · `statusPermitidos` · `podeAcessarProntuario` (profissional de saúde **vinculado**; Recepção/Admin **não** abrem prontuário) · `podeEditarOdontograma` (dentista vinculado) · `podeVerPaciente` · `filtrarPacientes`. Faltam `podeVerValores` (RN04) e regras novas por módulo (HOF, exames, documentos).

### Perfis e especialidades

`Perfil.especialidades`: dentista → {odontologia, harmonizacaoOrofacial}; biomedico → {biomedicina}; medico → {medicina}; enfermeiro → {enfermagem}; fisioterapeuta → {fisioterapia}; nutricionista → {nutricao}; psicologo → {psicologia}; Admin/Recepção → ∅ (`veClinicaInteira`).

### Catálogo de procedimentos (ids em `core/procedimento.dart`)

consulta-medica · consulta-enfermagem · sessao-fisioterapia · consulta-nutricional · sessao-psicologia · consulta-odontologica · profilaxia · restauracao · instalacao-aparelho · manutencao-ortodontica · remocao-aparelho · moldagem-escaneamento · **toxina-botulinica · preenchimento (HOF)** · **peeling · microagulhamento · coleta-exames (Biomedicina)**.

### Prontuário base (já feito) — API que os próximos passos usam

- `Atendimento` (id, pacienteId, profissionalId, agendamentoId?, inicio, fim?, status emAtendimento/encerrado), `Evolucao` (rascunho → `assinada`, `selo` provisório), `Adendo` (nasce assinado).
- `ProntuarioRepository`: `atendimentosDoPaciente(pacienteId, {profissionalId})`, `atendimentoAtivo(pacienteId, profissionalId)`, `iniciarAtendimento`, `encerrarAtendimento` (exige tudo assinado), `adicionarEvolucao`, `atualizarRascunho`, `descartarRascunho`, `assinarEvolucao`, `adicionarAdendo`, `temHistorico`.
- `AtendimentosCubit` (por paciente): `iniciar`, `encerrar`, `adicionarEvolucao`, `atualizarRascunho`, `descartarRascunho`, `assinar`, `adicionarAdendo`, `agendamentosIniciaveisHoje`.
- **HOF, Exames, Documentos, Anamnese e Biomedicina devem se prender ao `Atendimento`** (campo `atendimentoId`).

### `LogAcessoService.registrar({usuarioId, acao, entidade, entidadeId})` — em memória.

---

## 9. Pendências conhecidas (ficam para depois da Sprint 1)

- **Marco do servidor** (antes da Sprint 2): API REST, PostgreSQL, senha com hash, 2FA, RBAC/JWT, `LogAcesso` no servidor (IP, imutável, tela para o Admin), regras RN03/RN04/RN05 e conflitos de agenda no servidor, arquivos (exames/fotos) em armazenamento, assinatura digital real (hoje o "selo" é só um código de integridade provisório).
- Remover contas de teste e senha `123456` antes de qualquer uso real.
- Licença da imagem raster usada para vetorizar os dentes (uso comercial) e validação das siglas/cores do odontograma com os dentistas.
- Migrar para Cubit: Odontograma, Ortodontia (separar `ortodontia.dart` em domain/data), Auth. Mover `politica_acesso_service` para um módulo próprio quando fizer sentido.
- Sprint 2: Medicina/Enfermagem (SOAP), Nutrição, Psicologia (criptografia), Fisioterapia, **Estoque (RN06 completo)**, Financeiro. Sprint 3: WhatsApp (API oficial), marketing/opt-out, BI.

---

## 10. Armadilhas já encontradas (não repetir)

| Problema | Causa | Prevenção |
|---|---|---|
| Testes falhando com tipos "que não batem" e repositório duplicado | imports relativos (`'../lib/...'`) + `package:` ao mesmo tempo | sempre `package:ibn/...` |
| Arquivos antigos reaparecendo após mover | abas abertas no VS Code recriaram o arquivo | fechar abas antes de mover; conferir com script de duplicados |
| `flutter test` com `errno 112` | disco C: cheio (Temp do Flutter) | `$env:TEMP="F:\temp"` |
| Arquivos corrompidos com UTF‑16 | `>>` do PowerShell | editar no VS Code / `WriteAllText` UTF‑8 |
| `.dart` com classes cortadas/coladas | geração parcial de arquivos longos | entregar arquivos completos e rodar `analyze` a cada passo |
| Marca de arcada "voltava" ao desmarcar | estado ativo não ignorava o registro retificado | ao calcular "estado atual", ignorar registros apontados por `retificaId` |
| `Navigator`/`ScaffoldMessenger` após `await` | uso de `context` depois de gap assíncrono | capturar antes do `await` e checar `mounted` |
| Dois cubits da mesma coisa em rotas diferentes | rota empilhada fica fora do `BlocProvider` | `BlocProvider.value(value: cubit)` ou criar novo |

---

## 11. Arquivos que o usuário deve anexar na nova aba

**Sempre:** este guia · `0 - Sistema Clinico.pdf` · `ARQUITETURA.md` · `STATUS_PROJETO.md` · `diagramas_de_classe_sistema_clinico.md`.

| Passo | Anexar também (código de referência) |
|---|---|
| 0 Painel | `features/home/presentation/pages/painel_inicial.dart` · `features/agenda/presentation/cubit/agendamento_cubit.dart` + `agendamento_state.dart` · `features/agenda/data/agenda_service.dart` |
| 1 HOF | `features/ortodontia/presentation/widgets/aba_ortodontia_fotos.dart` · `features/ortodontia/domain/ortodontia.dart` · `features/prontuario/presentation/cubit/atendimentos_cubit.dart` + `atendimentos_state.dart` · `features/prontuario/domain/prontuario.dart` · `features/prontuario/data/prontuario_repository.dart` · `features/prontuario/presentation/pages/tela_prontuario_paciente.dart` · `core/politica_acesso_service.dart` · `core/log_acesso.dart` |
| 2 Exames | os de HOF + o widget de upload extraído no passo 1 |
| 3 Documentos | `features/auth/domain/usuario.dart` · `features/auth/domain/perfil.dart` · `features/auth/data/auth_service.dart` · `features/pacientes/domain/paciente.dart` · `core/formadores.dart` · `pubspec.yaml` |
| 4 Anamnese | `core/especialidade.dart` · `features/prontuario/...` (como acima) |
| 5 Plano/RN04 | `features/odontograma/domain/odontograma.dart` · `condicao_odonto.dart` · `core/procedimento.dart` · `core/politica_acesso_service.dart` · `features/auth/...` |
| 6 Biomedicina | `tela_prontuario_paciente.dart` · os modelos/cubits de Exames, Anamnese e HOF já criados · `core/procedimento.dart` |
| 7 Fechamento | `tela_prontuario_paciente.dart` · `pubspec.yaml` · todos os markdowns |

> Se a conversa nova precisar de um arquivo que não está na lista, ela deve **pedir**, nunca supor assinaturas.

---

## 12. Estimativa

| Passo | Esforço relativo |
|---|---|
| 0 Painel | P |
| 1 HOF | G |
| 2 Exames | M–G |
| 3 Documentos (+PDF) | G |
| 4 Anamnese | M |
| 5 Plano/RN04 | G |
| 6 Biomedicina | G |
| 7 Fechamento | M |

P = pequeno · M = médio · G = grande. Ordem pensada nas dependências: o seletor de arquivo (1→2), o PDF (3→2), a anamnese (4→6), os exames/`ResultadoLab` (2→6) e o `LoteAplicado` compartilhado (1→6).
