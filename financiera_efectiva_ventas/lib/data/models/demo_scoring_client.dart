class DemoScoringClient {
  const DemoScoringClient({
    required this.idCliente,
    required this.dni,
    required this.nombres,
    required this.apellidos,
    required this.edad,
    required this.ocupacion,
    required this.ingresosMensuales,
    required this.gastosMensuales,
    required this.deudaActual,
    required this.cuotasMensualesActuales,
    required this.numeroCreditosActivos,
    required this.historialPagos,
    required this.diasMora,
    required this.puntualidadPago,
    required this.tieneDeudaVencida,
    required this.reportadoSbs,
    required this.enListaNegra,
    required this.evidenciaFraude,
    required this.montoSolicitado,
    required this.plazoMeses,
    required this.destinoCredito,
    required this.destinoCreditoOtro,
    required this.antiguedadLaboralMeses,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    required this.estadoCliente,
    required this.estadoSolicitud,
    required this.score,
    required this.nivelRiesgo,
    required this.capacidadPagoDisponible,
    required this.ratioEndeudamiento,
    required this.recomendacionScoring,
  });

  final String idCliente;
  final String dni;
  final String nombres;
  final String apellidos;
  final int edad;
  final String ocupacion;
  final num ingresosMensuales;
  final num gastosMensuales;
  final num deudaActual;
  final num cuotasMensualesActuales;
  final int numeroCreditosActivos;
  final String historialPagos;
  final int diasMora;
  final num puntualidadPago;
  final bool tieneDeudaVencida;
  final bool reportadoSbs;
  final bool enListaNegra;
  final bool evidenciaFraude;
  final num montoSolicitado;
  final int plazoMeses;
  final String destinoCredito;
  final String destinoCreditoOtro;
  final int antiguedadLaboralMeses;
  final String direccion;
  final double latitud;
  final double longitud;
  final String estadoCliente;
  final String estadoSolicitud;
  final int score;
  final String nivelRiesgo;
  final num capacidadPagoDisponible;
  final num ratioEndeudamiento;
  final String recomendacionScoring;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  factory DemoScoringClient.fromJson(Map<String, Object?> json) {
    return DemoScoringClient(
      idCliente: json['id_cliente'] as String? ?? '',
      dni: json['dni'] as String? ?? '',
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      edad: (json['edad'] as num?)?.round() ?? 0,
      ocupacion: json['ocupacion'] as String? ?? '',
      ingresosMensuales: json['ingresos_mensuales'] as num? ?? 0,
      gastosMensuales: json['gastos_mensuales'] as num? ?? 0,
      deudaActual: json['deuda_actual'] as num? ?? 0,
      cuotasMensualesActuales: json['cuotas_mensuales_actuales'] as num? ?? 0,
      numeroCreditosActivos:
          (json['numero_creditos_activos'] as num?)?.round() ?? 0,
      historialPagos: json['historial_pagos'] as String? ?? 'sin historial',
      diasMora: (json['dias_mora'] as num?)?.round() ?? 0,
      puntualidadPago: json['puntualidad_pago'] as num? ?? 0,
      tieneDeudaVencida: json['tiene_deuda_vencida'] as bool? ?? false,
      reportadoSbs: json['reportado_sbs'] as bool? ?? false,
      enListaNegra: json['en_lista_negra'] as bool? ?? false,
      evidenciaFraude: json['evidencia_fraude'] as bool? ?? false,
      montoSolicitado: json['monto_solicitado'] as num? ?? 0,
      plazoMeses: (json['plazo_meses'] as num?)?.round() ?? 12,
      destinoCredito: json['destino_credito'] as String? ?? '',
      destinoCreditoOtro: json['destino_credito_otro'] as String? ?? '',
      antiguedadLaboralMeses:
          (json['antiguedad_laboral_meses'] as num?)?.round() ?? 0,
      direccion: json['direccion'] as String? ?? 'Huancayo, Peru',
      latitud: (json['latitud'] as num?)?.toDouble() ?? -12.0651,
      longitud: (json['longitud'] as num?)?.toDouble() ?? -75.2049,
      estadoCliente: json['estado_cliente'] as String? ?? 'Visitar',
      estadoSolicitud: json['estado_solicitud'] as String? ?? 'Negado',
      score: (json['score'] as num?)?.round() ?? 0,
      nivelRiesgo: json['nivel_riesgo'] as String? ?? '',
      capacidadPagoDisponible: json['capacidad_pago_disponible'] as num? ?? 0,
      ratioEndeudamiento: json['ratio_endeudamiento'] as num? ?? 0,
      recomendacionScoring: json['recomendacion_scoring'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id_cliente': idCliente,
      'dni': dni,
      'nombres': nombres,
      'apellidos': apellidos,
      'edad': edad,
      'ocupacion': ocupacion,
      'ingresos_mensuales': ingresosMensuales,
      'gastos_mensuales': gastosMensuales,
      'deuda_actual': deudaActual,
      'cuotas_mensuales_actuales': cuotasMensualesActuales,
      'numero_creditos_activos': numeroCreditosActivos,
      'historial_pagos': historialPagos,
      'dias_mora': diasMora,
      'puntualidad_pago': puntualidadPago,
      'tiene_deuda_vencida': tieneDeudaVencida,
      'reportado_sbs': reportadoSbs,
      'en_lista_negra': enListaNegra,
      'evidencia_fraude': evidenciaFraude,
      'monto_solicitado': montoSolicitado,
      'plazo_meses': plazoMeses,
      'destino_credito': destinoCredito,
      'destino_credito_otro': destinoCreditoOtro,
      'antiguedad_laboral_meses': antiguedadLaboralMeses,
      'direccion': direccion,
      'latitud': latitud,
      'longitud': longitud,
      'estado_cliente': estadoCliente,
      'estado_solicitud': estadoSolicitud,
      'score': score,
      'nivel_riesgo': nivelRiesgo,
      'capacidad_pago_disponible': capacidadPagoDisponible,
      'ratio_endeudamiento': ratioEndeudamiento,
      'recomendacion_scoring': recomendacionScoring,
    };
  }
}
