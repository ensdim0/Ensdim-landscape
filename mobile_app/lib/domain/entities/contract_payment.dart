class ContractPayment {
  final String id;
  final String contractId;
  final double amount;
  final String paymentMethod;
  final String paymentDate;
  final String? transferImageUrl;
  final String? notes;
  final String createdAt;
  final String? dueDate;
  final String? paymentGatewayUrl;
  final String? paymentGatewayOrderId;
  final String? gatewayStatus;
  final double? gatewayFeeAmount;
  final String? receiptUrl;
  final String? gatewayPaymentMethod;
  final Map<String, dynamic>? receiptData;

  const ContractPayment({
    required this.id,
    required this.contractId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    this.transferImageUrl,
    this.notes,
    required this.createdAt,
    this.dueDate,
    this.paymentGatewayUrl,
    this.paymentGatewayOrderId,
    this.gatewayStatus,
    this.gatewayFeeAmount,
    this.receiptUrl,
    this.gatewayPaymentMethod,
    this.receiptData,
  });

  bool get isTransfer => paymentMethod == 'transfer';
  bool get isCash => paymentMethod == 'cash';
  bool get isCheque => paymentMethod == 'cheque';
  bool get isCard => paymentMethod == 'card';
  bool get isPendingGateway => gatewayStatus == 'pending';
  bool get isPaidViaGateway => gatewayStatus == 'paid';
  bool get isScheduledNotSent => gatewayStatus == null && dueDate != null;

  /// تجاوز تاريخ الاستحقاق ولم تُدفع بعد
  bool get isLate {
    if (dueDate == null || gatewayStatus == 'paid') return false;
    final due = DateTime.tryParse(dueDate!);
    if (due == null) return false;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    return due.isBefore(todayDateOnly);
  }
}
