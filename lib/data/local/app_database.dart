import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/transaction_model.dart' as model;

part 'app_database.g.dart';

@DataClassName('LocalTransaction')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get type => text().map(const TransactionTypeConverter())();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get syncedWithFirebase => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PendingDeletion')
class PendingDeletions extends Table {
  TextColumn get transactionId => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {transactionId};
}

class TransactionTypeConverter extends TypeConverter<model.TransactionType, String> {
  const TransactionTypeConverter();

  @override
  model.TransactionType fromSql(String fromDb) {
    return model.TransactionType.values.firstWhere((value) => value.name == fromDb);
  }

  @override
  String toSql(model.TransactionType value) => value.name;
}

@DriftDatabase(tables: [Transactions, PendingDeletions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'money_app',
      native: DriftNativeOptions(
        databaseDirectory: () async {
          final directory = await getApplicationSupportDirectory();
          final databaseDirectory = Directory(p.join(directory.path, 'db'));
          if (!await databaseDirectory.exists()) {
            await databaseDirectory.create(recursive: true);
          }
          return databaseDirectory;
        },
      ),
    );
  }
}