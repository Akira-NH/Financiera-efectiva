import 'package:flutter/material.dart';

import '../../../core/services/financial_firestore_service.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/installment.dart';

class PaymentScheduleScreen extends StatelessWidget {
  const PaymentScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cronograma de pagos')),
      body: FutureBuilder<List<Installment>>(
        future: FinancialFirestoreService.instance.getInstallments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No se pudo cargar el cronograma.\n${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final installments = snapshot.data!;
          if (installments.isEmpty) {
            return const Center(child: Text('No hay cuotas registradas.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: installments.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final installment = installments[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  installment.isPaid ? Icons.check_circle : Icons.schedule,
                  color: installment.isPaid ? Colors.green : Colors.orange,
                ),
                title: Text('Cuota ${installment.number}'),
                subtitle: Text(
                  installment.isPaid
                      ? 'Pagada'
                      : 'Vence: ${installment.dueDate}',
                ),
                trailing: Text(
                  Formatters.currency(installment.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
