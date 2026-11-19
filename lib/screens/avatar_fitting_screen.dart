import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data' as typed_data;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import '../models/cloth_item.dart';
import '../services/ai_avatar_service.dart';
import '../widgets/cloth_thumbnail.dart';

class AvatarFittingScreen extends StatefulWidget {
  final List<ClothItem> clothes;
  final ClothItem? initialEquippedTop;
  final ClothItem? initialEquippedBottom;
  final ClothItem? initialEquippedOuter;
  final ClothItem? initialEquippedShoes;

  const AvatarFittingScreen({
    super.key,
    this.clothes = const [],
    this.initialEquippedTop,
    this.initialEquippedBottom,
    this.initialEquippedOuter,
    this.initialEquippedShoes,
  });

  @override
  State<AvatarFittingScreen> createState() => _AvatarFittingScreenState();
}

class _AvatarFittingScreenState extends State<AvatarFittingScreen> {
  final ImagePicker _picker = ImagePicker();
  final AiAvatarService _avatarService = AiAvatarService();

  typed_data.Uint8List? _customAvatarBytes;
  bool _isGeneratingAvatar = false;

  // 장착 중인 의상 아이템들
  ClothItem? _equippedTop;
  ClothItem? _equippedBottom;
  ClothItem? _equippedOuter;
  ClothItem? _equippedShoes;
  ClothItem? _equippedScarf;
  ClothItem? _equippedAccessory;

  String _selectedCategory = '전체';

  @override
  void initState() {
    super.initState();
    // 💡 AI 추천 코디를 통해 진입한 경우 초기 착용값 자동 등록
    _equippedTop = widget.initialEquippedTop;
    _equippedBottom = widget.initialEquippedBottom;
    _equippedOuter = widget.initialEquippedOuter;
    _equippedShoes = widget.initialEquippedShoes;
  }

  Future<void> _uploadUserPhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      setState(() {
        _isGeneratingAvatar = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ AI가 전신 사진을 분석하여 3D 아바타 모델을 생성 중입니다...'),
          backgroundColor: AppColors.primary,
        ),
      );

      final avatarBytes = await _avatarService.generateAvatarFromPhoto(bytes);

