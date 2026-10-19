import 'package:flowlog/screens/library/beans.dart';
import 'package:flowlog/screens/library/compare.dart';
import 'package:flowlog/screens/library/insights.dart';
import 'package:flowlog/screens/library/simulator.dart';
import 'package:flowlog/screens/library/tags.dart';
import 'package:flutter/material.dart';

/// Library tab: beans, tags, insights, compare, and simulator.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  /// Pending request to show a Library sub-tab (index), consumed by the
  /// mounted [LibraryScreen] or on its next init. Used by More → Target
  /// brew → "Build in Simulator", which used to land on Beans.
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  /// Index of the Simulator sub-tab.
  static const simulatorTabIndex = 4;

  /// Asks the Library tab to show the Simulator.
  static void showSimulator() => requestedTab.value = simulatorTabIndex;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  static const _simulatorTabIndex = LibraryScreen.simulatorTabIndex;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() {});
        }
      });
    LibraryScreen.requestedTab.addListener(_onTabRequested);
    _onTabRequested();
  }

  void _onTabRequested() {
    final index = LibraryScreen.requestedTab.value;
    if (index == null) {
      return;
    }
    LibraryScreen.requestedTab.value = null;
    if (index >= 0 && index < _tabController.length) {
      _tabController.index = index;
    }
  }

  @override
  void dispose() {
    LibraryScreen.requestedTab.removeListener(_onTabRequested);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lockSwipe = _tabController.index == _simulatorTabIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(key: Key('library_tab_beans'), text: 'Beans'),
            Tab(key: Key('library_tab_tags'), text: 'Tags'),
            Tab(key: Key('library_tab_insights'), text: 'Insights'),
            Tab(key: Key('library_tab_compare'), text: 'Compare'),
            Tab(key: Key('library_tab_simulator'), text: 'Simulator'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: lockSwipe ? const NeverScrollableScrollPhysics() : null,
        children: const [
          BeansScreen(),
          TagsScreen(),
          InsightsScreen(),
          CompareScreen(),
          SimulatorScreen(),
        ],
      ),
    );
  }
}