import 'package:flutter/material.dart';
import '../models/task_model.dart';

class TaskRewardDialog extends StatelessWidget {
  final TaskModel task;

  const TaskRewardDialog({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2C1930),
                Color(0xFF191024),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // أيقونة الاحتفال
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8800)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8800).withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 16),

              // العنوان
              const Text(
                'مبروك! تم إنجاز المهمة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                task.titleAr.isNotEmpty ? task.titleAr : task.titleEn,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),

              // قائمة المكافآت المستلمة
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (task.coinsReward > 0)
                      _buildRewardChip(
                        icon: '🪙',
                        title: '+${task.coinsReward}',
                        subtitle: 'عملات',
                        color: const Color(0xFFFFD700),
                      ),
                    if (task.expReward > 0)
                      _buildRewardChip(
                        icon: '⭐',
                        title: '+${task.expReward}',
                        subtitle: 'خبرة EXP',
                        color: const Color(0xFF64B5F6),
                      ),
                    if (task.storeItemName != null && task.storeItemName!.isNotEmpty)
                      _buildRewardChip(
                        icon: '🎁',
                        title: task.storeItemName!,
                        subtitle: 'عنصر حقيبة',
                        color: const Color(0xFFFF4081),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // زر التأكيد والمطالبة
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8800)],
                    ),
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8800).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'رائع! استلام الجائزة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C1930),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardChip({
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: Colors.white54),
        ),
      ],
    );
  }
}
