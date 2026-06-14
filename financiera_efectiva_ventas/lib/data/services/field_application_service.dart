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

  Future<String> submitToCommittee(Map<String, Object?> payload) async {
    final localId = payload['localId'] as String;
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
      return expedientNumber;
    }

    try {
      final batch = firestore.batch();
      final requestRef = firestore.collection(requestsCollection).doc(localId);
      batch.set(requestRef, submittedPayload, SetOptions(merge: true));
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
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
      return expedientNumber;
    } catch (_) {
      await saveDraft({
        ...payload,
        'localStatus': 'pendiente_envio',
        'syncStatus': 'pending',
      });
      return expedientNumber;
    }
  }
}