      if (!mounted) return;
      setState(() {
        _customAvatarBytes = avatarBytes;
        _isGeneratingAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 나만의 3D 피팅 아바타 생성이 완료되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _equipItem(ClothItem item) {
    setState(() {
      if (item.category == '상의') {
        _equippedTop = item;
      } else if (item.category == '하의') {
        _equippedBottom = item;
      } else if (item.category == '아우터') {
        _equippedOuter = item;
      } else if (item.category == '신발/잡화') {
        final title = item.title.toLowerCase();
        if (RegExp(r'목도리|스카프|머플러').hasMatch(title)) {
          _equippedScarf = item;
        } else if (RegExp(r'신발|운동화|구두|부츠|샌들|슬리퍼|sneaker|shoes?').hasMatch(title)) {
          _equippedShoes = item;
        } else {
          _equippedAccessory = item;
        }
      } else {
        _equippedTop = item;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✨ [${item.title}]을(를) 3D 아바타에 착용했습니다!'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleEquipItem(ClothItem item) {
    setState(() {
      if (item.category == '상의') {
        _equippedTop = (_equippedTop?.id == item.id) ? null : item;
      } else if (item.category == '하의') {
        _equippedBottom = (_equippedBottom?.id == item.id) ? null : item;
      } else if (item.category == '아우터') {
        _equippedOuter = (_equippedOuter?.id == item.id) ? null : item;
      } else if (item.category == '신발/잡화') {
        final title = item.title.toLowerCase();
        if (RegExp(r'목도리|스카프|머플러').hasMatch(title)) {
          _equippedScarf = (_equippedScarf?.id == item.id) ? null : item;
        } else if (RegExp(r'신발|운동화|구두|부츠|샌들|슬리퍼|sneaker|shoes?').hasMatch(title)) {
          _equippedShoes = (_equippedShoes?.id == item.id) ? null : item;
        } else {
          _equippedAccessory = (_equippedAccessory?.id == item.id) ? null : item;
        }
      } else {
        _equippedTop = (_equippedTop?.id == item.id) ? null : item;
      }
    });
  }

  void _resetOutfit() {
    setState(() {
      _equippedTop = null;
      _equippedBottom = null;
      _equippedOuter = null;
      _equippedShoes = null;
      _equippedScarf = null;
      _equippedAccessory = null;
    });
  }

  Widget _buildEquippedClothImageRelative(ClothItem? item, {
    required double top,
    required double left,
    required double width,
    required double height,
  }) {
    if (item == null) return const SizedBox.shrink();

    final child = _clothImage(item);
    if (child == null) return const SizedBox.shrink();

    final itemWidth = width * 300;
    final itemHeight = height * 440;

    return Positioned(
      top: (top * 440).clamp(0.0, 440 - itemHeight).toDouble(),
      left: (left * 300).clamp(0.0, 300 - itemWidth).toDouble(),
      width: itemWidth,
      height: itemHeight,
      child: child,
    );
  }

  Widget? _clothImage(ClothItem item) {
    if (item.imageBytes != null) {
      return Image.memory(item.imageBytes!, fit: BoxFit.contain);
    }
    final imageUrl = item.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, fit: BoxFit.contain);
    }
    try {
      return Image.memory(base64Decode(imageUrl), fit: BoxFit.contain);
    } catch (_) {
      return null;
    }
  }

  Widget _buildShoes(ClothItem item) {
    final shoe = _clothImage(item);
    if (shoe == null) return const SizedBox.shrink();
    final mirroredShoe = _clothImage(item)!;
    const groupWidth = 0.34;
    const groupHeight = 0.075;
    const left = 0.33 * 300;
    const top = 0.91 * 440;

    return Positioned(
      left: left.clamp(0.0, 300 - groupWidth * 300).toDouble(),
      top: top.clamp(0.0, 440 - groupHeight * 440).toDouble(),
      width: groupWidth * 300,
      height: groupHeight * 440,
      child: Row(
        children: [
          Expanded(child: shoe),
          Expanded(child: Transform.scale(scaleX: -1, child: mirroredShoe)),
        ],
      ),
    );
  }

  Widget _buildEquippedCloth(ClothItem? item) {
    if (item == null) return const SizedBox.shrink();
    final title = item.title.toLowerCase();
    if (RegExp(r'목도리|스카프|머플러').hasMatch(title)) {
      return _buildEquippedClothImageRelative(item, top: 0.16, left: 0.36, width: 0.28, height: 0.10);
    }
    if (RegExp(r'모자|캡|비니|hat|cap').hasMatch(title)) {
      return _buildEquippedClothImageRelative(item, top: 0.04, left: 0.37, width: 0.26, height: 0.12);
    }
    if (RegExp(r'가방|백팩|숄더백|bag|backpack').hasMatch(title)) {
      return _buildEquippedClothImageRelative(item, top: 0.30, left: 0.03, width: 0.23, height: 0.34);
    }
    if (RegExp(r'목걸이|넥타이|tie|necklace').hasMatch(title)) {
      return _buildEquippedClothImageRelative(item, top: 0.17, left: 0.40, width: 0.20, height: 0.24);
    }
    if (RegExp(r'벨트|허리띠|belt').hasMatch(title)) {
      return _buildEquippedClothImageRelative(item, top: 0.46, left: 0.24, width: 0.52, height: 0.08);
    }
    if (RegExp(r'양말|삭스|socks?').hasMatch(title)) {
      return _buildEquippedClothImageRelative(item, top: 0.82, left: 0.30, width: 0.40, height: 0.12);
    }
    if (RegExp(r'원피스|드레스|점프수트|롬퍼|dress|jumpsuit|romper').hasMatch(title)) {
      return _buildEquippedClothImageRelative(item, top: 0.18, left: 0.24, width: 0.52, height: 0.66);
    }
    if (item.category == '상의') {
      final isCropped = RegExp(r'크롭|cropped').hasMatch(title);
      return _buildEquippedClothImageRelative(item,
        top: isCropped ? 0.24 : 0.20, left: isCropped ? 0.27 : 0.21,
        width: isCropped ? 0.46 : 0.58, height: isCropped ? 0.22 : 0.34);
    }
    if (item.category == '하의') {
      final isShort = RegExp(r'반바지|숏츠|shorts').hasMatch(title);
      return _buildEquippedClothImageRelative(item,
        top: 0.49, left: 0.27, width: 0.46, height: isShort ? 0.22 : 0.43);
    }
    if (item.category == '아우터') {
      final isLong = RegExp(r'롱|코트|long|coat').hasMatch(title);
      return _buildEquippedClothImageRelative(item,
        top: 0.19, left: isLong ? 0.16 : 0.18,
        width: isLong ? 0.68 : 0.64, height: isLong ? 0.64 : 0.48);
    }
    if (item == _equippedShoes) {
      return _buildShoes(item);
    }
    return _buildEquippedClothImageRelative(item, top: 0.38, left: 0.64, width: 0.34, height: 0.28);
  }

  Widget _buildPaletteItemCard(ClothItem item, bool isEquipped, bool isDarkMode) {
    return Container(
      width: 116,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isEquipped
            ? AppColors.primary.withValues(alpha: 0.15)
            : (isDarkMode ? AppColors.darkContainerBackground : Colors.grey[100]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEquipped ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.black12 : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClothThumbnail(item: item, size: 78),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isEquipped ? FontWeight.bold : FontWeight.normal,
              color: isEquipped ? AppColors.primary : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.sizeOf(context);
    final avatarScale = math
        .min(
          1.35,
          math.min((screenSize.width - 48) / 300, (screenSize.height - 260) / 440),
        )
        .clamp(0.85, 1.35)
        .toDouble();

    final filteredClothes = _selectedCategory == '전체'
        ? widget.clothes
        : widget.clothes.where((c) => c.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('3D 아바타 피팅룸'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: '내 전신사진 업로드',
            onPressed: _uploadUserPhoto,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: '코디 초기화',
            onPressed: _resetOutfit,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🎮 3D 아바타 드래그 앤 드롭 피팅 스테이지 영역
            Expanded(
              child: DragTarget<ClothItem>(
                onWillAcceptWithDetails: (details) => true,
                onAcceptWithDetails: (details) => _equipItem(details.data),
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;

                  return Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isHovering
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : (isDarkMode ? AppColors.darkContainerBackground : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isHovering ? AppColors.primary : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 🧍 체형 가이드와 의상 레이어
                        Transform.scale(
                          scale: avatarScale,
                          child: SizedBox(
                            width: 300,
                            height: 440,
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                              // 1. 아바타 피규어 마네킹 또는 내 사진 기반 아바타
                              if (_isGeneratingAvatar)
                                const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(color: AppColors.primary),
                                      SizedBox(height: 16),
                                      Text('AI가 3D 아바타 모델을 합성 중입니다...'),
                                    ],
                                  ),
                                )
                              else if (_customAvatarBytes != null)
                                Image.memory(_customAvatarBytes!, width: 300, height: 440, fit: BoxFit.contain),
                              _buildEquippedCloth(_equippedBottom),
                              _buildEquippedCloth(_equippedTop),
                              _buildEquippedCloth(_equippedOuter),
                              _buildEquippedCloth(_equippedScarf),
                              _buildEquippedCloth(_equippedAccessory),
                              _buildEquippedCloth(_equippedShoes),
                              ],
                            ),
                          ),
                        ),

                        // 상단 현재 착용 정보 안내 태그
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '착용 중: ${_getEquippedSummary()}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        // 하단 드래그 안내 텍스트
                        Positioned(
                          bottom: 12,
                          child: Text(
                            '옷을 드래그하면 종류에 맞는 위치에 배치됩니다',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),

                        // 드래그 호버 시 안내 오버레이
                        if (isHovering)
                          Positioned(
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '✨ 놓으면 의상 종류에 맞춰 배치됩니다',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 🛍️ 하단 내 옷장 팔레트 (드래그 앤 드롭 지원)
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 카테고리 칩
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: ['전체', '상의', '하의', '아우터', '신발/잡화'].map((cat) {
                        final isSel = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(cat, style: const TextStyle(fontSize: 12)),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : (isDarkMode ? Colors.grey[300] : Colors.black87),
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedCategory = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // 내 옷장 옷 리스트 (드래그 앤 드롭 가능)
                  Expanded(
                    child: filteredClothes.isEmpty
                        ? const Center(
                            child: Text(
                              '해당 카테고리에 옷이 없습니다.\n옷장에 옷을 등록해 보세요!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            scrollDirection: Axis.horizontal,
                            itemCount: filteredClothes.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final item = filteredClothes[index];
                              final isEquipped = _isItemEquipped(item);

                              return Draggable<ClothItem>(
                                data: item,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Opacity(
                                    opacity: 0.85,
                                    child: Container(
                                      width: 110,
                                      height: 110,
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.primary, width: 2),
                                      ),
                                      child: ClothThumbnail(item: item, size: 88),
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _buildPaletteItemCard(item, isEquipped, isDarkMode),
                                ),
                                child: GestureDetector(
                                  onTap: () => _toggleEquipItem(item),
                                  child: _buildPaletteItemCard(item, isEquipped, isDarkMode),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isItemEquipped(ClothItem item) {
    return _equippedTop?.id == item.id ||
        _equippedBottom?.id == item.id ||
        _equippedOuter?.id == item.id ||
        _equippedShoes?.id == item.id ||
        _equippedScarf?.id == item.id ||
        _equippedAccessory?.id == item.id;
  }

  String _getEquippedSummary() {
    final items = <String>[];
    if (_equippedTop != null) items.add(_equippedTop!.title);
    if (_equippedBottom != null) items.add(_equippedBottom!.title);
    if (_equippedOuter != null) items.add(_equippedOuter!.title);
    if (_equippedShoes != null) items.add(_equippedShoes!.title);
    if (_equippedScarf != null) items.add(_equippedScarf!.title);
    if (_equippedAccessory != null) items.add(_equippedAccessory!.title);

    if (items.isEmpty) return '없음';
    return items.join(', ');
  }
}
