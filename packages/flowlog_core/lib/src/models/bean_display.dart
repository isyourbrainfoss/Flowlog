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

String _beanNameWithBrand(Bean bean) {
  final brand = bean.brand?.trim();
  if (brand == null || brand.isEmpty) {
    return bean.name;
  }
  return '$brand · ${bean.name}';
}

/// Human-readable bean label for pickers and lists.
///
/// When multiple beans share a [Bean.name], disambiguates with roast date,
/// origin, or a fallback hint.
String formatBeanDisplayLabel(Bean bean, {List<Bean>? allBeans}) {
  final displayName = _beanNameWithBrand(bean);
  final duplicates =
      allBeans != null && _sameNameCount(bean, allBeans) > 1;

  if (!duplicates) {
    if (bean.roastDate != null) {
      return '$displayName · ${formatBeanRoastDate(bean.roastDate!)}';
    }
    return displayName;
  }

  if (bean.roastDate != null) {
    return '$displayName · ${formatBeanRoastDate(bean.roastDate!)}';
  }

  if (bean.process != null && bean.process!.trim().isNotEmpty) {
    return '$displayName · ${bean.process!.trim()}';
  }

  if (bean.variety != null && bean.variety!.trim().isNotEmpty) {
    return '$displayName · ${bean.variety!.trim()}';
  }

  if (bean.origin != null && bean.origin!.trim().isNotEmpty) {
    return '$displayName · ${bean.origin!.trim()}';
  }

  return '$displayName · no roast date';
}