import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_bootstrap.dart';
import '../../core/data/health_measurement_data_service.dart';
import 'blood_pressure_assessment.dart';

class HealthInsightsPage extends StatefulWidget {
  const HealthInsightsPage({super.key, this.ownerId});

  final String? ownerId;

  @override
  State<HealthInsightsPage> createState() => _HealthInsightsPageState();
}

class _HealthInsightsPageState extends State<HealthInsightsPage> {
  late final HealthMeasurementDataService _service;
  List<HealthMeasurementHistoryItem> _items = const [];
  _HistoryRange _range = _HistoryRange.thirtyDays;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = HealthMeasurementDataService(
      client: SupabaseBootstrap.enabled ? Supabase.instance.client : null,
      ownerId: widget.ownerId,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.load(limit: 100);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được lịch sử sức khỏe. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _deleteMeasurement(HealthMeasurementHistoryItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa lần đo này?'),
        content: const Text(
          'Chỉ xóa kết quả đọc nhầm hoặc không muốn lưu. Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _alertRed),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    try {
      await _service.delete(item);
      if (!mounted) return;
      setState(
        () => _items = _items.where((value) => value.id != item.id).toList(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa lần đo khỏi lịch sử.')),
      );
    } catch (error, stackTrace) {
      debugPrint('DiVie health measurement delete failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa xóa được lần đo. Hãy thử lại.')),
      );
    }
  }

  List<HealthMeasurementHistoryItem> get _filteredItems {
    final now = DateTime.now();
    final since = switch (_range) {
      _HistoryRange.sevenDays => now.subtract(const Duration(days: 7)),
      _HistoryRange.thirtyDays => now.subtract(const Duration(days: 30)),
      _HistoryRange.all => null,
    };
    final result = _items
        .where((item) => since == null || item.measuredAt.isAfter(since))
        .toList();
    result.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return result;
  }

