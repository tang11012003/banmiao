import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../models/paper.dart';
import 'paper_report_page.dart';

/// 确认错题中间页：展示 OCR 识别结果，允许用户修正对/错标注后再生成报告。
class PaperConfirmPage extends StatefulWidget {
  final OcrScanResult scanResult;
  final Uint8List? imageBytes;
  final String subject;
  final String? examName;
  final int? studentId;

  const PaperConfirmPage({
    Key? key,
    required this.scanResult,
    this.imageBytes,
    required this.subject,
    this.examName,
    this.studentId,
  }) : super(key: key);

  @override
  State<PaperConfirmPage> createState() => _PaperConfirmPageState();
}

class _PaperConfirmPageState extends State<PaperConfirmPage> {
  late List<_QuestionState> _questions;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _questions = widget.scanResult.questions.map((q) {
      return _QuestionState(
        questionNum: q.questionNum,
        isWrong: q.status == 'wrong' || q.status == 'half',
        isNew: false,
      );
    }).toList();
  }

  int get _wrongCount => _questions.where((q) => q.isWrong).length;

  void _toggle(int index) {
    setState(() {
      _questions[index].isWrong = !_questions[index].isWrong;
    });
  }

  void _addQuestion() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加题号'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '输入题号，如 16',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final num = int.tryParse(controller.text.trim());
              if (num == null || num <= 0) return;
              final exists = _questions.any((q) => q.questionNum == num);
              if (exists) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('题号 $num 已存在')),
                );
                return;
              }
              setState(() {
                _questions.add(_QuestionState(
                  questionNum: num,
                  isWrong: true,
                  isNew: true,
                ));
                _questions.sort((a, b) => a.questionNum.compareTo(b.questionNum));
              });
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      final items = _questions.map((q) => <String, dynamic>{
        'question_num': q.questionNum,
        'status': q.isWrong ? 'wrong' : 'correct',
        'is_new': q.isNew,
      }).toList();

      final paper = await context.read<ApiClient>().confirmPaper(
        paperId: widget.scanResult.paperId,
        subject: widget.subject,
        examName: widget.examName,
        studentId: widget.studentId,
        items: items,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PaperReportPage(paperId: paper.id),
        ));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showImagePreview() {
    if (widget.imageBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(widget.imageBytes!, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _questions.length;
    return Scaffold(
      appBar: AppBar(title: const Text('确认错题信息')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 图片预览区
                if (widget.imageBytes != null)
                  GestureDetector(
                    onTap: _showImagePreview,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(widget.imageBytes!, fit: BoxFit.cover),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('点击放大',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // 统计行
                Text(
                  '共识别出 $total 道题，算法判断错题 ${widget.scanResult.wrongCount} 道',
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
                if (_wrongCount != widget.scanResult.wrongCount)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '当前标记错题 $_wrongCount 道',
                      style: TextStyle(
                          fontSize: 13, color: Colors.orange.shade700),
                    ),
                  ),
                const SizedBox(height: 16),

                // 题号网格
                const Text('点击切换对/错状态：',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ..._questions.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final q = entry.value;
                      final isWrong = q.isWrong;
                      return GestureDetector(
                        onTap: () => _toggle(idx),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isWrong
                                ? const Color(0xFFE53935)
                                : const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(20),
                            border: q.isNew
                                ? Border.all(
                                    color: Colors.orange, width: 2)
                                : null,
                          ),
                          child: Text(
                            '${q.questionNum}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isWrong ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }),
                    // 添加按钮
                    GestureDetector(
                      onTap: _addQuestion,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 48),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: const Icon(Icons.add, size: 18, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  total == 0
                      ? '未识别到题目，请手动添加'
                      : '红色=错题  灰色=正确  橙框=手动添加',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // 吸底操作栏
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '确认无误后将生成知识点诊断报告',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6D00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      _submitting ? '正在生成报告…' : '确认并生成报告',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionState {
  final int questionNum;
  bool isWrong;
  final bool isNew;

  _QuestionState({
    required this.questionNum,
    required this.isWrong,
    required this.isNew,
  });
}
