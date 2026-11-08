# Próximos passos — depois da Sprint 1 (ibn, Sistema Clínico)

**Data:** 03/11/2026 · **Tamanho:** P pequeno · M médio · G grande.

A Sprint 1 foi feita **só no app Flutter, com dados em memória**. Antes da Sprint 2 (que traz dados financeiros e sensíveis) vem o **marco do servidor**, porque hoje todas as regras de acesso e de integridade só existem no cliente.

---

## 1. Para fechar a Sprint 1 (Passo 7)

| # | Item | Tam. | Situação |
|---|---|---|---|
| 1 | Bloquear o encerramento do atendimento com rascunho de documento | P | feito no Passo 7 |
| 2 | Registro de abas por perfil (`abasDoPerfil`) | P | feito no Passo 7 |
| 3 | Unificar o diálogo de lote do HOF com o compartilhado; remover `_quarentena/` | P | feito no Passo 7 |
| 4 | **Odontograma de planejamento dentro do plano** (estado desejado ao fim do tratamento) | M–G | desenho a definir |
| 5 | Builds Windows/Android/Web e roteiro final por perfil (`CHECKLIST_SPRINT1.md`) | M | a executar |

## 2. Marco do servidor (entre a Sprint 1 e a Sprint 2)

| # | Entrega | Tam. | Observação |
|---|---|---|---|
| 1 | API REST + banco PostgreSQL + migrações (`EntidadeBase`) | G | trocar cada repositório em memória por chamadas à API, **mantendo os Cubits** |
| 2 | Login com senha **com hash**, 2FA, sessão com expiração, RBAC/JWT | G | remover contas de teste e a senha `123456` |
| 3 | **RN03 no servidor:** profissional só recebe dados de pacientes vinculados | G | no app hoje só esconde telas |
| 4 | **RN04 no servidor:** a API do executante nunca devolve valores, descontos ou pagamento | M | o app já tem a guia sem campos de dinheiro |
| 5 | **RN05 no servidor:** bloquear UPDATE/DELETE de registros assinados e encerrados; retificação e adendo | G | |
| 6 | **RN06 no servidor:** lote e validade obrigatórios; vencido recusado | M | HOF e Biomedicina |
| 7 | `LogAcesso` no servidor: IP, dispositivo, imutável, **tela de consulta para o Admin** | M | RNF03 |
| 8 | Conflitos de agenda (RN01/RN02) validados no servidor | M | dois computadores agendando ao mesmo tempo |
| 9 | Arquivos (exames, laudos, fotos) em armazenamento, não em memória | M | hoje bytes em memória |
| 10 | **Assinatura digital real** no lugar do "selo" provisório | G | evolução, documento, anamnese |
| 11 | Criptografia de campos sensíveis (RNF02) | M | preparar para Psicologia (Sprint 2) |
| 12 | Backup e acesso externo (domínio/VPN) | M | |

## 3. Pendências do app para tratar junto (anotadas durante a Sprint 1)

- `PacienteRepository.temHistorico` precisa consultar **todos** os módulos (anamnese, plano, exames, documentos, HOF, biomedicina). Hoje só vê vínculos e atendimentos; um paciente com dados e sem vínculo poderia ser excluído pelo Administrador (RN05). No servidor isso vira consulta ao banco.
- O **Administrador** respeita a RN04 pela regra, mas ainda não tem tela para ver os valores dos planos (entra com o Financeiro).
- **Validar com os profissionais da clínica:** siglas e cores do odontograma, perguntas dos modelos de anamnese, textos dos modelos de documento, o receituário de controle especial (hoje só texto, sem o formulário oficial), guias de exame.
- **Licença** da imagem raster usada para vetorizar os dentes (uso comercial).
- Raízes dos 3º molares ajustáveis por paciente; formas próprias de dentes decíduos.
- Foto de perfil e endereço do paciente; várias versões do termo LGPD.
- Valor padrão por procedimento no catálogo e criação do plano a partir do odontograma.
- Fonte Roboto opcional nos PDFs (`lib/assets/fontes/`).
- Migrar para Cubit os módulos que ainda não têm: Odontograma, Ortodontia (separar `ortodontia.dart` em domain/data) e Auth. Avaliar mover `politica_acesso_service` para um módulo de acesso.

## 4. Sprint 2 — multidisciplinar, estoque e financeiro

| Entrega | Tam. | Depende de |
|---|---|---|
| Prontuário SOAP, Medicina e Enfermagem (sinais vitais) | G | servidor |
| Nutrição (antropometria, gasto energético, plano alimentar em PDF) | G | servidor |
| Fisioterapia (avaliação, amplitudes, plano de reabilitação) | G | servidor |
| **Psicologia** com criptografia e sigilo reforçado (só o psicólogo do caso lê o conteúdo) | G | servidor + criptografia |
| **Estoque** (RN06 completo: insumos, lotes, movimentos, alertas de vencimento e estoque crítico), ligando `LoteAplicado` à baixa | G | servidor |
| **Financeiro:** contas a receber e a pagar, caixa diário, repasses por profissional | G | servidor |
| Tela do Administrador para ver valores dos planos (RN04) | M | financeiro |

## 5. Sprint 3 — WhatsApp, marketing e BI

| Entrega | Tam. |
|---|---|
| WhatsApp (API oficial): confirmação automática, resposta `[1] Confirmar` / `[2] Cancelar` / "SAIR" (opt-out) | G |
| Regras de retorno e campanhas segmentadas (excluindo opt-out) | G |
| Dashboard/BI: ocupação das salas, faturamento por especialidade, absenteísmo, estoque crítico | G |

## 6. Ordem recomendada

1. Fechar o Passo 7 da Sprint 1 e rodar o `CHECKLIST_SPRINT1.md`.
2. Marco do servidor (itens 1 a 3 primeiro; depois 4 a 7; arquivos e assinatura por último).
3. Sprint 2, começando por Estoque (liga com lote de HOF/Biomedicina) e Financeiro.
4. Sprint 3.
