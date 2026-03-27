import '../../domain/model/transaction_model.dart';
import '../local/dao/transaction_dao.dart';
import '../local/entity/transaction_entity.dart';

class TransactionRepository {
  final TransactionDao _dao = TransactionDao();

  Future<void> addTransaction(TransactionModel model) async {
    final entity = TransactionEntity(
      id: model.id,
      amount: model.amount,
      type: model.type,
      categoryId: model.categoryId,
      walletId: model.walletId,
      date: model.date.toIso8601String(),
      note: model.note,
      person: model.person,
    );
    await _dao.insert(entity);
  }

  Future<List<TransactionModel>> getTransactions() async {
    final entities = await _dao.getAll();
    return entities.map((entity) => TransactionModel(
      id: entity.id,
      amount: entity.amount,
      type: entity.type,
      categoryId: entity.categoryId,
      walletId: entity.walletId,
      date: DateTime.parse(entity.date),
      note: entity.note,
      person: entity.person,
    )).toList();
  }


  Future<void> deleteTransaction(String id) async {
    await _dao.delete(id);
  }
}