import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../data/models/client.dart';
import '../data/repositories/sales_repository.dart';
import '../widgets/app_shell_widgets.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key, required this.repository});

  final SalesRepository repository;

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  Client? selectedClient;

  @override
  void initState() {
    super.initState();
    selectedClient = widget.repository.clients.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final client = selectedClient;
    if (client == null) {
      return const AppScrollView(
        children: [
          SectionTitle(
            title: 'Ficha del cliente',
            subtitle: 'No hay clientes disponibles.',
          ),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sin clientes para mostrar. Sincroniza la cartera.'),
            ),
          ),
        ],
      );
    }

    final totalDebt = num.tryParse(client.totalDebt.replaceAll(',', '')) ?? 0;
    return AppScrollView(
      children: [
        SectionTitle(
          title: 'Ficha del cliente',
          subtitle: '${client.name} | DNI ${client.dni}',
        ),
        SizedBox(
          width: 420,
          child: DropdownButtonFormField<Client>(
            initialValue: client,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Seleccionar cliente'),
            items: [
              for (final item in widget.repository.clients)
                DropdownMenuItem(value: item, child: Text(item.name)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => selectedClient = value);
            },
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            InfoPanel(
              title: 'Datos generales',
              icon: Icons.person_outline,
              rows: [
                InfoRow('Nombre', client.name),
                InfoRow('DNI', client.dni),
                InfoRow('Telefono', client.phone),
                InfoRow('Direccion', client.location),
                InfoRow('Negocio', client.businessType),
                InfoRow('Antiguedad', client.businessAge),
                InfoRow('Ubicacion negocio', client.location),
              ],
            ),
            InfoPanel(
              title: 'Historial crediticio',
              icon: Icons.history,
              rows: [
                const InfoRow('Ultimo credito', 'S/ 8,500'),
                const InfoRow('Plazo', '12 meses'),
                const InfoRow('Estado', 'Vigente'),
                InfoRow(
                  'Pagos puntuales',
                  '${(client.preScore / 8).clamp(70, 99)}%',
                ),
              ],
            ),
            InfoPanel(
              title: 'Posicion del cliente',
              icon: Icons.monitor_heart_outlined,
              rows: [
                InfoRow('Deuda total', 'S/ ${client.totalDebt}'),
                const InfoRow('Cuotas al dia', '10'),
                const InfoRow('Cuotas en mora', '0'),
                const InfoRow('Ultimo pago', '12/06/2026'),
              ],
            ),
            InfoPanel(
              title: 'Productos activos',
              icon: Icons.account_balance_wallet_outlined,
              rows: const [
                InfoRow('Creditos vigentes', '1'),
                InfoRow('Ahorros', 'Cuenta activa'),
                InfoRow('Otros productos', 'Microseguro'),
              ],
            ),
            InfoPanel(
              title: 'Oferta vigente',
              icon: Icons.local_offer_outlined,
              rows: [
                InfoRow(
                  'Monto preaprobado',
                  'S/ ${(totalDebt + 3500).toStringAsFixed(0)}',
                ),
                const InfoRow('Plazo sugerido', '12 meses'),
                const InfoRow('Tasa referencial', '39.2% TEA'),
                const InfoRow('Vence', '30/07/2026'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Abrir marcador: ${client.phone}')),
                );
              },
              icon: const Icon(Icons.phone),
              label: const Text('Llamar'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Crear solicitud'),
            ),
            const StatusPill(
              label: 'Semaforo: Riesgo medio',
              color: AppTheme.brandGold,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _CreditHistoryTable(),
      ],
    );
  }
}

class _CreditHistoryTable extends StatelessWidget {
  const _CreditHistoryTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['Credito 00124', 'S/ 6,000', '10 meses', 'Cancelado'],
      ['Credito 00188', 'S/ 8,500', '12 meses', 'Vigente'],
      ['Renovacion', 'S/ 12,000', '12 meses', 'Preaprobado'],
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PanelHeader('Ultimos creditos', Icons.table_chart_outlined),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Producto')),
                  DataColumn(label: Text('Monto')),
                  DataColumn(label: Text('Plazo')),
                  DataColumn(label: Text('Estado')),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [for (final cell in row) DataCell(Text(cell))],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
