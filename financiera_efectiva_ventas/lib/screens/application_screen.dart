import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/repositories/sales_repository.dart';
import '../data/services/credit_scoring_service.dart';
import '../data/services/field_application_service.dart';
import '../widgets/app_shell_widgets.dart';

class ApplicationScreen extends StatefulWidget {
  const ApplicationScreen({super.key, required this.repository});

  final SalesRepository repository;

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  final applicationService = const FieldApplicationService();
  final formKey = GlobalKey<FormState>();
  final namesController = TextEditingController();
  final lastNamesController = TextEditingController();
  final dniController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final businessNameController = TextEditingController();
  final businessAddressController = TextEditingController();
  final incomeController = TextEditingController(text: '6500');
  final expensesController = TextEditingController(text: '2800');
  final amountController = TextEditingController(text: '12000');
  final termController = TextEditingController(text: '12');
  final otherPurposeController = TextEditingController();

  int currentStep = 0;
  bool draftSaved = false;
  bool consentAccepted = false;
  bool signatureCaptured = false;
  bool bureauDone = false;
  bool sending = false;
  String maritalStatus = 'Soltero';
  String education = 'Secundaria';
  String businessType = 'Comercio';
  String currency = 'PEN';
  String installmentType = 'mensual';
  String guarantee = 'sin garantia';
  String purpose = 'Capital de trabajo';
  CreditScoringResult? lastScoringResult;
  String bureauRating = 'Normal';
  String localApplicationId = '';
  final readyDocuments = <String>{};

  static const purposes = [
    'Capital de trabajo',
    'Compra de mercaderia',
    'Mejoramiento de vivienda',
    'Educacion',
    'Salud',
    'Pago de deudas',
    'Compra de activos o herramientas',
    'Negocio o emprendimiento',
    'Otros',
  ];
  static const requiredDocuments = [
    'DNI anverso',
    'DNI reverso',
    'Foto del negocio',
    'Foto del asesor con el cliente',
  ];
  static const optionalDocuments = [
    'RUC',
    'Recibo de servicios',
    'Contrato de alquiler',
    'Otros documentos legales',
  ];

  @override
  void initState() {
    super.initState();
    final client = widget.repository.clients.firstOrNull;
    if (client != null) {
      final parts = client.name.split(' ');
      namesController.text = parts.take(2).join(' ');
      lastNamesController.text = parts.skip(2).join(' ');
      dniController.text = client.dni;
      phoneController.text = client.phone
          .replaceAll(RegExp(r'\D'), '')
          .padRight(9, '0')
          .substring(0, 9);
      businessNameController.text = client.businessName;
      businessAddressController.text = client.location;
    }
    _loadDraft();
  }

