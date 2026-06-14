class CreditRequest {
  const CreditRequest({
    required this.id,
    required this.client,
    required this.amount,
    required this.segment,
    required this.status,
    required this.clientId,
    required this.amountValue,
    required this.termMonths,
    required this.purpose,
    required this.score,
    required this.riskLevel,
    required this.recommendation,
  });

  final String id;
  final String client;
  final String amount;
  final String segment;
  final String status;
  final String clientId;
  final num amountValue;
  final int termMonths;
  final String purpose;
  final int score;
  final String riskLevel;
  final String recommendation;

  factory CreditRequest.fromJson(Map<String, Object?> json, {String id = ''}) {
    final rawAmount = json['monto'] ?? json['amountLabel'] ?? json['amount'];
    final amountValue = json['amount'] is num
        ? json['amount'] as num
        : _parseAmount(rawAmount as String? ?? '');
    return CreditRequest(
      id: id,
      client: json['cliente'] as String? ?? '',
      amount: rawAmount is num
          ? 'S/ ${rawAmount.toStringAsFixed(2)}'
          : rawAmount as String? ?? '',
      segment: json['segmento'] as String? ?? '',
      status: json['estado'] as String? ?? json['status'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      amountValue: amountValue,
      termMonths:
          json['plazo_meses'] as int? ?? json['termMonths'] as int? ?? 12,
      purpose:
          json['destino_credito'] as String? ??
          json['purpose'] as String? ??
          '',
      score: (json['score'] as num?)?.round() ?? 0,
      riskLevel: json['nivel_riesgo'] as String? ?? '',
      recommendation: json['recomendacion_scoring'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'cliente': client,
      'monto': amount,
      'amount': amountValue,
      'segmento': segment,
      'estado': status,
      'clientId': clientId,
      'plazo_meses': termMonths,
      'destino_credito': purpose,
      'score': score,
      'nivel_riesgo': riskLevel,
      'recomendacion_scoring': recommendation,
    };
  }

  static num _parseAmount(String value) {
    final cleaned = value
        .replaceAll('S/', '')
        .replaceAll(' ', '')
        .replaceAll(',', '')
        .trim();
    return num.tryParse(cleaned) ?? 0;
  }
}
