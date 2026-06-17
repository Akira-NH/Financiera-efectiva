import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../features/credits/domain/entities/installment.dart';
import '../../features/credits/domain/entities/credit_request_status.dart';
import '../../features/credits/domain/entities/loan.dart';
import '../../features/dashboard/data/dashboard_mock_data.dart';
import '../../features/dashboard/domain/entities/financial_summary.dart';
import '../../features/dashboard/domain/entities/movement.dart';
import '../../features/operations/data/operations_mock_data.dart';
import '../../features/operations/domain/entities/operation_history_item.dart';
import '../../features/operations/domain/entities/operation_contact.dart';
import '../../features/operations/domain/entities/service_bill.dart';
import '../../features/savings/data/savings_mock_data.dart';
import '../../features/savings/domain/entities/account_statement.dart';
import '../../features/savings/domain/entities/deposit.dart';
import '../../features/savings/domain/entities/savings_account.dart';
import '../errors/app_exception.dart';
import 'client_database_service.dart';
import 'firebase_auth_service.dart';

class _OperationHistoryRow {
  const _OperationHistoryRow({required this.item, this.createdAt});

  final OperationHistoryItem item;
  final Timestamp? createdAt;
}

class FinancialFirestoreService {
  FinancialFirestoreService._();

  static final FinancialFirestoreService instance =
      FinancialFirestoreService._();

  static const num initialBalance = 1000;

  String? _ensuredClientId;
  Future<void>? _ensureProfileFuture;

