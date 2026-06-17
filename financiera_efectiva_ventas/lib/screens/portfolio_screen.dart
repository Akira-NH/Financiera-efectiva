import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../data/models/client.dart';
import '../data/repositories/sales_repository.dart';
import '../data/services/firestore_sales_service.dart';
import '../widgets/app_shell_widgets.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({
    super.key,
    required this.repository,
    required this.onRepositoryChanged,
    required this.onClientSelected,
  });

  final SalesRepository repository;
  final VoidCallback onRepositoryChanged;
  final ValueChanged<Client> onClientSelected;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final searchController = TextEditingController();
  String clientStatus = 'Todos';
  String requestStatus = 'Todos';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Client> get filteredClients {
    final query = searchController.text.trim().toLowerCase();
    return widget.repository.clients.where((client) {
      final textMatch =
          query.isEmpty ||
          client.name.toLowerCase().contains(query) ||
          client.dni.contains(query);
      final clientStatusMatch =
          clientStatus == 'Todos' || client.clientStatus == clientStatus;
      final requestStatusMatch =
          requestStatus == 'Todos' || client.requestStatus == requestStatus;
      return textMatch && clientStatusMatch && requestStatusMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clients = filteredClients;
    return AppScrollView(
      children: [
        SectionTitle(
          title: 'Cartera',
          subtitle:
              '${widget.repository.clients.length} clientes demo de scoring crediticio.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Buscar por nombre o DNI',
                ),
              ),
            ),
            _FilterDropdown(
              label: 'Estado cliente',
              value: clientStatus,
              values: const ['Todos', 'Visitar', 'Visitado'],
              onChanged: (value) => setState(() => clientStatus = value),
            ),
            _FilterDropdown(
              label: 'Estado solicitud',
              value: requestStatus,
              values: const ['Todos', 'Pendiente', 'Aceptado', 'Negado'],
              onChanged: (value) => setState(() => requestStatus = value),
            ),
            StatusPill(
              label: '${clients.length} resultados',
              color: AppTheme.brandBlue,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (clients.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay clientes que coincidan con los filtros.'),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final client in clients)
                SizedBox(
                  width: 390,
                  child: _ClientCard(
                    client: client,
                    onStatusChanged: _updateClientStatus,
                    onSelected: widget.onClientSelected,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _updateClientStatus(Client client, String status) async {
    try {
      await const FirestoreSalesService().updateClientStatus(
        clientId: client.clientId.isEmpty ? client.dni : client.clientId,
        requestId: client.requestId,
        status: status,
      );
      widget.onRepositoryChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cliente marcado como $status.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el estado: $error')),
      );
    }
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.onStatusChanged,
    required this.onSelected,
  });

  final Client client;
  final void Function(Client client, String status) onStatusChanged;
  final ValueChanged<Client> onSelected;

  @override
  Widget build(BuildContext context) {
    final initial = client.name.trim().isEmpty
        ? '?'
        : client.name.trim().characters.first.toUpperCase();
    final requestColor = switch (client.requestStatus) {
      'Aceptado' => Colors.green,
      'Pendiente' => AppTheme.brandGold,
      _ => AppTheme.brandCoral,
    };
    final clientColor = client.clientStatus == 'Visitado'
        ? AppTheme.brandNavy
        : AppTheme.brandGold;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelected(client),
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
                      Text('DNI ${client.dni}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(label: client.clientStatus, color: clientColor),
                StatusPill(label: client.requestStatus, color: requestColor),
                StatusPill(
                  label: 'Score ${client.preScore}',
                  color: AppTheme.brandBlue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Direccion: ${client.location}'),
            Text('Solicitud: S/ ${client.requestAmount.toStringAsFixed(0)}'),
            Text('Destino: ${client.creditPurpose}'),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              selected: {client.clientStatus},
              onSelectionChanged: (values) {
                final status = values.first;
                if (status != client.clientStatus) {
                  onStatusChanged(client, status);
                }
              },
              segments: const [
                ButtonSegment(value: 'Visitar', label: Text('Visitar')),
                ButtonSegment(value: 'Visitado', label: Text('Visitado')),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
