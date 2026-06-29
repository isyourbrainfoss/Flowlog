import 'package:flowlog/screens/history_screen.dart';
import 'package:flowlog/screens/library_screen.dart';
import 'package:flowlog/screens/live_screen.dart';
import 'package:flowlog/screens/more_screen.dart';
import 'package:flutter/material.dart';

/// Primary navigation tabs for the Flowlog shell.
enum AppTab {
  live,
  history,
  library,
  more,
}

class AppDestination {
  const AppDestination({
    required this.tab,
    required this.route,
    required this.label,
    required this.icon,
    required this.screen,
  });

  final AppTab tab;
  final String route;
  final String label;
  final IconData icon;
  final Widget screen;
}

const List<AppDestination> appDestinations = [
  AppDestination(
    tab: AppTab.live,
    route: '/live',
    label: 'Live',
    icon: Icons.play_circle_outline,
    screen: LiveScreen(),
  ),
  AppDestination(
    tab: AppTab.history,
    route: '/history',
    label: 'History',
    icon: Icons.history,
    screen: HistoryScreen(),
  ),
  AppDestination(
    tab: AppTab.library,
    route: '/library',
    label: 'Library',
    icon: Icons.local_cafe_outlined,
    screen: LibraryScreen(),
  ),
  AppDestination(
    tab: AppTab.more,
    route: '/more',
    label: 'More',
    icon: Icons.tune,
    screen: MoreScreen(),
  ),
];

Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    for (final destination in appDestinations)
      destination.route: (context) => Scaffold(
            appBar: AppBar(title: Text(destination.label)),
            body: destination.screen,
          ),
  };
}