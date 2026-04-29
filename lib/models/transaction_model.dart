class Transaction {
  final String id;
  final String title;
  final double amount;
  final TransactionType type; // 'income' or 'expense'
  final DateTime date;
  final String? category;
  final String? description;
  final bool syncedWithFirebase;
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.category,
    this.description,
    this.syncedWithFirebase = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert Transaction to Map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'date': date.toIso8601String(),
      'category': category,
      'description': description,
      'syncedWithFirebase': syncedWithFirebase ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create Transaction from SQLite Map
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: map['amount'] as double,
      type: TransactionType.values.firstWhere((e) => e.name == map['type']),
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String?,
      description: map['description'] as String?,
      syncedWithFirebase: (map['syncedWithFirebase'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// Convert Transaction to Map for Firebase
  Map<String, dynamic> toFirebaseMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'date': date.toIso8601String(),
      'category': category,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create Transaction from Firebase Map
  factory Transaction.fromFirebaseMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere((e) => e.name == map['type']),
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String?,
      description: map['description'] as String?,
      syncedWithFirebase: true,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// Create a copy of Transaction with updated fields
  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    DateTime? date,
    String? category,
    String? description,
    bool? syncedWithFirebase,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      syncedWithFirebase: syncedWithFirebase ?? this.syncedWithFirebase,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum TransactionType { income, expense }
