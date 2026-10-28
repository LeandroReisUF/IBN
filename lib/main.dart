import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/tela_login.dart';
import 'telas/tela_principal.dart';

void main() {
  runApp(const SistemaClinicoApp());
}

class SistemaClinicoApp extends StatelessWidget {
  const SistemaClinicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema Clínico',
      debugShowCheckedModeBanner: false,
      // Calendário e relógio em português (showDatePicker / showTimePicker).
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
      ),
      // Escuta o AuthService: login -> tela principal; sair -> tela de login.
      home: ListenableBuilder(
        listenable: auth,
        builder: (context, _) =>
            auth.logado ? const TelaPrincipal() : const TelaLogin(),
      ),
    );
  }
}