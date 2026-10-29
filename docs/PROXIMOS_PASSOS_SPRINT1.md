# Próximos Passos — Sprint 1 (plano de correção)

**Data:** 27/10/2026 · **Substitui** `PROXIMOS_PASSOS_SPRINT1.md` e `CHECKLIST_SPRINT1.md` anteriores.
**Diagnóstico completo:** `STATUS_PROJETO.md`. Cada passo termina com **critério de aceite** e deve ser feito na ordem.

Regras de trabalho (evitam repetir o que corrompeu os arquivos):
1. Edite arquivos no VS Code (UTF‑8). **Nunca** use `>>`/`echo` do PowerShell para gerar código.
2. Cada arquivo inteiro e completo por vez; depois rode `flutter analyze`. Meta: **0 erros**.
3. Um commit por passo.

---

## Passo 0 — Limpar o repositório ✅ (concluído em 27/10/2026)

1. Rode `flutter analyze` e anote os erros.
2. Mova para uma pasta fora de `lib/` (ex.: `_quarentena/`) os arquivos quebrados que ainda não serão reescritos:
   `aba_prontuario.dart`, `aba_anamnese.dart`, `aba_exames.dart`, `aba_hof.dart`, `aba_hof_dialogs.dart`, `aba_hof_dialogs_part2.dart`, `aba_documentos.dart`, e o conteúdo de `core/prontuario.dart`, `documentos.dart`, `exames.dart`, `hof.dart`.
3. Rode `flutter analyze` de novo.

**Aceite:** `flutter analyze` sem erros; `flutter test` passa; app abre.

## Passo 1 — Consertar a Ortodontia ✅ (validado em 27/10/2026)

**1.1 Estrutura**
- Criar `core/ortodontia_repository.dart` (mover `OrtodontiaRepository` e deixar os modelos em `ortodontia.dart`). Atualizar imports.
- Em `FichaOrtodontica`, adicionar `queixaPrincipal` (separado de `objetivos`).
- Em `AbaOrtodontia`: envolver tudo em `ListenableBuilder(listenable: ortodontiaRepository)` e ler ficha/manutenções/fotos **dentro** do builder. Remover o `Scaffold`/`AppBar` interno (usar só `TabBar` + `TabBarView`).

**1.2 Ficha (data e salvar)**
- Em `_AbaFichaWidget`: criar `GlobalKey<FormState>`, envolver o formulário em `Form` e guardar os controllers de arco/elástico como campos do `State` (não criar novos a cada `build`).
- Implementar `_escolherDataInstalacao` e `_escolherPrevisaoTermino` com `showDatePicker` + `setState`.
- Implementar `_salvar`: validar o `Form`, exigir tipo de aparelho e data de instalação, validar `previsao > instalação`, montar `FichaOrtodontica` (reusar `id` e `criadoEm` se existir), chamar `ortodontiaRepository.salvarFicha`, registrar `LogAcesso` (`salvou_ficha_orto`), fechar o modo edição e mostrar `SnackBar`.
- Adicionar ao formulário os campos de arco superior/inferior (fio, calibre) e elásticos; `onEditarFicha` da aba Arcos deve abrir o modo edição da Ficha (trocar para a aba 0).

**1.3 Manutenções**
- No diálogo, usar `StatefulBuilder` (ou widget próprio) para a data aparecer ao escolher.
- Criar `atualizarManutencao` no repositório; editar passa a **substituir** (e não duplicar). Por RN05, prefira "retificar" mantendo o original riscado.
- **Sem botão excluir.** Se necessário, "anular" com justificativa.
- "Agendar manutenção": adicionar parâmetros opcionais em `TelaFormAgendamento` (`pacienteIdInicial`, `procedimentoIdInicial = 'manutencao-ortodontica'`, `profissionalIdInicial`). **Decisão tomada (27/10/2026):** o dentista pode agendar o retorno do próprio paciente (`podeAgendarRetorno`, Passo 2).

**1.4 Fotos**
- Remover a URL `via.placeholder.com`. Usar `file_picker` (Windows/Web/Android) e `image_picker` (Android/iOS). Em Web não há `dart:io`: guardar bytes em memória por enquanto; em Windows/Android copiar para a pasta de documentos do app (`path_provider`).
- Mostrar miniatura com `Image.file`/`Image.memory`; visualizar em tela cheia ao tocar.

**1.5 Fase E (bug)**
- Em `marcasArcadaAtivas`, ignorar também os ids retificados (`retificaId`), como em `estadoAtual`.
- Teste: marcar → desmarcar → recarregar mantém desmarcado.

