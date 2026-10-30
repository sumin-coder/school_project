import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/cloth_item.dart';
import '../models/outfit_recommendation.dart';
import '../screens/avatar_fitting_screen.dart';
import 'cloth_thumbnail.dart';

class RecommendationCard extends StatefulWidget {
  final OutfitRecommendation item;
  final List<ClothItem> clothes;
  final VoidCallback onFavoriteToggle;

  const RecommendationCard({
    super.key,
    required this.item,
    this.clothes = const [],
    required this.onFavoriteToggle,
  });

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard> {
  bool _isExpanded = false;

  ClothItem? _findClothByTitle(String title) {
    if (title.isEmpty || title == '없음') return null;
    final cleanTitle = title.trim().toLowerCase();
    for (final c in widget.clothes) {
      final name = c.title.trim().toLowerCase();
      if (name == cleanTitle || name.contains(cleanTitle) || cleanTitle.contains(name)) {
        return c;
      }
    }
    return null;
  }

  void _navigateToAvatarFittingRoom(BuildContext context) {
    final topItem = _findClothByTitle(widget.item.top);
    final bottomItem = _findClothByTitle(widget.item.bottom);
    final outerItem = _findClothByTitle(widget.item.outer);
    final shoesItem = _findClothByTitle(widget.item.shoes);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarFittingScreen(
          clothes: widget.clothes,
          initialEquippedTop: topItem,
          initialEquippedBottom: bottomItem,
          initialEquippedOuter: outerItem,
          initialEquippedShoes: shoesItem,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🏷️ 헤더: TPO 태그 + 코디 제목 + 찜 버튼
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${widget.item.tpo}',
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
                    widget.item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    widget.item.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: widget.item.isFavorite
                        ? AppColors.primary
                        : (isDarkMode ? Colors.grey[400] : Colors.grey[500]),
                  ),
                  onPressed: widget.onFavoriteToggle,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 🖼️ 실제 옷 사진이 보이는 가로 아이템 카드리스트
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildOutfitItemCard('상의', widget.item.top, Icons.checkroom, isDarkMode),
                  const SizedBox(width: 8),
                  _buildOutfitItemCard('하의', widget.item.bottom, Icons.airline_seat_legroom_normal, isDarkMode),
                  if (widget.item.outer.isNotEmpty && widget.item.outer != '없음') ...[
                    const SizedBox(width: 8),
                    _buildOutfitItemCard('아우터', widget.item.outer, Icons.dry_cleaning, isDarkMode),
                  ],
                  if (widget.item.shoes.isNotEmpty && widget.item.shoes != '없음') ...[
                    const SizedBox(width: 8),
                    _buildOutfitItemCard('신발', widget.item.shoes, Icons.downhill_skiing, isDarkMode),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ✨ AI 코디 추천 이유 (접기/펼치기)
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isExpanded ? widget.item.aiReason : 'AI 추천 이유 보기',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                          height: 1.3,
                        ),
                        maxLines: _isExpanded ? null : 1,
                        overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 🎮 3D 아바타 피팅룸 바로 이동 및 착용 버튼
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToAvatarFittingRoom(context),
                icon: const Icon(Icons.sports_esports, size: 18),
                label: const Text('🎮 3D 아바타에서 입어보기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutfitItemCard(
    String categoryLabel,
    String clothTitle,
    IconData fallbackIcon,
    bool isDarkMode,
  ) {
    if (clothTitle.isEmpty || clothTitle == '없음') {
      return const SizedBox.shrink();
    }

    final matchedCloth = _findClothByTitle(clothTitle);

    return InkWell(
      onTap: () => _navigateToAvatarFittingRoom(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkCardBackground : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                categoryLabel,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (matchedCloth != null)
              ClothThumbnail(item: matchedCloth, size: 52)
            else
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  fallbackIcon,
                  size: 26,
                  color: AppColors.primary,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              clothTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey[200] : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
