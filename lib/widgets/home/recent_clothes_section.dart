import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/cloth_item.dart';
import '../cloth_thumbnail.dart';

class RecentClothesSection extends StatelessWidget {
  final List<ClothItem> items;
  final ValueChanged<int>? onTabChange;

  const RecentClothesSection({
    super.key,
    required this.items,
    this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최근 등록한 옷',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => onTabChange?.call(1),
              child: const Text(
                '전체보기',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        items.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '아직 등록된 옷이 없습니다.\n옷장 탭에서 새 옷을 등록해 보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            : SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      width: 100,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClothThumbnail(item: item, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }
}
