# Status do Projeto — ibn (Sistema Clínico)

**Última atualização:** 27/10/2026  
**Stack:** Flutter (Windows, Android, Web) — dados em memória (sem servidor)  
**Testes:** 75/75 ✅

---

## Legenda
- ✅ Concluído
- 🟡 Parcial / Em andamento
- ❌ Pendente

---

## Sprint 1 — Core + Odontologia + Biomedicina

| Módulo / Fase | Status | Observações |
|---------------|--------|-------------|
| Login / Perfis (RF01.1, RF01.2) | ✅ | Contas de teste, `Modulo` por perfil |
| Pacientes + LGPD (RF03.1) | ✅ | Responsável, termo, vínculos, inativar/excluir |
| Agenda + Salas (RF02, RN01, RN02) | ✅ | Conflitos, 10 testes |
| Política de Acesso (RN03) | ✅ | `PoliticaAcessoService`, `LogAcesso` |
| **Odontograma Fase A** (desenho + caixa) | ✅ | 18 testes |
| **Odontograma Fase B** (condições, evolução) | ✅ | 33 testes |
| **Odontograma Fase C** (raízes) | ✅ | 9 testes |
| **Odontograma Fase D** (decíduos) | ✅ | 4 testes |
| **Odontograma Fase E** (orto camada 1) | ✅ | **NOVO** — Marcas no dente + arcada |
| **Odontograma Fase F** (orto aba própria) | 🟡 | Modelos ✅, Repository ✅, UI 90% ✅ |
| HOF, Exames, Documentos, Anamnese | ❌ | Próximos |
| Servidor/API/PostgreSQL | ❌ | Após Sprint 1 |

---

## Total de Testes: **75/75 ✅**

| Suite | Testes |
|-------|--------|
| AgendaService | 10 |
| AnatomiaDente | 18 |
| CaixaDente (quadrada + redonda) | 10 |
| DesenhoDente (faixaDaRaiz) | 4 |
| Odontograma (estado, retificação, raízes, decíduos, visões, catálogo, acesso) | 33 |

---

## Fases do Odontograma (RF04.1)

| Fase | Descrição | Status |
|------|-----------|--------|
| **A** | Desenho 2D + caixa dividida | ✅ |
| **B** | Condições, evolução, retificação, visões | ✅ |
| **C** | Tratamentos de raiz | ✅ |
| **D** | Dentes decíduos | ✅ |
| **E** | Ortodontia — marcas no odontograma | ✅ **NOVO** |
| **F** | Ortodontia — aba própria (ficha, manutenções, fotos) | 🟡 |

### Fase E — Concluída (27/10/2026)
- 7 condições ortodônticas no catálogo (Bm, Be, Bd, Tb, Bt, Cf, Mi)
- Desenho no `CustomPainter` sobre a coroa
- Checkboxes por arcada (5 tipos × 2 arcadas) — só modo editável
- Toggle persiste via `OdontogramaRepository` com retificação RN05
- 4 procedimentos ortodônticos no catálogo
- Filtro "Ortodontia" nas categorias
- **75 testes passando**

### Fase F — Parcial (27/10/2026)
✅ Modelos: `FichaOrtodontica`, `ManutencaoOrtodontica`, `FotoComparativaOrto`  
✅ Repository: `OrtodontiaRepository` (ChangeNotifier)  
✅ UI: `AbaOrtodontia` composta por 4 widgets separados:
- `aba_ortodontia_ficha.dart` — ficha com tipo aparelho, datas, objetivos
- `aba_ortodontia_arcos.dart` — arcos/elásticos por arcada
- `aba_ortodontia_manutencoes.dart` — lista + dialog nova/editar
- `aba_ortodontia_fotos.dart` — grid + dialog adicionar (placeholder)
✅ Integração: aba "Ortodontia" no prontuário do dentista  
❌ Botão "Agendar manutenção" → `TelaFormAgendamento`  
❌ Upload real de fotos (`image_picker` / `file_picker`)  
❌ Testes automatizados

---

## Próximas Prioridades

1. **Fase F — Conclusão**
   - Botão "Agendar manutenção" no dialog de manutenção
   - Upload real de fotos
   - Testes automatizados

2. **Prontuário Base** (`Prontuario`, `Atendimento`, `Evolucao`, `Adendo`, `Anamnese`)

3. **HOF** (fichas, pontos, lote, fotos)

4. **Exames + Foto do paciente**

5. **Documentos** (prescrição, atestados, TCLE, PDF)

6. **Biomedicina** (RF05)

7. **Servidor** (API REST, PostgreSQL, hash, 2FA, RBAC, logs)

---

## Pendências Técnicas Conhecidas

- ⚠️ Contas de teste com senha `123456` — remover antes de uso real
- ⚠️ Dados em memória — perdem ao fechar app
- ⚠️ `GUIA_USO_SVGS_ODONTOGRAMA.md` não existe no repo (existem `manifest_direito.json` e `manifest_esquerdo.json`)
- ❓ Confirmar licença da imagem raster vetorizada (uso comercial)
- ❓ Validar siglas/cores com dentistas da clínica
- ❓ Limite idade decíduos (atual: 13 anos, constante)
- ❓ Raízes 3º molares ajustáveis por paciente
- ❓ Formas próprias de decíduos (hoje escala 0.75)

---

## Arquivos de Documentação no Projeto

| Arquivo | Descrição |
|---------|-----------|
| `Fase_E_ORTODONTIA_CAMADA1.md` | Detalhamento completo Fase E |
| `FASE_F_ORTODONTIA_ABA.md` | Detalhamento completo Fase F |
| `STATUS_PROJETO.md` | Este arquivo |
| `melhorias_odontograma.md` | Spec original (referência) |
| `diagramas_de_classe_sistema_clinico.md` | Diagramas Mermaid |