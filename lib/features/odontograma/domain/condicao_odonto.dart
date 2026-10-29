/// O que foi marcado: o dente inteiro, uma face ou uma raiz (raiz: Fase C).
enum AlvoOdonto {
  dente('Dente inteiro'),
  face('Face'),
  raiz('Raiz');

  final String rotulo;
  const AlvoOdonto(this.rotulo);
}

/// Em que ponto está o tratamento daquela marcação.
enum StatusTratamento {
  existente('Existente'),
  planejado('Planejado'),
  emAndamento('Em andamento'),
  realizado('Realizado');

  final String rotulo;
  const StatusTratamento(this.rotulo);
}

enum CategoriaCondicao {
  estado('Estado do dente'),
  patologia('Patologias'),
  restauracao('Restaurações'),
  protese('Próteses'),
  indicacao('Indicações'),
  periodonto('Periodonto'),
  raiz('Raízes'),
  ortodontia('Ortodontia');

  final String rotulo;
  const CategoriaCondicao(this.rotulo);
}

/// Marcas ortodônticas desenhadas sobre a coroa do dente (Fase E).
/// Cada uma corresponde a uma condição do catálogo cujo [marcaOrtodontia]
/// aponta para o tipo de desenho a fazer.
enum MarcaOrtodontia {
  braqueteMetalico('Bm'),
  braqueteEstetico('Be'),
  banda('Bd'),
  tubo('Tb'),
  botao('Bt'),
  contencaoFixa('Cf'),
  miniImplante('Mi');

  final String sigla;
  const MarcaOrtodontia(this.sigla);
}

/// Catálogo de condições (sigla, cor, onde se aplica). PROVISÓRIO: as siglas e
/// cores devem ser validadas pelos dentistas da clínica; depois o catálogo pode
/// virar um cadastro configurável.
///
/// [prioridade]: número menor = mais importante (decide o selo do dente).
/// [usaStatus]: false = a condição só "existe" (ex.: Ausente), sem planejar.
/// [marcaOrtodontia]: quando não-nula, a condição é ortodôntica e o dente
///   desenha a marca correspondente sobre a coroa (Fase E).
enum CondicaoOdonto {
  nenhum('', 'Nenhum', CategoriaCondicao.estado,
      {AlvoOdonto.dente, AlvoOdonto.face, AlvoOdonto.raiz}, 0x00000000, 999,
      usaStatus: false),
  higido('H', 'Hígido', CategoriaCondicao.estado, {AlvoOdonto.dente}, 0xFFA5D6A7, 60,
      usaStatus: false),
  higidoSelado('Hs', 'Hígido selado', CategoriaCondicao.estado,
      {AlvoOdonto.dente, AlvoOdonto.face}, 0xFF2E7D32, 61,
      usaStatus: false),
  ausente('A', 'Ausente', CategoriaCondicao.estado, {AlvoOdonto.dente}, 0xFF9E9E9E, 1,
      usaStatus: false),
  extraido('E', 'Extraído', CategoriaCondicao.estado, {AlvoOdonto.dente}, 0xFF616161, 2,
      usaStatus: false),
  incluso('I', 'Incluso', CategoriaCondicao.estado, {AlvoOdonto.dente}, 0xFF78909C, 4,
      usaStatus: false),
  restoRadicular('RR', 'Resto radicular', CategoriaCondicao.estado,
      {AlvoOdonto.dente, AlvoOdonto.raiz}, 0xFF6D4C41, 3,
      usaStatus: false),
  extracaoIndicada('Ei', 'Extração indicada', CategoriaCondicao.indicacao,
      {AlvoOdonto.dente}, 0xFFC62828, 5),
  selanteIndicado('Si', 'Selante indicado', CategoriaCondicao.indicacao,
      {AlvoOdonto.face}, 0xFF26A69A, 30),
  cariado('C', 'Cariado', CategoriaCondicao.patologia, {AlvoOdonto.face}, 0xFFE53935, 20),
  manchaBranca('M', 'Mancha branca ativa', CategoriaCondicao.patologia,
      {AlvoOdonto.face}, 0xFFB3E5FC, 31),
  fratura('Fr', 'Fratura', CategoriaCondicao.patologia,
      {AlvoOdonto.dente, AlvoOdonto.face}, 0xFFFB8C00, 11),
  calculo('Cd', 'Cálculo dental', CategoriaCondicao.patologia, {AlvoOdonto.dente},
      0xFFFDD835, 40),
  retracaoGengival('Rg', 'Retração gengival', CategoriaCondicao.periodonto,
      {AlvoOdonto.dente}, 0xFFF06292, 41),
  restaurado('R', 'Restaurado', CategoriaCondicao.restauracao, {AlvoOdonto.face},
      0xFF1E88E5, 21),
  restauradoComCarie('Rc', 'Restaurado com cárie', CategoriaCondicao.restauracao,
      {AlvoOdonto.face}, 0xFF1E88E5, 19,
      corSecundariaArgb: 0xFFE53935),
  coroa('Co', 'Coroa', CategoriaCondicao.protese, {AlvoOdonto.dente}, 0xFFFFB300, 6,
      pintaCoroa: true),
  proteseUnitaria('PU', 'Prótese coronária / unitária', CategoriaCondicao.protese,
      {AlvoOdonto.dente}, 0xFF8E24AA, 7,
      pintaCoroa: true),
  proteseTemporaria('PT', 'Prótese temporária', CategoriaCondicao.protese,
      {AlvoOdonto.dente}, 0xFFCE93D8, 8,
      pintaCoroa: true),
  pilar('P', 'Pilar (de prótese)', CategoriaCondicao.protese, {AlvoOdonto.dente},
      0xFF6A1B9A, 9),
  proteseParcialRemovivel('PPR', 'Prótese parcial removível', CategoriaCondicao.protese,
      {AlvoOdonto.dente}, 0xFFBA68C8, 10),

