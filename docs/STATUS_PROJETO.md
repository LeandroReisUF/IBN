# Status do Projeto — ibn (Sistema Clínico)

**Última atualização:** 28/10/2026 (Passo 1 validado; Passo 2 entregue, aguardando validação)
**Stack:** Flutter (Windows, Android, Web) — dados em memória (sem servidor)
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
| Odontologia — Anamnese | ⬜ em quarentena (`.dart.old`), Passo 6 |
| Odontologia — Odontograma (RF04.1) | ✅ Fases A–E |
| Odontologia — Ortodontia (extra, Fase F) | ✅ validado (analyze limpo, testes e roteiro manual) |
| Odontologia — HOF (RF04.2) | 🔴 só aba "em breve" + arquivos quebrados |
| Odontologia — Exames (RF04.3) | 🔴 idem |
| Odontologia — Prescrição/Atestados (RF04.4) | 🔴 idem |
| Biomedicina inteira (RF05) | ⬜ não iniciada (está na Sprint 1 do PDF) |

**Estimativa realista de conclusão da Sprint 1: ~55%** (o documento anterior dizia 90%). Falta HOF, exames, documentos, anamnese e Biomedicina.

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

**Passo 2 (🟡 entregue, aguardando validação):** `prontuario.dart` (reescrito), `prontuario_repository.dart`,
`aba_prontuario.dart` ("Atendimentos"), `prontuario_test.dart`. Só vira ✅ depois do analyze, dos testes e do roteiro de `PASSO2_APLICAR.md`.

**Ainda em quarentena / a reescrever:** HOF (Passo 3), Exames (4), Documentos (5), Anamnese (6).

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
| **Total declarado** | **75** (os arquivos de teste não foram reconferidos nesta revisão) |
| Fase F, HOF, Exames, Documentos, Prontuário | 0 |

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
