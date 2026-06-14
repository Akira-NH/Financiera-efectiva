import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/client.dart';
import '../models/credit_request.dart';
import '../models/demo_scoring_client.dart';
import '../models/route_visit.dart';
import '../repositories/firestore_sales_repository.dart';
import '../repositories/mock_sales_repository.dart';
import '../repositories/sales_repository.dart';

class FirestoreSalesService {
  const FirestoreSalesService();

  static const clientsCollection = 'sales_clients';
  static const requestsCollection = 'sales_credit_requests';
  static const routeVisitsCollection = 'sales_route_visits';
  static const scoringFeaturesCollection = 'sales_scoring_features';
  static const demoScoringClientsCollection = 'clientes_scoring_demo';

  FirebaseFirestore? get _firestore {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  Future<SalesRepository> loadRepository() async {
    final firestore = _firestore;
    const fallback = MockSalesRepository();
    if (firestore == null) return fallback;

    late final List<QuerySnapshot<Map<String, dynamic>>> snapshots;
    try {
      snapshots = await Future.wait([
        firestore.collection(clientsCollection).get(),
        firestore.collection(requestsCollection).get(),
        firestore.collection(routeVisitsCollection).get(),
      ]);
    } catch (_) {
      return fallback;
    }

    final clients = snapshots[0].docs
        .map((doc) => Client.fromJson(doc.data()))
        .where((client) => client.dni.isNotEmpty || client.name.isNotEmpty)
        .toList();
    final requests = snapshots[1].docs
        .map((doc) => CreditRequest.fromJson(doc.data(), id: doc.id))
        .where((request) => request.client.isNotEmpty)
        .toList();
    final routeVisits = snapshots[2].docs
        .map((doc) => RouteVisit.fromJson(doc.data()))
        .where((visit) => visit.client.isNotEmpty)
        .toList();

    return FirestoreSalesRepository(
      clients: clients.isEmpty ? fallback.clients : clients,
      requests: requests.isEmpty ? fallback.requests : requests,
      routeVisits: routeVisits.isEmpty ? fallback.routeVisits : routeVisits,
    );
  }

  Stream<List<CreditRequest>> watchCreditRequests({
    required List<CreditRequest> fallback,
  }) async* {
    final firestore = _firestore;
    if (firestore == null) {
      yield fallback;
      return;
    }

    try {
      await for (final snapshot
          in firestore
              .collection(requestsCollection)
              .orderBy('updatedAt', descending: true)
              .snapshots()) {
        final requests = snapshot.docs
            .map((doc) => CreditRequest.fromJson(doc.data(), id: doc.id))
            .where((request) => request.client.isNotEmpty)
            .toList();
        yield requests.isEmpty ? fallback : requests;
      }
    } catch (_) {
      yield fallback;
    }
  }

  Future<void> syncRepository(SalesRepository repository) async {
    final firestore = _firestore;
    if (firestore == null) return;

    final batch = firestore.batch();

    for (final client in repository.clients) {
      final id = client.dni.isEmpty ? client.name : client.dni;
      batch.set(
        firestore.collection(clientsCollection).doc(id),
        client.toJson(),
        SetOptions(merge: true),
      );
      batch.set(
        firestore.collection(scoringFeaturesCollection).doc(id),
        _featureRowFromClient(client),
        SetOptions(merge: true),
      );
    }

    for (final request in repository.requests) {
      final id = '${request.client}_${request.amount}'.replaceAll('/', '-');
      batch.set(
        firestore.collection(requestsCollection).doc(id),
        request.toJson(),
        SetOptions(merge: true),
      );
    }

    for (final visit in repository.routeVisits) {
      final id = '${visit.time}_${visit.client}'.replaceAll('/', '-');
      batch.set(
        firestore.collection(routeVisitsCollection).doc(id),
        visit.toJson(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<List<DemoScoringClient>> loadDemoScoringClients() async {
    final firestore = _firestore;
    if (firestore == null) return const [];

    final snapshot = await firestore
        .collection(demoScoringClientsCollection)
        .orderBy('id_cliente')
        .get();
    return snapshot.docs
        .map((doc) => DemoScoringClient.fromJson(doc.data()))
        .where((client) => client.idCliente.isNotEmpty)
        .toList();
  }

  Future<void> approveAndDisburse(CreditRequest request) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firestore no esta inicializado.');
    }
    if (request.id.isEmpty || request.clientId.isEmpty) {
      throw StateError('La solicitud no tiene un cliente vinculado.');
    }
    if (request.amountValue <= 0) {
      throw StateError('La solicitud no tiene un monto valido.');
    }
    final status = request.status.toLowerCase();
    if (!status.contains('aprob')) {
      throw StateError('Solo se puede desembolsar una solicitud aprobada.');
    }

    final clientRef = firestore.collection('clients').doc(request.clientId);
    final savingsRef = clientRef.collection('savings').doc('main');
    final creditRef = clientRef.collection('credits').doc('activeLoan');
    final salesRequestRef = firestore
        .collection(requestsCollection)
        .doc(request.id);
    final clientRequestRef = clientRef
        .collection('creditRequests')
        .doc(request.id);
    final movementRef = clientRef.collection('movements').doc();
    final operationRef = clientRef.collection('operations').doc();
    final now = DateTime.now();
    final today = _formatDate(now);
    final termMonths = request.termMonths <= 0 ? 12 : request.termMonths;
    final installmentAmount = request.amountValue / termMonths;
    final creditCodeLength = request.id.length < 8 ? request.id.length : 8;

    await firestore.runTransaction((transaction) async {
      final clientDoc = await transaction.get(clientRef);
      final savingsDoc = await transaction.get(savingsRef);
      final clientData = clientDoc.data() ?? {};
      final savingsData = savingsDoc.data() ?? {};
      final savingsBalance =
          savingsData['balance'] as num? ??
          clientData['savingsBalance'] as num? ??
          0;
      final piggyBankBalance =
          savingsData['piggyBankBalance'] as num? ??
          clientData['piggyBankBalance'] as num? ??
          0;
      final activeLoansBalance = clientData['activeLoansBalance'] as num? ?? 0;
      final newSavingsBalance = savingsBalance + request.amountValue;
      final newActiveLoansBalance = activeLoansBalance + request.amountValue;

      transaction.set(clientRef, {
        'savingsBalance': newSavingsBalance,
        'totalBalance': newSavingsBalance + piggyBankBalance,
        'activeLoansBalance': newActiveLoansBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(savingsRef, {
        'balance': newSavingsBalance,
        'piggyBankBalance': piggyBankBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(creditRef, {
        'id': 'CRE-${request.id.substring(0, creditCodeLength).toUpperCase()}',
        'amount': request.amountValue,
        'pendingBalance': request.amountValue,
        'status': 'Al dia',
        'isDisbursed': true,
        'sourceRequestId': request.id,
        'termMonths': termMonths,
        'purpose': request.purpose,
        'approvedAt': FieldValue.serverTimestamp(),
        'disbursedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (var i = 1; i <= termMonths; i++) {
        final dueDate = DateTime(now.year, now.month + i, now.day);
        transaction.set(
          clientRef
              .collection('installments')
              .doc(i.toString().padLeft(3, '0')),
          {
            'number': i,
            'dueDate': _formatDate(dueDate),
            'amount': installmentAmount,
            'isPaid': false,
            'creditId': request.id,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }

      transaction.set(movementRef, {
        'title': 'Desembolso de credito',
        'amount': request.amountValue,
        'date': today,
        'isIncome': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(operationRef, {
        'type': 'Desembolso de credito',
        'amount': request.amountValue,
        'status': 'Exitosa',
        'date': today,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(salesRequestRef, {
        'estado': 'Desembolsado',
        'status': 'Desembolsado',
        'approvedAt': FieldValue.serverTimestamp(),
        'disbursedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(clientRequestRef, {
        'status': 'Desembolsado',
        'approvedAt': FieldValue.serverTimestamp(),
        'disbursedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Map<String, int> buildSyncSummary(SalesRepository repository) {
    return {
      clientsCollection: repository.clients.length,
      requestsCollection: repository.requests.length,
      routeVisitsCollection: repository.routeVisits.length,
      scoringFeaturesCollection: repository.clients.length,
      demoScoringClientsCollection: 100,
    };
  }

  Map<String, Object?> _featureRowFromClient(Client client) {
    final scoreCampo = switch (client.segment) {
      'PREMIER' => 180,
      'ESTANDAR' => 145,
      _ => 95,
    };
    return {
      'dni': client.dni,
      'capacidad_ahorro': (client.preScore * .25).round(),
      'regularidad_ingresos': (client.preScore * .20).round(),
      'disciplina_financiera': (client.preScore * .20).round(),
      'vinculo_institucion': (client.preScore * .20).round(),
      'riesgo': (client.preScore * .15).round(),
      'score_transaccional': client.preScore,
      'score_campo': scoreCampo,
      'score_final': client.preScore + scoreCampo,
      'segmento_final': client.segment,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
