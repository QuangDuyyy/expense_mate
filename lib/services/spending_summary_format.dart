import 'spending_summary.dart';
import '../core/format.dart';

extension SpendingSummaryPresentation on SpendingSummary {
  String get label => period == SummaryPeriod.month
      ? 'Tháng ${start.month}/${start.year}'
      : '${dayLabel(start)} – ${dayLabel(end.subtract(const Duration(days: 1)))}';
  String fact(String id) {
    switch (id) {
      case 'total':
        return 'Tổng chi ${money(total)} trong kỳ đã chọn.';
      case 'count':
        return '${entries.length} khoản chi đã ghi nhận.';
      case 'daily_average':
        return 'Trung bình ${money(average)}/ngày trên $observedDays ngày.';
      case 'top_category':
        final i = topIndex;
        return i == null
            ? 'Chưa có danh mục chi tiêu.'
            : '${categories[i]} lớn nhất: ${money(totals[i])} (${(totals[i] / total * 100).toStringAsFixed(1)}%).';
      case 'comparison':
        if (previousTotal == 0)
          return 'Kỳ trước chưa có chi tiêu để tính tỷ lệ so sánh. $comparisonLabel.';
        final change = total - previousTotal;
        return '${change >= 0 ? 'Tăng' : 'Giảm'} ${money(change.abs())} (${changePercent!.abs().toStringAsFixed(1)}%) so với kỳ trước. $comparisonLabel.';
      case 'budget':
        if (budget == null) return 'Chưa đặt mục tiêu chi tháng.';
        final remaining = budget! - total;
        return remaining >= 0
            ? 'Còn ${money(remaining)} so với mục tiêu ${money(budget!)}.'
            : 'Đã vượt mục tiêu ${money(remaining.abs())}.';
      default:
        return '';
    }
  }
}
