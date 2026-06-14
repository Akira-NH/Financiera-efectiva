import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/financial_firestore_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../domain/entities/loan.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({this.showAppBar = true, super.key});

  final bool showAppBar;

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  static const _purposeOptions = [
    'Capital de trabajo',
    'Compra de mercadería',
    'Mejoramiento de vivienda',
    'Educación',
    'Salud',
    'Pago de deudas',
    'Compra de activos o herramientas',
    'Negocio o emprendimiento',
    'Otros',
  ];

  late Future<Loan?> _loanFuture;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _purposeController = TextEditingController();
  String _selectedPurpose = _purposeOptions.first;
  int _termMonths = 12;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loanFuture = FinancialFirestoreService.instance.getActiveLoan();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  num? _parseAmount(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final normalized = raw.contains(',')
        ? raw.replaceAll('.', '').replaceAll(',', '.')
        : raw.replaceAll(',', '');
    return num.tryParse(normalized);
  }

  String? _validateAmount(String? value) {
    final amount = _parseAmount(value ?? '');
    if (amount == null) return 'Ingresa un monto numérico válido.';
    if (amount <= 0) return 'El monto debe ser mayor a cero.';
    return null;
  }

  Future<void> _submitCreditRequest() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final purpose = _selectedPurpose == 'Otros'
          ? _purposeController.text.trim()
          : _selectedPurpose;
      await FinancialFirestoreService.instance.submitCreditRequest(
        amount: _parseAmount(_amountController.text)!,
        termMonths: _termMonths,
        purpose: purpose,
      );
      if (!mounted) return;
      _amountController.clear();
      _purposeController.clear();
      setState(() => _selectedPurpose = _purposeOptions.first);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada a fuerza de ventas.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.message
          : 'No se pudo enviar la solicitud.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? const AppTopBar() : null,
      body: FutureBuilder<Loan?>(
        future: _loanFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No se pudo cargar el crédito.\n${snapshot.error}'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final loan = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (loan == null) ...[
                const _NoActiveLoanCard(),
              ] else ...[
                _ActiveLoanCard(loan: loan),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, RouteNames.loanDetail),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Detalle'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            RouteNames.paymentSchedule,
                          );
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Cronograma'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _CreditRequestForm(
                formKey: _formKey,
                amountController: _amountController,
                purposeController: _purposeController,
                purposeOptions: _purposeOptions,
                selectedPurpose: _selectedPurpose,
                termMonths: _termMonths,
                isSubmitting: _isSubmitting,
                onPurposeChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedPurpose = value;
                    if (value != 'Otros') _purposeController.clear();
                  });
                },
                onTermChanged: (value) {
                  if (value == null) return;
                  setState(() => _termMonths = value);
                },
                onSubmit: _submitCreditRequest,
                amountValidator: _validateAmount,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActiveLoanCard extends StatelessWidget {
  const _ActiveLoanCard({required this.loan});

  final Loan loan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Préstamo activo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('Código: ${loan.id}'),
          const SizedBox(height: 8),
          Text('Monto inicial: ${Formatters.currency(loan.amount)}'),
          Text('Saldo pendiente: ${Formatters.currency(loan.pendingBalance)}'),
          Text('Estado: ${loan.status}'),
        ],
      ),
    );
  }
}

class _NoActiveLoanCard extends StatelessWidget {
  const _NoActiveLoanCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.assignment_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            'Sin préstamo activo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Cuando una solicitud sea aprobada y desembolsada, aparecerá aquí con su cronograma de pagos.',
          ),
        ],
      ),
    );
  }
}

class _CreditRequestForm extends StatelessWidget {
  const _CreditRequestForm({
    required this.formKey,
    required this.amountController,
    required this.purposeController,
    required this.purposeOptions,
    required this.selectedPurpose,
    required this.termMonths,
    required this.isSubmitting,
    required this.onPurposeChanged,
    required this.onTermChanged,
    required this.onSubmit,
    required this.amountValidator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController amountController;
  final TextEditingController purposeController;
  final List<String> purposeOptions;
  final String selectedPurpose;
  final int termMonths;
  final bool isSubmitting;
  final ValueChanged<String?> onPurposeChanged;
  final ValueChanged<int?> onTermChanged;
  final VoidCallback onSubmit;
  final String? Function(String?) amountValidator;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solicitar crédito',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Monto solicitado',
              hint: 'Ej. 5000',
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: amountValidator,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: termMonths,
              decoration: const InputDecoration(labelText: 'Plazo'),
              items: const [
                DropdownMenuItem(value: 6, child: Text('6 meses')),
                DropdownMenuItem(value: 12, child: Text('12 meses')),
                DropdownMenuItem(value: 18, child: Text('18 meses')),
                DropdownMenuItem(value: 24, child: Text('24 meses')),
              ],
              onChanged: isSubmitting ? null : onTermChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedPurpose,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Destino del crédito',
              ),
              items: [
                for (final purpose in purposeOptions)
                  DropdownMenuItem(
                    value: purpose,
                    child: Text(
                      purpose,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              selectedItemBuilder: (context) {
                return [
                  for (final purpose in purposeOptions)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        purpose,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ];
              },
              onChanged: isSubmitting ? null : onPurposeChanged,
            ),
            if (selectedPurpose == 'Otros') ...[
              const SizedBox(height: 12),
              AppTextField(
                label: 'Especifica el destino',
                hint: 'Describe el motivo del crédito',
                controller: purposeController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Especifica el destino del crédito.';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: isSubmitting ? 'Enviando...' : 'Enviar solicitud',
              icon: Icons.send_outlined,
              onPressed: isSubmitting ? null : onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
