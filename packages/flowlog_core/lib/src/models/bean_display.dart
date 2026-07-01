import 'bean.dart';

/// Formats a bean roast date for display (local calendar day).
String formatBeanRoastDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

int _sameNameCount(Bean bean, List<Bean> allBeans) {
  final lower = bean.name.toLowerCase();
  return allBeans.where((b) => b.name.toLowerCase() == lower).length;
}

/// Human-readable bean label for pickers and lists.
///
/// When multiple beans share a [Bean.name], disambiguates with roast date,
/// origin, or a fallback hint.
String formatBeanDisplayLabel(Bean bean, {List<Bean>? allBeans}) {
  final duplicates =
      allBeans != null && _sameNameCount(bean, allBeans) > 1;

  if (!duplicates) {
    if (bean.roastDate != null) {
      return '${bean.name} · ${formatBeanRoastDate(bean.roastDate!)}';
    }
    return bean.name;
  }

  if (bean.roastDate != null) {
    return '${bean.name} · ${formatBeanRoastDate(bean.roastDate!)}';
  }

  if (bean.origin != null && bean.origin!.trim().isNotEmpty) {
    return '${bean.name} · ${bean.origin!.trim()}';
  }

  return '${bean.name} · no roast date';
}