# Checklist Sprint 1 - ibn Sistema Clínico

## Fase F - Ortodontia Aba Própria (Prioridade MÁXIMA)

### Manutenções Ortodônticas
- [ ] Corrigir extends State<SecaoManutencoes> (já feito)
- [ ] Remover referências _abrirDialogo inexistentes
- [ ] Implementar dialog de criação/edição de manutenção
- [ ] Implementar botão "Agendar Manutenção" → TelaFormAgendamento
- [ ] Adicionar validação de campos obrigatórios
- [ ] Implementar exclusão de manutenção
- [ ] Testar listagem ordenada por data

### Fotos Comparativas
- [ ] Corrigir extends State<SecaoFotos> (já feito)
- [ ] Corrigir widget.paciente/widget.usuario (já feito)
- [ ] Implementar StatefulBuilder no dialog
- [ ] Implementar image_picker para câmera/galeria
- [ ] Implementar file_picker para upload arquivo
- [ ] Salvar foto em diretório local
- [ ] Exibir thumbnail real (não placeholder)
- [ ] Implementar exclusão de foto

### Ficha Ortodôntica
- [ ] Corrigir context em _linha/_visualizacao (já feito)
- [ ] Corrigir context em _card (já feito)
- [ ] Implementar validação de campos obrigatórios
- [ ] Implementar feedback visual após salvar
- [ ] Implementar carregamento de ficha existente
- [ ] Testar edição e atualização

### Testes Automatizados
- [ ] Criar test_ortodontia_repository_test.dart
- [ ] Testar salvar/carregar ficha
- [ ] Testar adicionar/listar manutenções
- [ ] Testar adicionar/listar fotos
- [ ] Testar notificação de listeners
- [ ] Meta: 15 testes novos

---

## Correções Técnicas

### Imports
- [x] aba_ortodontia_ficha.dart → import usuario.dart
- [x] aba_ortodontia_arcos.dart → import usuario.dart
- [x] aba_ortodontia_fotos.dart → import usuario.dart
- [x] aba_ortodontia_manutencoes.dart → import usuario.dart

### State Classes
- [x] _SecaoFotosState extends State<SecaoFotos>
- [x] _SecaoManutencoesState extends State<SecaoManutencoes>

### Context
- [x] _linha recebe BuildContext
- [x] _card recebe BuildContext
- [x] _visualizacao recebe BuildContext

---

## Build e Testes
- [ ] flutter clean && flutter pub get
- [ ] flutter run -d windows (sem erros)
- [ ] flutter test (75+ testes passando)
- [ ] flutter build windows --debug
- [ ] flutter build apk --debug
- [ ] Verificar em Android real

---

## Documentação
- [ ] Atualizar STATUS_PROJETO.md
- [ ] Atualizar FASE_F_ORTODONTIA_ABA.md
- [ ] Atualizar PROXIMOS_PASSOS_SPRINT1.md

---

## Estimativa: 23 horas (3-4 dias)