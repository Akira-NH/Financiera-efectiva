import 'package:flutter/material.dart';

import '../data/repositories/sales_repository.dart';
import '../data/services/firestore_sales_service.dart';
import '../widgets/app_shell_widgets.dart';
import 'application_screen.dart';
import 'customer_screen.dart';
import 'portfolio_screen.dart';
import 'requests_screen.dart';
import 'route_screen.dart';

class SalesForceHome extends StatefulWidget {
  const SalesForceHome({super.key});

  @override
  State<SalesForceHome> createState() => _SalesForceHomeState();
}

class _SalesForceHomeState extends State<SalesForceHome> {
  final salesService = const FirestoreSalesService();
  late Future<SalesRepository> repositoryFuture;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    repositoryFuture = salesService.loadRepository();
  }

  void _refreshRepository() {
    setState(() {
      repositoryFuture = salesService.loadRepository();
    });
  }

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      _Destination('Cartera', Icons.assignment_outlined),
      _Destination('Ruta', Icons.map_outlined),
      _Destination('Cliente', Icons.badge_outlined),
      _Destination('Solicitud', Icons.edit_document),
      _Destination('Estados', Icons.timeline_outlined),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 860;

    return FutureBuilder<SalesRepository>(
      future: repositoryFuture,
      builder: (context, snapshot) {
        final repository = snapshot.data;
        final pages = repository == null
            ? const [Center(child: CircularProgressIndicator())]
            : [
                PortfolioScreen(repository: repository),
                RouteScreen(repository: repository),
                CustomerScreen(repository: repository),
                ApplicationScreen(repository: repository),
                RequestsScreen(
                  repository: repository,
                  onRepositoryChanged: _refreshRepository,
                ),
              ];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: wide ? 24 : 16,
            title: const Row(
              children: [
                CompanyLogo(),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Financiera Efectiva | Fuerza de Ventas',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: const [SyncStatus(), SizedBox(width: 12)],
          ),
          body: Row(
            children: [
              if (wide && repository != null)
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => selectedIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final item in destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
                ),
              Expanded(child: pages[selectedIndex.clamp(0, pages.length - 1)]),
            ],
          ),
          bottomNavigationBar: wide || repository == null
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => selectedIndex = index);
                  },
                  destinations: [
                    for (final item in destinations)
                      NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon);

  final String label;
  final IconData icon;
}
