import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/credit_request.dart';
import '../models/demo_scoring_client.dart';
import '../models/route_visit.dart';

extension DemoScoringMapper on DemoScoringClient {
  Client toSalesClient() {
    return Client(
      clientId: idCliente,
      requestId: idCliente,
      name: nombreCompleto,
      dni: dni,
      phone: '9${dni.substring(dni.length - 8, dni.length)}',
      location: direccion,
      age: edad,
      businessName: ocupacion,
      businessType: ocupacion,
      businessAge: '${(antiguedadLaboralMeses / 12).floor()} anos',
      premises: 'Huancayo',
      sbsRating: reportadoSbs ? 'Observado' : 'Normal',
      totalDebt: deudaActual.toStringAsFixed(0),
      preScore: score,
      segment: estadoSolicitud,
      renewalDate: estadoCliente,
      monthlyIncome: ingresosMensuales,
      monthlyExpenses: gastosMensuales,
      currentInstallments: cuotasMensualesActuales,
      paymentCapacity: capacidadPagoDisponible,
      debtRatio: ratioEndeudamiento,
      activeCredits: numeroCreditosActivos,
      lateDays: diasMora,
      paymentPunctuality: puntualidadPago,
      creditPurpose: destinoCredito,
      requestAmount: montoSolicitado,
      termMonths: plazoMeses,
      clientStatus: estadoCliente,
      requestStatus: estadoSolicitud,
      recommendation: recomendacionScoring,
      latitude: latitud,
      longitude: longitud,
      fieldVisitCompleted: true,
    );
  }

  CreditRequest toCreditRequest() {
    return CreditRequest(
      id: idCliente,
      client: nombreCompleto,
      amount: 'S/ ${montoSolicitado.toStringAsFixed(2)}',
      segment: estadoSolicitud,
      status: estadoSolicitud,
      clientId: idCliente,
      dni: dni,
      clientStatus: estadoCliente,
      amountValue: montoSolicitado,
      termMonths: plazoMeses,
      purpose: destinoCredito,
      score: _scoreFromRisk(),
      riskLevel: nivelRiesgo,
      recommendation: recomendacionScoring,
      latitude: latitud,
      longitude: longitud,
      locationLabel: direccion,
      fieldVisitCompleted: true,
    );
  }

  RouteVisit toRouteVisit(int index) {
    return RouteVisit(
      '${8 + index}:00',
      nombreCompleto,
      direccion,
      estadoSolicitud == 'Aceptado' ? 'Solicitud aceptada' : 'Visita asignada',
      estadoSolicitud == 'Aceptado'
          ? const Color(0xFF2A9D8F)
          : const Color(0xFF3135FF),
      latitud,
      longitud,
    );
  }

  int _scoreFromRisk() => score;
}
