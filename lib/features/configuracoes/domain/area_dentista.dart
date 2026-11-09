/// Áreas em que o Administrador pode marcar um dentista como especialista.
enum AreaDentista {
  ortodontia('Ortodontia'),
  hof('Harmonização orofacial (HOF)');

  final String rotulo;
  const AreaDentista(this.rotulo);
}