  @override
  void dispose() {
    for (final controller in [
      namesController,
      lastNamesController,
      dniController,
      phoneController,
      emailController,
      businessNameController,
      businessAddressController,
      incomeController,
      expensesController,
      amountController,
      termController,
      otherPurposeController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  num get amount => num.tryParse(amountController.text) ?? 0;
  int get term => int.tryParse(termController.text) ?? 1;
  num get monthlyRate => .028;
  num get estimatedInstallment {
    if (amount <= 0 || term <= 0) return 0;
    final factor = math.pow(1 + monthlyRate, term);
    return amount * monthlyRate * factor / (factor - 1);
  }

  bool get documentsReady =>
      requiredDocuments.every((document) => readyDocuments.contains(document));
  String get selectedPurpose =>
      purpose == 'Otros' ? otherPurposeController.text.trim() : purpose;

  @override
  Widget build(BuildContext context) {
    return AppScrollView(
      children: [
        const SectionTitle(
          title: 'Nueva solicitud de credito',
          subtitle:
              'Formulario offline-first con documentos, buro y firma digital.',
        ),
        Form(
          key: formKey,
          child: Stepper(
            currentStep: currentStep,
            onStepTapped: (step) => setState(() => currentStep = step),
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: currentStep == 3
                          ? _sendToCommittee
                          : details.onStepContinue,
                      child: Text(
                        currentStep == 3 ? 'Enviar al comite' : 'Continuar',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: currentStep == 0 ? null : details.onStepCancel,
                      child: const Text('Atras'),
                    ),
                    TextButton.icon(
                      onPressed: _saveDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar borrador'),
                    ),
                  ],
                ),
              );
            },
            onStepContinue: () {
              if (currentStep < 3) setState(() => currentStep++);
            },
            onStepCancel: () {
              if (currentStep > 0) setState(() => currentStep--);
            },
            steps: [
              Step(
                title: const Text('Datos del solicitante'),
                isActive: currentStep >= 0,
                content: _ApplicantStep(
                  namesController: namesController,
                  lastNamesController: lastNamesController,
                  dniController: dniController,
                  phoneController: phoneController,
                  emailController: emailController,
                  maritalStatus: maritalStatus,
                  education: education,
                  onMaritalChanged: (value) =>
                      setState(() => maritalStatus = value!),
                  onEducationChanged: (value) =>
                      setState(() => education = value!),
                ),
              ),
              Step(
                title: const Text('Datos del negocio'),
                isActive: currentStep >= 1,
                content: _BusinessStep(
                  businessNameController: businessNameController,
                  businessAddressController: businessAddressController,
                  incomeController: incomeController,
                  expensesController: expensesController,
                  businessType: businessType,
                  onBusinessTypeChanged: (value) =>
                      setState(() => businessType = value!),
                ),
              ),
              Step(
                title: const Text('Condiciones del credito'),
                isActive: currentStep >= 2,
                content: _CreditTermsStep(
                  amountController: amountController,
                  termController: termController,
                  otherPurposeController: otherPurposeController,
                  currency: currency,
                  installmentType: installmentType,
                  guarantee: guarantee,
                  purpose: purpose,
                  estimatedInstallment: estimatedInstallment,
                  totalToPay: estimatedInstallment * term,
                  onChanged: () => setState(() {}),
                  onCurrencyChanged: (value) =>
                      setState(() => currency = value!),
                  onInstallmentChanged: (value) =>
                      setState(() => installmentType = value!),
                  onGuaranteeChanged: (value) =>
                      setState(() => guarantee = value!),
                  onPurposeChanged: (value) => setState(() => purpose = value!),
                ),
              ),
              Step(
                title: const Text('Confirmacion y firma'),
                isActive: currentStep >= 3,
                content: _ConfirmationStep(
                  amount: amount,
                  term: term,
                  purpose: selectedPurpose,
                  documentsReady: documentsReady,
                  bureauDone: bureauDone,
                  draftSaved: draftSaved,
                  consentAccepted: consentAccepted,
                  signatureCaptured: signatureCaptured,
                  sending: sending,
                  requiredDocuments: requiredDocuments,
                  optionalDocuments: optionalDocuments,
                  readyDocuments: readyDocuments,
                  bureauRating: bureauRating,
                  onToggleDocument: _toggleDocument,
                  onRunBureau: _runBureau,
                  onConsentChanged: (value) =>
                      setState(() => consentAccepted = value ?? false),
                  onSignature: () => setState(() => signatureCaptured = true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleDocument(String document) {
    setState(() {
      if (readyDocuments.contains(document)) {
        readyDocuments.remove(document);
      } else {
        readyDocuments.add(document);
      }
    });
  }

  Future<void> _loadDraft() async {
    final draft = await applicationService.loadDraft();
    if (!mounted || draft == null) return;
    setState(() {
      namesController.text = draft['names'] as String? ?? namesController.text;
      lastNamesController.text =
          draft['lastNames'] as String? ?? lastNamesController.text;
      dniController.text = draft['dni'] as String? ?? dniController.text;
      phoneController.text = draft['phone'] as String? ?? phoneController.text;
      emailController.text = draft['email'] as String? ?? emailController.text;
      businessNameController.text =
          draft['businessName'] as String? ?? businessNameController.text;
      businessAddressController.text =
          draft['businessAddress'] as String? ?? businessAddressController.text;
      incomeController.text =
          draft['monthlyIncome']?.toString() ?? incomeController.text;
      expensesController.text =
          draft['monthlyExpenses']?.toString() ?? expensesController.text;
      amountController.text =
          draft['amount']?.toString() ?? amountController.text;
      termController.text =
          draft['termMonths']?.toString() ?? termController.text;
      otherPurposeController.text =
          draft['otherPurpose'] as String? ?? otherPurposeController.text;
      maritalStatus = draft['maritalStatus'] as String? ?? maritalStatus;
      education = draft['education'] as String? ?? education;
      businessType = draft['businessType'] as String? ?? businessType;
      currency = draft['currency'] as String? ?? currency;
      installmentType = draft['installmentType'] as String? ?? installmentType;
      guarantee = draft['guarantee'] as String? ?? guarantee;
      purpose = draft['purpose'] as String? ?? purpose;
      localApplicationId = draft['localId'] as String? ?? localApplicationId;
      bureauRating = draft['bureauRating'] as String? ?? bureauRating;
      consentAccepted = draft['consentAccepted'] as bool? ?? consentAccepted;
      signatureCaptured =
          draft['signatureCaptured'] as bool? ?? signatureCaptured;
      bureauDone = draft['bureauDone'] as bool? ?? bureauDone;
      final documents = draft['readyDocuments'];
      if (documents is List) {
        readyDocuments
          ..clear()
          ..addAll(documents.whereType<String>());
      }
      draftSaved = true;
    });
  }

  Future<void> _saveDraft() async {
    await applicationService.saveDraft(_buildPayload(status: 'borrador'));
    if (!mounted) return;
    setState(() => draftSaved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Borrador guardado localmente.')),
    );
  }

  void _runBureau() {
    final dni = dniController.text.trim();
    if (dni.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa DNI valido antes de consultar buro.'),
        ),
      );
      return;
    }
    final lastDigit = int.tryParse(dni.characters.last) ?? 0;
    setState(() {
      bureauRating = switch (lastDigit % 5) {
        0 => 'Normal',
        1 => 'CPP',
        2 => 'Deficiente',
        3 => 'Dudoso',
        _ => 'Perdida',
      };
      bureauDone = true;
    });
  }

  Future<void> _sendToCommittee() async {
    if (!formKey.currentState!.validate()) return;
    if (purpose == 'Otros' && otherPurposeController.text.trim().isEmpty) {
      setState(() => currentStep = 2);
      return;
    }
    if (!signatureCaptured ||
        !consentAccepted ||
        !documentsReady ||
        !bureauDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa firma, consentimiento, documentos y buro.'),
        ),
      );
      return;
    }

    setState(() => sending = true);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _TransmissionProgressDialog(),
    );
    if (!mounted) return;
    final scoring = _evaluateScoring();
    final requestStatus = switch (scoring.estadoEvaluacion) {
      'Aprobado' => 'Aprobado',
      'Rechazado' => 'Rechazado',
      _ => 'En comite',
    };
    final expedient = await applicationService.submitToCommittee(
      _buildPayload(status: requestStatus, scoring: scoring),
    );
    if (!mounted) return;
    setState(() {
      sending = false;
      draftSaved = false;
      lastScoringResult = scoring;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Solicitud evaluada: ${scoring.estadoEvaluacion}. Expediente $expedient.',
        ),
      ),
    );
  }

  Map<String, Object?> _buildPayload({
    required String status,
    CreditScoringResult? scoring,
  }) {
    final localId = _ensureLocalApplicationId();
    final scoringResult = scoring ?? lastScoringResult ?? _evaluateScoring();
    final documents = [
      for (final document in requiredDocuments)
        {
          'type': document,
          'required': true,
          'status': readyDocuments.contains(document) ? 'LISTO' : 'OBLIGATORIO',
          'storageUrl': readyDocuments.contains(document)
              ? 'local://prototype/${Uri.encodeComponent(document)}'
              : '',
        },
      for (final document in optionalDocuments)
        {
          'type': document,
          'required': false,
          'status': readyDocuments.contains(document) ? 'LISTO' : 'PENDIENTE',
          'storageUrl': readyDocuments.contains(document)
              ? 'local://prototype/${Uri.encodeComponent(document)}'
              : '',
        },
    ];

    return {
      'localId': localId,
      'cliente':
          '${namesController.text.trim()} ${lastNamesController.text.trim()}'
              .trim(),
      'clientName':
          '${namesController.text.trim()} ${lastNamesController.text.trim()}'
              .trim(),
      'names': namesController.text.trim(),
      'lastNames': lastNamesController.text.trim(),
      'dni': dniController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'maritalStatus': maritalStatus,
      'education': education,
      'businessType': businessType,
      'businessName': businessNameController.text.trim(),
      'businessAddress': businessAddressController.text.trim(),
      'monthlyIncome': num.tryParse(incomeController.text) ?? 0,
      'monthlyExpenses': num.tryParse(expensesController.text) ?? 0,
      'ingresos_mensuales': num.tryParse(incomeController.text) ?? 0,
      'gastos_mensuales': num.tryParse(expensesController.text) ?? 0,
      'amount': amount,
      'monto': 'S/ ${amount.toStringAsFixed(2)}',
      'amountLabel': 'S/ ${amount.toStringAsFixed(2)}',
      'termMonths': term,
      'plazo_meses': term,
      'currency': currency,
      'installmentType': installmentType,
      'guarantee': guarantee,
      'purpose': selectedPurpose,
      'destino_credito': purpose,
      'destino_credito_otro': purpose == 'Otros'
          ? otherPurposeController.text.trim()
          : '',
      'otherPurpose': purpose == 'Otros'
          ? otherPurposeController.text.trim()
          : '',
      'estado': status,
      'status': status,
      'segmento': scoringResult.nivelRiesgo,
      'bureauDone': bureauDone,
      'bureauRating': bureauRating,
      'bureauResult': _bureauResult,
      'bureauRecommendation': _bureauRecommendation,
      'cuotas_mensuales_actuales': _currentInstallmentsForScoring(),
      'deuda_actual_scoring': _debtForScoring(),
      'consentAccepted': consentAccepted,
      'signatureCaptured': signatureCaptured,
      'readyDocuments': readyDocuments.toList(),
      'documents': documents,
      'syncStatus': 'pending',
      ...scoringResult.toJson(),
    };
  }

  num _currentInstallmentsForScoring() {
    final income = num.tryParse(incomeController.text) ?? 0;
    return bureauRating == 'Normal'
        ? (income * .08).round()
        : (income * .18).round();
  }

  num _debtForScoring() {
    final income = num.tryParse(incomeController.text) ?? 0;
    return bureauRating == 'Normal'
        ? (income * .18).round()
        : (income * .48).round();
  }

  CreditScoringResult _evaluateScoring() {
    final income = num.tryParse(incomeController.text) ?? 0;
    final expenses = num.tryParse(expensesController.text) ?? 0;
    final activeCredits = bureauRating == 'Normal' ? 1 : 2;
    final currentInstallments = _currentInstallmentsForScoring();
    final debt = _debtForScoring();
    final daysLate = switch (bureauRating) {
      'Normal' => 0,
      'CPP' => 8,
      'Deficiente' => 20,
      'Dudoso' => 45,
      _ => 90,
    };
    final punctuality = switch (bureauRating) {
      'Normal' => 96,
      'CPP' => 82,
      'Deficiente' => 66,
      'Dudoso' => 50,
      _ => 25,
    };
    final input = CreditScoringInput(
      ingresosMensuales: income,
      gastosMensuales: expenses,
      cuotasMensualesActuales: currentInstallments,
      deudaActual: debt,
      numeroCreditosActivos: activeCredits,
      puntualidadPago: punctuality,
      diasMora: daysLate,
      tieneDeudaVencida: daysLate > 30,
      reportadoSbs: _bureauResult == 'NO PROCEDE',
      enListaNegra: false,
      evidenciaFraude: false,
      montoSolicitado: amount,
      plazoMeses: term,
      antiguedadLaboralMeses: 24,
      historialPagos: bureauDone ? 'con historial' : 'sin historial',
    );
    return const CreditScoringService().evaluate(input);
  }

  String _ensureLocalApplicationId() {
    if (localApplicationId.isNotEmpty) return localApplicationId;
    final dni = dniController.text.trim();
    localApplicationId =
        'SOL-${dni.isEmpty ? 'SIN-DNI' : dni}-${DateTime.now().millisecondsSinceEpoch}';
    return localApplicationId;
  }

  String get _bureauResult {
    return switch (bureauRating) {
      'Normal' => 'APTO',
      'CPP' || 'Deficiente' => 'REVISAR',
      _ => 'NO PROCEDE',
    };
  }

  String get _bureauRecommendation {
    return switch (_bureauResult) {
      'APTO' => 'Continuar evaluacion y validar capacidad de pago.',
      'REVISAR' => 'Solicitar sustento adicional antes de comite.',
      _ => 'No continuar con la solicitud.',
    };
  }
}

class _ApplicantStep extends StatelessWidget {
  const _ApplicantStep({
    required this.namesController,
    required this.lastNamesController,
    required this.dniController,
    required this.phoneController,
    required this.emailController,
    required this.maritalStatus,
    required this.education,
    required this.onMaritalChanged,
    required this.onEducationChanged,
  });

  final TextEditingController namesController;
  final TextEditingController lastNamesController;
  final TextEditingController dniController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final String maritalStatus;
  final String education;
  final ValueChanged<String?> onMaritalChanged;
  final ValueChanged<String?> onEducationChanged;

  @override
  Widget build(BuildContext context) {
    return _FieldsWrap(
      children: [
        _TextInput('Nombres', namesController, required: true),
        _TextInput('Apellidos', lastNamesController, required: true),
        _TextInput('DNI', dniController, required: true, exactLength: 8),
        const _DatePlaceholder(),
        _DropdownInput(
          label: 'Estado civil',
          value: maritalStatus,
          values: const ['Soltero', 'Casado', 'Conviviente', 'Divorciado'],
          onChanged: onMaritalChanged,
        ),
        _DropdownInput(
          label: 'Grado de instruccion',
          value: education,
          values: const ['Primaria', 'Secundaria', 'Tecnica', 'Universitaria'],
          onChanged: onEducationChanged,
        ),
        _TextInput('Telefono', phoneController, required: true, exactLength: 9),
        _TextInput('Correo opcional', emailController),
      ],
    );
  }
}

class _BusinessStep extends StatelessWidget {
  const _BusinessStep({
    required this.businessNameController,
    required this.businessAddressController,
    required this.incomeController,
    required this.expensesController,
    required this.businessType,
    required this.onBusinessTypeChanged,
  });

  final TextEditingController businessNameController;
  final TextEditingController businessAddressController;
  final TextEditingController incomeController;
  final TextEditingController expensesController;
  final String businessType;
  final ValueChanged<String?> onBusinessTypeChanged;

  @override
  Widget build(BuildContext context) {
    return _FieldsWrap(
      children: [
        _DropdownInput(
          label: 'Tipo de negocio',
          value: businessType,
          values: const ['Comercio', 'Servicios', 'Produccion', 'Agropecuario'],
          onChanged: onBusinessTypeChanged,
        ),
        _TextInput(
          'Nombre del negocio',
          businessNameController,
          required: true,
        ),
        _TextInput('Direccion', businessAddressController, required: true),
        const _TextInput.stateless('Antiguedad', 'Ej. 3 anos y 4 meses'),
        _TextInput(
          'Ingresos mensuales',
          incomeController,
          required: true,
          numeric: true,
        ),
        _TextInput(
          'Gastos mensuales',
          expensesController,
          required: true,
          numeric: true,
        ),
        const _TextInput.stateless('Patrimonio estimado', 'Opcional'),
        const _TextInput.stateless(
          'Actividad economica',
          'Venta minorista, servicios, etc.',
        ),
      ],
    );
  }
}

class _CreditTermsStep extends StatelessWidget {
  const _CreditTermsStep({
    required this.amountController,
    required this.termController,
    required this.otherPurposeController,
    required this.currency,
    required this.installmentType,
    required this.guarantee,
    required this.purpose,
    required this.estimatedInstallment,
    required this.totalToPay,
    required this.onChanged,
    required this.onCurrencyChanged,
    required this.onInstallmentChanged,
    required this.onGuaranteeChanged,
    required this.onPurposeChanged,
  });

  final TextEditingController amountController;
  final TextEditingController termController;
  final TextEditingController otherPurposeController;
  final String currency;
  final String installmentType;
  final String guarantee;
  final String purpose;
  final num estimatedInstallment;
  final num totalToPay;
  final VoidCallback onChanged;
  final ValueChanged<String?> onCurrencyChanged;
  final ValueChanged<String?> onInstallmentChanged;
  final ValueChanged<String?> onGuaranteeChanged;
  final ValueChanged<String?> onPurposeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldsWrap(
          children: [
            _TextInput(
              'Monto solicitado',
              amountController,
              required: true,
              numeric: true,
              onChanged: (_) => onChanged(),
            ),
            _TextInput(
              'Plazo en meses',
              termController,
              required: true,
              numeric: true,
              onChanged: (_) => onChanged(),
            ),
            _DropdownInput(
              label: 'Moneda',
              value: currency,
              values: const ['PEN', 'USD'],
              onChanged: onCurrencyChanged,
            ),
            _DropdownInput(
              label: 'Tipo de cuota',
              value: installmentType,
              values: const ['mensual', 'quincenal', 'semanal'],
              onChanged: onInstallmentChanged,
            ),
            _DropdownInput(
              label: 'Garantia',
              value: guarantee,
              values: const [
                'sin garantia',
                'aval',
                'hipotecaria',
                'prendaria',
              ],
              onChanged: onGuaranteeChanged,
            ),
            _DropdownInput(
              label: 'Destino del credito',
              value: purpose,
              values: _ApplicationScreenState.purposes,
              onChanged: onPurposeChanged,
            ),
            if (purpose == 'Otros')
              _TextInput(
                'Especifica destino',
                otherPurposeController,
                required: true,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SimulationChip('Cuota estimada', estimatedInstallment),
            _SimulationChip('Total a pagar', totalToPay),
            _SimulationChip(
              'Costo financiero',
              totalToPay - (num.tryParse(amountController.text) ?? 0),
            ),
            const StatusPill(label: 'TEA ref. 39.2%', color: Colors.blue),
          ],
        ),
      ],
    );
  }
}

