import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/cloth_item.dart';
import '../../services/background_removal_service.dart';
import '../../services/closet_service.dart';

class AddClothDialog extends StatefulWidget {
  final String userEmail;
  final Uint8List originalBytes;
  final Uint8List? processedBytes;

  const AddClothDialog({
    super.key,
    required this.userEmail,
    required this.originalBytes,
    this.processedBytes,
  });

  static Future<void> show({
    required BuildContext context,
    required String userEmail,
    required Uint8List originalBytes,
    Uint8List? processedBytes,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AddClothDialog(
        userEmail: userEmail,
        originalBytes: originalBytes,
        processedBytes: processedBytes,
      ),
    );
  }

  @override
  State<AddClothDialog> createState() => _AddClothDialogState();
}

class _AddClothDialogState extends State<AddClothDialog> {
  final ClosetService _closetService = ClosetService();
  final BackgroundRemovalService _bgRemovalService = BackgroundRemovalService();

  String _name = '';
  String _category = '상의';
  String _color = '';
  String _selectedRegion = 'top'; // 'top', 'bottom', 'full', 'original'
  bool _isProcessing = false;

  final Map<String, Uint8List> _regionCache = {};
  late Uint8List _activeImageBytes;

  @override
  void initState() {
    super.initState();
    if (widget.processedBytes != null) {
      _regionCache['top'] = widget.processedBytes!;
      _regionCache['full'] = widget.processedBytes!;
    }
    _activeImageBytes = widget.processedBytes ?? widget.originalBytes;
  }

  Future<void> _updateRegion(String region, String cat) async {
    if (region == 'original') {
      setState(() {
        _selectedRegion = 'original';
        _activeImageBytes = widget.originalBytes;
      });
      return;
    }

    final cacheKey = '${cat}_$region';
    if (_regionCache.containsKey(cacheKey)) {
      setState(() {
        _selectedRegion = region;
        _activeImageBytes = _regionCache[cacheKey]!;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _selectedRegion = region;
    });

    final Uint8List? result = await _bgRemovalService.cropAndRemoveBackground(
      widget.originalBytes,
      category: cat,
      cropRegion: region,
    );

    if (result != null) {
      _regionCache[cacheKey] = result;
    }

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      if (result != null) {
        _activeImageBytes = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('새 옷 정보 입력'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 150,
                  width: 150,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDarkMode
                        ? AppColors.darkContainerBackground
                        : Colors.grey[200],
                    image: DecorationImage(
                      image: MemoryImage(_activeImageBytes),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    height: 150,
                    width: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                const Text(
                  '✂️ 영역 선택 (전신/착샷/마네킹용)',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('상의만'),
                        selected: _selectedRegion == 'top',
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          if (selected) _updateRegion('top', _category);
                        },
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('하의만'),
                        selected: _selectedRegion == 'bottom',
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          if (selected) _updateRegion('bottom', _category);
                        },
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('전체 누끼'),
                        selected: _selectedRegion == 'full',
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          if (selected) _updateRegion('full', _category);
                        },
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('원본'),
                        selected: _selectedRegion == 'original',
                        selectedColor: Colors.grey.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          if (selected) _updateRegion('original', _category);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: '옷 이름',
                hintText: '예: 베이지 니트',
              ),
              onChanged: (value) => _name = value,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: '카테고리'),
              items: ['상의', '하의', '아우터', '신발/잡화']
                  .map(
                    (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _category = val);
                  if (val == '하의' && _selectedRegion != 'bottom') {
                    _updateRegion('bottom', val);
                  } else if ((val == '상의' || val == '아우터') && _selectedRegion != 'top') {
                    _updateRegion('top', val);
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: '색상',
                hintText: '예: 진청, 블랙, 아이보리',
              ),
              onChanged: (value) => _color = value,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_name.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('옷 이름을 입력해 주세요!'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            final finalColor = _color.trim().isEmpty ? '기타' : _color.trim();

            final newItem = ClothItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: _name,
              category: _category,
              color: finalColor,
            );

            try {
              await _closetService.addClothItem(
                userEmail: widget.userEmail,
                item: newItem,
                imageBytes: _activeImageBytes,
              );

              if (!context.mounted) return;
              Navigator.pop(context);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('옷 등록 중 오류가 발생했습니다: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('등록'),
        ),
      ],
    );
  }
}
