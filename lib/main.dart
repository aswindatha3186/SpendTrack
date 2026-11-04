import 'package:flutter/material.dart';

import 'budgets/monthly_budget_screen.dart';
import 'insights/advanced_insights_dashboard.dart';
import 'models/app_notification.dart';
import 'models/monthly_budget.dart';
import 'models/recurring_transaction.dart';
import 'models/transaction.dart';
import 'notifications/budget_notification_generator.dart';
import 'notifications/notifications_screen.dart';
import 'recurring/recurring_transaction_processor.dart';
import 'recurring/recurring_transactions_screen.dart';
import 'services/budget_storage.dart';
import 'services/notification_storage.dart';
import 'services/recurring_transaction_storage.dart';
import 'services/transaction_storage.dart';
import 'theme/app_colors.dart';
import 'transactions/transaction_filter.dart';

void main() {
  runApp(const SpendTrackApp());
}

class SpendTrackApp extends StatelessWidget {
  const SpendTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SpendTrack',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        fontFamily: 'Roboto',
      ),
      home: const SpendTrackHome(),
    );
  }
}

class SpendTrackHome extends StatefulWidget {
  const SpendTrackHome({super.key});

  @override
  State<SpendTrackHome> createState() => _SpendTrackHomeState();
}

class _SpendTrackHomeState extends State<SpendTrackHome>
    with WidgetsBindingObserver {
  int selectedIndex = 0;
  final TransactionStorage _transactionStorage = TransactionStorage();
  final BudgetStorage _budgetStorage = BudgetStorage();
  final NotificationStorage _notificationStorage = NotificationStorage();
  final RecurringTransactionStorage _recurringTransactionStorage =
      RecurringTransactionStorage();
  List<Transaction> transactions = [];
  List<MonthlyBudget> budgets = [];
  List<RecurringTransaction> recurringTransactions = [];
  List<AppNotification> notifications = [];
  bool _budgetAlertsEnabled = true;
  bool _isLoading = true;
  bool _isSavingTransaction = false;
  bool _isSavingBudget = false;
  bool _isSavingRecurring = false;
  bool _isProcessingRecurring = false;
  String? _loadError;
  final TextEditingController _transactionSearchController =
      TextEditingController();
  bool? _transactionTypeFilter;
  String? _transactionCategoryFilter;
  DateTime? _transactionStartDateFilter;
  DateTime? _transactionEndDateFilter;
  double? _transactionMinimumAmount;
  double? _transactionMaximumAmount;
  TransactionSortOrder _transactionSortOrder = TransactionSortOrder.newest;

  int get _unreadNotificationCount =>
      notifications.where((item) => !item.isRead).length;

  List<Transaction> _sampleTransactions() => [
    Transaction(
      title: 'Grocery Shopping',
      category: 'Food',
      amount: 850,
      date: DateTime.now(),
      isIncome: false,
    ),
    Transaction(
      title: 'Monthly Allowance',
      category: 'Income',
      amount: 5000,
      date: DateTime.now(),
      isIncome: true,
    ),
    Transaction(
      title: 'College Transport',
      category: 'Travel',
      amount: 450,
      date: DateTime.now(),
      isIncome: false,
    ),
    Transaction(
      title: 'Coffee',
      category: 'Food',
      amount: 120,
      date: DateTime.now(),
      isIncome: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTransactions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transactionSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isLoading) {
      _processDueRecurringTransactions();
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final savedTransactions = await _transactionStorage.loadTransactions();
      final savedBudgets = await _budgetStorage.loadBudgets();
      final savedRecurring = await _recurringTransactionStorage
          .loadRecurringTransactions();
      final savedNotifications = await _notificationStorage.loadNotifications();
      final budgetAlertsEnabled = await _notificationStorage
          .loadBudgetAlertsEnabled();
      final loadedTransactions = savedTransactions ?? _sampleTransactions();
      if (savedTransactions == null) {
        await _transactionStorage.saveTransactions(loadedTransactions);
      }
      if (!mounted) return;
      setState(() {
        transactions = loadedTransactions;
        budgets = savedBudgets;
        recurringTransactions = savedRecurring;
        notifications = savedNotifications;
        _budgetAlertsEnabled = budgetAlertsEnabled;
        _isLoading = false;
      });
      await _processDueRecurringTransactions();
      await _syncBudgetAlerts();
    } catch (error, stackTrace) {
      debugPrint('Failed to load transactions: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load saved local data.';
      });
    }
  }

  double get totalIncome =>
      transactions.where((t) => t.isIncome).fold(0, (sum, t) => sum + t.amount);

  double get totalExpense => transactions
      .where((t) => !t.isIncome)
      .fold(0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  String money(double amount) => '₹${amount.toStringAsFixed(2)}';

  void showAddTransaction() {
    _showTransactionForm();
  }

  Future<void> _openMonthlyBudgets() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => MonthlyBudgetScreen(
          initialBudgets: budgets,
          transactions: transactions,
          onSaveBudgets: _persistBudgets,
        ),
      ),
    );
  }

  Future<void> _openRecurringTransactions() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => RecurringTransactionsScreen(
          initialRules: recurringTransactions,
          onSave: _persistRecurringTransactions,
        ),
      ),
    );
  }

  Future<List<RecurringTransaction>?> _persistRecurringTransactions(
    List<RecurringTransaction> updatedRules,
  ) async {
    if (_isSavingRecurring) return null;
    setState(() => _isSavingRecurring = true);
    try {
      await _recurringTransactionStorage.saveRecurringTransactions(
        updatedRules,
      );
      if (!mounted) return null;
      setState(() {
        recurringTransactions = updatedRules;
        _isSavingRecurring = false;
      });
      await _processDueRecurringTransactions();
      return recurringTransactions;
    } catch (error, stackTrace) {
      debugPrint('Failed to save recurring transactions: $error\n$stackTrace');
      if (mounted) setState(() => _isSavingRecurring = false);
      return null;
    }
  }

  Future<void> _processDueRecurringTransactions() async {
    if (_isProcessingRecurring || recurringTransactions.isEmpty) return;
    _isProcessingRecurring = true;
    try {
      final result = RecurringTransactionProcessor.processDue(
        recurringTransactions: recurringTransactions,
        existingTransactions: transactions,
        throughDate: DateTime.now(),
      );
      final newestFirst = [...result.transactions]
        ..sort((first, second) => second.date.compareTo(first.date));
      final updatedTransactions = [...newestFirst, ...transactions];
      if (result.transactions.isNotEmpty) {
        await _transactionStorage.saveTransactions(updatedTransactions);
        if (mounted) {
          setState(() => transactions = updatedTransactions);
        }
      }

      if (result.processedTransactions.isNotEmpty) {
        final processedAt = DateTime.now();
        await _notificationStorage.addIfAbsent(
          result.processedTransactions.map(
            (transaction) => AppNotification(
              id: 'recurring-processed:${transaction.id}',
              deduplicationKey: 'recurring-processed:${transaction.id}',
              title: 'Recurring transaction processed',
              message:
                  '"${transaction.title}" · ${transaction.isIncome ? 'Income' : 'Expense'} '
                  'of ${money(transaction.amount)} was added for '
                  '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}.',
              createdAt: processedAt,
            ),
          ),
        );
        final savedNotifications = await _notificationStorage
            .loadNotifications();
        if (mounted) setState(() => notifications = savedNotifications);
      }

      await _recurringTransactionStorage.saveRecurringTransactions(
        result.recurringTransactions,
      );
      if (mounted) {
        setState(() => recurringTransactions = result.recurringTransactions);
      }

      if (result.processedTransactions.isNotEmpty) {
        await _syncBudgetAlerts();
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to process recurring transactions: $error\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not process recurring transactions. They will be retried.',
            ),
          ),
        );
      }
    } finally {
      _isProcessingRecurring = false;
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(
          notifications: notifications,
          budgetAlertsEnabled: _budgetAlertsEnabled,
          onMarkRead: _markNotificationRead,
          onMarkAllRead: _markAllNotificationsRead,
          onDelete: _deleteNotification,
          onClearAll: _clearNotifications,
          onBudgetAlertsChanged: _setBudgetAlertsEnabled,
        ),
      ),
    );
  }

  Future<void> _syncBudgetAlerts() async {
    if (!_budgetAlertsEnabled) return;
    try {
      final candidates = BudgetNotificationGenerator.generate(
        budgets: budgets,
        transactions: transactions,
        createdAt: DateTime.now(),
      );
      await _notificationStorage.addIfAbsent(candidates);
      final savedNotifications = await _notificationStorage.loadNotifications();
      if (mounted) setState(() => notifications = savedNotifications);
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to generate budget notifications: $error\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update budget alerts. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _addTransactionNotification({
    required String action,
    required Transaction transaction,
  }) async {
    final verb = action == 'deleted'
        ? 'deleted'
        : action == 'updated'
        ? 'updated'
        : 'added';
    try {
      await _notificationStorage.addIfAbsent([
        AppNotification(
          title: 'Transaction $action',
          message:
              '"${transaction.title}" · ${transaction.isIncome ? 'Income' : 'Expense'} '
              'of ${money(transaction.amount)} $verb.',
          createdAt: DateTime.now(),
        ),
      ]);
      final savedNotifications = await _notificationStorage.loadNotifications();
      if (mounted) setState(() => notifications = savedNotifications);
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to save transaction notification: $error\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Transaction saved, but its notification could not be stored.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _markNotificationRead(String id, bool isRead) async {
    await _notificationStorage.markRead(id, isRead: isRead);
    final savedNotifications = await _notificationStorage.loadNotifications();
    if (mounted) setState(() => notifications = savedNotifications);
  }

  Future<void> _markAllNotificationsRead() async {
    await _notificationStorage.markAllRead();
    final savedNotifications = await _notificationStorage.loadNotifications();
    if (mounted) setState(() => notifications = savedNotifications);
  }

  Future<void> _deleteNotification(String id) async {
    await _notificationStorage.delete(id);
    final savedNotifications = await _notificationStorage.loadNotifications();
    if (mounted) setState(() => notifications = savedNotifications);
  }

  Future<void> _clearNotifications() async {
    await _notificationStorage.clearAll();
    if (mounted) setState(() => notifications = []);
  }

  Future<void> _setBudgetAlertsEnabled(bool enabled) async {
    await _notificationStorage.saveBudgetAlertsEnabled(enabled);
    if (!mounted) return;
    setState(() => _budgetAlertsEnabled = enabled);
    if (enabled) await _syncBudgetAlerts();
  }

  Future<bool> _persistBudgets(List<MonthlyBudget> updatedBudgets) async {
    if (_isSavingBudget) return false;
    setState(() => _isSavingBudget = true);
    try {
      await _budgetStorage.saveBudgets(updatedBudgets);
      if (!mounted) return false;
      setState(() {
        budgets = updatedBudgets;
        _isSavingBudget = false;
      });
      await _syncBudgetAlerts();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to save monthly budgets: $error\n$stackTrace');
      if (mounted) setState(() => _isSavingBudget = false);
      return false;
    }
  }

  Future<void> _showTransactionForm({Transaction? transaction}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => _TransactionFormSheet(
        transaction: transaction,
        onSave: (updatedTransaction) async {
          if (_isSavingTransaction) return false;
          final updatedTransactions = [...transactions];
          if (transaction == null) {
            updatedTransactions.insert(0, updatedTransaction);
          } else {
            final index = updatedTransactions.indexWhere(
              (item) => item.id == transaction.id,
            );
            if (index == -1) return false;
            updatedTransactions[index] = updatedTransaction;
          }

          final saved = await _persistTransactions(updatedTransactions);
          if (saved) {
            await _syncBudgetAlerts();
            await _addTransactionNotification(
              action: transaction == null ? 'added' : 'updated',
              transaction: updatedTransaction,
            );
          }
          if (saved && mounted && sheetContext.mounted) {
            Navigator.pop(sheetContext);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  transaction == null
                      ? 'Transaction added successfully!'
                      : 'Transaction updated successfully!',
                ),
              ),
            );
          }
          return saved;
        },
      ),
    );
  }

  Future<bool> _persistTransactions(
    List<Transaction> updatedTransactions,
  ) async {
    if (_isSavingTransaction) return false;
    setState(() => _isSavingTransaction = true);
    try {
      await _transactionStorage.saveTransactions(updatedTransactions);
      if (!mounted) return false;
      setState(() {
        transactions = updatedTransactions;
        _isSavingTransaction = false;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to save transactions: $error\n$stackTrace');
      if (mounted) {
        setState(() => _isSavingTransaction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save transaction. Please try again.'),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _confirmDeleteTransaction(Transaction transaction) async {
    if (_isSavingTransaction) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('Delete "${transaction.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted || _isSavingTransaction) return;

    final updatedTransactions = transactions
        .where((item) => item.id != transaction.id)
        .toList();
    final saved = await _persistTransactions(updatedTransactions);
    if (saved) {
      await _syncBudgetAlerts();
      await _addTransactionNotification(
        action: 'deleted',
        transaction: transaction,
      );
    }
  }

  void _handleTransactionAction(String action, Transaction transaction) {
    if (_isSavingTransaction) return;
    switch (action) {
      case 'edit':
        _showTransactionForm(transaction: transaction);
        break;
      case 'delete':
        _confirmDeleteTransaction(transaction);
        break;
    }
  }

  List<Transaction> get _visibleTransactions {
    return _activeTransactionFilters.apply(
      transactions,
      searchQuery: _transactionSearchController.text,
    );
  }

  TransactionFilters get _activeTransactionFilters => TransactionFilters(
    isIncome: _transactionTypeFilter,
    category: _transactionCategoryFilter,
    startDate: _transactionStartDateFilter,
    endDate: _transactionEndDateFilter,
    minimumAmount: _transactionMinimumAmount,
    maximumAmount: _transactionMaximumAmount,
    sortOrder: _transactionSortOrder,
  );

  bool get _hasTransactionFilters => _activeTransactionFilters.hasFilters;

  Future<void> _openTransactionFilters() async {
    final result = await showModalBottomSheet<TransactionFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _TransactionFilterSheet(
        categories: transactions.map((item) => item.category).toSet().toList()
          ..sort(),
        initialFilters: TransactionFilters(
          isIncome: _transactionTypeFilter,
          category: _transactionCategoryFilter,
          startDate: _transactionStartDateFilter,
          endDate: _transactionEndDateFilter,
          minimumAmount: _transactionMinimumAmount,
          maximumAmount: _transactionMaximumAmount,
          sortOrder: _transactionSortOrder,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _transactionTypeFilter = result.isIncome;
      _transactionCategoryFilter = result.category;
      _transactionStartDateFilter = result.startDate;
      _transactionEndDateFilter = result.endDate;
      _transactionMinimumAmount = result.minimumAmount;
      _transactionMaximumAmount = result.maximumAmount;
      _transactionSortOrder = result.sortOrder;
    });
  }

  void _clearTransactionFilters() {
    setState(() {
      _transactionSearchController.clear();
      _transactionTypeFilter = null;
      _transactionCategoryFilter = null;
      _transactionStartDateFilter = null;
      _transactionEndDateFilter = null;
      _transactionMinimumAmount = null;
      _transactionMaximumAmount = null;
      _transactionSortOrder = TransactionSortOrder.newest;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      dashboardPage(),
      transactionsPage(),
      insightsPage(),
      profilePage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: green))
            : _loadError != null
            ? _loadErrorView()
            : pages[selectedIndex],
      ),
      floatingActionButton: _isLoading || _loadError != null
          ? null
          : FloatingActionButton(
              onPressed: showAddTransaction,
              backgroundColor: green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add, size: 30),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: green.withValues(alpha: 0.13),
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _loadErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: navy, fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _loadTransactions,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboardPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: green,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SpendTrack',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Manage your money smartly',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('open-notifications'),
                tooltip: 'Notifications',
                onPressed: _openNotifications,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Badge(
                  isLabelVisible: _unreadNotificationCount > 0,
                  label: Text(
                    _unreadNotificationCount > 99
                        ? '99+'
                        : '$_unreadNotificationCount',
                  ),
                  child: const Icon(Icons.notifications_outlined, color: green),
                ),
              ),
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFE4F5E9),
                child: Icon(Icons.person, color: green),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              key: const Key('open-monthly-budgets'),
              onTap: _openMonthlyBudgets,
              borderRadius: BorderRadius.circular(17),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.savings_outlined, color: green),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Budgets',
                            style: TextStyle(
                              color: navy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Plan limits and track category spending',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: green),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              key: const Key('open-recurring-transactions'),
              onTap: _openRecurringTransactions,
              borderRadius: BorderRadius.circular(17),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.repeat, color: green),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recurring Transactions',
                            style: TextStyle(
                              color: navy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Automate regular income and expenses',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: green),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF123C2A), Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL BALANCE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  money(balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Your available balance',
                        style: TextStyle(color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.trending_up, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(
                child: summaryCard(
                  'Income',
                  totalIncome,
                  Icons.arrow_downward,
                  const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: summaryCard(
                  'Expenses',
                  totalExpense,
                  Icons.arrow_upward,
                  const Color(0xFFEF4444),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => selectedIndex = 1),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('See all'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (transactions.isEmpty)
            const Center(child: Text('No transactions yet.'))
          else
            ...transactions.take(5).map(transactionTile),

          const SizedBox(height: 85),
        ],
      ),
    );
  }

  Widget summaryCard(String title, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              money(amount),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget transactionTile(Transaction transaction) {
    final color = transaction.isIncome ? green : const Color(0xFFEF4444);

    IconData icon;
    switch (transaction.category) {
      case 'Food':
        icon = Icons.restaurant;
        break;
      case 'Travel':
        icon = Icons.directions_bus;
        break;
      case 'Shopping':
        icon = Icons.shopping_bag;
        break;
      case 'Education':
        icon = Icons.school;
        break;
      case 'Salary':
      case 'Allowance':
        icon = Icons.payments;
        break;
      default:
        icon = Icons.receipt_long;
    }

    return Container(
      key: Key('transaction-tile-${transaction.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${transaction.category} • ${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${transaction.isIncome ? '+' : '-'}${money(transaction.amount)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          PopupMenuButton<String>(
            key: Key('transaction-menu-${transaction.id}'),
            tooltip: 'Transaction actions',
            enabled: !_isSavingTransaction,
            onSelected: (action) =>
                _handleTransactionAction(action, transaction),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget transactionsPage() {
    final visibleTransactions = _visibleTransactions;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transactions',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${transactions.length} transactions recorded',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('transaction-search-field'),
            controller: _transactionSearchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search title or category',
              prefixIcon: const Icon(Icons.search, color: green),
              suffixIcon: _transactionSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('clear-transaction-search'),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _transactionSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('open-transaction-filters'),
                onPressed: _openTransactionFilters,
                icon: const Icon(Icons.tune, color: green),
                label: Text(
                  _hasTransactionFilters ? 'Filters applied' : 'Filters',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${visibleTransactions.length} of ${transactions.length}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              if (_transactionSearchController.text.isNotEmpty ||
                  _hasTransactionFilters)
                TextButton(
                  key: const Key('clear-all-transaction-filters'),
                  onPressed: _clearTransactionFilters,
                  child: const Text('Clear all'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: visibleTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          transactions.isEmpty
                              ? Icons.receipt_long_outlined
                              : Icons.search_off,
                          size: 44,
                          color: green,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          transactions.isEmpty
                              ? 'No transactions available.'
                              : 'No transactions match your search or filters.',
                          key: const Key('transaction-results-empty-state'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (transactions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _clearTransactionFilters,
                            child: const Text('Clear all filters'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    key: const Key('transaction-results-list'),
                    itemCount: visibleTransactions.length,
                    itemBuilder: (context, index) =>
                        transactionTile(visibleTransactions[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget insightsPage() {
    return AdvancedInsightsDashboard(transactions: transactions);
  }

  Widget profilePage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: Color(0xFFE4F5E9),
            child: Icon(Icons.person, size: 45, color: green),
          ),
          const SizedBox(height: 16),
          const Text(
            'SpendTrack User',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Personal Expense Tracker',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 25),
          const Text('Version 1.0.0'),
        ],
      ),
    );
  }
}

class _TransactionFormSheet extends StatefulWidget {
  const _TransactionFormSheet({
    required this.transaction,
    required this.onSave,
  });

  final Transaction? transaction;
  final Future<bool> Function(Transaction transaction) onSave;

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late String _category;
  late bool _isIncome;
  late DateTime _date;
  bool _isSaving = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _titleController = TextEditingController(text: transaction?.title ?? '');
    _amountController = TextEditingController(
      text: transaction?.amount.toString() ?? '',
    );
    _category = transaction?.category ?? 'Food';
    _isIncome = transaction?.isIncome ?? false;
    _date = transaction?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (title.isEmpty || amount == null || !amount.isFinite || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid description and amount.')),
      );
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        Transaction(
          id: widget.transaction?.id,
          title: title,
          category: _category,
          amount: amount,
          date: _date,
          isIncome: _isIncome,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _isIncome
        ? ['Salary', 'Business', 'Allowance', 'Other']
        : [
            'Food',
            'Travel',
            'Shopping',
            'Education',
            'Entertainment',
            'Health',
            'Other',
          ];
    if (!categories.contains(_category)) {
      categories.add(_category);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing ? 'Edit Transaction' : 'Add Transaction',
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_isIncome},
              onSelectionChanged: (value) {
                setState(() {
                  _isIncome = value.first;
                  _category = _isIncome ? 'Salary' : 'Food';
                });
              },
            ),
            const SizedBox(height: 20),
            const Text('Description'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter transaction name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Amount (₹)'),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: 'Enter amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Category'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: categories
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 16),
            const Text('Date'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('transaction-date-button'),
                onPressed: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (selectedDate != null && mounted) {
                    setState(() => _date = selectedDate);
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text('${_date.day}/${_date.month}/${_date.year}'),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _submit,
                child: Text(
                  _isEditing ? 'Save Changes' : 'Save Transaction',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionFilterSheet extends StatefulWidget {
  const _TransactionFilterSheet({
    required this.categories,
    required this.initialFilters,
  });

  final List<String> categories;
  final TransactionFilters initialFilters;

  @override
  State<_TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<_TransactionFilterSheet> {
  late bool? _isIncome;
  late String? _category;
  late DateTime? _startDate;
  late DateTime? _endDate;
  late TransactionSortOrder _sortOrder;
  late final TextEditingController _minimumAmountController;
  late final TextEditingController _maximumAmountController;

  @override
  void initState() {
    super.initState();
    final filters = widget.initialFilters;
    _isIncome = filters.isIncome;
    _category = filters.category;
    _startDate = filters.startDate;
    _endDate = filters.endDate;
    _sortOrder = filters.sortOrder;
    _minimumAmountController = TextEditingController(
      text: filters.minimumAmount?.toString() ?? '',
    );
    _maximumAmountController = TextEditingController(
      text: filters.maximumAmount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minimumAmountController.dispose();
    _maximumAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool start}) async {
    final initial = start
        ? _startDate ?? DateTime.now()
        : _endDate ?? _startDate ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = _dateOnly(selected);
      } else {
        _endDate = _dateOnly(selected);
      }
    });
  }

  void _apply() {
    final minimum = _parseAmount(_minimumAmountController.text);
    final maximum = _parseAmount(_maximumAmountController.text);
    if (_minimumAmountController.text.trim().isNotEmpty && minimum == null ||
        _maximumAmountController.text.trim().isNotEmpty && maximum == null ||
        (minimum != null && minimum < 0) ||
        (maximum != null && maximum < 0)) {
      _showError('Enter valid non-negative amount limits.');
      return;
    }
    if (minimum != null && maximum != null && minimum > maximum) {
      _showError('Minimum amount cannot exceed maximum amount.');
      return;
    }
    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      _showError('End date must be on or after start date.');
      return;
    }

    Navigator.pop(
      context,
      TransactionFilters(
        isIncome: _isIncome,
        category: _category,
        startDate: _startDate,
        endDate: _endDate,
        minimumAmount: minimum,
        maximumAmount: maximum,
        sortOrder: _sortOrder,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _reset() {
    setState(() {
      _isIncome = null;
      _category = null;
      _startDate = null;
      _endDate = null;
      _sortOrder = TransactionSortOrder.newest;
      _minimumAmountController.clear();
      _maximumAmountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 22,
      right: 22,
      top: 20,
      bottom: MediaQuery.of(context).viewInsets.bottom + 22,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filter transactions',
                  style: TextStyle(
                    color: navy,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                key: const Key('reset-transaction-filter-sheet'),
                onPressed: _reset,
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Transaction type'),
          const SizedBox(height: 7),
          DropdownButtonFormField<String>(
            key: const Key('transaction-type-filter'),
            initialValue: _isIncome == null
                ? 'all'
                : _isIncome!
                ? 'income'
                : 'expense',
            decoration: _decoration(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All types')),
              DropdownMenuItem(value: 'income', child: Text('Income')),
              DropdownMenuItem(value: 'expense', child: Text('Expense')),
            ],
            onChanged: (value) => setState(() {
              _isIncome = switch (value) {
                'income' => true,
                'expense' => false,
                _ => null,
              };
            }),
          ),
          const SizedBox(height: 14),
          const Text('Category'),
          const SizedBox(height: 7),
          DropdownButtonFormField<String>(
            key: const Key('transaction-category-filter'),
            initialValue: _category,
            isExpanded: true,
            decoration: _decoration(hintText: 'All categories'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text(
                  'All categories',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...widget.categories.map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 14),
          const Text('Date range'),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('transaction-start-date-filter'),
                onPressed: () => _selectDate(start: true),
                icon: const Icon(Icons.calendar_today, size: 17),
                label: Text(
                  _startDate == null
                      ? 'From'
                      : 'From ${_formatDate(_startDate!)}',
                ),
              ),
              OutlinedButton.icon(
                key: const Key('transaction-end-date-filter'),
                onPressed: () => _selectDate(start: false),
                icon: const Icon(Icons.event, size: 17),
                label: Text(
                  _endDate == null ? 'To' : 'To ${_formatDate(_endDate!)}',
                ),
              ),
              if (_startDate != null || _endDate != null)
                TextButton(
                  onPressed: () => setState(() {
                    _startDate = null;
                    _endDate = null;
                  }),
                  child: const Text('Clear dates'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Amount range'),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('transaction-minimum-amount-filter'),
                  controller: _minimumAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoration(hintText: 'Minimum'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('transaction-maximum-amount-filter'),
                  controller: _maximumAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoration(hintText: 'Maximum'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Sort by'),
          const SizedBox(height: 7),
          DropdownButtonFormField<TransactionSortOrder>(
            key: const Key('transaction-sort-order'),
            initialValue: _sortOrder,
            isExpanded: true,
            decoration: _decoration(),
            items: const [
              DropdownMenuItem(
                value: TransactionSortOrder.newest,
                child: Text(
                  'Newest first',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: TransactionSortOrder.oldest,
                child: Text(
                  'Oldest first',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: TransactionSortOrder.highestAmount,
                child: Text(
                  'Highest amount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: TransactionSortOrder.lowestAmount,
                child: Text(
                  'Lowest amount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _sortOrder = value);
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              key: const Key('apply-transaction-filters'),
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Apply filters'),
            ),
          ),
        ],
      ),
    ),
  );

  static InputDecoration _decoration({String? hintText}) => InputDecoration(
    hintText: hintText,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  static double? _parseAmount(String value) =>
      value.trim().isEmpty ? null : double.tryParse(value.trim());

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