class _ConfirmationStep extends StatelessWidget {
  const _ConfirmationStep({
    required this.amount,
    required this.term,
    required this.purpose,
    required this.documentsReady,
    required this.bureauDone,
    required this.draftSaved,
    required this.consentAccepted,
    required this.signatureCaptured,
    required this.sending,
    required this.requiredDocuments,
    required this.optionalDocuments,
    required this.readyDocuments,
    required this.bureauRating,
    required this.onToggleDocument,
    required this.onRunBureau,
    required this.onConsentChanged,
    required this.onSignature,
  });

  final num amount;
  final int term;
  final String purpose;
  final bool documentsReady;
  final bool bureauDone;
  final bool draftSaved;
  final bool consentAccepted;
  final bool signatureCaptured;
  final bool sending;
  final List<String> requiredDocuments;
  final List<String> optionalDocuments;
  final Set<String> readyDocuments;
  final String bureauRating;
  final ValueChanged<String> onToggleDocument;
  final VoidCallback onRunBureau;
  final ValueChanged<bool?> onConsentChanged;
  final VoidCallback onSignature;

  @override
  Widget build(BuildContext context) {
    final bureauColor = switch (bureauRating) {
      'Normal' => Colors.green,
      'CPP' => Colors.amber,
      'Deficiente' => Colors.orange,
      'Dudoso' => Colors.red,
      _ => Colors.grey.shade800,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoPanel(
          title: 'Resumen',
          icon: Icons.summarize_outlined,
          rows: [
            InfoRow('Monto', 'S/ ${amount.toStringAsFixed(2)}'),
            InfoRow('Plazo', '$term meses'),
            InfoRow('Destino', purpose.isEmpty ? 'Pendiente' : purpose),
            InfoRow('Borrador', draftSaved ? 'Guardado' : 'No guardado'),
          ],
        ),
        const SizedBox(height: 12),
        const PanelHeader(
          'Documentos de la solicitud',
          Icons.folder_copy_outlined,
        ),
        const SizedBox(height: 8),
        for (final document in requiredDocuments)
          _DocumentTile(
            label: document,
            requiredDocument: true,
            ready: readyDocuments.contains(document),
            onTap: () => onToggleDocument(document),
          ),
        for (final document in optionalDocuments)
          _DocumentTile(
            label: document,
            requiredDocument: false,
            ready: readyDocuments.contains(document),
            onTap: () => onToggleDocument(document),
          ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: bureauColor.withValues(alpha: .15),
            child: Icon(Icons.shield_outlined, color: bureauColor),
          ),
          title: Text(
            'Consulta de buro: ${bureauDone ? bureauRating : 'Pendiente'}',
          ),
          subtitle: Text(
            bureauDone
                ? 'Entidades: 2 | deuda total S/ 14,200 | resultado automatico generado'
                : 'Requiere consentimiento y firma antes del envio.',
          ),
          trailing: OutlinedButton(
            onPressed: onRunBureau,
            child: const Text('Consultar'),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: consentAccepted,
          onChanged: onConsentChanged,
          title: const Text('El cliente declara que los datos son veraces'),
        ),
        GestureDetector(
          onTap: onSignature,
          child: Container(
            height: 112,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: signatureCaptured ? Colors.green : Colors.black26,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              signatureCaptured
                  ? 'Firma digital capturada'
                  : 'Toca aqui para capturar firma',
            ),
          ),
        ),
        const SizedBox(height: 12),
        StatusPill(
          label: documentsReady
              ? 'Documentos obligatorios listos'
              : 'Faltan documentos obligatorios',
          color: documentsReady ? Colors.green : Colors.red,
        ),
      ],
    );
  }
}

