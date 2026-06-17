import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../data/models/client.dart';
import '../data/repositories/sales_repository.dart';
import '../data/services/firestore_sales_service.dart';
import '../widgets/app_shell_widgets.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({
    super.key,
    required this.repository,
    required this.onRepositoryChanged,
    this.selectedClientKey,
    required this.onClientSelected,
  });

  final SalesRepository repository;
  final VoidCallback onRepositoryChanged;
  final String? selectedClientKey;
  final ValueChanged<Client> onClientSelected;

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  Client? selectedClient;
  bool savingDecision = false;
  final Map<String, String> decisionOverrides = {};

  List<Client> get visibleClients {
    final routeNames = widget.repository.routeVisits
        .map((visit) => visit.client)
        .toSet();
    return widget.repository.clients
        .where(
          (client) =>
              routeNames.contains(client.name) || _isExternalRequest(client),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    selectedClient = _clientForKey(widget.selectedClientKey) ??
        visibleClients.firstOrNull;
  }

  @override
  void didUpdateWidget(covariant CustomerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clients = visibleClients;
    final current = selectedClient;
    final externalSelected = _clientForKey(widget.selectedClientKey);
    if (externalSelected != null &&
        _requestKey(externalSelected) !=
            (current == null ? '' : _requestKey(current))) {
      selectedClient = externalSelected;
      return;
    }
    if (current == null ||
        !clients.any((client) => _requestKey(client) == _requestKey(current))) {
      selectedClient = clients.firstOrNull;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = visibleClients;
    final client = _selectedFrom(clients);
    if (client == null || clients.isEmpty) {
      return const AppScrollView(
        children: [
          SectionTitle(
            title: 'Ficha del cliente',
            subtitle: 'No hay solicitudes pendientes de evaluacion.',
          ),
        ],
      );
    }

    return AppScrollView(
      children: [
        SectionTitle(
          title: 'Ficha del cliente',
          subtitle:
              '${_statusLabel(_statusFor(client))} | ${client.name} | DNI ${client.dni}',
        ),
        SizedBox(
          width: 460,
          child: DropdownButtonFormField<String>(
            initialValue: _requestKey(client),
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Cliente en ruta'),
            items: [
              for (final item in clients)
                DropdownMenuItem(
                  value: _requestKey(item),
                  child: Text(item.name),
                ),
            ],
            onChanged: (key) {
              if (key == null) return;
              final match = clients
                  .where((item) => _requestKey(item) == key)
                  .firstOrNull;
              if (match != null) {
                widget.onClientSelected(match);
                setState(() => selectedClient = match);
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            InfoPanel(
              title: 'Datos personales',
              icon: Icons.person_outline,
              rows: [
                InfoRow('Nombre', client.name),
                InfoRow('DNI', client.dni),
                InfoRow('Telefono', client.phone),
                InfoRow('Direccion', client.location),
              ],
            ),
            InfoPanel(
              title: 'Informacion financiera',
              icon: Icons.account_balance_wallet_outlined,
              rows: [
                InfoRow('Ingresos', 'S/ ${client.monthlyIncome}'),
                InfoRow('Gastos', 'S/ ${client.monthlyExpenses}'),
                InfoRow('Cuotas actuales', 'S/ ${client.currentInstallments}'),
                InfoRow('Deuda vigente', 'S/ ${client.totalDebt}'),
                InfoRow('Creditos activos', '${client.activeCredits}'),
              ],
            ),
            InfoPanel(
              title: 'Scoring crediticio',
              icon: Icons.analytics_outlined,
              rows: [
                InfoRow('Score', '${client.preScore}/100'),
              ],
            ),
            InfoPanel(
              title: 'Solicitud',
              icon: Icons.request_quote_outlined,
              rows: [
                InfoRow('Monto', 'S/ ${client.requestAmount}'),
                InfoRow('Plazo', '${client.termMonths} meses'),
                InfoRow('Destino', client.creditPurpose),
                InfoRow('Estado', _statusLabel(_statusFor(client))),
                InfoRow('Recomendacion', client.recommendation),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _CreditDecisionPanel(
          requestStatus: _statusFor(client),
          fieldVisitCompleted: client.fieldVisitCompleted,
          saving: savingDecision,
          onDecision: _updateDecision,
        ),
      ],
    );
  }

  Future<void> _updateDecision(String decision) async {
    final client = _selectedFrom(visibleClients);
    if (client == null || savingDecision) return;
    if (!client.fieldVisitCompleted) return;
    final currentStatus = _statusFor(client);
    if (currentStatus != 'Pendiente') return;
    setState(() => savingDecision = true);
    final messenger = ScaffoldMessenger.of(context);
    final requestId = _requestKey(client);
    try {
      await const FirestoreSalesService().updateCreditDecision(
        clientId: client.clientId.isEmpty ? client.dni : client.clientId,
        requestId: requestId,
        decision: decision,
      );
      setState(() => decisionOverrides[requestId] = decision);
      messenger.showSnackBar(
        SnackBar(content: Text('Solicitud marcada como $decision.')),
      );
      widget.onRepositoryChanged();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $error')),
      );
    } finally {
      if (mounted) setState(() => savingDecision = false);
    }
  }

  String _requestKey(Client client) {
    if (client.requestId.isNotEmpty) return client.requestId;
    if (client.clientId.isNotEmpty) return client.clientId;
    return client.dni;
  }

  Client? _selectedFrom(List<Client> clients) {
    if (clients.isEmpty) return null;
    final current = selectedClient;
    if (current == null) return clients.first;
    final key = _requestKey(current);
    return clients.where((client) => _requestKey(client) == key).firstOrNull ??
        clients.first;
  }

  Client? _clientForKey(String? key) {
    if (key == null) return null;
    return visibleClients
        .where((client) => _requestKey(client) == key)
        .firstOrNull;
  }

  String _statusFor(Client client) {
    return decisionOverrides[_requestKey(client)] ?? client.requestStatus;
  }

  bool _isExternalRequest(Client client) {
    return client.requestId.isNotEmpty &&
        !client.requestId.startsWith('CLI-DEMO-');
  }

  String _statusLabel(String status) {
    return status == 'Pendiente' ? 'Pendiente de Evaluacion' : status;
  }
}

class _CreditDecisionPanel extends StatelessWidget {
  const _CreditDecisionPanel({
    required this.requestStatus,
    required this.fieldVisitCompleted,
    required this.saving,
    required this.onDecision,
  });

  final String requestStatus;
  final bool fieldVisitCompleted;
  final bool saving;
  final ValueChanged<String> onDecision;

  @override
  Widget build(BuildContext context) {
    final isPending = requestStatus == 'Pendiente';
    final canEvaluate = isPending && fieldVisitCompleted;
    final label = isPending ? 'Pendiente de Evaluacion' : requestStatus;
    final statusColor = switch (requestStatus) {
      'Aceptado' => Colors.green,
      'Negado' => AppTheme.brandCoral,
      _ => AppTheme.brandGold,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PanelHeader('Estado de Creditos', Icons.fact_check_outlined),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(
                  label: 'Estado: $label',
                  color: statusColor,
                ),
                if (isPending && !fieldVisitCompleted)
                  const StatusPill(
                    label: 'Completa Solicitud antes de evaluar',
                    color: Colors.blueGrey,
                  ),
                if (canEvaluate) ...[
                  FilledButton.icon(
                    onPressed: saving ? null : () => onDecision('Aceptado'),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Aceptar credito'),
                  ),
                  OutlinedButton.icon(
                    onPressed: saving ? null : () => onDecision('Negado'),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Rechazar solicitud'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
