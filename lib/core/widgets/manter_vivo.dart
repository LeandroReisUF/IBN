import 'package:flutter/material.dart';

/// Mantém o estado do filho quando a aba sai da tela (dentro de um TabBarView),
/// para não perder o que foi digitado e ainda não foi salvo.
class ManterVivo extends StatefulWidget {
  final Widget child;
  const ManterVivo({super.key, required this.child});

  @override
  State<ManterVivo> createState() => _ManterVivoState();
}

class _ManterVivoState extends State<ManterVivo> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}