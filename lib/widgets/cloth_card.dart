import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/cloth_item.dart';
import 'dialogs/virtual_fitting_dialog.dart';

class ClothCard extends StatefulWidget {
  final ClothItem item;
  final VoidCallback onDelete;
  final VoidCallback? onFavoriteToggle;

  static final Map<String, Uint8List> _base64Cache = {};

  const ClothCard({
    super.key,
    required this.item,
    required this.onDelete,
    this.onFavoriteToggle,
  });

  @override
  State<ClothCard> createState() => _ClothCardState();
}

class _ClothCardState extends State<ClothCard> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item.isFavorite;
  }

  @override
  void didUpdateWidget(covariant ClothCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.isFavorite != widget.item.isFavorite) {
      _isFavorite = widget.item.isFavorite;
    }
  }

  static Uint8List? _getDecodedBytes(String base64Str) {
    if (ClothCard._base64Cache.containsKey(base64Str)) {
      return ClothCard._base64Cache[base64Str];
    }
    try {
      final decoded = base64Decode(base64Str);
      ClothCard._base64Cache[base64Str] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Widget _buildImage(String? imageUrl, Uint8List? imageBytes, bool isDarkMode) {
    Widget imageWidget;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        imageWidget = Image.network(
          imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.broken_image,
                size: 36,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
              ),
            );
          },
        );
      } else {
        final bytes = _getDecodedBytes(imageUrl);
        if (bytes != null) {
          imageWidget = Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  Icons.broken_image,
                  size: 36,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                ),
              );
            },
          );
        } else {
          return Center(
            child: Icon(
              Icons.checkroom,
              size: 48,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
            ),
          );
        }
      }
    } else if (imageBytes != null) {
      imageWidget = Image.memory(
        imageBytes,
        fit: BoxFit.contain,
      );
    } else {
      return Center(
        child: Icon(
          Icons.checkroom,
          size: 48,
          color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(child: imageWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          VirtualFittingDialog.show(
            context: context,
            defaultItemName: widget.item.title,
          );
        },
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[200],
                    child: _buildImage(widget.item.imageUrl, widget.item.imageBytes, isDarkMode),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.item.category,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.accessibility_new,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.item.color.isNotEmpty && widget.item.color != '기타') ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.item.color,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (widget.onFavoriteToggle != null)
              Positioned(
                top: 6,
                left: 6,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isFavorite = !_isFavorite;
                    });
                    widget.onFavoriteToggle!();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey<bool>(_isFavorite),
                        color: _isFavorite ? AppColors.primary : Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: widget.onDelete,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
