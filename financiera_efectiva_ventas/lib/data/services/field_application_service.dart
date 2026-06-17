import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FieldApplicationService {
  const FieldApplicationService();

  static const _draftKey = 'field_credit_application_draft';
  static const draftsCollection = 'sales_application_drafts';
  static const requestsCollection = 'sales_credit_requests';
  static const documentsCollection = 'sales_request_documents';
  static const bureauCollection = 'sales_bureau_checks';
  static const progressCollection = 'sales_submission_progress';

  FirebaseFirestore? get _firestore {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  Future<void> saveDraft(Map<String, Object?> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      ...payload,
      'localStatus': 'borrador',
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_draftKey, jsonEncode(draft));

    final firestore = _firestore;
    if (firestore == null) return;

    try {
      await firestore
          .collection(draftsCollection)
          .doc(payload['localId'] as String?)
          .set({...draft, 'syncStatus': 'synced'}, SetOptions(merge: true));
    } catch (_) {
      await prefs.setString(
        _draftKey,
        jsonEncode({...draft, 'syncStatus': 'pending'}),
      );
    }
  }

  Future<Map<String, Object?>?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }

  Future<void> syncPendingDraft() async {
    final draft = await loadDraft();
    if (draft == null || draft['localStatus'] != 'pendiente_envio') return;
    final firestore = _firestore;
    if (firestore == null) return;

    try {
      await _writeSubmission(firestore, draft);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {
      // Se reintentara de forma transparente en el proximo arranque/guardado.
    }
  }

  Future<FieldSaveResult> submitToCommittee(Map<String, Object?> payload) async {
    final expedientNumber = 'EXP-${DateTime.now().millisecondsSinceEpoch}';
    final submittedPayload = {
      ...payload,
      'expedientNumber': expedientNumber,
      'estado': payload['estado'] ?? payload['status'] ?? 'En comite',
      'status': payload['status'] ?? payload['estado'] ?? 'En comite',
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final firestore = _firestore;
    if (firestore == null) {
      await saveDraft({
        ...payload,
        'localStatus': 'pendiente_envio',
        'syncStatus': 'pending',
      });
      return FieldSaveResult.local(
        expedientNumber,
        'Firebase no esta inicializado en esta ejecucion.',
      );
    }

    try {
      await _writeSubmission(firestore, submittedPayload);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
      return FieldSaveResult.synced(expedientNumber);
    } catch (error) {
      await saveDraft({
        ...payload,
        'localStatus': 'pendiente_envio',
        'syncStatus': 'pending',
      });
      return FieldSaveResult.local(expedientNumber, error.toString());
    }
  }

  Future<void> _writeSubmission(
    FirebaseFirestore firestore,
    Map<String, Object?> payload,
  ) async {
    final localId = payload['localId'] as String;
    final batch = firestore.batch();
    final requestRef = firestore.collection(requestsCollection).doc(localId);
    batch.set(requestRef, {
      ...payload,
      'syncStatus': 'synced',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final clientId = payload['clientId'] as String? ?? '';
    final dni = payload['dni'] as String? ?? '';
    if (clientId.isNotEmpty && clientId != localId) {
      batch.set(
        firestore
            .collection('clients')
            .doc(clientId)
            .collection('creditRequests')
            .doc(localId),
        {
          ...payload,
          'syncStatus': 'synced',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    final salesClientId = dni.isNotEmpty ? dni : clientId;
    if (salesClientId.isNotEmpty) {
      batch.set(
        firestore.collection('sales_clients').doc(salesClientId),
        {
          'clientId': clientId,
          'requestId': localId,
          'dni': dni,
          'nombres': payload['cliente'],
          'telefono': payload['phone'],
          'ubicacion': payload['businessAddress'],
          'negocio': payload['businessName'],
          'rubro': payload['businessType'],
          'ingresos_mensuales': payload['monthlyIncome'],
          'gastos_mensuales': payload['monthlyExpenses'],
          'estado_cliente': payload['estado_cliente'],
          'estado_solicitud': payload['estado_solicitud'],
          'fieldVisitCompleted': payload['fieldVisitCompleted'],
          'solicitud_completada': payload['solicitud_completada'],
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    batch.set(
      firestore.collection(draftsCollection).doc(localId),
      {
        ...payload,
        'localStatus': 'enviado',
        'syncStatus': 'synced',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      firestore.collection(bureauCollection).doc(localId),
      {
        'requestId': localId,
        'dni': payload['dni'],
        'rating': payload['bureauRating'],
        'result': payload['bureauResult'],
        'recommendation': payload['bureauRecommendation'],
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      firestore.collection(progressCollection).doc(localId),
      {
        'requestId': localId,
        'lastCompletedStep': 'Solicitud enviada',
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final documents = payload['documents'];
    if (documents is List) {
      for (final item in documents) {
        if (item is! Map) continue;
        final documentType = item['type'] as String? ?? 'documento';
        batch.set(
          firestore
              .collection(documentsCollection)
              .doc('${localId}_$documentType'),
          {
            'requestId': localId,
            'documentType': documentType,
            'required': item['required'] as bool? ?? false,
            'status': item['status'] as String? ?? 'PENDIENTE',
            'storageUrl': item['storageUrl'] as String? ?? '',
            'localPath': item['localPath'] as String? ?? '',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();
  }
}

class FieldSaveResult {
  const FieldSaveResult({
    required this.expedientNumber,
    required this.synced,
    this.errorMessage = '',
  });

  factory FieldSaveResult.synced(String expedientNumber) {
    return FieldSaveResult(expedientNumber: expedientNumber, synced: true);
  }

  factory FieldSaveResult.local(String expedientNumber, String errorMessage) {
    return FieldSaveResult(
      expedientNumber: expedientNumber,
      synced: false,
      errorMessage: errorMessage,
    );
  }

  final String expedientNumber;
  final bool synced;
  final String errorMessage;
}
