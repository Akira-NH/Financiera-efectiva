import 'dart:io';
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/client.dart';
import '../data/repositories/sales_repository.dart';
import '../data/services/credit_scoring_service.dart';
import '../data/services/field_application_service.dart';
import '../widgets/app_shell_widgets.dart';

class ApplicationScreen extends StatefulWidget {
  const ApplicationScreen({
    super.key,
    required this.repository,
    required this.selectedClient,
    required this.onSaved,
  });

  final SalesRepository repository;
  final Client? selectedClient;
  final VoidCallback onSaved;

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
  final incomeController = TextEditingController();
  final expensesController = TextEditingController();
  final amountController = TextEditingController();
  final termController = TextEditingController();
  final otherPurposeController = TextEditingController();
  final birthDateController = TextEditingController();
  final imagePicker = ImagePicker();

  int currentStep = 0;
  bool draftSaved = false;
  bool sending = false;
  XFile? customerPhoto;
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
  String loadedClientKey = '';
  String saveDiagnostics = 'Sin intentos de guardado aun.';
  Timer? autosaveTimer;

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
  @override
  void initState() {
    super.initState();
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
      birthDateController,
    ]) {
      controller.addListener(_scheduleAutosave);
    }
    applicationService.syncPendingDraft();
    _applySelectedClient();
    if (widget.selectedClient == null) {
      _loadDraft();
    }
  }

  @override
  void didUpdateWidget(covariant ApplicationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_clientKey(widget.selectedClient) != _clientKey(oldWidget.selectedClient)) {
      _applySelectedClient();
    }
  }

  @override
  void dispose() {
    autosaveTimer?.cancel();
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
      birthDateController,
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

  String get selectedPurpose =>
      purpose == 'Otros' ? otherPurposeController.text.trim() : purpose;

  @override
  Widget build(BuildContext context) {
    final selectedClient = widget.selectedClient;
    if (selectedClient == null) {
      return const AppScrollView(
        children: [
          SectionTitle(
            title: 'Solicitud',
            subtitle:
                'Seleccione primero un cliente desde Cartera o Ruta para completar su solicitud.',
          ),
        ],
      );
    }

    return AppScrollView(
      children: [
        SectionTitle(
          title: 'Solicitud de ${selectedClient.name}',
          subtitle:
              'Ficha de levantamiento asociada a la solicitud ${selectedClient.requestId.isEmpty ? selectedClient.dni : selectedClient.requestId}.',
        ),
        _SaveDiagnosticsCard(message: saveDiagnostics),
        const SizedBox(height: 12),
        Form(
          key: formKey,
          child: Stepper(
            currentStep: currentStep,
            physics: const NeverScrollableScrollPhysics(),
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
                        currentStep == 3 ? 'Guardar' : 'Continuar',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: currentStep == 0 ? null : details.onStepCancel,
                      child: const Text('Atras'),
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
                  birthDateController: birthDateController,
                  maritalStatus: maritalStatus,
                  education: education,
                  onMaritalChanged: (value) {
                    setState(() => maritalStatus = value!);
                    _scheduleAutosave();
                  },
                  onEducationChanged: (value) {
                    setState(() => education = value!);
                    _scheduleAutosave();
                  },
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
                  onBusinessTypeChanged: (value) {
                    setState(() => businessType = value!);
                    _scheduleAutosave();
                  },
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
                  onCurrencyChanged: (value) {
                    setState(() => currency = value!);
                    _scheduleAutosave();
                  },
                  onInstallmentChanged: (value) {
                    setState(() => installmentType = value!);
                    _scheduleAutosave();
                  },
                  onGuaranteeChanged: (value) {
                    setState(() => guarantee = value!);
                    _scheduleAutosave();
                  },
                  onPurposeChanged: (value) {
                    setState(() => purpose = value!);
                    _scheduleAutosave();
                  },
                ),
              ),
              Step(
                title: const Text('Confirmacion y firma'),
                isActive: currentStep >= 3,
                content: _ConfirmationStep(
                  amount: amount,
                  term: term,
                  purpose: selectedPurpose,
                  draftSaved: draftSaved,
                  customerPhoto: customerPhoto,
                  onTakePhoto: _takeCustomerPhoto,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
      draftSaved = true;
    });
  }

  Future<void> _saveDraft({bool silent = false}) async {
    if (widget.selectedClient == null) return;
    await applicationService.saveDraft(_buildPayload(status: 'borrador'));
    if (!mounted) return;
    setState(() => draftSaved = true);
    if (silent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Borrador guardado localmente.')),
    );
  }

  void _scheduleAutosave() {
    if (widget.selectedClient == null) return;
    autosaveTimer?.cancel();
    autosaveTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _saveDraft(silent: true);
    });
  }

  Future<void> _sendToCommittee() async {
    if (!formKey.currentState!.validate()) return;
    if (purpose == 'Otros' && otherPurposeController.text.trim().isEmpty) {
      setState(() => currentStep = 2);
      return;
    }
    if (customerPhoto == null) {
      setState(() => currentStep = 3);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura la fotografia del DNI.')),
      );
      return;
    }

    setState(() => sending = true);
    final payload = _buildPayload(status: 'Pendiente', scoring: _evaluateScoring());
    final targetError = _validatePersistenceTarget(payload);
    if (targetError != null) {
      setState(() {
        sending = false;
        saveDiagnostics = targetError;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(targetError)),
      );
      return;
    }
    setState(() => saveDiagnostics = _diagnosticsBeforeSave(payload));
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _TransmissionProgressDialog(),
    );
    if (!mounted) return;
    final result = await applicationService.submitToCommittee(
      payload,
    );
    if (!mounted) return;
    setState(() {
      sending = false;
      draftSaved = false;
      lastScoringResult = _evaluateScoring();
      saveDiagnostics = _diagnosticsAfterSave(payload, result);
    });
    if (result.synced) widget.onSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.synced
              ? 'Solicitud guardada y sincronizada. Expediente ${result.expedientNumber}.'
              : 'Solicitud guardada localmente. Se sincronizara al recuperar conexion.',
        ),
      ),
    );
  }

  Map<String, Object?> _buildPayload({
    required String status,
    CreditScoringResult? scoring,
  }) {
    final localId = _ensureLocalApplicationId();
    final isFinalSave = status != 'borrador';
    final scoringResult = scoring ?? lastScoringResult ?? _evaluateScoring();
    final documents = [
      if (customerPhoto != null)
        {
          'type': 'DNI cliente',
          'required': true,
          'status': 'LISTO',
          'localPath': customerPhoto!.path,
        },
    ];

    return {
      'localId': localId,
      'requestId': localId,
      'id_solicitud': localId,
      'clientId':
          widget.selectedClient?.clientId.isNotEmpty == true
              ? widget.selectedClient!.clientId
              : dniController.text.trim(),
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
      'telefono': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'correo': emailController.text.trim(),
      'birthDate': birthDateController.text.trim(),
      'maritalStatus': maritalStatus,
      'education': education,
      'businessType': businessType,
      'businessName': businessNameController.text.trim(),
      'businessAddress': businessAddressController.text.trim(),
      'negocio': businessNameController.text.trim(),
      'rubro': businessType,
      'ubicacion': businessAddressController.text.trim(),
      'monthlyIncome': num.tryParse(incomeController.text) ?? 0,
      'monthlyExpenses': num.tryParse(expensesController.text) ?? 0,
      'ingresos_mensuales': num.tryParse(incomeController.text) ?? 0,
      'gastos_mensuales': num.tryParse(expensesController.text) ?? 0,
      'amount': amount,
      'monto_solicitado': amount,
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
      'estado_solicitud': status,
      'fieldVisitCompleted': isFinalSave,
      'solicitud_completada': isFinalSave,
      'estado_cliente': isFinalSave
          ? 'Visitado'
          : (widget.selectedClient?.clientStatus ?? 'Visitar'),
      'segmento': scoringResult.nivelRiesgo,
      'bureauDone': false,
      'bureauRating': bureauRating,
      'bureauResult': _bureauResult,
      'bureauRecommendation': _bureauRecommendation,
      'cuotas_mensuales_actuales': _currentInstallmentsForScoring(),
      'deuda_actual_scoring': _debtForScoring(),
      'documents': documents,
      'customerPhotoPath': customerPhoto?.path ?? '',
      'dniPhotoPath': customerPhoto?.path ?? '',
      'syncStatus': 'pending',
      ...scoringResult.toJson(),
    };
  }

  String? _validatePersistenceTarget(Map<String, Object?> payload) {
    final requestId = payload['requestId'] as String? ?? '';
    final clientId = payload['clientId'] as String? ?? '';
    final dni = payload['dni'] as String? ?? '';
    if (widget.selectedClient == null) {
      return 'Error: no hay cliente seleccionado para asociar la solicitud.';
    }
    if (requestId.isEmpty) {
      return 'Error: solicitudId vacio. Abre Solicitud desde Ruta > Ver ficha completa.';
    }
    if (clientId.isEmpty) {
      return 'Error: clienteId vacio. No se puede actualizar clients/{clienteId}.';
    }
    if (dni.isEmpty || dni.length != 8) {
      return 'Error: DNI invalido o vacio. Verifica datos del solicitante.';
    }
    return null;
  }

  String _diagnosticsBeforeSave(Map<String, Object?> payload) {
    final requestId = payload['requestId'] as String? ?? '';
    final clientId = payload['clientId'] as String? ?? '';
    final dni = payload['dni'] as String? ?? '';
    return 'Guardando...\n'
        'solicitudId: $requestId\n'
        'clienteId: $clientId\n'
        'DNI: $dni\n'
        'Rutas Firestore:\n'
        '- sales_credit_requests/$requestId\n'
        '- clients/$clientId/creditRequests/$requestId\n'
        '- sales_clients/$dni';
  }

  String _diagnosticsAfterSave(
    Map<String, Object?> payload,
    FieldSaveResult result,
  ) {
    final base = _diagnosticsBeforeSave(payload);
    if (result.synced) {
      return '$base\nResultado: sincronizado correctamente en Firestore.';
    }
    return '$base\nResultado: guardado local, no sincronizado.\n'
        'Error Firestore: ${result.errorMessage}';
  }

  Future<void> _takeCustomerPhoto() async {
    final photo = await imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1280,
    );
    if (photo == null || !mounted) return;
    setState(() => customerPhoto = photo);
    _scheduleAutosave();
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
      historialPagos: 'sin historial',
    );
    return const CreditScoringService().evaluate(input);
  }

  void _applySelectedClient() {
    final client = widget.selectedClient;
    final key = _clientKey(client);
    if (client == null || key.isEmpty || key == loadedClientKey) return;
    final parts = client.name.trim().split(RegExp(r'\s+'));
    final firstNames = parts.length <= 2
        ? client.name.trim()
        : parts.take(2).join(' ');
    final lastNames = parts.length <= 2 ? '' : parts.skip(2).join(' ');
    loadedClientKey = key;
    localApplicationId = client.requestId.isNotEmpty
        ? client.requestId
        : (client.clientId.isNotEmpty ? client.clientId : client.dni);
    namesController.text = firstNames;
    lastNamesController.text = lastNames;
    dniController.text = client.dni;
    phoneController.text = client.phone;
    businessNameController.text = client.businessName == 'Solicitud nueva'
        ? ''
        : client.businessName;
    businessAddressController.text = client.location;
    amountController.text = client.requestAmount > 0
        ? client.requestAmount.toStringAsFixed(0)
        : amountController.text;
    termController.text = client.termMonths > 0
        ? client.termMonths.toString()
        : termController.text;
    if (purposes.contains(client.creditPurpose)) {
      purpose = client.creditPurpose;
      otherPurposeController.clear();
    } else if (client.creditPurpose.isNotEmpty) {
      purpose = 'Otros';
      otherPurposeController.text = client.creditPurpose;
    }
    setState(() {});
  }

  String _clientKey(Client? client) {
    if (client == null) return '';
    if (client.requestId.isNotEmpty) return client.requestId;
    if (client.clientId.isNotEmpty) return client.clientId;
    return client.dni;
  }

  String _ensureLocalApplicationId() {
    final selectedId = widget.selectedClient?.requestId ?? '';
    if (selectedId.isNotEmpty) {
      localApplicationId = selectedId;
      return localApplicationId;
    }
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
    required this.birthDateController,
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
  final TextEditingController birthDateController;
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
        _TextInput(
          'DNI',
          dniController,
          required: true,
          exactLength: 8,
          numeric: true,
        ),
        _DatePlaceholder(controller: birthDateController),
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
        _TextInput(
          'Telefono',
          phoneController,
          required: true,
          exactLength: 9,
          numeric: true,
        ),
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
        const _TextInput.stateless('Antiguedad', null),
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
        const _TextInput.stateless('Patrimonio estimado', null),
        const _TextInput.stateless('Actividad economica', null),
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
    required this.draftSaved,
    required this.customerPhoto,
    required this.onTakePhoto,
  });

  final num amount;
  final int term;
  final String purpose;
  final bool draftSaved;
  final XFile? customerPhoto;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
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
          'Captura de documento',
          Icons.camera_alt_outlined,
        ),
        const SizedBox(height: 12),
        _PhotoCaptureTile(
          photo: customerPhoto,
          onTakePhoto: onTakePhoto,
          label: 'Fotografia del DNI',
          emptyLabel: 'Pendiente de captura',
          readyLabel: 'DNI capturado',
          icon: Icons.badge_outlined,
        ),
      ],
    );
  }
}

