import '../models/demo_scoring_client.dart';

class CreditScoringInput {
  const CreditScoringInput({
    required this.ingresosMensuales,
    required this.gastosMensuales,
    required this.cuotasMensualesActuales,
    required this.deudaActual,
    required this.numeroCreditosActivos,
    required this.puntualidadPago,
    required this.diasMora,
    required this.tieneDeudaVencida,
    required this.reportadoSbs,
    required this.enListaNegra,
    required this.evidenciaFraude,
    required this.montoSolicitado,
    required this.plazoMeses,
    required this.antiguedadLaboralMeses,
    required this.historialPagos,
  });

  final num ingresosMensuales;
  final num gastosMensuales;
  final num cuotasMensualesActuales;
  final num deudaActual;
  final int numeroCreditosActivos;
  final num puntualidadPago;
  final int diasMora;
  final bool tieneDeudaVencida;
  final bool reportadoSbs;
  final bool enListaNegra;
  final bool evidenciaFraude;
  final num montoSolicitado;
  final int plazoMeses;
  final int antiguedadLaboralMeses;
  final String historialPagos;

  num get capacidadPagoDisponible =>
      ingresosMensuales - gastosMensuales - cuotasMensualesActuales;

  num get ratioEndeudamiento {
    if (ingresosMensuales <= 0) return 100;
    return ((cuotasMensualesActuales + deudaActual) / ingresosMensuales) * 100;
  }

  factory CreditScoringInput.fromDemoClient(DemoScoringClient client) {
    return CreditScoringInput(
      ingresosMensuales: client.ingresosMensuales,
      gastosMensuales: client.gastosMensuales,
      cuotasMensualesActuales: client.cuotasMensualesActuales,
      deudaActual: client.deudaActual,
      numeroCreditosActivos: client.numeroCreditosActivos,
      puntualidadPago: client.puntualidadPago,
      diasMora: client.diasMora,
      tieneDeudaVencida: client.tieneDeudaVencida,
      reportadoSbs: client.reportadoSbs,
      enListaNegra: client.enListaNegra,
      evidenciaFraude: client.evidenciaFraude,
      montoSolicitado: client.montoSolicitado,
      plazoMeses: client.plazoMeses,
      antiguedadLaboralMeses: client.antiguedadLaboralMeses,
      historialPagos: client.historialPagos,
    );
  }
}

class CreditScoringResult {
  const CreditScoringResult({
    required this.score,
    required this.nivelRiesgo,
    required this.estadoEvaluacion,
    required this.semaforo,
    required this.recomendacion,
    required this.capacidadPagoDisponible,
    required this.ratioEndeudamiento,
    required this.rechazoAutomatico,
    required this.motivoRechazo,
    required this.detalle,
  });

  final int score;
  final String nivelRiesgo;
  final String estadoEvaluacion;
  final String semaforo;
  final String recomendacion;
  final num capacidadPagoDisponible;
  final num ratioEndeudamiento;
  final bool rechazoAutomatico;
  final String motivoRechazo;
  final Map<String, int> detalle;

  Map<String, Object?> toJson() {
    return {
      'score': score,
      'nivel_riesgo': nivelRiesgo,
      'estado_evaluacion': estadoEvaluacion,
      'semaforo_riesgo': semaforo,
      'recomendacion_scoring': recomendacion,
      'capacidad_pago_disponible': capacidadPagoDisponible,
      'ratio_endeudamiento': ratioEndeudamiento,
      'rechazo_automatico': rechazoAutomatico,
      'motivo_rechazo': motivoRechazo,
      'score_ingresos': detalle['ingresos'] ?? 0,
      'score_capacidad_pago': detalle['capacidadPago'] ?? 0,
      'score_dias_mora': detalle['diasMora'] ?? 0,
      'score_puntualidad': detalle['puntualidad'] ?? 0,
      'score_ratio_endeudamiento': detalle['ratioEndeudamiento'] ?? 0,
      'score_creditos_activos': detalle['creditosActivos'] ?? 0,
      'score_antiguedad_laboral': detalle['antiguedadLaboral'] ?? 0,
      'score_buro_sbs': detalle['buroSbs'] ?? 0,
    };
  }
}

class CreditScoringService {
  const CreditScoringService();

