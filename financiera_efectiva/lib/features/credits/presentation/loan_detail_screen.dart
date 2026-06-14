import 'package:flutter/material.dart';

import '../../../core/services/financial_firestore_service.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/loan.dart';

class LoanDetailScreen extends StatelessWidget {
  const LoanDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del crédito')),
      body: FutureBuilder<Loan?>(
        future: FinancialFirestoreService.instance.getActiveLoan(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No se pudo cargar el detalle.\n${snapshot.error}'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final loan = snapshot.data;
          if (loan == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay un crédito aprobado y desembolsado para mostrar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crédito ${loan.id}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        label: 'Monto inicial',
                        value: Formatters.currency(loan.amount),
                      ),
                      _DetailRow(
                        label: 'Saldo pendiente',
                        value: Formatters.currency(loan.pendingBalance),
                      ),
                      _DetailRow(label: 'Estado', value: loan.status),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
