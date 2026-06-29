import 'package:flowlog/screens/library/beans.dart';
import 'package:flowlog/screens/library/compare.dart';
import 'package:flowlog/screens/library/tags.dart';
import 'package:flutter/material.dart';

/// Library tab: bean inventory, tags, and shot comparison.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: const TabBar(
            tabs: [
              Tab(key: Key('library_tab_beans'), text: 'Beans'),
              Tab(key: Key('library_tab_tags'), text: 'Tags'),
              Tab(key: Key('library_tab_compare'), text: 'Compare'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BeansScreen(),
            TagsScreen(),
            CompareScreen(),
          ],
        ),
      ),
    );
  }
}