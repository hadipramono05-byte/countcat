import 'package:flutter_test/flutter_test.dart';
import 'package:tiktok_seller/core/currency/rupiah.dart';
import 'package:tiktok_seller/data/database/app_database.dart';
import 'package:tiktok_seller/data/models/statuses.dart';
import 'package:tiktok_seller/data/models/transaction.dart';
import 'package:tiktok_seller/data/repositories/live_session_repository.dart';
import 'package:tiktok_seller/data/repositories/settings_repository.dart';
import 'package:tiktok_seller/data/repositories/transaction_repository.dart';
import 'package:tiktok_seller/features/sales/transaction_validator.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository settings;
  late LiveSessionRepository sessions;
  late TransactionRepository transactions;

  setUp(() { database = AppDatabase.inMemoryForTesting(); settings = SettingsRepository(database); sessions = LiveSessionRepository(database); transactions = TransactionRepository(database); });
  tearDown(() => database.close());

  test('parses Rupiah input', () { expect(Rupiah.parse('5000'), 5000); expect(Rupiah.parse('5.000'), 5000); expect(Rupiah.parse('Rp5.000'), 5000); });
  test('formats Rupiah', () { expect(Rupiah.format(5000), 'Rp5.000'); expect(Rupiah.format(12500), 'Rp12.500'); expect(Rupiah.format(100000), 'Rp100.000'); });
  test('saves and reads global HPP', () async { await settings.setGlobalHpp(5000); expect(await settings.getGlobalHpp(), 5000); });
  test('creates and lists sessions newest first', () async { await sessions.createSession(name: 'Live #1'); await sessions.createSession(name: 'Live #2'); final items = await sessions.listSessions(); expect(items.map((item) => item.name), ['Live #2', 'Live #1']); });
  test('new session becomes selected', () async { final session = await sessions.createSession(name: 'Live Malam'); expect(await sessions.getSelectedSessionId(), session.id); expect((await sessions.getSelectedSession())?.name, 'Live Malam'); });
  test('selects a session', () async { final first = await sessions.createSession(name: 'Live #1'); final second = await sessions.createSession(name: 'Live #2'); await sessions.setSelectedSessionId(first.id); expect(await sessions.getSelectedSessionId(), first.id); expect(second.id, isNot(first.id)); });
  test('creates a transaction', () async { final id = await transactions.insertTransaction(_transaction()); expect(id, 1); });
  test('rejects duplicate order ID', () async { await transactions.insertTransaction(_transaction()); await expectLater(transactions.insertTransaction(_transaction()), throwsA(isA<DuplicateOrderIdException>())); });
  test('validates required transaction values', () { expect(TransactionValidator.productCode(''), isNotNull); expect(TransactionValidator.orderId(''), isNotNull); expect(TransactionValidator.quantity('0'), isNotNull); expect(TransactionValidator.quantity('1'), isNull); });
  test('paid requires paidAt', () { expect(TransactionValidator.paidAt(PaymentStatus.paid, null), isNotNull); });
  test('paid accepts valid paidAt', () { expect(TransactionValidator.paidAt(PaymentStatus.paid, DateTime(2026, 9, 26)), isNull); });
  test('pending and cancelled accept null paidAt', () { expect(TransactionValidator.paidAt(PaymentStatus.pending, null), isNull); expect(TransactionValidator.paidAt(PaymentStatus.cancelled, null), isNull); });
  test('normalizes paidAt', () { final date = DateTime(2026, 9, 26, 7); expect(TransactionValidator.normalizePaidAt(PaymentStatus.paid, date), date.toUtc()); expect(TransactionValidator.normalizePaidAt(PaymentStatus.pending, date), isNull); expect(TransactionValidator.normalizePaidAt(PaymentStatus.cancelled, date), isNull); });
  test('cancelled payment status maps to DIBATALKAN', () { expect(PaymentStatus.cancelled.label, 'DIBATALKAN'); });
  test('order statuses do not include DIBATALKAN', () { expect(OrderStatus.values.map((status) => status.label), isNot(contains('DIBATALKAN'))); });
  test('cancelled transaction preserves financial amounts', () async { final now = DateTime.now(); final transaction = Transaction(productCode: 'SKU-C', orderId: 'ORDER-C', quantity: 1, gmvAmount: 22000, paymentStatus: PaymentStatus.cancelled, netIncomeAmount: 20000, orderStatus: OrderStatus.shipping, createdAt: now, updatedAt: now); await transactions.insertTransaction(transaction); final row = (await (await database.database).query('transactions', where: 'order_id = ?', whereArgs: ['ORDER-C'])).single; expect(row['gmv_amount'], 22000); expect(row['net_income_amount'], 20000); expect(row['paid_at'], isNull); });
  test('payment and order statuses remain independent', () async { final now = DateTime.now(); final combinations = [(PaymentStatus.paid, OrderStatus.newOrder), (PaymentStatus.paid, OrderStatus.dropoff), (PaymentStatus.paid, OrderStatus.shipping), (PaymentStatus.paid, OrderStatus.returned), (PaymentStatus.cancelled, OrderStatus.newOrder), (PaymentStatus.cancelled, OrderStatus.shipping), (PaymentStatus.cancelled, OrderStatus.returned)]; for (var index = 0; index < combinations.length; index++) { final combination = combinations[index]; await transactions.insertTransaction(Transaction(productCode: 'SKU-$index', orderId: 'COMBO-$index', quantity: 1, gmvAmount: 10000, paymentStatus: combination.$1, paidAt: combination.$1 == PaymentStatus.paid ? now : null, netIncomeAmount: 9000, orderStatus: combination.$2, createdAt: now, updatedAt: now)); } expect((await (await database.database).query('transactions')).length, combinations.length); });
}

Transaction _transaction() { final now = DateTime.now(); return Transaction(productCode: 'SKU-1', orderId: 'ORDER-1', quantity: 1, gmvAmount: 12000, paymentStatus: PaymentStatus.pending, netIncomeAmount: 10000, orderStatus: OrderStatus.newOrder, createdAt: now, updatedAt: now); }
