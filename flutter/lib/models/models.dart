class Trip {
  final String id;
  final String name;
  final String description;
  final String currency;
  final String emoji;

  Trip({required this.id, required this.name, required this.description, required this.currency, this.emoji = ''});

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'],
        name: j['name'],
        description: j['description'] ?? '',
        currency: j['currency'] ?? 'USD',
        emoji: j['emoji'] ?? '',
      );
}

class Member {
  final String id;
  final String tripId;
  final String name;
  final String email;

  Member({required this.id, required this.tripId, required this.name, required this.email});

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: j['id'],
        tripId: j['trip_id'],
        name: j['name'],
        email: j['email'] ?? '',
      );
}

class Expense {
  final String id;
  final String description;
  final double amount;
  final String category;
  final String notes;
  final String paidById;
  final DateTime date;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    this.notes = '',
    required this.paidById,
    required this.date,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'],
        description: j['description'],
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] ?? 'other',
        notes: j['notes'] ?? '',
        paidById: j['paid_by_id'],
        date: DateTime.parse(j['date']),
      );
}

class Balance {
  final Member member;
  final double totalPaid;
  final double totalOwed;
  final double netBalance;

  Balance({required this.member, required this.totalPaid, required this.totalOwed, required this.netBalance});

  factory Balance.fromJson(Map<String, dynamic> j) => Balance(
        member: Member.fromJson(j['member']),
        totalPaid: (j['total_paid'] as num).toDouble(),
        totalOwed: (j['total_owed'] as num).toDouble(),
        netBalance: (j['net_balance'] as num).toDouble(),
      );
}

class Settlement {
  final Member from;
  final Member to;
  final double amount;

  Settlement({required this.from, required this.to, required this.amount});

  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
        from: Member.fromJson(j['from']),
        to: Member.fromJson(j['to']),
        amount: (j['amount'] as num).toDouble(),
      );
}
