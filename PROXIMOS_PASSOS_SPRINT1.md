# Próximos Passos - Sprint 1
## ibn Sistema Clínico - Conclusão Sprint 1

**Data:** 27/10/2026  
**Status Atual:** 🟡 **Parcialmente Concluída - 90%**
**Testes:** 75/75 ✅
**Objetivo:** Fechar Fase F (Ortodontia) e estabilizar Sprint 1

---

## 🎯 Situação Atual

### ✅ Concluído na Sprint 1
- **Core System**: Login, Perfis, Agenda, Política de Acesso
- **Odontograma Fase A-E**: Desenho, condições, raízes, decíduos, ortodontia integrada
- **Modelos Fase F**: FichaOrtodontica, ManutencaoOrtodontica, FotoComparativaOrto
- **Repository**: OrtodontiaRepository (ChangeNotifier)
- **UI Base**: AbaOrtodontia com 4 sub-abas
- **Integração**: Aba Ortodontia no prontuário do dentista

### 🟡 Pendente Fase F (Ortodontia Aba Própria)
- Botões de ação funcionais
- Upload real de fotos
- Testes automatizados
- Integração com agendamento

---

## 📋 Passos Restantes - Prioridade Alta

### 1. **Fase F - Conclusão Ortodontia** (Estimativa: 2-3 dias)

#### 1.1. Manutenções Ortodônticas
- [ ] **Implementar `_abrirDialogo` em `aba_ortodontia_manutencoes.dart`**
  - Dialog para criar/editar manutenção
  - Campos: data, ativação realizada, próxima manutenção, observações
  - Validação de campos obrigatórios
  - Integração com `ortodontiaRepository.adicionarManutencao()`
  
- [ ] **Botão "Agendar Manutenção"**
  - Conexão com `TelaFormAgendamento`
  - Preencher automaticamente paciente e procedimento
  - Validar conflitos (RN01, RN02)
  
- [ ] **Listagem com ações**
  - Botão editar/excluir em cada linha
  - Filtro por período
  - Busca por termo

#### 1.2. Fotos Comparativas
- [ ] **Upload real de fotos**
  - Implementar `image_picker` (câmera/galeria)
  - Implementar `file_picker` (arquivos)
  - Salvar em diretório local/pasta do paciente
  - Exibir thumbnail real (não placeholder)
  
- [ ] **Organização de fotos**
  - Classificar por "Antes/Depois"
  - Tags por data/estágio
  - Visualização em grid com zoom
  - Opção deletar

#### 1.3. Ficha Ortodôntica
- [ ] **Validação completa**
  - Campos obrigatórios (tipo aparelho, data instalação)
  - Validação de datas (instalação < previsao)
  - Feedback visual de erros
  
- [ ] **Persistência melhorada**
  - Atualização em tempo real com ChangeNotifier
  - Feedback visual após salvar
  - Undo/Redo básico

#### 1.4. Testes Automatizados
- [ ] **Testes Fase F**
  ```dart
  test('FichaOrtodontica salva e carrega corretamente')
  test('ManutencaoOrtodontica persiste com ordenação')
  test('FotoComparativaOrto adiciona e lista')
  test('OrtodontiaRepository notifica listeners')
  ```
  - Meta: +15 testes (total 90)

---

### 2. **Correções Técnicas Urgentes** (Estimativa: 1 dia)

#### 2.1. Bugs Conhecidos
- [ ] **Contexto em widgets**: Alguns `_linha` e `_card` precisam de `BuildContext`
- [ ] **State classes**: Verificar todos `extends State<Widget>` corretos
- [ ] **Getters widget.***: Usar `widget.paciente` em vez de `paciente` direto

#### 2.2. Importações
- [ ] **Import Usuario**: Todos arquivos de seção devem importar `../../core/usuario.dart`
- [ ] **Consistência**: Verificar todos imports de `auth_service`, `formadores`

#### 2.3. Documentação
- [ ] **FASE_F_ORTODONTIA_ABA.md**: Atualizar com status real
- [ ] **STATUS_PROJETO.md**: Atualizar após conclusão Fase F

---

### 3. **Refinamentos UI/UX** (Estimativa: 1-2 dias)

#### 3.1. Prontuário Completo
- [ ] **Aba Anamnese**: Formulário básico de anamnese
- [ ] **Aba Documentos**: Upload de laudos, receitas, termos
- [ ] **Aba Exames**: Solicitação e visualização de exames
- [ ] **Aba HOF**: Integração básica (placeholder)

#### 3.2. Melhorias Odontograma
- [ ] **Tooltip**: Mostrar condição ao hover/click
- [ ] **Histórico**: Visualizar evolução temporal
- [ ] **Export**: Exportar odontograma como PDF/PNG

---

## 📊 Estimativa de Tempo

| Fase | Tarefa | Horas | Status |
|------|--------|-------|--------|
| Fase F | Manutenções completas | 6h | 🟡 |
| Fase F | Fotos upload real | 4h | 🟡 |
| Fase F | Testes automatizados | 3h | ❌ |
| Correções | Bugs técnicos | 4h | 🟡 |
| Refinamentos | UI/UX | 6h | ❌ |
| **Total** | | **23h** | |

**Previsão de conclusão**: 3-4 dias úteis

---

## 🚀 Próximos Módulos (Pós Sprint 1)

### Sprint 2 - Biomedicina + HOF
1. **Prontuário Base**
   - Modelo `Prontuario`, `Atendimento`, `Evolucao`
   - Anamnese estruturada
   - Histórico completo

2. **HOF (Harmonização Orofacial)**
   - Fichas de avaliação facial
   - Pontos anatômicos
   - Fotos com marcação
   - Relatórios

3. **Biomedicina**
   - Prontuário específico
   - Procedimentos correlacionados
   - Integração com agenda

### Sprint 3 - Infraestrutura
1. **Servidor/API**
   - REST API com FastAPI/Node
   - PostgreSQL
   - Autenticação JWT
   - Hash de senhas
   - 2FA

2. **Sync & Backup**
   - Sincronização offline/online
   - Backup automático
   - Export/import dados

---

## ✅ Critérios de Aceitação Sprint 1

- [ ] **Aba Ortodontia 100% funcional**
  - CRUD ficha
  - CRUD manutenções
  - Upload fotos real
  - Integração agendamento
  
- [ ] **Testes**: 90+ testes passando
- [ ] **Build Windows**: Sem erros de compilação
- [ ] **Build Android**: APK funcional
- [ ] **Build Web**: Funcional básico
- [ ] **Documentação**: Status atualizado

---

## 📝 Observações

### Pendências Técnicas
- ⚠️ Dados em memória (perdem ao fechar app)
- ⚠️ Contas de teste com senha fraca
- ⚠️ Sem servidor ainda
- ⚠️ Licença imagens odontograma

### Próximos Passos Imediatos
1. Corrigir bugs de compilação Fase F
2. Implementar dialog de manutenções
3. Upload real de fotos
4. Escrever testes automatizados
5. Testar build em Windows/Android

---

**Responsável**: Time de Desenvolvimento  
**Revisão**: 28/10/2026  
**Meta**: Fechar Sprint 1 até 31/10/2026