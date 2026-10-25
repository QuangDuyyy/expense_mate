import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

export 'expense_values.dart';

const categoryColors = [
  Color(0xFFF59E0B),
  Color(0xFF3B82F6),
  Color(0xFFA855F7),
  Color(0xFF14B8A6),
  Color(0xFFEF6461),
  Color(0xFF64748B),
];
const categoryIcons = [
  Icons.restaurant_rounded,
  Icons.directions_bus_rounded,
  Icons.shopping_bag_rounded,
  Icons.school_rounded,
  Icons.home_rounded,
  Icons.more_horiz,
];
String money(num value) => '${NumberFormat('#,###', 'vi_VN').format(value)} đ';
String dayLabel(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
