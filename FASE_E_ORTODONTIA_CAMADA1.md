# Fase E — Ortodontia, Camada 1 (Marcas no Odontograma)

**Data:** 27/10/2026  
**Status:** ✅ **CONCLUÍDA**  
**Testes:** 75/75 passando

---

## Resumo

Implementação da **Fase E** do refinamento do odontograma: marcas ortodônticas desenhadas sobre os dentes e checkboxes de aparelho por arcada.

---

## 1. Modelos de Dados (`core/odontograma.dart`)

### Enum `MarcaOrtodontia`
| Valor | Sigla | Descrição |
|-------|-------|-----------|
| `braqueteMetalico` | Bm | Braquete metálico |
| `braqueteEstetico` | Be | Braquete estético |
| `banda` | Bd | Banda (só multirradiculares) |
| `tubo` | Tb | Tubo (só multirradiculares) |
| `botao` | Bt | Botão |
| `contencaoFixa` | Cf | Contenção fixa |
| `miniImplante` | Mi | Mini-implante |

### Enum `ArcadaOdonto`
- `superior` — Arcada superior
- `inferior` — Arcada inferior

### Enum `TipoMarcaArcada`
| Valor | Rótulo |
|-------|--------|
| `aparelhoFixo` | Aparelho fixo |
| `aparelhoMovel` | Aparelho móvel / placa |
| `alinhadores` | Alinhadores |
| `contencaoRemovivel` | Contenção removível |
| `expansor` | Expansor |

### Classe `MarcaArcada`
Registro de marca de arcada (RN05 — só inclusão + retificação via `retificaId`).