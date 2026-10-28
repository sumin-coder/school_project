import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import '../models/cloth_item.dart';
import '../widgets/cloth_card.dart';
import '../widgets/dialogs/add_cloth_dialog.dart';
import '../widgets/dialogs/api_key_dialog.dart';
import '../widgets/dialogs/confirm_delete_dialog.dart';
import '../widgets/sheets/image_source_sheet.dart';
import '../services/closet_service.dart';
import '../services/background_removal_service.dart';

class ClosetScreen extends StatefulWidget {
  final String userEmail;

  const ClosetScreen({super.key, required this.userEmail});

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  final ImagePicker _picker = ImagePicker();
  final ClosetService _closetService = ClosetService();
  final BackgroundRemovalService _bgRemovalService = BackgroundRemovalService();

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final originalBytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      _showLoadingDialog('⚡ 100% 무료 초고속 배경 제거 중...');

      Uint8List? processedBytes;
      try {
        processedBytes = await _bgRemovalService.removeBackground(originalBytes);
      } catch (e) {
        debugPrint('배경 제거 처리 실패: $e');
      }

      if (!mounted) return;
      Navigator.pop(context); // 로딩 팝업 닫기

      if (processedBytes != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ 100% 무료 초고속 배경 제거가 적용되었습니다!'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('배경 제거 처리 중 문제가 발생하여 원본 이미지를 채택합니다.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      AddClothDialog.show(
        context: context,
        userEmail: widget.userEmail,
        originalBytes: originalBytes,
        processedBytes: processedBytes,
      );
    }
  }

  void _showImageSourceSelector() {
    ImageSourceSheet.show(
      context: context,
      onSourceSelected: _pickImage,
      onApiKeySelected: () => ApiKeyDialog.show(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('스마트 옷장'),
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              tooltip: '배경 제거 API 키 설정',
              onPressed: () => ApiKeyDialog.show(context),
            ),
          ],
          bottom: TabBar(
            tabAlignment: TabAlignment.start,
            isScrollable: true,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            tabs: const [
              Tab(text: '전체'),
              Tab(icon: Icon(Icons.favorite, size: 16), text: '즐겨찾기'),
              Tab(text: '상의'),
              Tab(text: '하의'),
              Tab(text: '아우터'),
              Tab(text: '신발/잡화'),
            ],
          ),
        ),
        body: StreamBuilder<List<ClothItem>>(
          stream: _closetService.getClothesStream(widget.userEmail),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final clothes = snapshot.data ?? [];

            return TabBarView(
              children: [
                _buildClothingGrid('전체', clothes, isDarkMode),
                _buildClothingGrid('즐겨찾기', clothes, isDarkMode),
                _buildClothingGrid('상의', clothes, isDarkMode),
                _buildClothingGrid('하의', clothes, isDarkMode),
                _buildClothingGrid('아우터', clothes, isDarkMode),
                _buildClothingGrid('신발/잡화', clothes, isDarkMode),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showImageSourceSelector,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('옷 추가'),
        ),
      ),
    );
  }

  Widget _buildClothingGrid(
    String category,
    List<ClothItem> allClothes,
    bool isDarkMode,
  ) {
    final filteredList = category == '전체'
        ? allClothes
        : category == '즐겨찾기'
            ? allClothes.where((item) => item.isFavorite).toList()
            : allClothes.where((item) => item.category == category).toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category == '즐겨찾기' ? Icons.favorite_border : Icons.checkroom,
              size: 64,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              category == '즐겨찾기'
                  ? '즐겨찾기(찜)한 옷이 없습니다.\n하트 버튼을 눌러 관심 옷을 추가해 보세요!'
                  : '등록된 $category(이)가 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final item = filteredList[index];
        return ClothCard(
          key: ValueKey(item.id),
          item: item,
          onDelete: () => ConfirmDeleteDialog.show(
            context: context,
            userEmail: widget.userEmail,
            item: item,
          ),
          onFavoriteToggle: () async {
            await _closetService.toggleFavorite(
              userEmail: widget.userEmail,
              clothId: item.id,
              isFavorite: !item.isFavorite,
            );
          },
        );
      },
    );
  }
}