  List<HealthMeasurementHistoryItem> get _chartItems => _filteredItems
      .where(
        (item) =>
            item.systolic != null ||
            item.diastolic != null ||
            item.pulse != null,
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final latest = items.isEmpty ? null : items.last;
    final latestAssessment = latest == null
        ? null
        : BloodPressureAssessment.evaluate(
            systolic: latest.systolic,
            diastolic: latest.diastolic,
          );
    final latestHeartRate = latest == null
        ? null
        : HeartRateAssessment.evaluate(latest.pulse);
    final insights = _buildInsights(items);

    return Scaffold(
      backgroundColor: const Color(0xFFF1FAFA),
      appBar: AppBar(
        title: const Text('Xu hướng sức khỏe'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  const Text(
                    'Theo dõi sức khỏe',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF102B52),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Xem lại các lần đo đã lưu và nhận biết thay đổi theo thời gian.',
                    style: TextStyle(color: Color(0xFF66758A)),
                  ),
                  const SizedBox(height: 18),
                  _RangeSelector(
                    value: _range,
                    onChanged: (value) => setState(() => _range = value),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) _ErrorCard(message: _error!),
                  if (_error == null && items.isEmpty)
                    const _EmptyCard(
                      title: 'Chưa có dữ liệu đo',
                      message:
                          'Sau khi chụp và xác nhận kết quả máy đo, dữ liệu sẽ xuất hiện ở đây.',
                    ),
                  if (_error == null && items.isNotEmpty) ...[
                    _SummaryCards(
                      latest: latest!,
                      items: items,
                      assessment: latestAssessment!,
                      heartRate: latestHeartRate!,
                    ),
                    const SizedBox(height: 16),
                    _HeartRateStatusCard(
                      pulse: latest.pulse,
                      assessment: latestHeartRate!,
                    ),
                    if (latestAssessment.isAbnormal ||
                        latestHeartRate.needsAttention) ...[
                      const SizedBox(height: 16),
                      _CurrentReadingAlert(
                        assessment: latestAssessment,
                        heartRate: latestHeartRate,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Biểu đồ huyết áp',
                      subtitle:
                          'Đơn vị: mmHg · xanh bình thường, vàng cần theo dõi, đỏ cần chú ý',
                      child: _chartItems.length < 2
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: Text(
                                'Cần ít nhất 2 lần đo để hiển thị xu hướng.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : SizedBox(
                              height: 250,
                              child: CustomPaint(
                                painter: _VitalsChartPainter(_chartItems),
                                child: const SizedBox.expand(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Cảnh báo xu hướng',
                      subtitle: 'Tín hiệu cần theo dõi từ dữ liệu đã lưu',
                      child: Column(
                        children: insights
                            .map((insight) => _InsightTile(insight: insight))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Lịch sử đo',
                      subtitle: '${items.length} lần đo trong khoảng đã chọn',
                      child: Column(
                        children: items.reversed
                            .map(
                              (item) => _HistoryRow(
                                item: item,
                                onDelete: () => _deleteMeasurement(item),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Thông tin chỉ mang tính theo dõi, không thay thế tư vấn y tế. Nếu chỉ số bất thường kéo dài hoặc có triệu chứng bất thường, hãy liên hệ nhân viên y tế.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<_HealthInsight> _buildInsights(
    List<HealthMeasurementHistoryItem> items,
  ) {
    if (items.isEmpty) return const [];
    final latest = items.last;
    final insights = <_HealthInsight>[];
    final recent = items.reversed.take(3).toList();
    final assessment = BloodPressureAssessment.evaluate(
      systolic: latest.systolic,
      diastolic: latest.diastolic,
    );
    final abnormalCount = recent
        .where(
          (item) => BloodPressureAssessment.evaluate(
            systolic: item.systolic,
            diastolic: item.diastolic,
          ).isAbnormal,
        )
        .length;

    if (assessment.isAbnormal) {
      insights.add(
        _HealthInsight(
          icon: _iconForAssessment(assessment),
          color: _colorForAssessment(assessment),
          title: assessment.title,
          message: assessment.message,
        ),
      );
    }

    if (abnormalCount >= 2) {
      insights.add(
        const _HealthInsight(
          icon: Icons.monitor_heart_outlined,
          color: Color(0xFFDC2626),
          title: 'Nhiều lần đo gần đây cần chú ý',
          message:
              'Ít nhất 2 trong 3 lần đo gần đây có chỉ số ngoài mức theo dõi. Bác nên trao đổi với người thân hoặc nhân viên y tế.',
        ),
      );
    }

    final heartRate = HeartRateAssessment.evaluate(latest.pulse);
    if (heartRate.needsAttention) {
      insights.add(
        _HealthInsight(
          icon: heartRate.isDanger
              ? Icons.priority_high_rounded
              : Icons.favorite_border_rounded,
          color: _colorForHeartRate(heartRate),
          title: heartRate.title,
          message: heartRate.message,
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        const _HealthInsight(
          icon: Icons.check_circle_outline_rounded,
          color: Color(0xFF059669),
          title: 'Chưa thấy tín hiệu bất thường rõ ràng',
          message:
              'Các dữ liệu gần đây đang tương đối ổn định trong phạm vi theo dõi của ứng dụng.',
        ),
      );
    }
    return insights;
  }
}

enum _HistoryRange { sevenDays, thirtyDays, all }

const _normalGreen = Color(0xFF059669);
const _watchAmber = Color(0xFFD97706);
const _alertRed = Color(0xFFDC2626);
const _criticalRed = Color(0xFFB91C1C);
const _mutedGray = Color(0xFF66758A);

Color _colorForAssessment(BloodPressureAssessment assessment) =>
    assessment.isNormal
    ? _normalGreen
    : assessment.level == BloodPressureLevel.elevated
    ? _watchAmber
    : assessment.isCritical
    ? _criticalRed
    : _alertRed;

IconData _iconForAssessment(BloodPressureAssessment assessment) =>
    switch (assessment.level) {
      BloodPressureLevel.normal => Icons.check_circle_outline_rounded,
      BloodPressureLevel.low => Icons.south_rounded,
      BloodPressureLevel.critical => Icons.priority_high_rounded,
      BloodPressureLevel.unavailable => Icons.help_outline_rounded,
      _ => Icons.warning_amber_rounded,
    };

Color _colorForHeartRate(HeartRateAssessment assessment) =>
    switch (assessment.level) {
      HeartRateLevel.healthy => _normalGreen,
      HeartRateLevel.attention => _watchAmber,
      HeartRateLevel.danger => _alertRed,
      HeartRateLevel.unavailable => _mutedGray,
    };

class _CurrentReadingAlert extends StatelessWidget {
  const _CurrentReadingAlert({
    required this.assessment,
    required this.heartRate,
  });

  final BloodPressureAssessment assessment;
  final HeartRateAssessment heartRate;

  @override
  Widget build(BuildContext context) {
    final color = _colorForAssessment(assessment);
    final pulseWarning = heartRate.needsAttention;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconForAssessment(assessment), color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(assessment.message, style: const TextStyle(height: 1.35)),
                if (pulseWarning) ...[
                  const SizedBox(height: 8),
                  Text(
                    heartRate.message,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});

  final _HistoryRange value;
  final ValueChanged<_HistoryRange> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<_HistoryRange>(
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(value: _HistoryRange.sevenDays, label: Text('7 ngày')),
      ButtonSegment(value: _HistoryRange.thirtyDays, label: Text('30 ngày')),
      ButtonSegment(value: _HistoryRange.all, label: Text('Tất cả')),
    ],
    selected: {value},
    onSelectionChanged: (selection) => onChanged(selection.first),
  );
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.latest,
    required this.items,
    required this.assessment,
    required this.heartRate,
  });

  final HealthMeasurementHistoryItem latest;
  final List<HealthMeasurementHistoryItem> items;
  final BloodPressureAssessment assessment;
  final HeartRateAssessment heartRate;

  @override
  Widget build(BuildContext context) {
    final pressures = items
        .where((item) => item.systolic != null && item.diastolic != null)
        .toList();
    final averageSystolic = pressures.isEmpty
        ? null
        : (pressures.map((item) => item.systolic!).reduce((a, b) => a + b) /
                  pressures.length)
              .round();
    final averageDiastolic = pressures.isEmpty
        ? null
        : (pressures.map((item) => item.diastolic!).reduce((a, b) => a + b) /
                  pressures.length)
              .round();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricCard(
          label: 'Lần đo gần nhất',
          value: '${latest.systolic ?? '—'}/${latest.diastolic ?? '—'}',
          suffix: 'mmHg',
          color: _colorForAssessment(assessment),
        ),
        _MetricCard(
          label: 'Trung bình',
          value: '${averageSystolic ?? '—'}/${averageDiastolic ?? '—'}',
          suffix: 'mmHg',
          color: const Color(0xFF2563EB),
        ),
        _MetricCard(
          label: 'Nhịp tim gần nhất',
          value: '${latest.pulse ?? '—'}',
          suffix: 'lần/phút',
          color: _colorForHeartRate(heartRate),
        ),
      ],
    );
  }
}

class _HeartRateStatusCard extends StatelessWidget {
  const _HeartRateStatusCard({required this.pulse, required this.assessment});

  final int? pulse;
  final HeartRateAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final color = _colorForHeartRate(assessment);
    return _SectionCard(
      title: 'Nhịp tim lần gần nhất',
      subtitle: 'Đánh giá từ lần vừa chụp và lưu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: color, size: 30),
              const SizedBox(width: 10),
              Text(
                '${pulse ?? '—'} lần/phút',
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  assessment.title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(assessment.message, style: const TextStyle(height: 1.35)),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeartRateThreshold(
                color: _alertRed,
                label: 'Đỏ: dưới 50 hoặc trên 120',
              ),
              _HeartRateThreshold(
                color: _watchAmber,
                label: 'Vàng: 50–59 hoặc 101–120',
              ),
              _HeartRateThreshold(color: _normalGreen, label: 'Xanh: 60–100'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeartRateThreshold extends StatelessWidget {
  const _HeartRateThreshold({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
  });

  final String label;
  final String value;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 165,
    child: Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF66758A))),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(suffix, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF102B52),
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF66758A))),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _HealthInsight {
  const _HealthInsight({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});

  final _HealthInsight insight;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: insight.color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(insight.icon, color: insight.color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight.title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: insight.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(insight.message, style: const TextStyle(height: 1.35)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item, required this.onDelete});

  final HealthMeasurementHistoryItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final assessment = BloodPressureAssessment.evaluate(
      systolic: item.systolic,
      diastolic: item.diastolic,
    );
    final color = _colorForAssessment(assessment);
    final date = item.measuredAt.toLocal();
    final stamp =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        assessment.isNormal
            ? Icons.check_circle_rounded
            : _iconForAssessment(assessment),
        color: color,
      ),
      title: Text(
        '${item.systolic ?? '—'} / ${item.diastolic ?? '—'} mmHg',
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
      subtitle: Text(
        '${assessment.title} · Nhịp tim ${item.pulse ?? '—'} · $stamp',
      ),
      trailing: IconButton(
        tooltip: 'Xóa lần đo',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Icon(
            Icons.insights_rounded,
            size: 42,
            color: Color(0xFF0F9EAA),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: const Color(0xFFFFF1F2),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFBE123C)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _VitalsChartPainter extends CustomPainter {
  _VitalsChartPainter(this.items);

  final List<HealthMeasurementHistoryItem> items;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const right = 12.0;
    const top = 12.0;
    const bottom = 30.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      math.max(left + 1, size.width - right),
      math.max(top + 1, size.height - bottom),
    );
    final values = [
      ...items
          .where((item) => item.systolic != null)
          .map((item) => item.systolic!),
      ...items
          .where((item) => item.diastolic != null)
          .map((item) => item.diastolic!),
    ];
    if (values.isEmpty) return;
    final minValue = ((values.reduce(math.min) - 10) / 10).floor() * 10;
    final maxValue = ((values.reduce(math.max) + 10) / 10).ceil() * 10;
    final range = math.max(1, maxValue - minValue).toDouble();

    final gridPaint = Paint()
      ..color = const Color(0xFFE3E8EF)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(fontSize: 10, color: Color(0xFF718096));
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _drawText(
        canvas,
        '${(maxValue - range * i / 4).round()}',
        Offset(0, y - 7),
        labelStyle,
      );
    }

    _drawSeries(
      canvas,
      chart,
      items.map((item) => item.systolic?.toDouble()).toList(),
      const Color(0xFF0F9EAA),
      minValue.toDouble(),
      range,
    );
    _drawSeries(
      canvas,
      chart,
      items.map((item) => item.diastolic?.toDouble()).toList(),
      const Color(0xFF2563EB),
      minValue.toDouble(),
      range,
    );
    _drawText(
      canvas,
      'Tâm thu',
      Offset(chart.left, size.height - 18),
      const TextStyle(
        fontSize: 10,
        color: Color(0xFF0F9EAA),
        fontWeight: FontWeight.w700,
      ),
    );
    _drawText(
      canvas,
      'Tâm trương',
      Offset(chart.left + 62, size.height - 18),
      const TextStyle(
        fontSize: 10,
        color: Color(0xFF2563EB),
        fontWeight: FontWeight.w700,
      ),
    );
    if (items.isNotEmpty) {
      final first = _shortDate(items.first.measuredAt);
      final last = _shortDate(items.last.measuredAt);
      _drawText(canvas, first, Offset(chart.left, size.height - 4), labelStyle);
      final lastPainter = _textPainter(last, labelStyle);
      lastPainter.paint(
        canvas,
        Offset(chart.right - lastPainter.width, size.height - 4),
      );
    }
  }

  void _drawSeries(
    Canvas canvas,
    Rect chart,
    List<double?> values,
    Color color,
    double minValue,
    double range,
  ) {
    if (values.isEmpty) return;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = ui.Path();
    var started = false;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        started = false;
        continue;
      }
      final x = values.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (values.length - 1);
      final y = chart.bottom - ((value - minValue) / range) * chart.height;
      final point = Offset(x, y.clamp(chart.top, chart.bottom));
      if (!started) {
        path.moveTo(point.dx, point.dy);
        started = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
      final assessment = BloodPressureAssessment.evaluate(
        systolic: items[i].systolic,
        diastolic: items[i].diastolic,
      );
      canvas.drawCircle(
        point,
        3.5,
        Paint()..color = _colorForAssessment(assessment),
      );
    }
    canvas.drawPath(path, line);
  }

  String _shortDate(DateTime value) => '${value.day}/${value.month}';

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    _textPainter(text, style).paint(canvas, offset);
  }

  TextPainter _textPainter(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: ui.TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(covariant _VitalsChartPainter oldDelegate) =>
      oldDelegate.items != items;
}
