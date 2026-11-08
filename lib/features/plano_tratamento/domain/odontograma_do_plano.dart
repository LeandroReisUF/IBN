/// O odontograma DESEJADO de um plano (como se quer que a boca fique ao fim do
/// tratamento) é guardado no mesmo `OdontogramaRepository` do odontograma
/// clínico, mas sob uma chave própria no lugar do id do paciente. Assim os dois
/// nunca se misturam e as regras (só inclusão, retificação, status) são as mesmas.
String chaveOdontogramaDoPlano(String planoId) => 'plano:$planoId';

/// A chave é de um odontograma de plano (e não de um paciente)?
bool ehChaveOdontogramaDePlano(String chave) => chave.startsWith('plano:');