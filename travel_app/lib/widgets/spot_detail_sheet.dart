import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/spot.dart';
import '../providers/spot_provider.dart';
import '../utils/app_theme.dart';
import '../utils/color_utils.dart';
import 'lightbox_widget.dart';

class SpotDetailSheet extends StatefulWidget {
  final String spotId;

  const SpotDetailSheet({super.key, required this.spotId});

  @override
  State<SpotDetailSheet> createState() => _SpotDetailSheetState();
}

class _SpotDetailSheetState extends State<SpotDetailSheet> {
  bool _editing = false;
  late TextEditingController _metaCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _catCtrl;

  @override
  void initState() {
    super.initState();
    final spot = context.read<SpotProvider>().getById(widget.spotId);
    _metaCtrl = TextEditingController(text: spot?.meta ?? '');
    _descCtrl = TextEditingController(text: spot?.desc ?? '');
    _catCtrl = TextEditingController(text: spot?.category ?? '打卡');
  }

  @override
  void dispose() {
    _metaCtrl.dispose();
    _descCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Spot spot) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 60);
    if (files.isEmpty) return;
    final provider = context.read<SpotProvider>();
    for (final f in files) {
      final bytes = await f.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${f.name} 超过2MB，已跳过')),
          );
        }
        continue;
      }
      final b64 = base64Encode(bytes);
      await provider.addPhoto(spot.id, b64);
    }
  }

  Future<void> _saveEdit(Spot spot) async {
    final updated = spot.copyWith(
      meta: _metaCtrl.text.trim(),
      desc: _descCtrl.text.trim(),
      category: _catCtrl.text.trim().isEmpty ? '打卡' : _catCtrl.text.trim(),
    );
    await context.read<SpotProvider>().updateSpot(updated);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SpotProvider>(
      builder: (context, provider, _) {
        final spot = provider.getById(widget.spotId);
        if (spot == null) return const SizedBox.shrink();

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${spot.emoji} ${spot.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6B9D),
                        ),
                      ),
                    ),
                    if (!_editing)
                      TextButton.icon(
                        onPressed: () => setState(() => _editing = true),
                        icon: const Text('✏️'),
                        label: const Text('编辑',
                            style: TextStyle(color: Color(0xFFC084FC))),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    if (spot.isCustom && !_editing)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _confirmDelete(context, spot),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                if (!_editing) ...[
                  // View mode
                  if (spot.meta.isNotEmpty)
                    Text(spot.meta,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  if (spot.desc.isNotEmpty)
                    Text(spot.desc,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF555555),
                            height: 1.5)),
                  const SizedBox(height: 8),
                  _CategoryChip(category: spot.category),
                ] else ...[
                  // Edit mode
                  _buildLabel('距离/时间'),
                  _buildTextField(_metaCtrl, '如：往返 4.8km · 14分钟'),
                  _buildLabel('分类'),
                  _buildTextField(_catCtrl, '如：打卡、美食、住宿'),
                  _buildLabel('描述'),
                  _buildTextField(_descCtrl, '景点描述…', maxLines: 3),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _saveEdit(spot),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.purple),
                        child: const Text('💾 保存',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _editing = false),
                        child: const Text('取消'),
                      ),
                    ),
                  ]),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Photo section
                _PhotoSection(
                  spot: spot,
                  onAddPhoto: () => _pickImage(spot),
                  onDeletePhoto: (idx) =>
                      provider.deletePhoto(spot.id, idx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(text,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      );

  Widget _buildTextField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFE0D0FF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFC084FC)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
      );

  Future<void> _confirmDelete(BuildContext context, Spot spot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除地点'),
        content: Text('确认删除「${spot.name}」？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<SpotProvider>().deleteSpot(spot.id);
      Navigator.pop(context);
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE9D5FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category,
        style: const TextStyle(
            color: Color(0xFF6D28D9), fontSize: 12),
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final Spot spot;
  final VoidCallback onAddPhoto;
  final void Function(int) onDeletePhoto;

  const _PhotoSection({
    required this.spot,
    required this.onAddPhoto,
    required this.onDeletePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final photos = spot.photoBase64;

    if (photos.isEmpty) {
      return GestureDetector(
        onTap: onAddPhoto,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 2),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_camera_outlined,
                    size: 40, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('点击添加打卡照片',
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${photos.length} 张打卡照',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _PhotoThumb(
              base64Str: photos[i],
              onTap: () => _openLightbox(context, photos, i),
              onDelete: () => onDeletePhoto(i),
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onAddPhoto,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('＋ 添加更多照片',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 12)),
          ),
        ),
      ],
    );
  }

  void _openLightbox(
      BuildContext context, List<String> photos, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) => LightboxWidget(photos: photos, initialIndex: index),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String base64Str;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PhotoThumb({
    required this.base64Str,
    required this.onTap,
    required this.onDelete,
  });

  Uint8List _decode() => base64Decode(base64Str);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _decode(),
              width: 160,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 160,
                height: 180,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