  // ----- Raízes e periodonto (Fase C) -----
  tratamentoEndodontico('Te', 'Tratamento endodôntico (canal)', CategoriaCondicao.raiz,
      {AlvoOdonto.raiz}, 0xFF00ACC1, 50),
  retratamentoEndodontico('Rte', 'Retratamento endodôntico', CategoriaCondicao.raiz,
      {AlvoOdonto.raiz}, 0xFF00838F, 51),
  pulpotomia('Pp', 'Pulpotomia', CategoriaCondicao.raiz,
      {AlvoOdonto.dente, AlvoOdonto.raiz}, 0xFF26C6DA, 52,
      soDeciduo: true),
  pinoNucleo('Pn', 'Pino / núcleo intrarradicular', CategoriaCondicao.raiz,
      {AlvoOdonto.raiz}, 0xFF8D6E63, 53),
  lesaoPeriapical('Lp', 'Lesão periapical', CategoriaCondicao.raiz, {AlvoOdonto.raiz},
      0xFFD84315, 54),
  reabsorcaoRadicular('Rab', 'Reabsorção radicular', CategoriaCondicao.raiz,
      {AlvoOdonto.raiz}, 0xFFAD1457, 55),
  apicectomia('Ap', 'Apicectomia', CategoriaCondicao.raiz, {AlvoOdonto.raiz}, 0xFF5D4037, 56),
  mobilidade('Mob', 'Mobilidade dental', CategoriaCondicao.periodonto, {AlvoOdonto.dente},
      0xFFFF7043, 57),
  bolsaPeriodontal('Bp', 'Bolsa periodontal', CategoriaCondicao.periodonto,
      {AlvoOdonto.dente}, 0xFFC2185B, 58),
  lesaoFurca('Fu', 'Lesão de furca', CategoriaCondicao.periodonto, {AlvoOdonto.dente},
      0xFF7B1FA2, 59,
      soMultirradicular: true),
  raspagem('Ras', 'Raspagem e alisamento radicular', CategoriaCondicao.periodonto,
      {AlvoOdonto.dente, AlvoOdonto.raiz}, 0xFF3949AB, 62),
  implante('Imp', 'Implante osseointegrado', CategoriaCondicao.raiz, {AlvoOdonto.dente},
      0xFF455A64, 63),

  // ----- Ortodontia (Fase E) -----
  braqueteMetalico('Bm', 'Braquete metálico', CategoriaCondicao.ortodontia,
      {AlvoOdonto.dente}, 0xFF78909C, 70,
      marcaOrtodontia: MarcaOrtodontia.braqueteMetalico),
  braqueteEstetico('Be', 'Braquete estético', CategoriaCondicao.ortodontia,
      {AlvoOdonto.dente}, 0xFFE0E0E0, 71,
      marcaOrtodontia: MarcaOrtodontia.braqueteEstetico),
  banda('Bd', 'Banda', CategoriaCondicao.ortodontia, {AlvoOdonto.dente},
      0xFF8D6E63, 72, marcaOrtodontia: MarcaOrtodontia.banda,
      soMultirradicular: true),
  tubo('Tb', 'Tubo', CategoriaCondicao.ortodontia, {AlvoOdonto.dente},
      0xFF616161, 73, marcaOrtodontia: MarcaOrtodontia.tubo,
      soMultirradicular: true),
  botao('Bt', 'Botão', CategoriaCondicao.ortodontia, {AlvoOdonto.dente},
      0xFFEF5350, 74, marcaOrtodontia: MarcaOrtodontia.botao),
  contencaoFixa('Cf', 'Contenção fixa', CategoriaCondicao.ortodontia,
      {AlvoOdonto.dente}, 0xFF0D47A1, 75,
      marcaOrtodontia: MarcaOrtodontia.contencaoFixa),
  miniImplante('Mi', 'Mini-implante', CategoriaCondicao.ortodontia,
      {AlvoOdonto.dente}, 0xFFFFD54F, 76,
      marcaOrtodontia: MarcaOrtodontia.miniImplante);

  final String sigla;
  final String rotulo;
  final CategoriaCondicao categoria;
  final Set<AlvoOdonto> alvos;
  final int corArgb;
  final int prioridade;
  final bool usaStatus;
  final MarcaOrtodontia? marcaOrtodontia; // desenho orto sobre a coroa (Fase E)
  final int? corSecundariaArgb; // listras (ex.: Restaurado com cárie)
  final bool pintaCoroa; // tinge a coroa do desenho (ex.: Coroa dourada)
  final bool soDeciduo; // só aparece em dentes decíduos (ex.: Pulpotomia)
  final bool soMultirradicular; // só em dentes com mais de uma raiz (ex.: Furca)

  const CondicaoOdonto(
    this.sigla,
    this.rotulo,
    this.categoria,
    this.alvos,
    this.corArgb,
    this.prioridade, {
    this.usaStatus = true,
    this.marcaOrtodontia,
    this.corSecundariaArgb,
    this.pintaCoroa = false,
    this.soDeciduo = false,
    this.soMultirradicular = false,
  });

  /// Condições que podem ser marcadas em [alvo] ("Nenhum" vem primeiro).
  /// Condições só de decíduos ou só de multirradiculares ficam de fora quando
  /// o dente não for desse tipo.
  static List<CondicaoOdonto> paraAlvo(
    AlvoOdonto alvo, {
    bool deciduo = false,
    bool multirradicular = true,
  }) =>
      values
          .where((c) =>
              c.alvos.contains(alvo) &&
              (!c.soDeciduo || deciduo) &&
              (!c.soMultirradicular || multirradicular))
          .toList();
}