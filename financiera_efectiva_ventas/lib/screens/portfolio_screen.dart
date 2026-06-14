import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../data/models/client.dart';
import '../data/repositories/sales_repository.dart';
import '../widgets/app_shell_widgets.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key, required this.repository});

  final SalesRepository repository;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final searchController = TextEditingController();
  String filter = 'Todos';

  static const filters = [
    'Todos',
    'Renovaciones',
    'Nuevas',
    'En mora',
    'Visitados',
  ];
  static const managementTypes = [
    'RENOVACION',
    'AMPLIACION',
    'NUEVA SOLICITUD',
    'SEGUIMIENTO',
    'RECUPERACION MORA',
    'DESERTOR',
  ];
  static const priorities = ['ALTA', 'MEDIA', 'NORMAL'];
  static const visitStates = [
    'pendiente',
    'visitado',
    'no encontrado',
    'reagendado',
    'negocio cerrado',
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Client> get _filteredClients {
    final query = searchController.text.trim().toLowerCase();
    return widget.repository.clients.where((client) {
      final index = widget.repository.clients.indexOf(client);
      final management = managementTypes[index % managementTypes.length];
      final visitState = visitStates[index % visitStates.length];
      final matchesFilter = switch (filter) {
        'Renovaciones' =>
          management == 'RENOVACION' || management == 'AMPLIACION',
        'Nuevas' => management == 'NUEVA SOLICITUD',
        'En mora' => management == 'RECUPERACION MORA',
        'Visitados' => visitState == 'visitado',
        _ => true,
      };
      final lastDigits = client.dni.length >= 4
          ? client.dni.substring(client.dni.length - 4)
          : client.dni;
      final matchesQuery =
          query.isEmpty ||
          client.name.toLowerCase().contains(query) ||
          lastDigits.contains(query);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clients = _filteredClients;
    return AppScrollView(
      children: [
        const SectionTitle(
          title: 'Cartera diaria',
          subtitle:
              'Clientes asignados, visitas del dia y trabajo offline-first.',
        ),
        const MetricsGrid(
          metrics: [
            Metric('Renovaciones', '18', Icons.repeat, AppTheme.brandBlue),
            Metric('Visitas hoy', '12', Icons.location_on, AppTheme.brandNavy),
            Metric(
              'Monto potencial',
              'S/ 96k',
              Icons.payments,
              AppTheme.brandCoral,
            ),
            Metric('Mora alerta', '3', Icons.warning_amber, AppTheme.brandGold),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Buscar cliente o ultimos 4 digitos',
                ),
              ),
            ),
            SegmentedButton<String>(
              selected: {filter},
              onSelectionChanged: (values) =>
                  setState(() => filter = values.first),
              segments: [
                for (final item in filters)
                  ButtonSegment(value: item, label: Text(item)),
              ],
            ),
            const StatusPill(
              label: 'Local + Firebase',
              color: AppTheme.brandGold,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (clients.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay clientes que coincidan con la busqueda.'),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final client in clients)
                SizedBox(
                  width: 380,
                  child: _DailyClientCard(
                    client: client,
                    index: widget.repository.clients.indexOf(client),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DailyClientCard extends StatelessWidget {
  const _DailyClientCard({required this.client, required this.index});

  final Client client;
  final int index;

  @override
  Widget build(BuildContext context) {
    final management = _PortfolioScreenState
        .managementTypes[index % _PortfolioScreenState.managementTypes.length];
    final priority = _PortfolioScreenState
        .priorities[index % _PortfolioScreenState.priorities.length];
    final visitState = _PortfolioScreenState
        .visitStates[index % _PortfolioScreenState.visitStates.length];
    final totalDebt = num.tryParse(client.totalDebt.replaceAll(',', '')) ?? 0;
    final amount =
        'S/ ${(totalDebt + client.preScore * 20).toStringAsFixed(0)}';
    final initial = client.name.trim().isEmpty
        ? '?'
        : client.name.trim().characters.first.toUpperCase();
    final priorityColor = switch (priority) {
      'ALTA' => Colors.red,
      'MEDIA' => AppTheme.brandGold,
      _ => Colors.green,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(initial)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text('DNI ${_maskedDocument(client.dni)}'),
                    ],
                  ),
                ),
                StatusPill(label: priority, color: priorityColor),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(label: management, color: AppTheme.brandBlue),
                StatusPill(label: visitState, color: AppTheme.brandNavy),
                StatusPill(label: amount, color: AppTheme.brandCoral),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showClientSheet(context, client),
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Ver ficha'),
                ),
                FilledButton.icon(
                  onPressed: () => _showMessage(
                    context,
                    'Solicitud iniciada para ${client.name}',
                  ),
                  icon: const Icon(Icons.edit_document),
                  label: const Text('Iniciar solicitud'),
                ),
                IconButton.filledTonal(
                  tooltip: 'Ver en mapa',
                  onPressed: () => _showMessage(
                    context,
                    'Marcador abierto en ruta del dia.',
                  ),
                  icon: const Icon(Icons.map_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _maskedDocument(String dni) {
    if (dni.length <= 3) return '***$dni';
    return '***${dni.substring(dni.length - 3)}';
  }

  void _showClientSheet(BuildContext context, Client client) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(client.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Telefono: ${client.phone}'),
              Text('Negocio: ${client.businessName} - ${client.businessType}'),
              Text('Ubicacion: ${client.location}'),
              Text('SBS: ${client.sbsRating}'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text('Cerrar ficha rapida'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
