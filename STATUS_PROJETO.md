# Status do Projeto — ibn (Sistema Clínico)

**Última atualização:** 03/11/2026 (Sprint 1: todos os módulos clínicos validados; fechamento em andamento)
**Stack:** Flutter (Windows, Android, Web) · Cubit (`flutter_bloc`) · dados em memória (sem servidor) · estrutura em `ARQUITETURA.md`
**Legenda:** ✅ funciona · 🟡 parcial (existe, mas com falhas conhecidas) · 🔴 quebrado / não compila · ⬜ não iniciado

> **Regra deste documento:** só marca ✅ o que foi conferido no código. Antes, vários itens estavam
> marcados como concluídos sem estarem (ex.: "Fase F 90%"). Esta versão corrige isso.

---

## 1. Resumo honesto da Sprint 1

| Bloco da Sprint 1 (PDF de requisitos) | Situação real |
|---|---|
| Infra/segurança base (BD, nuvem, RBAC) | 🟡 RBAC só no app; sem banco, sem servidor |
| Cadastro de pacientes (RF03.1) | ✅ (faltam foto, endereço, versões do termo) |
| Agenda multissala (RF02, RN01, RN02) | ✅ (revalidação no servidor pendente) |
| Anamnese configurável (RF03.3) | ✅ validado (modelos odontológico, estético e geral; assinadas compartilhadas por especialidade) |
| Odontologia — Odontograma (RF04.1) | ✅ Fases A–E |
| Odontologia — Ortodontia (extra, Fase F) | ✅ validado (analyze limpo, testes e roteiro manual) |
| Odontologia — HOF (RF04.2) | ✅ validado em 30/10/2026 (lote e validade RN06, retificação RN05, fotos antes/depois) |
| Odontologia — Exames (RF04.3) | ✅ validado em 31/10/2026 (solicitação, anexos JPG/PNG/PDF, substituição por retificação) |
| Odontologia — Documentos: prescrição, atestado, TCLE e PDF (RF04.4) | ✅ validado em 31/10/2026 |
| Odontologia — Plano de tratamento e orçamento com sigilo ao executante (RF04.5, **RN04**) | ✅ validado (guia sem valores; falta o odontograma de planejamento do plano) |
| Biomedicina (RF05): anamnese estética, procedimentos com lote e validade (RN06), exames e resultados com alerta | ✅ validado |

**Estimativa realista de conclusão da Sprint 1: ~95%.** Falta o fechamento (Passo 7): odontograma de planejamento dentro do plano, builds nas 3 plataformas e a revisão final de RN03/RN04/RN05/RN06 por perfil. Depois vem o **marco do servidor**.

---

## 2. Odontograma (RF04.1)

| Fase | Descrição | Status | Observação conferida no código |
|---|---|---|---|
| A | Desenho 2D + caixa dividida | ✅ | `desenho_dente.dart`, `caixa_dente.dart` |
| B | Condições, evolução, retificação, visões | ✅ | `condicao_odonto.dart`, `dialogo_evolucao.dart`, `menu_condicoes.dart` |
| C | Raízes | ✅ | divisão em faixas horizontais |
| D | Decíduos | ✅ | escala **0,75** (a spec dizia 0,7); limite 13 anos |
| E | Ortodontia camada 1 | ✅ | bug das marcas de arcada corrigido |
| F | Ortodontia aba própria | ✅ | seção 3 |

**Bug na Fase E (marcas de arcada) — CORRIGIDO no Passo 1:** `OdontogramaRepository.marcasArcadaAtivas` descarta
os registros com `retificaId`, mas **não descarta o registro original que foi retificado**.
Resultado: ao desmarcar um tipo de aparelho, a marca "volta" ao recarregar. Correção: ignorar também os ids apontados por `retificaId` (como `estadoAtual` já faz).

Outras observações:
- As marcas de arcada ficam só nos chips; **não são desenhadas** nas arcadas.
- `MarcaOrtodontia` está em `condicao_odonto.dart` (a doc dizia `odontograma.dart`).
- `OrtodontiaRepository` mora dentro de `core/odontograma.dart` (deveria ter arquivo próprio).

---

## 3. Ortodontia — Fase F (✅ validado em 27/10/2026)

