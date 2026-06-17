import 'package:flutter/material.dart';

import 'config/theme.dart';
import 'screens/sales_login_screen.dart';
import 'screens/sales_force_home.dart';

class FuerzaVentasApp extends StatefulWidget {
  const FuerzaVentasApp({super.key});

  @override
  State<FuerzaVentasApp> createState() => _FuerzaVentasAppState();
}

class _FuerzaVentasAppState extends State<FuerzaVentasApp> {
  bool authenticated = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fuerza de Ventas',
      theme: AppTheme.light,
      home: authenticated
          ? const SalesForceHome()
          : SalesLoginScreen(
              onAuthenticated: () => setState(() => authenticated = true),
            ),
    );
  }
}
