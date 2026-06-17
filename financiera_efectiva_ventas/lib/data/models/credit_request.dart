class CreditRequest {
  const CreditRequest({
    required this.id,
    required this.client,
    required this.amount,
    required this.segment,
    required this.status,
    required this.clientId,
    required this.dni,
    this.clientStatus = 'Visitar',
    required this.amountValue,
    required this.termMonths,
    required this.purpose,
    required this.score,
    required this.riskLevel,
    required this.recommendation,
    this.latitude = 0,
    this.longitude = 0,
    this.locationLabel = '',
    this.fieldVisitCompleted = false,
    this.phone = '',
    this.businessName = '',
    this.businessType = '',
    this.monthlyIncome = 0,
    this.monthlyExpenses = 0,
    this.currentInstallments = 0,
    this.debt = 0,
  });

  final String id;
  final String client;
  final String amount;
  final String segment;
  final String status;
  final String clientId;
  final String dni;
  final String clientStatus;
  final num amountValue;
  final int termMonths;
  final String purpose;
  final int score;
  final String riskLevel;
  final String recommendation;
  final double latitude;
  final double longitude;
  final String locationLabel;
  final bool fieldVisitCompleted;
  final String phone;
  final String businessName;
  final String businessType;
  final num monthlyIncome;
  final num monthlyExpenses;
  final num currentInstallments;
  final num debt;

  factory CreditRequest.fromJson(Map<String, Object?> json, {String id = ''}) {
    final rawAmount = json['monto'] ?? json['amountLabel'] ?? json['amount'];
    final amountValue = json['amount'] is num
        ? json['amount'] as num
        : _parseAmount(rawAmount as String? ?? '');
    return CreditRequest(
      id: id,
      client: json['cliente'] as String? ?? '',
      amount: rawAmount is num
          ? 'S/ ${rawAmount.toStringAsFixed(2)}'
          : rawAmount as String? ?? '',
      segment: json['segmento'] as String? ?? '',
      status:
          json['estado_solicitud'] as String? ??
          json['estado'] as String? ??
          json['status'] as String? ??
          '',
      clientId: json['clientId'] as String? ?? '',
      dni:
          json['dni'] as String? ??
          json['documentNumber'] as String? ??
          json['documento'] as String? ??
          '',
      clientStatus:
          json['estado_cliente'] as String? ??
          json['clientStatus'] as String? ??
          'Visitar',
      amountValue: amountValue,
      termMonths:
          json['plazo_meses'] as int? ?? json['termMonths'] as int? ?? 12,
      purpose:
          json['destino_credito'] as String? ??
          json['purpose'] as String? ??
          '',
      score: (json['score'] as num?)?.round() ?? 0,
      riskLevel: json['nivel_riesgo'] as String? ?? '',
      recommendation: json['recomendacion_scoring'] as String? ?? '',
      latitude: (json['latitud'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitud'] as num?)?.toDouble() ?? 0,
      locationLabel: json['ubicacion'] as String? ?? '',
      fieldVisitCompleted:
          json['fieldVisitCompleted'] as bool? ??
          json['solicitud_completada'] as bool? ??
          false,
      phone: json['phone'] as String? ?? json['telefono'] as String? ?? '',
      businessName:
          json['businessName'] as String? ?? json['negocio'] as String? ?? '',
      businessType:
          json['businessType'] as String? ??
          json['rubro'] as String? ??
          json['destino_credito'] as String? ??
          '',
      monthlyIncome:
          json['monthlyIncome'] as num? ??
          json['ingresos_mensuales'] as num? ??
          0,
      monthlyExpenses:
          json['monthlyExpenses'] as num? ??
          json['gastos_mensuales'] as num? ??
          0,
      currentInstallments: json['cuotas_mensuales_actuales'] as num? ?? 0,
      debt: json['deuda_actual_scoring'] as num? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'cliente': client,
      'monto': amount,
      'amount': amountValue,
      'segmento': segment,
      'estado': status,
      'clientId': clientId,
      'dni': dni,
      'estado_cliente': clientStatus,
      'plazo_meses': termMonths,
      'destino_credito': purpose,
      'score': score,
      'nivel_riesgo': riskLevel,
      'recomendacion_scoring': recommendation,
      'latitud': latitude,
      'longitud': longitude,
      'ubicacion': locationLabel,
      'fieldVisitCompleted': fieldVisitCompleted,
      'solicitud_completada': fieldVisitCompleted,
      'telefono': phone,
      'businessName': businessName,
      'businessType': businessType,
      'monthlyIncome': monthlyIncome,
      'monthlyExpenses': monthlyExpenses,
      'cuotas_mensuales_actuales': currentInstallments,
      'deuda_actual_scoring': debt,
    };
  }

  static num _parseAmount(String value) {
    final cleaned = value
        .replaceAll('S/', '')
        .replaceAll(' ', '')
        .replaceAll(',', '')
        .trim();
    return num.tryParse(cleaned) ?? 0;
  }
}