**1.6 Testes** (`test/ortodontia_test.dart`, meta ≥ 12): salvar/carregar ficha; validação de datas; manutenções ordenadas; editar não duplica; fotos; `notifyListeners`; bug das marcas de arcada.

**Aceite:** escolher datas funciona; salvar ficha persiste e reaparece ao reabrir a aba; manutenção nova aparece na lista na hora; foto real aparece; `flutter test` verde.

## Passo 2 — Prontuário base 🟡 (entregue em 28/10/2026, aguardando validação — ver `PASSO2_APLICAR.md`)

1. Reescrever `core/prontuario.dart` **do zero**, com classes imutáveis (`final`) e `copiarCom`: `Prontuario`, `Atendimento`, `Evolucao`, `Adendo`, modelos de Anamnese.
2. Criar `core/prontuario_repository.dart` (`ProntuarioRepository` com `iniciarAtendimento`, `encerrarAtendimento`, `adicionarEvolucao`, `assinarEvolucao`, `adicionarAdendo`) e a instância `prontuarioRepository`.
3. **RN05:** evolução assinada ou atendimento encerrado → o repositório recusa alteração; correção só por `Adendo`.
4. Todo atendimento/evolução gera `LogAcesso`.
5. Vincular o atendimento ao `Agendamento` (muda o status para Em atendimento/Atendido).
6. Testes: encerramento, assinatura, adendo, bloqueio de edição.

**Aceite:** dentista inicia atendimento, registra evolução, assina; não consegue editar; adendo funciona.

## Passo 3 — HOF (≈2 dias)

Reescrever `core/hof.dart` completo (enums `TipoHOF`, `AreaFaceHOF`, `LadoFaceHOF`; `PontoAplicacao`, `InsumoHOF` com lote e validade, `ProcedimentoHOF`, `FotoComparativaHOF`, `HOFRepository`).
Tela: lista de procedimentos, diálogo (tipo, pontos, produto, UI/ml, marca, **lote e validade obrigatórios — RN06**), galeria antes/depois. Dialogs em arquivos públicos (sem `_` se forem usados em outro arquivo) e ligados à aba `Harmonização (HOF)`.
**Aceite:** registrar procedimento com lote; ele aparece na lista; lote vencido é recusado.

## Passo 4 — Exames (≈1–2 dias)

Reescrever `core/exames.dart`. Solicitar exame (guia imprimível vem no Passo 5), anexar JPG/PNG/PDF (reaproveitar o seletor de arquivos do Passo 1.4), listar por paciente.
**Aceite:** solicitar, anexar e visualizar um arquivo.

## Passo 5 — Documentos (≈2 dias)

Reescrever `core/documentos.dart` (sem passar `''`/`DateTime.now()` ao `super`). Modelos (prescrição, atestado, TCLE) com preenchimento automático de paciente/data/profissional (CRO). Gerar PDF (`pdf` + `printing`). Assinado = imutável (RN05).
**Aceite:** gerar prescrição a partir de modelo, ver PDF, documento assinado não edita.

## Passo 6 — Anamnese odontológica (≈1 dia)

Formulário dinâmico por `ModeloAnamnese`; modelo odontológico padrão.

## Passo 7 — Ligar as abas

Em `tela_prontuario_paciente.dart`, trocar os `_EmBreve` pelas abas reais, só quando cada uma estiver aceita. Abas ainda vazias continuam como "em breve".

## Passo 8 — Fechamento da Sprint 1

- [ ] `flutter analyze` limpo · `flutter test` ≥ 100 testes
- [ ] `flutter run -d windows`, `flutter build apk --debug`, `flutter build web`
- [ ] Atualizar `STATUS_PROJETO.md`, `diagramas_de_classe_sistema_clinico.md`, `melhorias_odontograma.md`
- [ ] **Biomedicina (RF05)** — está na Sprint 1 do PDF e não foi iniciada: replanejar (Sprint 1b) ou mover formalmente.

---

## Depois da Sprint 1 (alinhado ao PDF)

1. **Marco do servidor** (antes da Sprint 2, dados financeiros): API REST, PostgreSQL, senha com hash, 2FA, RBAC, `LogAcesso` e conflitos de agenda no servidor. Um servidor na máquina da clínica, acessível por `http://IP-do-servidor` na rede wifi, e por domínio/VPN para acesso externo; o mesmo app Flutter fala com a API.
2. **Sprint 2:** multidisciplinar (SOAP, nutrição, psicologia criptografada, fisio), estoque (RN06), financeiro.
3. **Sprint 3:** WhatsApp API oficial, marketing/opt-out, dashboards.