Corrigido no Passo 1 e conferido por `flutter analyze` (0 erros), `flutter test` e roteiro manual completo.

| Item | Situação |
|---|---|
| Ficha: datas, validação, salvar (cada salvar = nova versão, RN05) | ✅ |
| Arcos e elásticos (editados na ficha, exibidos na aba) | ✅ |
| Manutenções: data no diálogo, retificação (sem excluir, RN05), lista atualiza na hora | ✅ |
| Agendar manutenção pré-preenchido (paciente, dentista, procedimento, Sala 3) | ✅ |
| Fotos com upload real (`file_picker`, bytes em memória) | ✅ (arquivo no servidor: marco do servidor) |
| Modelos/repositório em `core/ortodontia.dart` | ✅ |
| Testes (`ortodontia_test.dart`, 14) | ✅ |

**Decisão (27/10/2026):** o dentista pode agendar o retorno do próprio paciente (implementada no Passo 2).

---

## 4. Prontuário base, HOF, Exames, Documentos, Anamnese

**Passo 0 (✅):** os arquivos quebrados foram para quarentena (`*.dart.old`); `flutter analyze` ficou sem erros.

**Passo 2 (✅ validado em 28/10/2026):** `prontuario.dart`, `prontuario_repository.dart`, `aba_prontuario.dart` ("Atendimentos": iniciar → evoluir → assinar → encerrar; adendo, RN05), `prontuario_test.dart`. Analyze limpo, testes passando e roteiro manual completo. Decisão aplicada: dentista agenda retorno do próprio paciente (`podeAgendarRetorno`).

**Reescritos como features (todos validados):** HOF, Exames (com resultados laboratoriais), Documentos (com PDF), Anamnese, Plano de tratamento e Biomedicina. A pasta `_quarentena/` foi removida no Passo 7.

Diagnóstico original dos arquivos quebrados (histórico):

Na tela, `tela_prontuario_paciente.dart` mostra `_EmBreve(...)` nessas abas. Os arquivos que existem no
repositório **estão corrompidos/incompletos e não compilam** (só não derrubam o app porque ninguém os importa):

| Arquivo | Problema |
|---|---|
| `core/prontuario.dart` | classes cortadas e coladas umas dentro das outras; campos não-`final` em classes `const`; **não existe `prontuarioRepository`** |
| `core/documentos.dart` | `preencher()` cortado ao meio; classes inseridas dentro de outra; `copiarCom` do TCLE truncado; construtores passam `pacienteId: ''` e `emitidoEm: DateTime.now()` ao `super`, apagando os dados |
| `core/exames.dart` | `copiarCom` truncado; trecho solto depois de `examesRepository` |
| `core/hof.dart` | enum `LadoFaceHOF` partido (valores no fim do arquivo); `ProcedimentoHOF` truncado; `FichaHOF.copiarCom` passa `DateTime?` a campo `DateTime`; procedimentos novos não entram em `ficha.procedimentos` (a aba nunca mostraria) |
| `aba_prontuario.dart`, `aba_anamnese.dart`, `aba_exames.dart`, `aba_hof.dart`, `aba_documentos.dart` | métodos fora da classe, métodos `_build...` inexistentes, `Usuario` sem import, acesso a membros privados de outra biblioteca |
| `aba_hof_dialogs.dart`, `aba_hof_dialogs_part2.dart` | classes privadas (`_Dialog...`) em arquivos que não são `part`; o `part2` termina com lixo **UTF‑16** |

**Provável causa:** arquivos gravados por redirecionamento do PowerShell (`>>`, que grava UTF‑16) e/ou
colagens parciais. Padrão: arquivos longos "emendados" em pedaços.

**Por que "75 testes passam":** os testes só compilam o que é importado a partir de `main.dart`. Rodar
`flutter analyze` mostrará dezenas de erros.

---

## 5. Testes

| Suite | Testes |
|---|---|
| AgendaService | 10 |
| AnatomiaDente | 18 |
| CaixaDente | 10 |
| DesenhoDente (faixaDaRaiz) | 4 |
| Odontograma | 33 |
| **Total declarado (28/10)** | **75** — desatualizado; use o resultado de `flutter test` |
| Fase F, HOF, Exames, Documentos, Anamnese, Prontuário | cada módulo tem testes do repositório (e do Cubit, quando existe); o total atual sai de `flutter test` |

