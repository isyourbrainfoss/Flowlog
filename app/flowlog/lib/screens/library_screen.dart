import 'package:flowlog/screens/library/beans.dart';
import 'package:flowlog/screens/library/compare.dart';
import 'package:flowlog/screens/library/insights.dart';
import 'package:flowlog/screens/library/simulator.dart';
import 'package:flowlog/screens/library/tags.dart';
import 'package:flutter/material.dart';

/// Library tab: beans, tags, insights, compare, and simulator.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(key: Key('library_tab_beans'), text: 'Beans'),
              Tab(key: Key('library_tab_tags'), text: 'Tags'),
              Tab(key: Key('library_tab_insights'), text: 'Insights'),
              Tab(key: Key('library_tab_compare'), text: 'Compare'),
              Tab(key: Key('library_tab_simulator'), text: 'Simulator'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BeansScreen(),
            TagsScreen(),
            InsightsScreen(),
            CompareScreen(),
            SimulatorScreen(),
          ],
        ),
      ),
    );
  }
}