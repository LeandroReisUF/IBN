import 'package:flutter/services.dart';

/// Funções de formatação e validação usadas nos formulários.

String somenteDigitos(String texto) => texto.replaceAll(RegExp(r'\D'), '');

String formatarCpf(String texto) {
  final d = somenteDigitos(texto);
  if (d.length != 11) return texto;
  return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
}

String formatarTelefone(String texto) {
  final d = somenteDigitos(texto);
  if (d.length == 11) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  }
  if (d.length == 10) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  }
  return texto;
}

String formatarData(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}

/// Lê "dd/mm/aaaa". Retorna null se o texto não for uma data real.
DateTime? lerData(String texto) {
  final partes = texto.split('/');
  if (partes.length != 3 || partes[2].length != 4) return null;
  final dia = int.tryParse(partes[0]);
  final mes = int.tryParse(partes[1]);
  final ano = int.tryParse(partes[2]);
  if (dia == null || mes == null || ano == null) return null;
  final data = DateTime(ano, mes, dia);
  if (data.day != dia || data.month != mes || data.year != ano) return null;
  return data;
}

int idadeEm(DateTime nascimento) {
  final hoje = DateTime.now();
  var idade = hoje.year - nascimento.year;
  if (hoje.month < nascimento.month ||
      (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
    idade--;
  }
  return idade;
}

bool cpfValido(String texto) {
  final d = somenteDigitos(texto);
  if (d.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;

  int calcularDigito(int quantidade) {
    var soma = 0;
    for (var i = 0; i < quantidade; i++) {
      soma += int.parse(d[i]) * (quantidade + 1 - i);
    }
    final resto = (soma * 10) % 11;
    return resto == 10 ? 0 : resto;
  }

  return calcularDigito(9) == int.parse(d[9]) &&
      calcularDigito(10) == int.parse(d[10]);
}

/// Máscara de digitação. '#' = um dígito. Ex.: '###.###.###-##' (CPF).
/// Para telefone, [mascaraCurta] é usada enquanto houver até
/// [digitosCurta] dígitos (fixo de 10 dígitos x celular de 11).
class MascaraFormatter extends TextInputFormatter {
  final String mascara;
  final String? mascaraCurta;
  final int digitosCurta;

  const MascaraFormatter(this.mascara, {this.mascaraCurta, this.digitosCurta = 0});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    var digitos = somenteDigitos(novo.text);
    final maximo = '#'.allMatches(mascara).length;
    if (digitos.length > maximo) digitos = digitos.substring(0, maximo);

    final usar = (mascaraCurta != null && digitos.length <= digitosCurta)
        ? mascaraCurta!
        : mascara;

    final saida = StringBuffer();
    var i = 0;
    for (final c in usar.split('')) {
      if (i >= digitos.length) break;
      if (c == '#') {
        saida.write(digitos[i]);
        i++;
      } else {
        saida.write(c);
      }
    }
    final texto = saida.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

// ---------- datas e horas (agenda) ----------

const nomesDiaSemana = [
  'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira',
  'sexta-feira', 'sábado', 'domingo',
];

const nomesMes = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

String formatarHora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Remove a hora, deixando só o dia.
DateTime soData(DateTime d) => DateTime(d.year, d.month, d.day);

bool mesmoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;