---

## 6. Divergências entre documentos corrigidas

- `PROXIMOS_PASSOS` colocava Biomedicina/HOF na Sprint 2 e servidor na Sprint 3. **No PDF:** Biomedicina e HOF são Sprint 1; Sprint 2 = multidisciplinar + estoque + financeiro; Sprint 3 = WhatsApp + marketing + BI. O "marco do servidor" fica **entre a Sprint 1 e a 2**.
- Login/RBAC e Política de Acesso estavam ✅; ficam 🟡 (sem hash, 2FA, RBAC granular, nada no servidor).
- `GUIA_USO_SVGS_ODONTOGRAMA.md` agora existe no projeto (o status antigo dizia que não).
- Checklist pedia "excluir manutenção/foto": **contraria a RN05** (prontuário não se apaga). Troca-se por anulação/retificação.

## 7. Pendências técnicas (inalteradas)

- Contas de teste e senha `123456` · dados em memória · sem servidor/API/PostgreSQL
- Licença da imagem raster dos dentes · validar siglas/cores com dentistas
- Raízes dos 3º molares ajustáveis · formas próprias de decíduos
- Contas de teste com **registro de conselho fictício** (`Usuario.conselho` e `registroConselho`): cadastrar os reais antes de emitir documentos de verdade
- Validar com os profissionais os textos dos modelos de documento, as perguntas da anamnese e o receituário de controle especial (hoje só texto, sem o formulário oficial)
- PDF (`pdf` e `printing`): validado no Windows; conferir Web e Android · fonte Roboto opcional em `lib/assets/fontes/`
- ✅ O encerramento do atendimento passou a ser bloqueado enquanto houver rascunho de documento (Passo 7)
- Anamnese: as **assinadas** são compartilhadas entre profissionais da mesma especialidade (decisão); rascunhos e o modelo geral ficam privados. Confirmar no servidor
- `PacienteRepository.temHistorico` precisa consultar todos os módulos (anamnese, plano, exames, documentos, HOF, biomedicina), senão um paciente com dados e sem vínculo poderia ser excluído (RN05)
- O Administrador respeita RN04 pela regra, mas ainda não tem tela para ver os valores dos planos (vem com o Financeiro, Sprint 2)
- Resultado de exame fora do padrão **só alerta** (decisão): não bloqueia procedimento
- Odontograma de planejamento dentro do plano de tratamento: estado desejado ao fim do tratamento (Passo 7)

---

## 8. Arquitetura (refatoração em andamento)

Detalhes e estrutura real em `ARQUITETURA.md`.

| Módulo | features/ | Cubit | Testes do Cubit |
|---|---|---|---|
| Agenda | ✅ | ✅ | 13 |
| Home / Painel | ✅ | ✅ (validado em 30/10/2026) | 1 |
| Pacientes | ✅ | ✅ (validado em 29/10/2026) | 16 |
| Prontuário (atendimentos) | ✅ | ✅ | ~17 |
| Auth, Odontograma, Ortodontia | ✅ | ⬜ | — |
| HOF | ✅ | ✅ | testes do repositório e do Cubit |
| Exames | ✅ | ✅ | testes do repositório e do Cubit |
| Documentos | ✅ | ✅ | testes do repositório, do Cubit e do PDF |
| Anamnese | ✅ | ✅ | testes do repositório e do Cubit |
| Plano de tratamento | ✅ | ✅ | testes do repositório, da RN04 e do Cubit |
| Biomedicina | ✅ | ✅ | testes do repositório, dos resultados de exames e do Cubit |

Migração para `features/` concluída em 28/10/2026 (analyze limpo e testes passando após remover 14 duplicatas deixadas nos caminhos antigos).

Lições registradas: usar sempre `package:ibn/...` (inclusive nos testes); fechar as abas do editor antes de mover arquivos; disco C: cheio derruba o `flutter test` (usar `TEMP` em F:); o `MultiPage` do pacote `pdf` só quebra a página entre widgets (dividir o texto em linhas, como em `pdf_simples.dart`); arquivo novo copiado sem o `import` na tela que o usa dá `undefined_method`.