  FirebaseFirestore? get _firestore {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  String get _clientId =>
      FirebaseAuthService.instance.currentUser?.uid ??
      ClientDatabaseService.instance.currentClient?.id ??
      'CLI-001';

  String get _today {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }

  Future<void> ensureClientFinancialProfile() async {
    final firestore = _firestore;
    if (firestore == null) return;

    final clientId = _clientId;
    if (_ensuredClientId == clientId) return;

    final pendingEnsure = _ensureProfileFuture;
    if (pendingEnsure != null) return pendingEnsure;

    _ensureProfileFuture = _ensureClientFinancialProfile(
      firestore: firestore,
      clientId: clientId,
    );

    try {
      await _ensureProfileFuture;
      _ensuredClientId = clientId;
    } finally {
      _ensureProfileFuture = null;
    }
  }

  Future<void> _ensureClientFinancialProfile({
    required FirebaseFirestore firestore,
    required String clientId,
  }) async {
    final clientRef = firestore.collection('clients').doc(clientId);
    final savingsRef = clientRef.collection('savings').doc('main');

    await firestore.runTransaction((transaction) async {
      final clientDoc = await transaction.get(clientRef);
      final savingsDoc = await transaction.get(savingsRef);

      if (!clientDoc.exists) {
        transaction.set(clientRef, {
          'totalBalance': initialBalance,
          'savingsBalance': initialBalance,
          'piggyBankBalance': 0,
          'activeLoansBalance': 0,
          'financialProfileSeeded': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final data = clientDoc.data() ?? {};
        final updates = <String, Object?>{};
        final totalBalance = data['totalBalance'] as num?;
        final savingsBalance = data['savingsBalance'] as num?;
        if (!data.containsKey('totalBalance')) {
          updates['totalBalance'] = savingsBalance ?? initialBalance;
        }
        if (!data.containsKey('savingsBalance')) {
          updates['savingsBalance'] = totalBalance ?? initialBalance;
        }
        if (!data.containsKey('activeLoansBalance')) {
          updates['activeLoansBalance'] = 0;
        }
        if (!data.containsKey('piggyBankBalance')) {
          updates['piggyBankBalance'] = 0;
        }
        if (!data.containsKey('financialProfileSeeded')) {
          updates['financialProfileSeeded'] = true;
        }
        if (updates.isNotEmpty) transaction.update(clientRef, updates);
      }

      if (!savingsDoc.exists) {
        final clientData = clientDoc.data() ?? {};
        final savingsBalance =
            clientData['savingsBalance'] as num? ??
            clientData['totalBalance'] as num? ??
            initialBalance;
        final piggyBankBalance = clientData['piggyBankBalance'] as num? ?? 0;
        transaction.set(savingsRef, {
          'number': 'AHO-${clientId.substring(0, 6).toUpperCase()}',
          'balance': savingsBalance,
          'piggyBankBalance': piggyBankBalance,
          'status': 'Activa',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final savingsData = savingsDoc.data() ?? {};
        final clientData = clientDoc.data() ?? {};
        final updates = <String, Object?>{};
        if (!savingsData.containsKey('balance')) {
          updates['balance'] =
              clientData['savingsBalance'] as num? ??
              clientData['totalBalance'] as num? ??
              initialBalance;
        }
        if (!savingsData.containsKey('piggyBankBalance')) {
          updates['piggyBankBalance'] =
              clientData['piggyBankBalance'] as num? ?? 0;
        }
        if (updates.isNotEmpty) transaction.update(savingsRef, updates);
      }
    });
  }

  Future<FinancialSummary> getSummary() async {
    final firestore = _firestore;
    if (firestore == null) return DashboardMockData.summary;

    await ensureClientFinancialProfile();
    final doc = await firestore.collection('clients').doc(_clientId).get();
    final data = doc.data();
    if (data == null) {
      return const FinancialSummary(
        totalBalance: initialBalance,
        savingsBalance: initialBalance,
        activeLoansBalance: 0,
      );
    }

    return FinancialSummary(
      totalBalance: data['totalBalance'] as num? ?? initialBalance,
      savingsBalance: data['savingsBalance'] as num? ?? initialBalance,
      activeLoansBalance: data['activeLoansBalance'] as num? ?? 0,
    );
  }

  Future<FinancialSummary> getCachedSummary() async {
    final firestore = _firestore;
    if (firestore == null) return DashboardMockData.summary;

    Map<String, dynamic>? data;
    try {
      final doc = await firestore
          .collection('clients')
          .doc(_clientId)
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 2));
      data = doc.data();
    } catch (_) {
      data = null;
    }

    data ??= await _fetchClientDataFromServer(firestore);
    return _summaryFromClientData(data);
  }

  Future<List<Movement>> getMovements({int? limit}) async {
    final firestore = _firestore;
    if (firestore == null) return DashboardMockData.movements;

    await ensureClientFinancialProfile();
    Query<Map<String, dynamic>> query = firestore
        .collection('clients')
        .doc(_clientId)
        .collection('movements')
        .orderBy('createdAt', descending: true);

    if (limit != null) query = query.limit(limit);

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return const [];

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Movement(
        title: data['title'] as String? ?? 'Movimiento',
        date: data['date'] as String? ?? '',
        amount: data['amount'] as num? ?? 0,
        isIncome: data['isIncome'] as bool? ?? false,
      );
    }).toList();
  }

  Future<List<Movement>> getCachedMovements({int? limit}) async {
    final firestore = _firestore;
    if (firestore == null) return DashboardMockData.movements;

    QuerySnapshot<Map<String, dynamic>>? snapshot;
    try {
      Query<Map<String, dynamic>> query = firestore
          .collection('clients')
          .doc(_clientId)
          .collection('movements')
          .orderBy('createdAt', descending: true);

      if (limit != null) query = query.limit(limit);

      snapshot = await query
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      snapshot = null;
    }

    if (snapshot == null || snapshot.docs.isEmpty) {
      snapshot = await _fetchMovementsFromServer(firestore, limit: limit);
    }

    if (snapshot == null || snapshot.docs.isEmpty) {
      return const [];
    }

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Movement(
        title: data['title'] as String? ?? 'Movimiento',
        date: data['date'] as String? ?? '',
        amount: data['amount'] as num? ?? 0,
        isIncome: data['isIncome'] as bool? ?? false,
      );
    }).toList();
  }

  Future<Map<String, dynamic>?> _fetchClientDataFromServer(
    FirebaseFirestore firestore,
  ) async {
    try {
      final doc = await firestore
          .collection('clients')
          .doc(_clientId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 6));
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _fetchMovementsFromServer(
    FirebaseFirestore firestore, {
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = firestore
          .collection('clients')
          .doc(_clientId)
          .collection('movements')
          .orderBy('createdAt', descending: true);

      if (limit != null) query = query.limit(limit);

      return query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }

  FinancialSummary _summaryFromClientData(Map<String, dynamic>? data) {
    if (data == null) {
      return const FinancialSummary(
        totalBalance: 0,
        savingsBalance: 0,
        activeLoansBalance: 0,
      );
    }

    return FinancialSummary(
      totalBalance: data['totalBalance'] as num? ?? 0,
      savingsBalance: data['savingsBalance'] as num? ?? 0,
      activeLoansBalance: data['activeLoansBalance'] as num? ?? 0,
    );
  }

  Future<SavingsAccount> getSavingsAccount() async {
    final firestore = _firestore;
    if (firestore == null) return SavingsMockData.account;

    await ensureClientFinancialProfile();
    final doc = await firestore
        .collection('clients')
        .doc(_clientId)
        .collection('savings')
        .doc('main')
        .get();

    final data = doc.data();
    if (data == null) return SavingsMockData.account;

    return SavingsAccount(
      number: data['number'] as String? ?? '',
      balance: data['balance'] as num? ?? initialBalance,
      status: data['status'] as String? ?? 'Activa',
      piggyBankBalance: data['piggyBankBalance'] as num? ?? 0,
    );
  }

  Future<SavingsAccount> transferToPiggyBank(num amount) {
    return _movePiggyBankMoney(
      amount: amount,
      direction: _PiggyBankDirection.deposit,
    );
  }

  Future<SavingsAccount> withdrawFromPiggyBank(num amount) {
    return _movePiggyBankMoney(
      amount: amount,
      direction: _PiggyBankDirection.withdraw,
    );
  }

  Future<SavingsAccount> _movePiggyBankMoney({
    required num amount,
    required _PiggyBankDirection direction,
  }) async {
    final firestore = _firestore;
    if (amount <= 0) {
      throw const AppException('El monto debe ser mayor a cero.');
    }
    if (firestore == null) {
      throw const AppException('No se pudo conectar con la base de datos.');
    }

    await ensureClientFinancialProfile();

    final clientRef = firestore.collection('clients').doc(_clientId);
    final savingsRef = clientRef.collection('savings').doc('main');
    final operationRef = clientRef.collection('operations').doc();
    final movementRef = clientRef.collection('movements').doc();
    final depositRef = clientRef.collection('deposits').doc();

    return firestore.runTransaction((transaction) async {
      final clientDoc = await transaction.get(clientRef);
      final savingsDoc = await transaction.get(savingsRef);
      final clientData = clientDoc.data() ?? {};
      final savingsData = savingsDoc.data() ?? {};
      final availableBalance =
          savingsData['balance'] as num? ??
          clientData['savingsBalance'] as num? ??
          initialBalance;
      final piggyBankBalance =
          savingsData['piggyBankBalance'] as num? ??
          clientData['piggyBankBalance'] as num? ??
          0;

      if (direction == _PiggyBankDirection.deposit &&
          availableBalance < amount) {
        throw const AppException(
          'Saldo disponible insuficiente para depositar en la alcancía.',
        );
      }
      if (direction == _PiggyBankDirection.withdraw &&
          piggyBankBalance < amount) {
        throw const AppException(
          'Saldo insuficiente en la alcancía para retirar.',
        );
      }

      final newAvailableBalance = direction == _PiggyBankDirection.deposit
          ? availableBalance - amount
          : availableBalance + amount;
      final newPiggyBankBalance = direction == _PiggyBankDirection.deposit
          ? piggyBankBalance + amount
          : piggyBankBalance - amount;
      final totalBalance = newAvailableBalance + newPiggyBankBalance;
      final operationTitle = direction == _PiggyBankDirection.deposit
          ? 'Depósito a alcancía'
          : 'Retiro de alcancía';

      transaction.set(clientRef, {
        'totalBalance': totalBalance,
        'savingsBalance': newAvailableBalance,
        'piggyBankBalance': newPiggyBankBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(savingsRef, {
        'number':
            savingsData['number'] as String? ??
            'AHO-${_clientId.substring(0, 6).toUpperCase()}',
        'balance': newAvailableBalance,
        'piggyBankBalance': newPiggyBankBalance,
        'status': savingsData['status'] as String? ?? 'Activa',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(operationRef, {
        'type': operationTitle,
        'amount': amount,
        'status': 'Exitosa',
        'date': _today,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(movementRef, {
        'title': operationTitle,
        'amount': amount,
        'date': _today,
        'isIncome': direction == _PiggyBankDirection.withdraw,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(depositRef, {
        'amount': amount,
        'date': _today,
        'reference': direction == _PiggyBankDirection.deposit
            ? 'ALC-DEP'
            : 'ALC-RET',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return SavingsAccount(
        number:
            savingsData['number'] as String? ??
            'AHO-${_clientId.substring(0, 6).toUpperCase()}',
        balance: newAvailableBalance,
        piggyBankBalance: newPiggyBankBalance,
        status: savingsData['status'] as String? ?? 'Activa',
      );
    });
  }

  Future<List<Deposit>> getDeposits() async {
    final firestore = _firestore;
    if (firestore == null) return SavingsMockData.deposits;

    final snapshot = await firestore
        .collection('clients')
        .doc(_clientId)
        .collection('deposits')
        .orderBy('createdAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) return const [];

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Deposit(
        date: data['date'] as String? ?? '',
        amount: data['amount'] as num? ?? 0,
        reference: data['reference'] as String? ?? doc.id,
      );
    }).toList();
  }

  Future<List<AccountStatement>> getStatements() async {
    final firestore = _firestore;
    if (firestore == null) return SavingsMockData.statements;

    final snapshot = await firestore
        .collection('clients')
        .doc(_clientId)
        .collection('statements')
        .orderBy('createdAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) return const [];

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return AccountStatement(
        period: data['period'] as String? ?? '',
        openingBalance: data['openingBalance'] as num? ?? 0,
        closingBalance: data['closingBalance'] as num? ?? 0,
      );
    }).toList();
  }

  Future<Loan?> getActiveLoan() async {
    final firestore = _firestore;
    if (firestore == null) return null;

    final doc = await firestore
        .collection('clients')
        .doc(_clientId)
        .collection('credits')
        .doc('activeLoan')
        .get();

    final data = doc.data();
    if (data == null) return null;

    final status = data['status'] as String? ?? '';
    final isDisbursed = data['isDisbursed'] as bool? ?? true;
    final normalizedStatus = status.toLowerCase();
    final isApprovedStatus =
        normalizedStatus.contains('aprob') ||
        normalizedStatus.contains('desembols') ||
        normalizedStatus.contains('al dia') ||
        normalizedStatus.contains('al d');

    if (!isDisbursed || !isApprovedStatus) return null;

    return Loan(
      id: data['id'] as String? ?? doc.id,
      amount: data['amount'] as num? ?? 0,
      pendingBalance: data['pendingBalance'] as num? ?? 0,
      status: status.isEmpty ? 'Al dia' : status,
    );
  }

  Future<List<Installment>> getInstallments() async {
    final firestore = _firestore;
    if (firestore == null) return const [];

    final activeLoan = await getActiveLoan();
    if (activeLoan == null) return const [];

    final snapshot = await firestore
        .collection('clients')
        .doc(_clientId)
        .collection('installments')
        .orderBy('number')
        .get();

    if (snapshot.docs.isEmpty) return const [];

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Installment(
        number: data['number'] as int? ?? 0,
        dueDate: data['dueDate'] as String? ?? '',
        amount: data['amount'] as num? ?? 0,
        isPaid: data['isPaid'] as bool? ?? false,
      );
    }).toList();
  }

  Stream<List<CreditRequestStatus>> watchCreditRequestStatuses() async* {
    final firestore = _firestore;
    if (firestore == null) {
      yield const [];
      return;
    }

    await ensureClientFinancialProfile();

    yield* firestore
        .collection('clients')
        .doc(_clientId)
        .collection('creditRequests')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final rawStatus =
            data['estado_solicitud'] as String? ??
            data['estado'] as String? ??
            data['status'] as String? ??
            'Pendiente';
        final rawAmount = data['amount'];
        final updatedAt = data['updatedAt'];
        return CreditRequestStatus(
          id: data['id'] as String? ?? doc.id,
          amount: rawAmount is num ? rawAmount : 0,
          termMonths:
              data['termMonths'] as int? ??
              data['plazo_meses'] as int? ??
              0,
          purpose:
              data['purpose'] as String? ??
              data['destino_credito'] as String? ??
              'No registrado',
          status: _normalizeCreditRequestStatus(rawStatus),
          updatedAtLabel: updatedAt is Timestamp
              ? _formatDate(updatedAt.toDate())
              : 'Sin fecha',
        );
      }).toList();
    });
  }

  String _normalizeCreditRequestStatus(String status) {
    final value = status.trim().toLowerCase();
    if (value == 'aceptado' || value == 'aprobado') return 'Aceptado';
    if (value == 'negado' || value == 'rechazado') return 'Negado';
    return 'Pendiente de evaluacion';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> submitCreditRequest({
    required num amount,
    required int termMonths,
    required String purpose,
    double? latitude,
    double? longitude,
    String? locationLabel,
  }) async {
    final firestore = _firestore;
    if (amount <= 0) {
      throw const AppException('El monto debe ser mayor a cero.');
    }
    if (termMonths <= 0) {
      throw const AppException('Selecciona un plazo válido.');
    }
    if (firestore == null) {
      throw const AppException('No se pudo conectar con la base de datos.');
    }

    await ensureClientFinancialProfile();

    final clientRef = firestore.collection('clients').doc(_clientId);
    final clientDoc = await clientRef.get();
    final clientData = clientDoc.data() ?? {};
    final localClient = ClientDatabaseService.instance.currentClient;
    final currentUser = FirebaseAuthService.instance.currentUser;
    final fullName =
        clientData['fullName'] as String? ??
        currentUser?.displayName ??
        localClient?.fullName ??
        'Cliente';
    final documentNumber =
        clientData['documentNumber'] as String? ??
        localClient?.documentNumber ??
        _clientId;
    final phone = clientData['phone'] as String? ?? localClient?.phone ?? '';
    final email =
        clientData['email'] as String? ??
        currentUser?.email ??
        localClient?.email ??
        '';
    final requestRef = clientRef.collection('creditRequests').doc();
    final salesRequestRef = firestore
        .collection('sales_credit_requests')
        .doc(requestRef.id);
    final salesClientRef = firestore
        .collection('sales_clients')
        .doc(documentNumber);
    final amountLabel = 'S/ ${amount.toStringAsFixed(2)}';
    final cleanPurpose = purpose.trim();

    final batch = firestore.batch();
    batch.set(requestRef, {
      'id': requestRef.id,
      'clientId': _clientId,
      'clientName': fullName,
      'documentNumber': documentNumber,
      'email': email,
      'phone': phone,
      'amount': amount,
      'amountLabel': amountLabel,
      'termMonths': termMonths,
      'purpose': cleanPurpose,
      'latitud': latitude,
      'longitud': longitude,
      'ubicacion': locationLabel ?? (clientData['location'] as String? ?? ''),
      'status': 'Preaprobado',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(salesRequestRef, {
      'cliente': fullName,
      'monto': amountLabel,
      'amount': amount,
      'segmento': 'POR EVALUAR',
      'estado': 'Preaprobado',
      'clientId': _clientId,
      'dni': documentNumber,
      'telefono': phone,
      'correo': email,
      'plazo_meses': termMonths,
      'destino_credito': cleanPurpose,
      'latitud': latitude,
      'longitud': longitude,
      'ubicacion': locationLabel ?? (clientData['location'] as String? ?? ''),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(salesClientRef, {
      'dni': documentNumber,
      'nombres': fullName,
      'telefono': phone,
      'ubicacion': clientData['location'] as String? ?? '',
      'latitud': latitude,
      'longitud': longitude,
      'edad': clientData['age'] as int? ?? 0,
      'negocio': clientData['businessName'] as String? ?? 'Por registrar',
      'rubro': clientData['businessType'] as String? ?? 'Por evaluar',
      'antiguedad_negocio':
          clientData['businessAge'] as String? ?? 'Por registrar',
      'tenencia_local': clientData['premises'] as String? ?? 'Por evaluar',
      'calificacion_sbs': clientData['sbsRating'] as String? ?? 'Por evaluar',
      'deuda_total': clientData['totalDebt'] as String? ?? '0',
      'score_preliminar': clientData['preScore'] as int? ?? 0,
      'segmento': clientData['segment'] as String? ?? 'POR EVALUAR',
      'fecha_renovacion': 'Solicitud nueva',
      'clientId': _clientId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<List<OperationHistoryItem>> getOperations() async {
    final firestore = _firestore;
    if (firestore == null) return OperationsMockData.history;

    await ensureClientFinancialProfile();
    final snapshot = await firestore
        .collection('clients')
        .doc(_clientId)
        .collection('operations')
        .orderBy('createdAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) return const [];

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return OperationHistoryItem(
        type: data['type'] as String? ?? 'Operación',
        date: data['date'] as String? ?? '',
        amount: data['amount'] as num? ?? 0,
        status: data['status'] as String? ?? 'Exitosa',
      );
    }).toList();
  }

  Future<List<OperationHistoryItem>> getOperationHistory() async {
    final firestore = _firestore;
    if (firestore == null) return OperationsMockData.history;

    await ensureClientFinancialProfile();
    final clientRef = firestore.collection('clients').doc(_clientId);
    final operationsSnapshot = await clientRef
        .collection('operations')
        .orderBy('createdAt', descending: true)
        .get();
    final operationServiceIds = <String>{};
    final history = <_OperationHistoryRow>[];

    for (final doc in operationsSnapshot.docs) {
      final data = doc.data();
      final serviceId = data['serviceId'] as String?;
      if (serviceId != null && serviceId.isNotEmpty) {
        operationServiceIds.add(serviceId);
      }
      history.add(
        _OperationHistoryRow(
          item: OperationHistoryItem(
            type: data['type'] as String? ?? 'OperaciÃ³n',
            date: data['date'] as String? ?? '',
            amount: data['amount'] as num? ?? 0,
            status: data['status'] as String? ?? 'Exitosa',
          ),
          createdAt: data['createdAt'] as Timestamp?,
        ),
      );
    }

    final movementsSnapshot = await clientRef
        .collection('movements')
        .orderBy('createdAt', descending: true)
        .get();

    for (final doc in movementsSnapshot.docs) {
      final data = doc.data();
      final title = data['title'] as String? ?? '';
      final serviceId = data['serviceId'] as String?;
      final hasOperation =
          serviceId != null && operationServiceIds.contains(serviceId);
      if (!title.startsWith('Pago') || hasOperation) continue;
      history.add(
        _OperationHistoryRow(
          item: OperationHistoryItem(
            type: title,
            date: data['date'] as String? ?? '',
            amount: data['amount'] as num? ?? 0,
            status: data['status'] as String? ?? 'Exitosa',
          ),
          createdAt: data['createdAt'] as Timestamp?,
        ),
      );
    }

    history.sort((a, b) {
      final aDate = a.createdAt?.toDate();
      final bDate = b.createdAt?.toDate();
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return history.map((row) => row.item).toList();
  }

  List<ServiceBill> _defaultServiceBills() {
    return [
      ServiceBill(
        id: 'aqua_peru',
        type: 'Agua',
        companyName: 'AquaPerú',
        amount: 45,
        dueDate: _nextDueDate(day: 18),
        allowRepeatedPayments: true,
      ),
      ServiceBill(
        id: 'electro_andes',
        type: 'Luz',
        companyName: 'ElectroAndes',
        amount: 78,
        dueDate: _nextDueDate(day: 20),
        allowRepeatedPayments: false,
      ),
      ServiceBill(
        id: 'net_sur',
        type: 'Internet',
        companyName: 'NetSur',
        amount: 89.90,
        dueDate: _nextDueDate(day: 25),
        allowRepeatedPayments: false,
      ),
    ];
  }

  DateTime _nextDueDate({required int day}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(now.year, now.month, day);
    if (dueDate.isBefore(today)) return DateTime(now.year, now.month + 1, day);
    return dueDate;
  }

  Future<List<ServiceBill>> getServiceBills() async {
    final firestore = _firestore;
    final bills = _defaultServiceBills();
    if (firestore == null) return bills;

    final snapshot = await firestore
        .collection('clients')
        .doc(_clientId)
        .collection('serviceBills')
        .get();
    final stateById = {for (final doc in snapshot.docs) doc.id: doc.data()};

    return bills.map((bill) {
      final state = stateById[bill.id];
      final isPaid = state == null ? false : _isCurrentBillPaid(bill, state);
      return bill.copyWith(isPaid: isPaid);
    }).toList();
  }

  bool _isCurrentBillPaid(ServiceBill bill, Map<String, dynamic> state) {
    if (bill.allowRepeatedPayments) return false;

    final isPaid = state['isPaid'] as bool? ?? false;
    if (!isPaid) return false;

    final paidBillingPeriod = state['paidBillingPeriod'] as String?;
    if (paidBillingPeriod != null) {
      return paidBillingPeriod == bill.billingPeriod;
    }

    final paidDueDate = state['dueDate'] as String?;
    return paidDueDate == bill.dueDateLabel;
  }

  Future<List<ServiceNotification>> getServiceNotifications() async {
    final bills = await getServiceBills();
    return bills.where((bill) => !bill.isPaid || bill.allowRepeatedPayments).map((
      bill,
    ) {
      final title = bill.isDueSoon
          ? '${bill.type} próximo a vencer'
          : '${bill.type} pendiente de pago';
      return ServiceNotification(
        title: title,
        message:
            '${bill.companyName} vence el ${bill.dueDateLabel} por S/ ${bill.amount.toStringAsFixed(2)}.',
        iconName: bill.type,
      );
    }).toList();
  }

  Future<void> payServiceBill(ServiceBill bill) async {
    final firestore = _firestore;
    if (firestore == null) return;
    if (!bill.canPay) {
      throw AppException('${bill.companyName} ya fue pagado.');
    }

    await ensureClientFinancialProfile();

    final clientRef = firestore.collection('clients').doc(_clientId);
    final savingsRef = clientRef.collection('savings').doc('main');
    final serviceBillRef = clientRef.collection('serviceBills').doc(bill.id);
    final operationsRef = clientRef.collection('operations').doc();
    final movementsRef = clientRef.collection('movements').doc();

    await firestore.runTransaction((transaction) async {
      final clientDoc = await transaction.get(clientRef);
      final savingsDoc = await transaction.get(savingsRef);
      final serviceBillDoc = await transaction.get(serviceBillRef);
      final clientData = clientDoc.data() ?? {};
      final savingsData = savingsDoc.data() ?? {};
      final serviceBillData = serviceBillDoc.data() ?? {};
      final alreadyPaid = _isCurrentBillPaid(bill, serviceBillData);

      if (!bill.allowRepeatedPayments && alreadyPaid) {
        throw AppException('${bill.companyName} ya fue pagado.');
      }

      final availableBalance =
          savingsData['balance'] as num? ??
          clientData['savingsBalance'] as num? ??
          initialBalance;
      if (availableBalance < bill.amount) {
        throw const AppException(
          'Saldo insuficiente para realizar la operación.',
        );
      }

      final piggyBankBalance =
          savingsData['piggyBankBalance'] as num? ??
          clientData['piggyBankBalance'] as num? ??
          0;
      final newAvailableBalance = availableBalance - bill.amount;
      final newTotalBalance = newAvailableBalance + piggyBankBalance;
      final title = 'Pago ${bill.companyName}';

      transaction.set(clientRef, {
        'totalBalance': newTotalBalance,
        'savingsBalance': newAvailableBalance,
        'piggyBankBalance': piggyBankBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(savingsRef, {
        'balance': newAvailableBalance,
        'piggyBankBalance': piggyBankBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(serviceBillRef, {
        'companyName': bill.companyName,
        'type': bill.type,
        'amount': bill.amount,
        'dueDate': bill.dueDateLabel,
        'paidBillingPeriod': bill.billingPeriod,
        'isPaid': !bill.allowRepeatedPayments,
        'lastPaidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(operationsRef, {
        'type': title,
        'amount': bill.amount,
        'status': 'Exitosa',
        'date': _today,
        'createdAt': FieldValue.serverTimestamp(),
        'serviceId': bill.id,
        'serviceType': bill.type,
        'companyName': bill.companyName,
        'dueDate': bill.dueDateLabel,
      });
      transaction.set(movementsRef, {
        'title': title,
        'amount': bill.amount,
        'date': _today,
        'isIncome': false,
        'createdAt': FieldValue.serverTimestamp(),
        'serviceId': bill.id,
        'serviceType': bill.type,
        'companyName': bill.companyName,
        'dueDate': bill.dueDateLabel,
      });
    });
  }

  OperationContact _contactFromData(String id, Map<String, dynamic> data) {
    return OperationContact(
      id: id,
      fullName: data['fullName'] as String? ?? 'Cliente sin nombre',
      email: data['email'] as String? ?? '',
      documentNumber: data['documentNumber'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Future<List<OperationContact>> searchContactsByName(String query) async {
    final firestore = _firestore;
    if (firestore == null) return const [];

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.length < 2) return const [];

    final snapshot = await firestore.collection('clients').limit(50).get();
    return snapshot.docs
        .where((doc) => doc.id != _clientId)
        .map((doc) => _contactFromData(doc.id, doc.data()))
        .where(
          (contact) => contact.fullName.toLowerCase().contains(normalizedQuery),
        )
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  Future<List<OperationContact>> getQuickAccessContacts() async {
    final firestore = _firestore;
    if (firestore == null) return const [];

    final snapshot = await firestore
        .collection('clients')
        .doc(_clientId)
        .collection('quickAccess')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => _contactFromData(doc.id, doc.data()))
        .toList();
  }

  Future<void> addQuickAccessContact(OperationContact contact) async {
    final firestore = _firestore;
    if (firestore == null) return;
    if (contact.id == _clientId) {
      throw const AppException('No puedes agregarte a tus accesos rápidos.');
    }

    final contactDoc = await firestore
        .collection('clients')
        .doc(contact.id)
        .get();
    if (!contactDoc.exists) {
      throw const AppException('El contacto seleccionado no existe.');
    }

    await firestore
        .collection('clients')
        .doc(_clientId)
        .collection('quickAccess')
        .doc(contact.id)
        .set({
          'fullName': contact.fullName,
          'email': contact.email,
          'documentNumber': contact.documentNumber,
          'photoUrl': contact.photoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> removeQuickAccessContact(String contactId) async {
    final firestore = _firestore;
    if (firestore == null) return;

    await firestore
        .collection('clients')
        .doc(_clientId)
        .collection('quickAccess')
        .doc(contactId)
        .delete();
  }

  Future<OperationContact> getContactById(String contactId) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw const AppException('No se pudo validar el contacto.');
    }

    final doc = await firestore.collection('clients').doc(contactId).get();
    final data = doc.data();
    if (!doc.exists || data == null || contactId == _clientId) {
      throw const AppException('El contacto seleccionado no existe.');
    }
    return _contactFromData(doc.id, data);
  }

  Future<void> recordContactTransfer({
    required OperationContact contact,
    required num amount,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;
    if (amount <= 0) {
      throw const AppException('El monto debe ser mayor a cero.');
    }
    if (contact.id == _clientId) {
      throw const AppException('No puedes transferirte a tu propia cuenta.');
    }

    await ensureClientFinancialProfile();

    final senderRef = firestore.collection('clients').doc(_clientId);
    final recipientRef = firestore.collection('clients').doc(contact.id);
    final senderSavingsRef = senderRef.collection('savings').doc('main');
    final recipientSavingsRef = recipientRef.collection('savings').doc('main');
    final senderOperationRef = senderRef.collection('operations').doc();
    final senderMovementRef = senderRef.collection('movements').doc();
    final recipientMovementRef = recipientRef.collection('movements').doc();

    final senderDoc = await senderRef.get().timeout(
      const Duration(seconds: 10),
    );
    final recipientDoc = await recipientRef.get().timeout(
      const Duration(seconds: 10),
    );

    final senderData = senderDoc.data() ?? {};
    final recipientData = recipientDoc.data();
    if (!recipientDoc.exists || recipientData == null) {
      throw const AppException('El contacto seleccionado no existe.');
    }

    final currentBalance =
        senderData['savingsBalance'] as num? ??
        senderData['totalBalance'] as num? ??
        initialBalance;
    if (currentBalance < amount) {
      throw const AppException(
        'Saldo insuficiente para realizar la operación.',
      );
    }

    final recipientBalance =
        recipientData['totalBalance'] as num? ?? initialBalance;
    final recipientSavingsBalance =
        recipientData['savingsBalance'] as num? ?? recipientBalance;
    final newSenderBalance = currentBalance - amount;
    final newRecipientBalance = recipientBalance + amount;
    final newRecipientSavingsBalance = recipientSavingsBalance + amount;
    final batch = firestore.batch();

    batch.update(senderRef, {
      'totalBalance': newSenderBalance,
      'savingsBalance': newSenderBalance,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(senderSavingsRef, {
      'balance': newSenderBalance,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(recipientRef, {
      'totalBalance': newRecipientBalance,
      'savingsBalance': newRecipientSavingsBalance,
      'activeLoansBalance': recipientData['activeLoansBalance'] as num? ?? 0,
      'financialProfileSeeded': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(recipientSavingsRef, {
      'balance': newRecipientSavingsBalance,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(senderOperationRef, {
      'type': 'Transferencia',
      'amount': amount,
      'status': 'Exitosa',
      'date': _today,
      'createdAt': FieldValue.serverTimestamp(),
      'recipientId': contact.id,
      'recipientName': contact.fullName,
    });
    batch.set(senderMovementRef, {
      'title': 'Transferencia a ${contact.fullName}',
      'amount': amount,
      'date': _today,
      'isIncome': false,
      'createdAt': FieldValue.serverTimestamp(),
      'recipientId': contact.id,
      'recipientName': contact.fullName,
    });
    batch.set(recipientMovementRef, {
      'title': 'Depósito de usuario',
      'amount': amount,
      'date': _today,
      'isIncome': true,
      'createdAt': FieldValue.serverTimestamp(),
      'senderId': _clientId,
    });
    await batch.commit().timeout(const Duration(seconds: 12));
  }

  Future<void> recordOperation({
    required String type,
    required num amount,
    required Map<String, Object?> detail,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;
    if (amount <= 0) {
      throw const AppException('El monto debe ser mayor a cero.');
    }

    await ensureClientFinancialProfile();

    final clientRef = firestore.collection('clients').doc(_clientId);
    final savingsRef = clientRef.collection('savings').doc('main');
    final operationsRef = clientRef.collection('operations').doc();
    final movementsRef = clientRef.collection('movements').doc();

    await firestore.runTransaction((transaction) async {
      final clientDoc = await transaction.get(clientRef);
      final data = clientDoc.data() ?? {};
      final currentBalance =
          data['savingsBalance'] as num? ??
          data['totalBalance'] as num? ??
          initialBalance;
      if (currentBalance < amount) {
        throw const AppException(
          'Saldo insuficiente para realizar la operación.',
        );
      }

      final newBalance = currentBalance - amount;
      transaction.update(clientRef, {
        'totalBalance': newBalance,
        'savingsBalance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(savingsRef, {
        'balance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(operationsRef, {
        'type': type,
        'amount': amount,
        'status': 'Exitosa',
        'date': _today,
        'createdAt': FieldValue.serverTimestamp(),
        ...detail,
      });
      transaction.set(movementsRef, {
        'title': type,
        'amount': amount,
        'date': _today,
        'isIncome': false,
        'createdAt': FieldValue.serverTimestamp(),
        ...detail,
      });
    });
  }
}

enum _PiggyBankDirection { deposit, withdraw }
