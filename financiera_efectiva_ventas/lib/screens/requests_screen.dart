import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models/credit_request.dart';
import '../utils/scoring.dart';
import '../data/repositories/sales_repository.dart';
import '../data/services/firestore_sales_service.dart';
import '../data/services/power_bi_export_service.dart';
import '../widgets/app_shell_widgets.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({
    super.key,
    required this.repository,
    required this.onRepositoryChanged,
  });

  final SalesRepository repository;
  final VoidCallback onRepositoryChanged;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Enviadas',
      'En comite',
      'Aprobadas',
      'Rechazadas',
      'Desembolsadas',
    ];

    return StreamBuilder<List<CreditRequest>>(
      stream: const FirestoreSalesService().watchCreditRequests(
        fallback: repository.requests,
      ),
      initialData: repository.requests,
      builder: (context, snapshot) {
        final requests = snapshot.data ?? repository.requests;
        return AppScrollView(
          children: [
            const SectionTitle(
              title: 'Estado de solicitudes',
              subtitle:
                  'Seguimiento en tiempo real desde envio hasta desembolso.',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DefaultTabController(
                  length: tabs.length,
                  child: Column(
                    children: [
                      const TabBar(
                        isScrollable: true,
                        tabs: [
                          Tab(text: 'Enviadas'),
                          Tab(text: 'En comite'),
                          Tab(text: 'Aprobadas'),
                          Tab(text: 'Rechazadas'),
                          Tab(text: 'Desembolsadas'),
                        ],
                      ),
                      SizedBox(
                        height: 460,
                        child: TabBarView(
                          children: [
                            for (final tab in tabs)
                              _RequestsTab(
                                requests: _requestsForTab(tab, requests),
                                onRepositoryChanged: onRepositoryChanged,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ExportPanel(repository: repository),
          ],
        );
      },
    );
  }

  List<CreditRequest> _requestsForTab(
    String tab,
    List<CreditRequest> requests,
  ) {
    return requests.where((request) {
      final status = request.status.toLowerCase();
      return switch (tab) {
        'Enviadas' =>
          status.contains('preaprob') ||
              status.contains('contact') ||
              status.contains('visita') ||
              status.contains('enviado'),
        'En comite' => status.contains('comite') || status.contains('comité'),
        'Aprobadas' => status.contains('aprobado'),
        'Rechazadas' => status.contains('rechaz'),
        'Desembolsadas' => status.contains('desembols'),
        _ => true,
      };
    }).toList();
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.requests,
    required this.onRepositoryChanged,
  });

  final List<CreditRequest> requests;
  final VoidCallback onRepositoryChanged;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(child: Text('No hay solicitudes en este estado.'));
    }

    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        for (final request in requests)
          RequestTimelineTile(
            request: request,
            onRepositoryChanged: onRepositoryChanged,
          ),
      ],
    );
  }
}

class RequestTimelineTile extends StatefulWidget {
  const RequestTimelineTile({
    super.key,
    required this.request,
    required this.onRepositoryChanged,
  });

  final CreditRequest request;
  final VoidCallback onRepositoryChanged;

  @override
  State<RequestTimelineTile> createState() => _RequestTimelineTileState();
}

class _RequestTimelineTileState extends State<RequestTimelineTile> {
  bool isProcessing = false;

  Future<void> _disburse() async {
    if (isProcessing) return;
    setState(() => isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await const FirestoreSalesService().approveAndDisburse(widget.request);
      messenger.showSnackBar(
        const SnackBar(content: Text('Crédito aprobado y desembolsado.')),
      );
      widget.onRepositoryChanged();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo desembolsar: $error')),
      );
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const states = [
      'Preaprobado',
      'Contactado',
      'Visita agendada',
      'Visita realizada',
      'Comite',
      'Aprobado',
      'Desembolsado',
    ];
    final request = widget.request;
    final current = states.indexOf(request.status);
    final canDisburse =
        request.clientId.isNotEmpty &&
        request.id.isNotEmpty &&
        request.status.toLowerCase().contains('aprob') &&
        request.amountValue > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.client} | ${request.amount}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              StatusPill(
                label: request.status,
                color: segmentColor(request.segment),
              ),
            ],
          ),
          if (request.score > 0 || request.riskLevel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  label: 'Score ${request.score}',
                  color: Theme.of(context).colorScheme.primary,
                ),
                StatusPill(
                  label: request.riskLevel.isEmpty
                      ? 'Riesgo pendiente'
                      : 'Riesgo ${request.riskLevel}',
                  color: segmentColor(request.riskLevel),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < states.length; i++)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: i <= current
                            ? Theme.of(context).colorScheme.secondary
                            : const Color(0xFFD8DEE8),
                        child: i <= current
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Text(states[i]),
                      if (i < states.length - 1)
                        Container(
                          width: 28,
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: i < current
                              ? Theme.of(context).colorScheme.secondary
                              : const Color(0xFFD8DEE8),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (canDisburse) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showDetail(context, request, states),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver detalle'),
                  ),
                  FilledButton.icon(
                    onPressed: isProcessing ? null : _disburse,
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.account_balance_wallet_outlined),
                    label: Text(
                      isProcessing ? 'Procesando...' : 'Aprobar y desembolsar',
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _showDetail(context, request, states),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver detalle'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDetail(
    BuildContext context,
    CreditRequest request,
    List<String> states,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final current = states.indexOf(request.status);
        return AlertDialog(
          title: Text(request.client),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Monto solicitado: ${request.amount}'),
                  Text('Estado actual: ${request.status}'),
                  if (request.score > 0) Text('Score: ${request.score}/100'),
                  if (request.riskLevel.isNotEmpty)
                    Text('Nivel de riesgo: ${request.riskLevel}'),
                  if (request.recommendation.isNotEmpty)
                    Text('Recomendacion: ${request.recommendation}'),
                  Text(
                    'Analista asignado: ${request.segment == 'PREMIER' ? 'Comite senior' : 'Por asignar'}',
                  ),
                  const SizedBox(height: 12),
                  const PanelHeader('Linea de tiempo', Icons.timeline),
                  const SizedBox(height: 8),
                  for (var i = 0; i < states.length; i++)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        i <= current
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: i <= current ? Colors.green : Colors.grey,
                      ),
                      title: Text(states[i]),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

class ExportPanel extends StatelessWidget {
  const ExportPanel({super.key, required this.repository});

  final SalesRepository repository;

  @override
  Widget build(BuildContext context) {
    const powerBiExport = PowerBiExportService();
    const firestoreService = FirestoreSalesService();
    final dataset = powerBiExport.buildDataset(
      clients: repository.clients,
      requests: repository.requests,
      routeVisits: repository.routeVisits,
    );
    final syncSummary = firestoreService.buildSyncSummary(repository);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PanelHeader('Exportacion de datos', Icons.dataset_outlined),
            const SizedBox(height: 12),
            const Text(
              'Datos preparados para seguimiento comercial y reportes de gestion.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  label: '${syncSummary.keys.length} colecciones',
                  color: Theme.of(context).colorScheme.primary,
                ),
                StatusPill(
                  label: '${dataset.totalRows} registros',
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const StatusPill(
                  label: 'Firestore activo',
                  color: Color(0xFFF4B740),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _showCsvPreview(
                      context,
                      'perfiles_clientes.csv',
                      dataset.clientsCsv,
                    );
                  },
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Clientes'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    _showCsvPreview(
                      context,
                      'creditos_preaprobados.csv',
                      dataset.requestsCsv,
                    );
                  },
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Solicitudes'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _showCsvPreview(
                      context,
                      'visitas_ruta.csv',
                      dataset.routeCsv,
                    );
                  },
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('Rutas'),
                ),
                FilledButton.icon(
                  onPressed: () => _syncFirestore(context, firestoreService),
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: const Text('Sincronizar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncFirestore(
    BuildContext context,
    FirestoreSalesService firestoreService,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await firestoreService.syncRepository(repository);
      messenger.showSnackBar(
        const SnackBar(content: Text('Datos sincronizados con Firestore')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo sincronizar con Firestore')),
      );
    }
  }

  void _showCsvPreview(BuildContext context, String fileName, String csv) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(fileName),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(csv),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csv));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Datos copiados')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar CSV'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}
