import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/constants.dart';
import '../models/paper.dart';

/// 高考倒计时卡片。距离 ≤100 天使用强化红色样式（PRD FR-CAL-001）。
class CountdownCard extends StatelessWidget {
  final int days;
  final String gaokaoDate;

  const CountdownCard(
      {Key? key, required this.days, required this.gaokaoDate})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final urgent = days <= 100;
    final color = urgent ? Colors.redAccent : Colors.indigo;
    return Card(
      color: color,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.timer, color: Colors.white, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '距离高考还有',
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$days',
                          style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const TextSpan(
                          text: ' 天',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '高考日期：$gaokaoDate',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 考试/日程卡片。
class ExamCard extends StatelessWidget {
  final String title;
  final String date;
  final String? subtitle;

  const ExamCard(
      {Key? key,
      required this.title,
      required this.date,
      this.subtitle})
      : super(key: key);

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.event, color: Colors.indigo),
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: Text(
            date,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
}

/// 三档知识点卡片（🔴🟡🟢）。
class KpLevelCard extends StatelessWidget {
  final ExamKpResult kp;

  const KpLevelCard({Key? key, required this.kp}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = Color(TierLevel.colorValue(kp.level));
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, radius: 8),
        title: Text(kp.knowledgeName),
        subtitle: Text(
            '错误率 ${(kp.errorRate * 100).toStringAsFixed(0)}% · '
            '${kp.wrongQuestions}/${kp.totalQuestions} 题'),
        trailing: Text(TierLevel.label(kp.level),
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// 统一日期格式化工具。
String formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