  CreditScoringResult evaluate(CreditScoringInput input) {
    final capacidad = input.capacidadPagoDisponible;
    final ratio = input.ratioEndeudamiento;
    final detalle = <String, int>{
      'ingresos': _monthlyIncomeScore(input.ingresosMensuales),
      'capacidadPago': _paymentCapacityScore(capacidad),
      'diasMora': _lateDaysScore(input.diasMora),
      'puntualidad': _punctualityScore(input.puntualidadPago),
      'ratioEndeudamiento': _debtRatioScore(ratio),
      'creditosActivos': _activeCreditsScore(input.numeroCreditosActivos),
      'antiguedadLaboral': _seniorityScore(input.antiguedadLaboralMeses),
      'buroSbs': _bureauScore(input),
    };
    final score = detalle.values.fold<int>(0, (sum, value) => sum + value);
    final automaticRejection = _automaticRejection(input, capacidad, ratio);
    if (automaticRejection != null) {
      return _result(
        score: score,
        nivel: 'Rechazo automatico',
        estado: 'Rechazado',
        semaforo: 'Rojo',
        recomendacion: 'Rechazar: $automaticRejection',
        capacidad: capacidad,
        ratio: ratio,
        rechazoAutomatico: true,
        motivoRechazo: automaticRejection,
        detalle: detalle,
      );
    }

    if (score >= 80) {
      return _result(
        score: score,
        nivel: 'Bajo',
        estado: 'Aprobado',
        semaforo: 'Verde',
        recomendacion: 'Credito aprobado automaticamente.',
        capacidad: capacidad,
        ratio: ratio,
        detalle: detalle,
      );
    }
    if (score >= 60) {
      return _result(
        score: score,
        nivel: 'Medio',
        estado: 'Revision manual',
        semaforo: 'Amarillo',
        recomendacion: 'Revision manual del asesor o comite.',
        capacidad: capacidad,
        ratio: ratio,
        detalle: detalle,
      );
    }
    return _result(
      score: score,
      nivel: 'Alto',
      estado: 'Rechazado',
      semaforo: 'Rojo',
      recomendacion: 'Credito rechazado por riesgo alto.',
      capacidad: capacidad,
      ratio: ratio,
      detalle: detalle,
    );
  }

  CreditScoringResult _result({
    required int score,
    required String nivel,
    required String estado,
    required String semaforo,
    required String recomendacion,
    required num capacidad,
    required num ratio,
    required Map<String, int> detalle,
    bool rechazoAutomatico = false,
    String motivoRechazo = '',
  }) {
    return CreditScoringResult(
      score: score.clamp(0, 100),
      nivelRiesgo: nivel,
      estadoEvaluacion: estado,
      semaforo: semaforo,
      recomendacion: recomendacion,
      capacidadPagoDisponible: capacidad,
      ratioEndeudamiento: ratio,
      rechazoAutomatico: rechazoAutomatico,
      motivoRechazo: motivoRechazo,
      detalle: detalle,
    );
  }

  String? _automaticRejection(
    CreditScoringInput input,
    num capacidad,
    num ratio,
  ) {
    if (input.enListaNegra) return 'cliente en lista negra';
    if (input.reportadoSbs) return 'reporte SBS negativo activo';
    if (input.evidenciaFraude) return 'evidencia de fraude o suplantacion';
    if (capacidad <= 0) return 'capacidad de pago menor o igual a cero';
    if (ratio > 90) return 'ratio de endeudamiento superior al 90%';
    if (input.diasMora > 90) return 'mas de 90 dias de mora acumulada';
    return null;
  }

  int _monthlyIncomeScore(num income) {
    if (income >= 5000) return 15;
    if (income >= 3500) return 12;
    if (income >= 2000) return 8;
    if (income >= 1200) return 4;
    return 0;
  }

  int _paymentCapacityScore(num capacity) {
    if (capacity >= 2000) return 10;
    if (capacity >= 1000) return 8;
    if (capacity >= 500) return 5;
    if (capacity >= 1) return 2;
    return 0;
  }

  int _lateDaysScore(int days) {
    if (days == 0) return 15;
    if (days <= 7) return 10;
    if (days <= 30) return 5;
    return 0;
  }

  int _punctualityScore(num punctuality) {
    if (punctuality >= 95) return 15;
    if (punctuality >= 85) return 12;
    if (punctuality >= 70) return 6;
    return 0;
  }

  int _debtRatioScore(num ratio) {
    if (ratio <= 30) return 15;
    if (ratio <= 50) return 10;
    if (ratio <= 70) return 5;
    return 0;
  }

  int _activeCreditsScore(int activeCredits) {
    if (activeCredits <= 1) return 5;
    if (activeCredits <= 3) return 3;
    if (activeCredits <= 5) return 1;
    return 0;
  }

  int _seniorityScore(int months) {
    if (months > 60) return 15;
    if (months >= 36) return 12;
    if (months >= 12) return 8;
    if (months >= 6) return 4;
    return 0;
  }

  int _bureauScore(CreditScoringInput input) {
    if (input.enListaNegra || input.evidenciaFraude || input.reportadoSbs) {
      return 0;
    }
    if (input.tieneDeudaVencida) return 3;
    if (input.diasMora > 0) return 7;
    return 10;
  }
}
