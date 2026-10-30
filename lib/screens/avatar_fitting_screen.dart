import 'dart:convert';
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
        _equippedShoes = item;
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
        _equippedShoes = (_equippedShoes?.id == item.id) ? null : item;
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
    });
  }

  Widget _buildEquippedClothImage(ClothItem? item, double top, double left, double width, double height) {
    if (item == null) return const SizedBox.shrink();

    Widget? child;
    if (item.imageBytes != null) {
      child = Image.memory(item.imageBytes!, fit: BoxFit.contain);
    } else if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      if (item.imageUrl!.startsWith('http')) {
        child = Image.network(item.imageUrl!, fit: BoxFit.contain);
      } else {
        try {
          final decoded = base64Decode(item.imageUrl!);
          child = Image.memory(decoded, fit: BoxFit.contain);
        } catch (_) {}
      }
    }

    if (child == null) return const SizedBox.shrink();

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: child,
    );
  }

  Widget _buildPaletteItemCard(ClothItem item, bool isEquipped, bool isDarkMode) {
    return Container(
      width: 90,
      padding: const EdgeInsets.all(6),
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
          ClothThumbnail(item: item, size: 48),
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

    final filteredClothes = _selectedCategory == '전체'
        ? widget.clothes
        : widget.clothes.where((c) => c.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_esports, color: AppColors.primary),
            SizedBox(width: 8),
            Text('3D 아바타 피팅룸'),
          ],
        ),
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
                        // 배경 네온 그리드 스팟
                        Positioned(
                          bottom: 20,
                          child: Container(
                            width: 220,
                            height: 35,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: const BorderRadius.all(Radius.elliptical(220, 35)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 아바타 피규어 이미지 (내 사진 업로드 기반 또는 기본 3D 아바타)
                        if (_isGeneratingAvatar)
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: AppColors.primary),
                              SizedBox(height: 16),
                              Text('AI가 3D 아바타 모델을 합성하고 있습니다...'),
                            ],
                          )
                        else if (_customAvatarBytes != null)
                          Image.memory(_customAvatarBytes!, height: 420, fit: BoxFit.contain)
                        else
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.accessibility_new,
                                size: 260,
                                color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '하단 옷장의 옷을 드래그해서 아바타에 놓아보세요!\n(상단 📷 버튼으로 내 전신 사진을 올릴 수도 있습니다)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),

                        // 👗 아바타 레이어 위 장착된 의상 오버레이
                        _buildEquippedClothImage(_equippedShoes, 320, 80, 140, 70),
                        _buildEquippedClothImage(_equippedBottom, 200, 70, 160, 140),
                        _buildEquippedClothImage(_equippedTop, 100, 75, 150, 130),
                        _buildEquippedClothImage(_equippedOuter, 90, 60, 180, 150),

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
                                '✨ 손을 놓으면 아바타에 착용됩니다!',
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
                                      width: 85,
                                      height: 85,
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.primary, width: 2),
                                      ),
                                      child: ClothThumbnail(item: item, size: 60),
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
        _equippedShoes?.id == item.id;
  }

  String _getEquippedSummary() {
    final items = <String>[];
    if (_equippedTop != null) items.add(_equippedTop!.title);
    if (_equippedBottom != null) items.add(_equippedBottom!.title);
    if (_equippedOuter != null) items.add(_equippedOuter!.title);
    if (_equippedShoes != null) items.add(_equippedShoes!.title);

    if (items.isEmpty) return '없음';
    return items.join(', ');
  }
}
