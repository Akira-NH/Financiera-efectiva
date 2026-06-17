import 'package:financiera_efectiva_ventas/app.dart';
import 'package:financiera_efectiva_ventas/data/demo/demo_scoring_seed.dart';
import 'package:financiera_efectiva_ventas/data/mappers/demo_scoring_mapper.dart';
import 'package:financiera_efectiva_ventas/data/repositories/firestore_sales_repository.dart';
import 'package:financiera_efectiva_ventas/data/services/credit_scoring_service.dart';
import 'package:financiera_efectiva_ventas/data/services/firestore_sales_service.dart';
import 'package:financiera_efectiva_ventas/data/services/power_bi_export_service.dart';
import 'package:financiera_efectiva_ventas/utils/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows sales force dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const FuerzaVentasApp());
    await tester.pumpAndSettle();

    expect(find.text('Ingreso asesor'), findsOneWidget);
    await tester.tap(find.text('Usar asesor demo'));
    await tester.pump();
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Financiera Efectiva | Fuerza de Ventas'), findsOneWidget);
    expect(find.text('Cartera'), findsWidgets);
    expect(find.text('Maria Quispe Ramos'), findsWidgets);
    expect(find.text('Sincronizado'), findsOneWidget);
  });

  test('classifies final scores from scoring rules', () {
    expect(classifyFinal(760, false), 'PREMIER');
    expect(classifyFinal(620, false), 'ESTANDAR');
    expect(classifyFinal(360, false), 'BASICO');
    expect(classifyFinal(900, true), 'NO APLICA');
  });

  test('evaluates internal credit scoring decisions', () {
    const service = CreditScoringService();

    final lowRisk = service.evaluate(
      const CreditScoringInput(
        ingresosMensuales: 7200,
        gastosMensuales: 2400,
        cuotasMensualesActuales: 600,
        deudaActual: 900,
        numeroCreditosActivos: 1,
        puntualidadPago: 98,
        diasMora: 0,
        tieneDeudaVencida: false,
        reportadoSbs: false,
        enListaNegra: false,
        evidenciaFraude: false,
        montoSolicitado: 9000,
        plazoMeses: 12,
        antiguedadLaboralMeses: 48,
        historialPagos: 'excelente',
      ),
    );
    final manualReview = service.evaluate(
      const CreditScoringInput(
        ingresosMensuales: 3800,
        gastosMensuales: 2100,
        cuotasMensualesActuales: 450,
        deudaActual: 1100,
        numeroCreditosActivos: 2,
        puntualidadPago: 84,
        diasMora: 7,
        tieneDeudaVencida: false,
        reportadoSbs: false,
        enListaNegra: false,
        evidenciaFraude: false,
        montoSolicitado: 10000,
        plazoMeses: 18,
        antiguedadLaboralMeses: 18,
        historialPagos: 'regular',
      ),
    );
    final veto = service.evaluate(
      const CreditScoringInput(
        ingresosMensuales: 9000,
        gastosMensuales: 2000,
        cuotasMensualesActuales: 0,
        deudaActual: 0,
        numeroCreditosActivos: 0,
        puntualidadPago: 100,
        diasMora: 0,
        tieneDeudaVencida: false,
        reportadoSbs: false,
        enListaNegra: true,
        evidenciaFraude: false,
        montoSolicitado: 5000,
        plazoMeses: 6,
        antiguedadLaboralMeses: 60,
        historialPagos: 'excelente',
      ),
    );

    expect(lowRisk.estadoEvaluacion, 'Aprobado');
    expect(manualReview.estadoEvaluacion, 'Revision manual');
    expect(veto.estadoEvaluacion, 'Rechazado');
  });

  test('builds Firestore sync summary and Power BI dataset', () {
    final demoClients = DemoScoringSeed.buildClients();
    final routeClients = demoClients.take(4).toList();
    final repository = FirestoreSalesRepository(
      clients: demoClients.map((client) => client.toSalesClient()).toList(),
      requests: demoClients.map((client) => client.toCreditRequest()).toList(),
      routeVisits: [
        for (var i = 0; i < routeClients.length; i++)
          routeClients[i].toRouteVisit(i),
      ],
    );
    const firestore = FirestoreSalesService();
    const exporter = PowerBiExportService();

    final summary = firestore.buildSyncSummary(repository);
    final dataset = exporter.buildDataset(
      clients: repository.clients,
      requests: repository.requests,
      routeVisits: repository.routeVisits,
    );

    expect(summary[FirestoreSalesService.clientsCollection], 100);
    expect(dataset.clientsCsv, contains('dni,nombres,telefono'));
    expect(dataset.requestsCsv, contains('cliente,monto,segmento,estado'));
    expect(dataset.totalRows, 204);
  });
}