class _SaveDiagnosticsCard extends StatelessWidget {
  const _SaveDiagnosticsCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isError = message.contains('Error') || message.contains('no sincronizado');
    final color = isError ? Colors.orange : Colors.blueGrey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
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
  const _DatePlaceholder({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: const InputDecoration(
        labelText: 'Fecha de nacimiento',
        suffixIcon: Icon(Icons.calendar_month_outlined),
      ),
      onTap: () async {
        final now = DateTime.now();
        final selected = await showDatePicker(
          context: context,
          initialDate: DateTime(now.year - 25, now.month, now.day),
          firstDate: DateTime(now.year - 90),
          lastDate: now,
        );
        if (selected == null) return;
        controller.text =
            '${selected.day.toString().padLeft(2, '0')}/'
            '${selected.month.toString().padLeft(2, '0')}/${selected.year}';
      },
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Campo obligatorio';
        final parts = text.split('/');
        if (parts.length != 3) return 'Fecha invalida';
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day == null || month == null || year == null) {
          return 'Fecha invalida';
        }
        final birthDate = DateTime(year, month, day);
        final now = DateTime.now();
        if (birthDate.isAfter(now)) return 'No puede ser futura';
        final age =
            now.year -
            birthDate.year -
            (DateTime(now.year, birthDate.month, birthDate.day).isAfter(now)
                ? 1
                : 0);
        if (age < 18) return 'Debe ser mayor de edad';
        return null;
      },
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

class _PhotoCaptureTile extends StatelessWidget {
  const _PhotoCaptureTile({
    required this.photo,
    required this.onTakePhoto,
    this.label = 'Fotografia del cliente',
    this.emptyLabel = 'Pendiente de captura',
    this.readyLabel = 'Fotografia capturada',
    this.icon = Icons.person_add_alt_1,
  });

  final XFile? photo;
  final VoidCallback onTakePhoto;
  final String label;
  final String emptyLabel;
  final String readyLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final preview = ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: compact ? double.infinity : 96,
                height: compact ? 180 : 96,
                child: photo == null
                    ? ColoredBox(
                        color: const Color(0xFFE9ECFF),
                        child: Icon(
                          icon,
                          color: Theme.of(context).colorScheme.primary,
                          size: 34,
                        ),
                      )
                    : Image.file(File(photo!.path), fit: BoxFit.cover),
              ),
            );
            final details = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(photo == null ? emptyLabel : readyLabel),
                const SizedBox(height: 10),
                Align(
                  alignment: compact
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onTakePhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(photo == null ? 'Tomar foto' : 'Retomar'),
                  ),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  preview,
                  const SizedBox(height: 12),
                  details,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                preview,
                const SizedBox(width: 12),
                Expanded(child: details),
              ],
            );
          },
        ),
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
      title: const Text('Guardar solicitud'),
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
