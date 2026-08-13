import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/community.dart';

/// 把 circleId 转成圈子名（基于本地默认圈子目录）。
String hupuCircleName(int id) {
  for (final c in DefaultCircles.list) {
    if (c['id'] == id) return c['name'] as String;
  }
  return '圈子';
}

/// 虎扑（Hupu）风帖子卡片。
///
/// 视觉要点：浅灰背景上的白色圆角卡片、暖橙红主色、醒目的「有用」投票、
/// 「热 / 报告」徽标、圈子 Chip、标题 + 2 行摘要 + 底部操作栏。
/// 「有用」为本地乐观交互（演示用，不调后端）。
class HupuPostCard extends StatefulWidget {
  final CommunityPost post;
  final VoidCallback? onTap;

  const HupuPostCard({Key? key, required this.post, this.onTap})
      : super(key: key);

  @override
  State<HupuPostCard> createState() => _HupuPostCardState();
}

class _HupuPostCardState extends State<HupuPostCard> {
  static const Color _primary = Color(0xFFE6431A);

  late int _litCount;
  late bool _lit;

  @override
  void initState() {
    super.initState();
    _litCount = widget.post.likeCount;
    _lit = false;
  }

  void _toggleLit() {
    setState(() {
      if (_lit) {
        _lit = false;
        _litCount -= 1;
      } else {
        _lit = true;
        _litCount += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final isHot = p.isPinned || p.likeCount > 100;
    final title = p.title?.isNotEmpty == true ? p.title! : p.content;
    final summary = p.title?.isNotEmpty == true ? p.content : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：圈子 Chip + 徽标
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _circleChip(hupuCircleName(p.circleId)),
                  if (isHot) _textBadge('热', _primary),
                  if (p.isShareReport)
                    _iconBadge('报告', Colors.indigo, Icons.insights),
                ],
              ),
              const SizedBox(height: 8),
              // 标题（加粗单行）
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // 正文摘要（2 行）
              if (summary.isNotEmpty)
                Text(
                  summary,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF616161),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 10),
              // 图片特殊样式：首图 banner + 多图角标
              if (p.images.isNotEmpty) _imageBanner(p.images),
              const SizedBox(height: 12),
              // 底部操作栏
              Row(
                children: [
                  _litButton(),
                  const SizedBox(width: 18),
                  _stat(Icons.chat_bubble_outline, '${p.commentCount}'),
                  const SizedBox(width: 18),
                  _stat(Icons.share_outlined, '${p.shareCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleChip(String name) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          name,
          style: const TextStyle(
            fontSize: 11,
            color: _primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  /// 首图 banner（圆角裁切），多图显示「+N」角标。
  Widget _imageBanner(List<String> images) {
    final first = images.first;
    final extra = images.length - 1;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            '${ApiConstants.baseUrl}$first',
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 180,
              color: Colors.grey.shade200,
              child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey)),
            ),
          ),
        ),
        if (extra > 0)
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('+${extra}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _textBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _iconBadge(String text, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  Widget _litButton() => TextButton(
        onPressed: _toggleLit,
        style: TextButton.styleFrom(
          foregroundColor: _lit ? _primary : const Color(0xFF757575),
          backgroundColor: _lit ? _primary.withOpacity(0.1) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb,
              size: 16,
              color: _lit ? _primary : const Color(0xFFBDBDBD),
            ),
            const SizedBox(width: 4),
            Text(
              '有用 $_litCount',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _lit ? _primary : const Color(0xFF757575),
              ),
            ),
          ],
        ),
      );

  Widget _stat(IconData icon, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF9E9E9E)),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
          ),
        ],
      );
}
