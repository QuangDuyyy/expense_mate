const categories = [
  'Ăn uống',
  'Di chuyển',
  'Mua sắm',
  'Học tập',
  'Sinh hoạt',
  'Khác',
];
int categoryIndex(String category) {
  final index = categories.indexOf(category);
  return index < 0 ? categories.length - 1 : index;
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
