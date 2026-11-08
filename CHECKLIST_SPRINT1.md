# Checklist final da Sprint 1 — ibn (Sistema Clínico)

**Data:** 03/11/2026 · Marque cada item só depois de conferir na tela. Contas de teste (senha `123456`) e pacientes em `GUIA_FINALIZAR_SPRINT1.md`, seção 8.

**Pacientes de exemplo:** Maria (p1) {Dr. Davi, Nina} · João Pedro, 12 anos (p2) {Dra. Marta, Dr. Davi} · Ana Beatriz (p3) {Bia, Paulo} · Carlos (p4) {Dr. Davi, Fábio}.

---

## 1. Verificações automáticas

- [ ] `flutter analyze` sem erros (só `info` de estilo são aceitáveis).
- [ ] `flutter test` verde. **Total de testes:** ______ (meta da Sprint: ≥ 200).
- [ ] Nenhum arquivo `.dart.old` nem pasta `_quarentena/` no projeto.
- [ ] Nenhum import relativo em `lib/` e `test/` (`Select-String -Path lib\*.dart,test\*.dart -Pattern "import '\.\./" -Recurse` não devolve nada).

## 2. Builds

- [ ] `flutter build windows --debug` conclui (primeira vez baixa o PDFium: precisa de internet).
- [ ] `flutter build apk --debug` conclui.
- [ ] `flutter build web` conclui.
- [ ] Windows: login, agenda e prontuário abrem; **PDF abre** em Documentos e em Exames.
- [ ] Web: login, agenda e prontuário abrem; conferir a pré-visualização de PDF (pode exigir script no `web/index.html`).
- [ ] Android (emulador ou aparelho): login, agenda e prontuário abrem; escolher imagem e PDF em Exames.
- [ ] **Largura de celular (< 600 px):** menu em gaveta, odontograma com rolagem horizontal, formulário de anamnese e diálogos rolam sem estourar.

## 3. RN03 — cada profissional só vê o que é seu

| Conta | O que conferir |
|---|---|
| **Ana (Admin)** | Pacientes: lista global (4). Menu **sem** Prontuário. |
| **Rita (Recepção)** | Pacientes: lista global (4); pode cadastrar/vincular. Menu **sem** Prontuário. |
| **Dr. Davi** | Pacientes: só Maria, João Pedro e Carlos (não vê Ana). Agenda: só os próprios atendimentos. |
| **Dra. Lúcia** | Pacientes: nenhum (sem vínculos). Agenda vazia. |
| **Bia (Biomédica)** | Pacientes: só Ana Beatriz. Prontuário com 4 abas. |
| **Paulo (Psicólogo)** | Pacientes: só Ana Beatriz. Prontuário mostra "em breve". |

- [ ] Cada linha da tabela confere.
- [ ] Dentro do prontuário, cada profissional vê só os próprios atendimentos, HOF, exames, documentos e procedimentos (confira com o Dr. Davi e a Dra. Lúcia no mesmo paciente depois do encaminhamento).
- [ ] **Anamnese:** a Dra. Lúcia vê a anamnese **assinada** do Dr. Davi (mesma especialidade), mas não o rascunho dele nem o modelo geral.

## 4. RN04 — o executante nunca recebe valores

- [ ] **Dr. Davi** cria um plano em Maria, adiciona Restauração (dente 26, valor e desconto) e define o pagamento.
- [ ] Ele encaminha o procedimento à **Dra. Lúcia**, com instruções clínicas.
- [ ] **Dra. Lúcia** abre Maria (agora vinculada): na aba Plano de tratamento aparece só "Encaminhados a você", **sem nenhum valor, desconto, total ou pagamento** em lugar nenhum.
- [ ] Ela marca como realizado; o Dr. Davi vê "Realizado" e o total no plano dele.
- [ ] Os testes de `plano_test.dart` e `plano_cubit_test.dart` passam (varrem a guia atrás de dinheiro).

## 5. RN05 — o que foi assinado não se altera

- [ ] **Evolução:** assinada não edita nem descarta; só **adendo**. Atendimento só encerra com tudo assinado.
- [ ] **Atendimento:** com **rascunho de documento** pendente, o encerramento é recusado; depois de assinar ou descartar, encerra.
- [ ] **Documento:** assinado não edita; **Corrigir** cria novo rascunho e o original fica "Corrigido".
- [ ] **Anamnese:** assinada não edita; **Atualizar** cria nova versão e a anterior fica "Substituída".
- [ ] **Exame:** arquivo e resultado não se apagam; **Substituir/Corrigir** exige justificativa e deixa o antigo riscado.
- [ ] **Odontograma, Ortodontia, HOF e Biomedicina:** só inclusão; **Retificar** e **Anular** deixam o original riscado. Não existe botão de excluir dado clínico em nenhuma tela.
- [ ] **Plano de tratamento:** procedimento não é apagado, só **Cancelado**; realizado não cancela.

## 6. RN06 — lote e validade

- [ ] **HOF:** toxina, preenchimento e bioestimulador sem produto/lote/validade: botão **Registrar** desabilitado. Lote vencido: erro no diálogo.
- [ ] **Biomedicina:** todo procedimento exige ao menos um produto com lote e validade; vencido é recusado.
- [ ] Validade vale até o fim do próprio dia (testes de `hof_test.dart` e `biomedicina_test.dart`).

## 7. RNF03 — registro de acesso (LGPD)

- [ ] Abrir prontuário e cada ação clínica geram `LogAcesso` (coberto por testes dos Cubits; ainda **não existe tela de consulta**: vem com o servidor).

## 8. Fluxos de ponta a ponta

- [ ] **Dr. Davi, Maria:** iniciar atendimento (vinculado à agenda) → anamnese → odontograma → plano → exame → documento → encerrar. A agenda passa a "Atendido".
- [ ] **Bia, Ana Beatriz:** iniciar atendimento do peeling → anamnese estética → procedimento com lote → exame com resultado alto (alerta vermelho) → laudo em PDF → encerrar.
- [ ] **Rita:** agenda um retorno e vê o paciente vinculado ao profissional.

## 9. Documentação

- [ ] `STATUS_PROJETO.md`, `ARQUITETURA.md`, `diagramas_de_classe_sistema_clinico.md`, `GUIA_FINALIZAR_SPRINT1.md` e `PROXIMOS_PASSOS_SPRINT1.md` atualizados (✅ só no que foi validado).

---

**Sprint 1 só fecha quando todos os itens acima estiverem marcados.** O que ficar de fora entra em `PROXIMOS_PASSOS_SPRINT1.md`.
