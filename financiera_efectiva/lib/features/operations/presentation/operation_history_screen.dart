import 'package:flutter/material.dart';

import '../../../core/services/financial_firestore_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../domain/entities/operation_history_item.dart';

class OperationHistoryScreen extends StatefulWidget {
  const OperationHistoryScreen({
    this.showAppBar = true,
    this.refreshToken = 0,
    super.key,
  });

  final bool showAppBar;
  final int refreshToken;

  @override
  State<OperationHistoryScreen> createState() => _OperationHistoryScreenState();
}

class _OperationHistoryScreenState extends State<OperationHistoryScreen> {
  String _filter = 'Todas';
  late Future<List<OperationHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = FinancialFirestoreService.instance.getOperationHistory();
  }

  @override
  void didUpdateWidget(covariant OperationHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      setState(() {
        _historyFuture =
            FinancialFirestoreService.instance.getOperationHistory();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? const AppTopBar() : null,
      body: FutureBuilder<List<OperationHistoryItem>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _HistoryLoadError(error: snapshot.error);
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final history = snapshot.data!;
          final filtered = _filter == 'Todas'
              ? history
              : history.where((item) {
                  if (_filter == 'Pago') return item.type.startsWith('Pago');
                  return item.type == _filter;
                }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Historial', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                selected: {_filter},
                onSelectionChanged: (values) {
                  setState(() => _filter = values.first);
                },
                segments: const [
                  ButtonSegment(value: 'Todas', label: Text('Todas')),
                  ButtonSegment(
                    value: 'Transferencia',
                    label: Text('Transferencias'),
                  ),
                  ButtonSegment(value: 'Pago', label: Text('Pagos')),
                ],
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(
                    child: Text('No hay movimientos para mostrar.'),
                  ),
                )
              else
                ...filtered.map((item) => _HistoryTile(item: item)),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryLoadError extends StatelessWidget {
  const _HistoryLoadError({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              error == null
                  ? 'No se pudo cargar el historial.'
                  : 'No se pudo cargar el historial.\n$error',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final OperationHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item.type.startsWith('Pago') ? Icons.payments : Icons.swap_horiz,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(item.type),
      subtitle: Text('${item.date} - ${item.status}'),
      trailing: Text(
        '-${Formatters.currency(item.amount)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
