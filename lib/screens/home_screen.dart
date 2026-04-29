import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../utils/utils.dart' as app_utils;
import '../widgets/transaction_widgets.dart';
import 'add_transaction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Money App'), elevation: 0),
      body: Consumer<TransactionProvider>(
        builder: (context, transactionProvider, _) {
          if (transactionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (transactionProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${transactionProvider.errorMessage}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      transactionProvider.clearError();
                      transactionProvider.loadTransactions();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => transactionProvider.pullFromRemote(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  if (transactionProvider.hasPendingChanges)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            color: Colors.amber.shade900,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Hay cambios pendientes de sincronizar con Firebase',
                              style: TextStyle(color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Summary Cards
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        FutureBuilder<double>(
                          future: transactionProvider.getTotalBalance(),
                          builder: (context, snapshot) {
                            final balance = snapshot.data ?? 0.0;
                            return SummaryCard(
                              title: 'Total Balance',
                              amount: balance,
                              color: balance >= 0 ? Colors.green : Colors.red,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<Map<String, double>>(
                          future: transactionProvider.getTotals(
                            app_utils.DateUtils.getFirstDayOfMonth(
                              DateTime.now(),
                            ),
                            app_utils.DateUtils.getLastDayOfMonth(
                              DateTime.now(),
                            ),
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final totals = snapshot.data!;
                            return Row(
                              children: [
                                Expanded(
                                  child: SummaryCard(
                                    title: 'Income',
                                    amount: totals['income'] ?? 0,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SummaryCard(
                                    title: 'Expense',
                                    amount: totals['expense'] ?? 0,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Transactions List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  if (transactionProvider.transactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _navigateToAddTransaction(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Transaction'),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactionProvider.transactions.length,
                      itemBuilder: (context, index) {
                        final transaction =
                            transactionProvider.transactions[index];
                        return TransactionCard(
                          transaction: transaction,
                          onTap: () =>
                              _navigateToEditTransaction(context, transaction),
                          onDelete: () =>
                              _showDeleteConfirmation(context, transaction.id),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddTransaction(context),
        tooltip: 'Add Transaction',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToAddTransaction(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
  }

  void _navigateToEditTransaction(
    BuildContext context,
    Transaction transaction,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(transaction: transaction),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String transactionId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Transaction?'),
          content: const Text(
            'Are you sure you want to delete this transaction? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<TransactionProvider>().deleteTransaction(
                  transactionId,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted')),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
