import '../models/demo_scoring_client.dart';
import '../services/credit_scoring_service.dart';

class DemoScoringSeed {
  const DemoScoringSeed._();

  static List<DemoScoringClient> buildClients() {
    return [for (var index = 1; index <= 100; index++) _buildClient(index)];
  }

  static DemoScoringClient _buildClient(int index) {
    final kind = switch (index) {
      <= 40 => 'bajo',
      <= 75 => 'medio',
      <= 95 => 'alto',
      _ => 'rechazo',
    };
    const names = [
      'Maria',
      'Jose',
      'Rosa',
      'Luis',
      'Carmen',
      'Jorge',
      'Ana',
      'Miguel',
      'Lucia',
      'Carlos',
    ];
    const lastNames = [
      'Quispe Ramos',
      'Huaman Flores',
      'Medina Soto',
      'Torres Vega',
      'Castillo Rojas',
      'Paredes Nunez',
      'Salazar Cueva',
      'Mendoza Leon',
      'Vargas Silva',
      'Chavez Molina',
    ];
    const occupations = [
      'Comerciante',
      'Transportista',
      'Costurera',
      'Tecnico electricista',
      'Docente',
      'Vendedor mayorista',
      'Restaurante familiar',
      'Agricultor',
      'Ferretero',
      'Emprendedora digital',
    ];
    const destinations = [
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
    const addresses = [
      'Plaza Constitucion, Huancayo',
      'Real Plaza Huancayo',
      'Mercado Modelo de Huancayo',
      'Parque de la Identidad Wanka',
      'Universidad Nacional del Centro del Peru',
      'Estadio Huancayo',
      'Jiron Real y Paseo La Breña',
      'Terminal Terrestre Huancayo',
      'Hospital Daniel Alcides Carrion',
      'Feria Dominical de Huancayo',
    ];

    final incomeBase = kind == 'bajo'
        ? 5200
        : kind == 'medio'
        ? 3800
        : 1500;
    final income = incomeBase + ((index * 137) % 1700);
    final expenses =
        (income *
                (kind == 'bajo'
                    ? .42
                    : kind == 'medio'
                    ? .5
                    : .68))
            .round();
    final installments =
        (income *
                (kind == 'bajo'
                    ? .06
                    : kind == 'medio'
                    ? .1
                    : .26))
            .round();
    final debt =
        (income *
                (kind == 'bajo'
                    ? .16
                    : kind == 'medio'
                    ? .22
                    : .55))
            .round();
    final lateDays = kind == 'bajo'
        ? index % 3
        : kind == 'medio'
        ? 1 + (index % 12)
        : kind == 'alto'
        ? 18 + (index % 55)
        : 92 + (index % 8);
    final blacklist = kind == 'rechazo' && index.isEven;
    final sbs = kind == 'rechazo' && index.isOdd;
    final fraud = kind == 'rechazo' && index == 99;
    final punctuality = kind == 'bajo'
        ? 96 + (index % 4)
        : kind == 'medio'
        ? 86 + (index % 8)
        : 42 + (index % 28);
    final activeCredits = kind == 'bajo'
        ? index % 2
        : kind == 'medio'
        ? 2
        : 4 + (index % 3);
    final seniority = kind == 'bajo'
        ? 62 + (index % 36)
        : kind == 'medio'
        ? 18 + (index % 34)
        : 3 + (index % 20);
    final destination = destinations[(index - 1) % destinations.length];
    final lat = -12.0651 + (((index - 1) % 10) - 5) * .0045;
    final lng = -75.2049 + (((index - 1) ~/ 10) - 5) * .0042;
    final input = CreditScoringInput(
      ingresosMensuales: income,
      gastosMensuales: expenses,
      cuotasMensualesActuales: installments,
      deudaActual: debt,
      numeroCreditosActivos: activeCredits,
      puntualidadPago: punctuality,
      diasMora: lateDays,
      tieneDeudaVencida: kind == 'alto' || kind == 'rechazo',
      reportadoSbs: sbs,
      enListaNegra: blacklist,
      evidenciaFraude: fraud,
      montoSolicitado: kind == 'bajo'
          ? 8000 + index * 120
          : kind == 'medio'
          ? 10000 + index * 90
          : 6000 + index * 70,
      plazoMeses: const [6, 9, 12, 18, 24][index % 5],
      antiguedadLaboralMeses: seniority,
      historialPagos: index % 11 == 0
          ? 'sin historial'
          : kind == 'bajo'
          ? 'excelente'
          : kind == 'medio'
          ? 'regular'
          : 'deficiente',
    );
    final score = const CreditScoringService().evaluate(input);

    return DemoScoringClient(
      idCliente: 'CLI-DEMO-${index.toString().padLeft(3, '0')}',
      dni: '${71000000 + index}',
      nombres: names[(index - 1) % names.length],
      apellidos: lastNames[(index - 1) % lastNames.length],
      edad: 23 + (index % 38),
      ocupacion: occupations[(index - 1) % occupations.length],
      ingresosMensuales: income,
      gastosMensuales: expenses,
      deudaActual: debt,
      cuotasMensualesActuales: installments,
      numeroCreditosActivos: activeCredits,
      historialPagos: input.historialPagos,
      diasMora: lateDays,
      puntualidadPago: punctuality,
      tieneDeudaVencida: kind == 'alto' || kind == 'rechazo',
      reportadoSbs: sbs,
      enListaNegra: blacklist,
      evidenciaFraude: fraud,
      montoSolicitado: input.montoSolicitado,
      plazoMeses: input.plazoMeses,
      destinoCredito: destination,
      destinoCreditoOtro: destination == 'Otros'
          ? 'Financiamiento especifico de temporada'
          : '',
      antiguedadLaboralMeses: seniority,
      direccion: addresses[(index - 1) % addresses.length],
      latitud: lat,
      longitud: lng,
      estadoCliente: index <= 4 ? 'Visitar' : 'Visitado',
      estadoSolicitud: index <= 4
          ? 'Pendiente'
          : score.estadoEvaluacion == 'Aprobado'
          ? 'Aceptado'
          : 'Negado',
      score: score.score,
      nivelRiesgo: score.nivelRiesgo,
      capacidadPagoDisponible: score.capacidadPagoDisponible,
      ratioEndeudamiento: score.ratioEndeudamiento,
      recomendacionScoring: score.recomendacion,
    );
  }
}
