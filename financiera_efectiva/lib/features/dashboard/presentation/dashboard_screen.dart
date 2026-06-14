import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../core/services/financial_firestore_service.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../credits/presentation/credits_screen.dart';
import '../../operations/presentation/operation_history_screen.dart';
import '../../operations/presentation/operation_menu_screen.dart';
import '../domain/entities/financial_summary.dart';
import '../domain/entities/movement.dart';
import 'widgets/balance_card.dart';
import 'widgets/movement_list.dart';
import 'widgets/product_summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  int _refreshToken = 0;
  final Set<int> _loadedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardHome(refreshToken: _refreshToken),
      _loadedTabs.contains(1)
          ? const OperationMenuScreen()
          : const SizedBox.shrink(),
      _loadedTabs.contains(2)
          ? const CreditsScreen(showAppBar: false)
          : const SizedBox.shrink(),
      _loadedTabs.contains(3)
          ? OperationHistoryScreen(
              showAppBar: false,
              refreshToken: _refreshToken,
            )
          : const SizedBox.shrink(),
    ];

    return Scaffold(
      appBar: const AppTopBar(),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() {
          _currentIndex = index;
          _loadedTabs.add(index);
          _refreshToken++;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz),
            label: 'Operación',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_score_outlined),
            selectedIcon: Icon(Icons.credit_score),
            label: 'Créditos',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Historial',
          ),
        ],
      ),
    );
  }
}

class _DashboardHome extends StatefulWidget {
  const _DashboardHome({required this.refreshToken});

  final int refreshToken;

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  late Future<_DashboardHomeData> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHomeData();
  }

  @override
  void didUpdateWidget(covariant _DashboardHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _homeFuture = _loadHomeData();
    }
  }

  Future<_DashboardHomeData> _loadHomeData() async {
    final service = FinancialFirestoreService.instance;

    final results = await Future.wait([
      service.getCachedSummary(),
      service.getCachedMovements(limit: 5),
    ]);

    return _DashboardHomeData(
      summary: results[0] as FinancialSummary,
      movements: results[1] as List<Movement>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardHomeData>(
      future: _homeFuture,
      builder: (context, snapshot) {
        return RefreshIndicator(
          onRefresh: () async {
            final future = _loadHomeData();
            setState(() => _homeFuture = future);
            try {
              await future;
            } catch (_) {
              // FutureBuilder muestra el error; el refresh solo debe cerrarse.
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (snapshot.hasError)
                _InlineLoadError(
                  message: 'No se pudo cargar la información de inicio.',
                  error: snapshot.error,
                )
              else if (!snapshot.hasData)
                const SizedBox(
                  height: 96,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                BalanceCard(
                  title: 'Saldo general',
                  amount: snapshot.data!.summary.totalBalance,
                  icon: Icons.account_balance_wallet,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ProductSummaryCard(
                      title: 'Ahorros',
                      subtitle: 'Saldo y estados',
                      icon: Icons.savings,
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.savings),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ProductSummaryCard(
                      title: 'Créditos',
                      subtitle: 'Cuotas y cronograma',
                      icon: Icons.credit_score,
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.credits),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Theme.of(context).cardTheme.color,
                collapsedBackgroundColor: Theme.of(context).cardTheme.color,
                title: Text(
                  'Últimos movimientos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                children: [
                  if (snapshot.hasError)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No se pudieron cargar los movimientos.'),
                    )
                  else if (!snapshot.hasData)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.data!.movements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Aún no tienes movimientos.'),
                    )
                  else
                    MovementList(movements: snapshot.data!.movements),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHomeData {
  const _DashboardHomeData({required this.summary, required this.movements});

  final FinancialSummary summary;
  final List<Movement> movements;
}

class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.message, this.error});

  final String message;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        error == null ? message : '$message\n$error',
        style: TextStyle(color: colorScheme.onErrorContainer),
      ),
    );
  }
}