class _FieldsWrap extends StatelessWidget {
  const _FieldsWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 760
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput(
    this.label,
    this.controller, {
    this.required = false,
    this.numeric = false,
    this.exactLength,
    this.onChanged,
  }) : hint = null;

  const _TextInput.stateless(this.label, this.hint)
    : controller = null,
      required = false,
      numeric = false,
      exactLength = null,
      onChanged = null;

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool required;
  final bool numeric;
  final int? exactLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return 'Campo obligatorio';
        if (exactLength != null && text.length != exactLength) {
          return 'Debe tener $exactLength digitos';
        }
        if (numeric && text.isNotEmpty && num.tryParse(text) == null) {
          return 'Ingresa un numero valido';
        }
        return null;
      },
    );
  }
}

class _DropdownInput extends StatelessWidget {
  const _DropdownInput({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in values)
          DropdownMenuItem(
            value: item,
            child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _DatePlaceholder extends StatelessWidget {
  const _DatePlaceholder();

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: const InputDecoration(labelText: 'Fecha de nacimiento'),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Campo obligatorio' : null,
    );
  }
}

class _SimulationChip extends StatelessWidget {
  const _SimulationChip(this.label, this.amount);

  final String label;
  final num amount;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: S/ ${amount.toStringAsFixed(2)}'),
      avatar: const Icon(Icons.calculate_outlined),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.label,
    required this.requiredDocument,
    required this.ready,
    required this.onTap,
  });

  final String label;
  final bool requiredDocument;
  final bool ready;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ready ? Icons.check_circle : Icons.radio_button_unchecked,
        color: ready ? Colors.green : Colors.orange,
      ),
      title: Text(label),
      subtitle: Text(requiredDocument ? 'OBLIGATORIO' : 'Opcional'),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: ready ? 'Eliminar' : 'Tomar foto',
            onPressed: onTap,
            icon: Icon(
              ready ? Icons.delete_outline : Icons.camera_alt_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Previsualizar',
            onPressed: ready ? () {} : null,
            icon: const Icon(Icons.visibility_outlined),
          ),
        ],
      ),
    );
  }
}

class _TransmissionProgressDialog extends StatefulWidget {
  const _TransmissionProgressDialog();

  @override
  State<_TransmissionProgressDialog> createState() =>
      _TransmissionProgressDialogState();
}

class _TransmissionProgressDialogState
    extends State<_TransmissionProgressDialog> {
  int step = 0;
  static const steps = [
    'Validando datos',
    'Subiendo documentos',
    'Registrando solicitud',
    'Asignando expediente',
    'Solicitud enviada',
  ];

  @override
  void initState() {
    super.initState();
    _advance();
  }

  Future<void> _advance() async {
    for (var i = 0; i < steps.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => step = i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enviar al comite'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < steps.length; i++)
            ListTile(
              leading: Icon(
                i <= step ? Icons.check_circle : Icons.radio_button_unchecked,
                color: i <= step ? Colors.green : Colors.grey,
              ),
              title: Text(steps[i]),
            ),
        ],
      ),
    );
  }
}
