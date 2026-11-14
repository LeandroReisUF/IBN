# Checklist final da Sprint 1 — ibn (Sistema Clínico)

**Data:** 13/11/2026 · Marque cada item só depois de conferir na tela. Contas de teste (senha `123456`) e pacientes em `GUIA_FINALIZAR_SPRINT1.md`, seção 8.

**Pacientes de exemplo:** Maria (p1) {Dr. Davi, Nina} · João Pedro, 12 anos (p2) {Dra. Marta, Dr. Davi} · Ana Beatriz (p3) {Bia, Paulo} · Carlos (p4) {Dr. Davi, Fábio}. **Áreas:** Dr. Davi com Ortodontia e HOF; Dra. Lúcia sem nenhuma.

---

## 1. Verificações automáticas

- [ ] `flutter analyze` sem erros (só `info` de estilo são aceitáveis).
- [ ] `flutter test` verde. **Total de testes:** ______ (meta da Sprint: ≥ 200).
- [ ] Nenhum arquivo `.dart.old` nem pasta `_quarentena/` no projeto.
- [ ] Nenhum import relativo em `lib/` e `test/` (`Select-String -Path lib\*.dart,test\*.dart -Pattern "import '\.\./" -Recurse` não devolve nada).
- [ ] Nenhum `showDialog` de formulário clínico: só confirmações (`Descartar rascunho?`, `Cancelar procedimento?`) e o ampliar de foto.

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
| **Ana (Admin)** | Pacientes: lista global (4). Menu **sem** Prontuário e **com** Configurações. |
| **Rita (Recepção)** | Pacientes: lista global (4); pode cadastrar/vincular. Menu **sem** Prontuário e **sem** Configurações. Painel: cartões de hoje **não** abrem o prontuário. |
| **Dr. Davi** | Pacientes: só Maria, João Pedro e Carlos. Agenda: só os próprios atendimentos. Prontuário: **Anamnese e odontograma**, Ortodontia, Atendimentos, Plano de tratamento, Harmonização (HOF), Exames, Documentos. |
| **Dra. Lúcia** | Pacientes: nenhum. Agenda vazia. Depois de vinculada, o prontuário **não** mostra Ortodontia nem HOF até a Ana liberar a área. |
| **Bia (Biomédica)** | Pacientes: só Ana Beatriz. Prontuário com 4 abas. |
| **Paulo (Psicólogo)** | Pacientes: só Ana Beatriz. Prontuário mostra "em breve". |

- [ ] Cada linha da tabela confere.
- [ ] Dentro do prontuário, cada profissional vê só os próprios atendimentos, HOF, exames, documentos e procedimentos (confira com o Dr. Davi e a Dra. Lúcia no mesmo paciente depois do encaminhamento).
- [ ] **Anamnese:** a Dra. Lúcia vê a anamnese **assinada** do Dr. Davi (mesma especialidade), mas não o rascunho dele nem o modelo geral.

## 3.1 Configurações do Administrador (conta Ana)

- [ ] **Salas:** criar "Sala 5" só com Nutrição; ela aparece no agendamento de nutrição. Excluir a Sala 5 (sem agendamento) funciona; excluir a Sala 3 (tem agendamento) é recusado e **Desativar** a tira do formulário. Editar um agendamento de sala desativada não quebra o formulário.
- [ ] **Bloqueios:** bloquear a Sala 4 hoje, 8h às 18h; agendar peeling nesse horário mostra o motivo na prévia; **Desbloquear** libera. O aviso informa quantos agendamentos já marcados ficaram no período.
- [ ] **Procedimentos:** criar "Avaliação inicial" com Odontologia e Biomedicina; Dr. Davi e Bia agendam, Dra. Marta não. Procedimento já usado só **desativa**; "Manutenção ortodôntica" não exclui nem desativa.
- [ ] **Cores:** trocar a cor do Dentista; agenda e painel mudam. Cor repetida é recusada.
- [ ] **Dentistas:** liberar Ortodontia para a Dra. Lúcia; a aba aparece ao reabrir o prontuário. Remover a área esconde a aba e mantém os registros.
- [ ] Rita, Dr. Davi e os demais **não** veem Configurações.

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

- [ ] **Dr. Davi, Maria (pelo painel):** tocar no cartão de hoje abre o prontuário → **Anamnese e odontograma** (preencher e **Salvar anamnese**; sem itens obrigatórios; Exame físico e Odontograma abrem e fecham) → aba **Atendimentos**: bloco **amarelo** → **Iniciar atendimento** (verde, agendamento vira "Em atendimento") → evolução inline → exame → documento → plano → assinar tudo → **Encerrar** (bloco **cinza**, agendamento "Atendido").
- [ ] **Anamnese:** mudar e salvar de novo cria nova versão e a anterior fica "Substituída" no histórico; sem mudança, o botão fica desabilitado. Escrever sem salvar, trocar de aba e voltar mantém o texto.
- [ ] **Ortodontia (Dr. Davi):** Odontograma com Superior e Inferior em linhas separadas e só condições ortodônticas; Ficha e Arcos na mesma aba; Manutenção registrada e retificada no painel.
- [ ] **Bia, Ana Beatriz:** iniciar o atendimento do peeling → anamnese estética → procedimento com produto, lote e validade inline → exame laboratorial com resultado alto (alerta vermelho) → laudo em PDF → encerrar.
- [ ] **Rita:** agenda um retorno e vê as tags (sala, procedimento, profissional) e a cor do tipo; o paciente passa a vinculado ao profissional.
- [ ] **Ana:** bloqueia uma sala e confere que Rita não consegue agendar nela.

## 9. Documentação

- [ ] `STATUS_PROJETO.md`, `ARQUITETURA.md`, `diagramas_de_classe_sistema_clinico.md`, `GUIA_FINALIZAR_SPRINT1.md` e `PROXIMOS_PASSOS_SPRINT1.md` atualizados (✅ só no que foi validado).

---

**Sprint 1 só fecha quando todos os itens acima estiverem marcados.** O que ficar de fora entra em `PROXIMOS_PASSOS_SPRINT1.md`.
