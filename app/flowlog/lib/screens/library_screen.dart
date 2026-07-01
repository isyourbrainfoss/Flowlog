import 'package:flowlog/screens/library/beans.dart';
import 'package:flowlog/screens/library/compare.dart';
import 'package:flowlog/screens/library/insights.dart';
import 'package:flowlog/screens/library/simulator.dart';
import 'package:flowlog/screens/library/tags.dart';
import 'package:flutter/material.dart';

/// Library tab: beans, tags, insights, compare, and simulator.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  static const _simulatorTabIndex = 4;

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
  }

  @override
  void dispose() {
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