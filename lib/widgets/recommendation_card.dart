import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/outfit_recommendation.dart';

class RecommendationCard extends StatefulWidget {
  final OutfitRecommendation item;
  final VoidCallback onFavoriteToggle;

  const RecommendationCard({
    super.key,
    required this.item,
    required this.onFavoriteToggle,
  });

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildClothChip(Icons.checkroom, widget.item.top, isDarkMode),
                _buildClothChip(Icons.airline_seat_legroom_normal, widget.item.bottom, isDarkMode),
                if (widget.item.outer != '없음')
                  _buildClothChip(Icons.dry_cleaning, widget.item.outer, isDarkMode),
                _buildClothChip(Icons.downhill_skiing, widget.item.shoes, isDarkMode),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _isExpanded ? widget.item.aiReason : 'AI 추천 이유 보기',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
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
          ],
        ),
      ),
    );
  }

  Widget _buildClothChip(IconData icon, String label, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkCardBackground : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.grey[200] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
