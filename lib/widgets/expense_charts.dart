import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';

class ExpenseCharts extends StatefulWidget {
  final List<int> totals;
  final List<int> daily;
  final List<String>? labels;
  final String caption;
  const ExpenseCharts({
    super.key,
    required this.totals,
    required this.daily,
    this.labels,
    this.caption = 'Trong kỳ đã chọn',
  });
  @override
  State<ExpenseCharts> createState() => _ExpenseChartsState();
}

class _ExpenseChartsState extends State<ExpenseCharts>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();
  @override
  void didUpdateWidget(covariant ExpenseCharts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totals.join(',') != widget.totals.join(',') ||
        oldWidget.daily.join(',') != widget.daily.join(',')) {
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sum = widget.totals.fold<int>(0, (a, b) => a + b);
    final muted = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        children: [
          Semantics(
            label: 'Chi tiêu theo danh mục, tổng ${money(sum)}',
            child: SizedBox(
              height: 240,
              width: 240,
              child: CustomPaint(
                painter: DonutPainter(widget.totals, controller.value, muted),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.caption),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: 150,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              money(sum),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 19,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (sum == 0)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Chưa có chi tiêu trong kỳ này.'),
            ),
          ...List.generate(
            categories.length,
            (i) => ListTile(
              leading: CircleAvatar(
                radius: 6,
                backgroundColor: categoryColors[i],
              ),
              title: Text(categories[i]),
              trailing: Text(money(widget.totals[i])),
              dense: true,
            ),
          ),
          const Divider(height: 36),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Chi tiêu từng ngày',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Cột cao nhất: ${money(widget.daily.isEmpty ? 0 : widget.daily.reduce(math.max))}',
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: List.generate(
              widget.daily.length,
              (i) => 'Ngày ${i + 1}: ${money(widget.daily[i])}',
            ).join(', '),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                painter: BarPainter(
                  widget.daily,
                  controller.value,
                  Theme.of(context).colorScheme.primary,
                  muted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children:
                (widget.labels ??
                        const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
                    .map(
                      (s) => Expanded(
                        child: Center(
                          child: Text(s, style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class DonutPainter extends CustomPainter {
  final List<int> totals;
  final double progress;
  final Color background;
  DonutPainter(this.totals, this.progress, this.background);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 22;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24;
    canvas.drawCircle(center, radius, paint..color = background);
    final sum = totals.fold<int>(0, (a, b) => a + b);
    if (sum == 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < totals.length; i++) {
      final sweep = 2 * math.pi * totals[i] / sum;
      canvas.drawArc(
        rect,
        start,
        sweep * progress,
        false,
        paint..color = categoryColors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.background != background ||
      oldDelegate.totals.join(',') != totals.join(',');
}

class BarPainter extends CustomPainter {
  final List<int> daily;
  final double progress;
  final Color color;
  final Color background;
  BarPainter(this.daily, this.progress, this.color, this.background);
  @override
  void paint(Canvas canvas, Size size) {
    final maximum = daily.fold<int>(0, math.max);
    if (daily.isEmpty) return;
    final step = size.width / daily.length;
    final paint = Paint()..color = background;
    for (var i = 0; i < daily.length; i++) {
      final left = i * step + step * 0.2, width = step * 0.6;
      final track = Rect.fromLTWH(left, 0, width, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(track, const Radius.circular(8)),
        paint..color = background,
      );
      final height = maximum == 0
          ? 0.0
          : daily[i] / maximum * size.height * progress;
      if (height > 0)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, size.height - height, width, height),
            const Radius.circular(8),
          ),
          paint..color = color,
        );
    }
  }

  @override
  bool shouldRepaint(covariant BarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.background != background ||
      oldDelegate.daily.join(',') != daily.join(',');
}
