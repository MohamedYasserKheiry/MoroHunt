import 'package:flutter/material.dart';

import '../data/moroccan_cities.dart';

/// Facebook-style day/month/year birthdate selector, shared between
/// sign-up and profile editing. Reports the 3 parts individually via
/// [onDayChanged]/[onMonthChanged]/[onYearChanged] so the parent can
/// validate the combination (e.g. reject Feb 30) however it needs to.
class BirthdateDropdownsRow extends StatelessWidget {
  final int? day;
  final int? month;
  final int? year;
  final ValueChanged<int?> onDayChanged;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<int?> onYearChanged;

  const BirthdateDropdownsRow({
    super.key,
    required this.day,
    required this.month,
    required this.year,
    required this.onDayChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = List<int>.generate(
      89,
      (i) => now.year - 12 - i,
    ); // 12..100 y/o

    return Row(
      children: [
        Expanded(
          child: _SingleDropdown<int>(
            hint: 'اليوم',
            value: day,
            items: List.generate(31, (i) => i + 1),
            labelBuilder: (v) => '$v',
            onChanged: onDayChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _SingleDropdown<int>(
            hint: 'الشهر',
            value: month,
            items: List.generate(12, (i) => i + 1),
            labelBuilder: (v) => arabicMonths[v - 1],
            onChanged: onMonthChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SingleDropdown<int>(
            hint: 'السنة',
            value: year,
            items: years,
            labelBuilder: (v) => '$v',
            onChanged: onYearChanged,
          ),
        ),
      ],
    );
  }
}

/// Validates a day/month/year combination, returning null if invalid
/// (e.g. Feb 30 rolling over to March) rather than silently correcting it.
DateTime? buildValidBirthdate(int? day, int? month, int? year) {
  if (day == null || month == null || year == null) return null;
  final d = DateTime(year, month, day);
  if (d.year != year || d.month != month || d.day != day) return null;
  return d;
}

class _SingleDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;

  const _SingleDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          dropdownColor: const Color(0xFF1C1F1A),
          items: items
              .map(
                (v) => DropdownMenuItem<T>(
                  value: v,
                  child: Text(
                    labelBuilder(v),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
