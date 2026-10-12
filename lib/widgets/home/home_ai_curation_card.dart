import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/cloth_item.dart';
import '../../models/outfit_recommendation.dart';
import '../cloth_thumbnail.dart';

class HomeAiCurationCard extends StatelessWidget {
  final OutfitRecommendation? recommendation;
  final List<ClothItem> recentItems;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final ValueChanged<int>? onTabChange;

  const HomeAiCurationCard({
    super.key,
    required this.recommendation,
    required this.recentItems,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    this.onTabChange,
  });

  ClothItem? _findClothItemByTitle(String title) {
    if (title.isEmpty || title == '없음') return null;
    try {
      final cleanTitle = title.trim().toLowerCase();
      return recentItems.firstWhere(
        (item) =>
            item.title.trim().toLowerCase() == cleanTitle ||
            cleanTitle.contains(item.title.trim().toLowerCase()) ||
            item.title.trim().toLowerCase().contains(cleanTitle),
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildOutfitItemChip(
    String label,
    String clothTitle,
    IconData defaultIcon,
    bool isDarkMode,
  ) {
    if (clothTitle.isEmpty || clothTitle == '없음') {
      return const SizedBox.shrink();
    }

    final ClothItem? matchedItem = _findClothItemByTitle(clothTitle);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkCardBackground : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (matchedItem != null)
            ClothThumbnail(item: matchedItem, size: 28)
          else
            Icon(
              defaultIcon,
              size: 18,
              color: AppColors.primary,
            ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                clothTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.grey[200] : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'AI가 오늘 날씨와 옷장을 분석하여 코디를 생성 중입니다...',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (recentItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Icon(Icons.checkroom, size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              '아직 옷장에 등록된 옷이 없습니다.\n새 옷을 추가하면 AI가 오늘 날씨에 딱 맞는 코디를 추천해 드립니다!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => onTabChange?.call(1),
              icon: const Icon(Icons.add),
              label: const Text('옷장에서 옷 추가하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null || recommendation == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome, size: 40, color: Colors.orangeAccent),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? '추천 코디를 불러올 수 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              label: const Text('다시 추천받기', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    }

    final item = recommendation!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${item.tpo}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: Colors.amber),
                      SizedBox(width: 4),
                      Text(
                        'AI 추천',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOutfitItemChip('상의', item.top, Icons.checkroom, isDarkMode),
                _buildOutfitItemChip('하의', item.bottom, Icons.airline_seat_legroom_normal, isDarkMode),
                if (item.outer.isNotEmpty && item.outer != '없음')
                  _buildOutfitItemChip('아우터', item.outer, Icons.dry_cleaning, isDarkMode),
                if (item.shoes.isNotEmpty && item.shoes != '없음')
                  _buildOutfitItemChip('신발', item.shoes, Icons.downhill_skiing, isDarkMode),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.aiReason,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  tooltip: '다른 코디 제안받기',
                  onPressed: onRefresh,
                ),
                TextButton.icon(
                  onPressed: () => onTabChange?.call(2),
                  icon: const Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                  label: const Text(
                    '더 많은 AI 코디 보기',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
