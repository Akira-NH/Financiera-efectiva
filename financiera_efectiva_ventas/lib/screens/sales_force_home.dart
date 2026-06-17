import 'package:flutter/material.dart';

import '../data/models/client.dart';
import '../data/repositories/sales_repository.dart';
import '../data/services/firestore_sales_service.dart';
import '../widgets/app_shell_widgets.dart';
import 'application_screen.dart';
import 'customer_screen.dart';
import 'portfolio_screen.dart';
import 'route_screen.dart';

class SalesForceHome extends StatefulWidget {
  const SalesForceHome({super.key});

  @override
  State<SalesForceHome> createState() => _SalesForceHomeState();
}

class _SalesForceHomeState extends State<SalesForceHome> {
  final salesService = const FirestoreSalesService();
  late Stream<SalesRepository> repositoryStream;
  int selectedIndex = 0;
  String? selectedClientKey;

  @override
  void initState() {
    super.initState();
    repositoryStream = salesService.watchRepository();
  }

  void _refreshRepository() {
    setState(() {
      repositoryStream = salesService.watchRepository();
    });
  }

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      _Destination('Cartera', Icons.assignment_outlined),
      _Destination('Ruta', Icons.map_outlined),
      _Destination('Solicitud', Icons.edit_document),
      _Destination('Cliente', Icons.badge_outlined),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 860;

    return StreamBuilder<SalesRepository>(
      stream: repositoryStream,
      builder: (context, snapshot) {
        final repository = snapshot.data;
        final selectedClient = repository == null
            ? null
            : _selectedClientFrom(repository);
        final pages = repository == null
            ? const [Center(child: CircularProgressIndicator())]
            : [
                PortfolioScreen(
                  repository: repository,
                  onRepositoryChanged: _refreshRepository,
                  onClientSelected: (client) => setState(() {
                    selectedClientKey = _clientKey(client);
                  }),
                ),
                RouteScreen(
                  repository: repository,
                  onClientSelected: (client) => setState(() {
                    selectedClientKey = _clientKey(client);
                  }),
                  onOpenApplication: (client) => setState(() {
                    selectedClientKey = _clientKey(client);
                    selectedIndex = 2;
                  }),
                ),
                ApplicationScreen(
                  repository: repository,
                  selectedClient: selectedClient,
                  onSaved: _refreshRepository,
                ),
                CustomerScreen(
                  repository: repository,
                  onRepositoryChanged: _refreshRepository,
                  selectedClientKey: selectedClientKey,
                  onClientSelected: (client) => setState(() {
                    selectedClientKey = _clientKey(client);
                  }),
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

  String _clientKey(Client client) {
    if (client.requestId.isNotEmpty) return client.requestId;
    if (client.clientId.isNotEmpty) return client.clientId;
    return client.dni;
  }

  Client? _selectedClientFrom(SalesRepository repository) {
    final key = selectedClientKey;
    if (key == null) return null;
    return repository.clients
        .where((client) => _clientKey(client) == key)
        .firstOrNull;
  }
}

class _Destination {
  const _Destination(this.label, this.icon);

  final String label;
  final IconData icon;
}
