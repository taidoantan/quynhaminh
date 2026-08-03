class MoneyTransaction {
  final String id, type, category, note, merchant;
  final double amount;
  final DateTime date;
  MoneyTransaction(
      {required this.id,
      required this.type,
      required this.category,
      required this.amount,
      required this.date,
      this.note = '',
      this.merchant = ''});
  factory MoneyTransaction.fromJson(Map<String, dynamic> j) => MoneyTransaction(
      id: j['id'],
      type: j['type'],
      category: j['category'],
      amount: (j['amount'] as num).toDouble(),
      date: DateTime.parse(j['date']),
      note: j['note'] ?? '',
      merchant: j['merchant'] ?? '');
}
