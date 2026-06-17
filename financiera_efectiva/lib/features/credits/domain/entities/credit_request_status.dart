class CreditRequestStatus {
  const CreditRequestStatus({
    required this.id,
    required this.amount,
    required this.termMonths,
    required this.purpose,
    required this.status,
    required this.updatedAtLabel,
  });

  final String id;
  final num amount;
  final int termMonths;
  final String purpose;
  final String status;
  final String updatedAtLabel;
}
