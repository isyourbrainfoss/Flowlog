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
/// Unique names stay short (no roast date). When multiple beans share a
/// [Bean.name], disambiguates with roast date, process, variety, origin, or
/// a fallback hint.
String formatBeanDisplayLabel(Bean bean, {List<Bean>? allBeans}) {
  // Repair at the display edge so a raw/synced bean cannot paint mojibake
  // even if a caller skipped BeanRepository.
  final cleaned = bean.repaired();
  final displayName = _beanNameWithBrand(cleaned);
  final duplicates =
      allBeans != null && _sameNameCount(cleaned, allBeans) > 1;

  if (!duplicates) {
    return displayName;
  }

  if (cleaned.roastDate != null) {
    return '$displayName · ${formatBeanRoastDate(cleaned.roastDate!)}';
  }

  if (cleaned.process != null && cleaned.process!.trim().isNotEmpty) {
    return '$displayName · ${cleaned.process!.trim()}';
  }

  if (cleaned.variety != null && cleaned.variety!.trim().isNotEmpty) {
    return '$displayName · ${cleaned.variety!.trim()}';
  }

  if (cleaned.origin != null && cleaned.origin!.trim().isNotEmpty) {
    return '$displayName · ${cleaned.origin!.trim()}';
  }

  return '$displayName · no roast date';
}