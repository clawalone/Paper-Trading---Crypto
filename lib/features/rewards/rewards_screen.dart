import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../data/user_provider.dart';
import '../../data/models.dart';
import '../learn/quiz_screen.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final profile = userState.profile;

    final currentLevel = (profile.xp ~/ 250) + 1;
    final xpForNextLevel = currentLevel * 250;
    final xpIntoCurrentLevel = profile.xp % 250;
    final rankName = currentLevel >= 5 ? 'Strategy Captain' : 'Rookie Trader';
    final progress = xpIntoCurrentLevel / 250.0;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final quizAttemptedToday = profile.lastQuizAttempt != null && profile.lastQuizAttempt!.startsWith(todayStr);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Rewards Hub', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // ── HERO RANK CARD ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF3BA2F), Color(0xFFE0A800)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFF3BA2F).withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                        child: const Icon(Icons.military_tech, size: 40, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Level $currentLevel • $rankName', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 14)),
                            Text('${profile.xp} XP', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 32)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Progress to next rank', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 12)),
                      Text('${xpForNextLevel - profile.xp} XP needed', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.black26,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── DAILY CHECK IN ──────────────────────────────────────────────────
            const Text('Daily Check-In', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2329),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2B3139)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Streak', style: TextStyle(color: Color(0xFF848E9C), fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 20),
                              const SizedBox(width: 4),
                              Text('${profile.streak} Days', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: userState.hasClaimedDaily ? null : () {
                              ref.read(userProvider.notifier).claimDailyReward();
                              final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claimed! +${formatter.format(1000)} & +30 XP'), backgroundColor: AppColors.profit));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: userState.hasClaimedDaily ? const Color(0xFF2B3139) : AppColors.primary,
                              foregroundColor: userState.hasClaimedDaily ? const Color(0xFF848E9C) : Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: Text(userState.hasClaimedDaily ? 'Claimed' : 'Claim Today', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── TASK CENTER ─────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Task Center', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Earn XP', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            ...userState.missions.map((m) {
              final safeTarget = m.target <= 0 ? 1 : m.target;
              final progressPercent = (m.progress / safeTarget).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: m.completed ? AppColors.profit.withOpacity(0.05) : const Color(0xFF1E2329),
                  borderRadius: BorderRadius.circular(16),
                  border: m.completed ? Border.all(color: AppColors.profit.withOpacity(0.3)) : null,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: m.completed ? AppColors.profit.withOpacity(0.15) : const Color(0xFF2B3139),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(m.completed ? Icons.check_circle : Icons.flag_outlined,
                              color: m.completed ? AppColors.profit : const Color(0xFF848E9C), size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.title, style: TextStyle(
                                color: m.completed ? Colors.white : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              )),
                              const SizedBox(height: 4),
                              Text('+${m.reward} XP', style: TextStyle(
                                color: m.completed ? AppColors.profit : AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              )),
                            ],
                          ),
                        ),
                        if (m.completed)
                          GestureDetector(
                            onTap: () => ref.read(userProvider.notifier).claimMission(m.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF3BA2F), Color(0xFFE0A800)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFFF3BA2F).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: const Text('Claim!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                          )
                        else
                          Text('${m.progress}/${m.target}', style: const TextStyle(color: Color(0xFF848E9C), fontWeight: FontWeight.w700)),
                      ],
                    ),
                    if (!m.completed) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: const Color(0xFF2B3139),
                          color: AppColors.primary,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              );
            }),
            
            // Learning Quiz Card
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2329),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.school, color: Colors.blueAccent, size: 20),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Learning Quiz', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Complete for +120 XP', style: TextStyle(color: Color(0xFF848E9C), fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: quizAttemptedToday ? null : () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizScreen()));
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: quizAttemptedToday ? Colors.grey : Colors.blueAccent),
                          borderRadius: BorderRadius.circular(8),
                          color: quizAttemptedToday ? Colors.grey.withValues(alpha: 0.1) : Colors.transparent,
                        ),
                        child: Text(quizAttemptedToday ? 'Done' : 'Start', style: TextStyle(color: quizAttemptedToday ? Colors.grey : Colors.blueAccent, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // ── ACHIEVEMENTS (BADGES) ──────────────────────────────────────────
            const Text('Achievements', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: ALL_BADGES.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemBuilder: (context, index) {
                final badge = ALL_BADGES[index];
                final isUnlocked = profile.unlockedBadges.contains(badge.id);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUnlocked ? AppColors.primary.withOpacity(0.05) : const Color(0xFF1E2329),
                    border: Border.all(color: isUnlocked ? AppColors.primary.withOpacity(0.3) : const Color(0xFF2B3139)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(badge.icon, style: TextStyle(fontSize: 24, color: isUnlocked ? null : Colors.grey)),
                          if (isUnlocked)
                            const Icon(Icons.check_circle, color: AppColors.primary, size: 16)
                          else
                            const Icon(Icons.lock, color: Color(0xFF4B5563), size: 16),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        badge.title,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white : const Color(0xFF848E9C),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badge.description,
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
