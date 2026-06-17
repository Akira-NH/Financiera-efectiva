class Client {
  const Client({
    required this.name,
    required this.dni,
    required this.phone,
    required this.location,
    required this.age,
    required this.businessName,
    required this.businessType,
    required this.businessAge,
    required this.premises,
    required this.sbsRating,
    required this.totalDebt,
    required this.preScore,
    required this.segment,
    required this.renewalDate,
    this.clientId = '',
    this.requestId = '',
    this.monthlyIncome = 0,
    this.monthlyExpenses = 0,
    this.currentInstallments = 0,
    this.paymentCapacity = 0,
    this.debtRatio = 0,
    this.activeCredits = 0,
    this.lateDays = 0,
    this.paymentPunctuality = 0,
    this.creditPurpose = '',
    this.requestAmount = 0,
    this.termMonths = 0,
    this.clientStatus = 'Visitar',
    this.requestStatus = 'Negado',
    this.recommendation = '',
    this.latitude = 0,
    this.longitude = 0,
    this.fieldVisitCompleted = false,
  });

  final String name;
  final String dni;
  final String phone;
  final String location;
  final int age;
  final String businessName;
  final String businessType;
  final String businessAge;
  final String premises;
  final String sbsRating;
  final String totalDebt;
  final int preScore;
  final String segment;
  final String renewalDate;
  final String clientId;
  final String requestId;
  final num monthlyIncome;
  final num monthlyExpenses;
  final num currentInstallments;
  final num paymentCapacity;
  final num debtRatio;
  final int activeCredits;
  final int lateDays;
  final num paymentPunctuality;
  final String creditPurpose;
  final num requestAmount;
  final int termMonths;
  final String clientStatus;
  final String requestStatus;
  final String recommendation;
  final double latitude;
  final double longitude;
  final bool fieldVisitCompleted;

  factory Client.fromJson(Map<String, Object?> json) {
    return Client(
      dni: json['dni'] as String? ?? '',
      name: json['nombres'] as String? ?? '',
      phone: json['telefono'] as String? ?? '',
      location: json['ubicacion'] as String? ?? '',
      age: json['edad'] as int? ?? 0,
      businessName: json['negocio'] as String? ?? '',
      businessType: json['rubro'] as String? ?? '',
      businessAge: json['antiguedad_negocio'] as String? ?? '',
      premises: json['tenencia_local'] as String? ?? '',
      sbsRating: json['calificacion_sbs'] as String? ?? '',
      totalDebt: json['deuda_total'] as String? ?? '',
      preScore: json['score_preliminar'] as int? ?? 0,
      segment: json['segmento'] as String? ?? '',
      renewalDate: json['fecha_renovacion'] as String? ?? '',
      clientId: json['id_cliente'] as String? ?? '',
      requestId: json['requestId'] as String? ?? json['id_solicitud'] as String? ?? '',
      monthlyIncome: json['ingresos_mensuales'] as num? ?? 0,
      monthlyExpenses: json['gastos_mensuales'] as num? ?? 0,
      currentInstallments: json['cuotas_mensuales_actuales'] as num? ?? 0,
      paymentCapacity: json['capacidad_pago_disponible'] as num? ?? 0,
      debtRatio: json['ratio_endeudamiento'] as num? ?? 0,
      activeCredits: (json['numero_creditos_activos'] as num?)?.round() ?? 0,
      lateDays: (json['dias_mora'] as num?)?.round() ?? 0,
      paymentPunctuality: json['puntualidad_pago'] as num? ?? 0,
      creditPurpose: json['destino_credito'] as String? ?? '',
      requestAmount: json['monto_solicitado'] as num? ?? 0,
      termMonths: (json['plazo_meses'] as num?)?.round() ?? 0,
      clientStatus: json['estado_cliente'] as String? ?? 'Visitar',
      requestStatus: json['estado_solicitud'] as String? ?? 'Negado',
      recommendation: json['recomendacion_scoring'] as String? ?? '',
      latitude: (json['latitud'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitud'] as num?)?.toDouble() ?? 0,
      fieldVisitCompleted:
          json['fieldVisitCompleted'] as bool? ??
          json['solicitud_completada'] as bool? ??
          false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'dni': dni,
      'nombres': name,
      'telefono': phone,
      'ubicacion': location,
      'edad': age,
      'negocio': businessName,
      'rubro': businessType,
      'antiguedad_negocio': businessAge,
      'tenencia_local': premises,
      'calificacion_sbs': sbsRating,
      'deuda_total': totalDebt,
      'score_preliminar': preScore,
      'segmento': segment,
      'fecha_renovacion': renewalDate,
      'id_cliente': clientId,
      'requestId': requestId,
      'ingresos_mensuales': monthlyIncome,
      'gastos_mensuales': monthlyExpenses,
      'cuotas_mensuales_actuales': currentInstallments,
      'capacidad_pago_disponible': paymentCapacity,
      'ratio_endeudamiento': debtRatio,
      'numero_creditos_activos': activeCredits,
      'dias_mora': lateDays,
      'puntualidad_pago': paymentPunctuality,
      'destino_credito': creditPurpose,
      'monto_solicitado': requestAmount,
      'plazo_meses': termMonths,
      'estado_cliente': clientStatus,
      'estado_solicitud': requestStatus,
      'recomendacion_scoring': recommendation,
      'latitud': latitude,
      'longitud': longitude,
      'fieldVisitCompleted': fieldVisitCompleted,
      'solicitud_completada': fieldVisitCompleted,
    };
  }
}
