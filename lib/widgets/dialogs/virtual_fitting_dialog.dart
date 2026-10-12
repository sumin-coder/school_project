import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/fitting_report_model.dart';
import '../../services/ai_fitting_service.dart';

class VirtualFittingDialog extends StatefulWidget {
  final String? defaultItemName;

  const VirtualFittingDialog({
    super.key,
    this.defaultItemName,
  });

  static Future<void> show({
    required BuildContext context,
    String? defaultItemName,
  }) {
    return showDialog(
      context: context,
      builder: (context) => VirtualFittingDialog(
        defaultItemName: defaultItemName,
      ),
    );
  }

  @override
  State<VirtualFittingDialog> createState() => _VirtualFittingDialogState();
}

class _VirtualFittingDialogState extends State<VirtualFittingDialog> {
  final _heightController = TextEditingController(text: '175');
  final _weightController = TextEditingController(text: '68');
  final _shoulderController = TextEditingController(text: '45');
  final _chestController = TextEditingController(text: '96');
  late final TextEditingController _itemNameController;

  final AiFittingService _fittingService = AiFittingService();

  bool _isLoading = false;
  FittingReportModel? _report;

  @override
  void initState() {
    super.initState();
    _itemNameController = TextEditingController(
      text: widget.defaultItemName ?? '베이지 니트',
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _shoulderController.dispose();
    _chestController.dispose();
    _itemNameController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerateReport() async {
    final height = double.tryParse(_heightController.text) ?? 175;
    final weight = double.tryParse(_weightController.text) ?? 68;
    final shoulder = double.tryParse(_shoulderController.text) ?? 45;
    final chest = double.tryParse(_chestController.text) ?? 96;
    final itemName = _itemNameController.text.trim();

    setState(() {
      _isLoading = true;
    });

    final report = await _fittingService.generateFittingReport(
      height: height,
      weight: weight,
      shoulder: shoulder,
      chest: chest,
      itemName: itemName,
      sizeChartInfo: 'S: Shoulder 42/Chest 90, M: Shoulder 45/Chest 96, L: Shoulder 48/Chest 102, XL: Shoulder 51/Chest 108',
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _report = report;
    });
  }

  Widget _buildFitBadge(String label, String value) {
    Color badgeColor = Colors.green;
    if (value.contains('Tight')) badgeColor = Colors.orange;
    if (value.contains('Loose')) badgeColor = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13, color: badgeColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.accessibility_new, color: AppColors.primary),
          SizedBox(width: 8),
          Text('AI 3D 가상 피팅 리포트'),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                labelText: '의류 명칭',
                hintText: '예: 베이지 니트',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '키 (cm)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '몸무게 (kg)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _shoulderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '어깨너비 (cm)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _chestController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '가슴둘레 (cm)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleGenerateReport,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_isLoading ? 'AI 3D 분석 중...' : '가상 피팅 시뮤레이션'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (_report != null) ...[
              const Divider(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '추천 사이즈: ${_report!.recommendedSize}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '적합도 ${_report!.fitScore}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildFitBadge('Shoulder', _report!.shoulderFit),
                        _buildFitBadge('Chest', _report!.chestFit),
                        _buildFitBadge('Length', _report!.lengthFit),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _report!.summary,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
