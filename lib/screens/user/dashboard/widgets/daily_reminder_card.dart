import 'package:flutter/material.dart';

import 'package:sawata/models/advice.dart';
import 'package:sawata/services/advice_service.dart';

enum _AdviceLoadState { loading, success, error }

class DailyReminderCard extends StatefulWidget {
  const DailyReminderCard({super.key});

  @override
  State<DailyReminderCard> createState() => _DailyReminderCardState();
}

class _DailyReminderCardState extends State<DailyReminderCard> {
  static const _mintBg = Color(0xFFDDEEE7);
  static const _darkGreen = Color(0xFF16332B);
  static const _mint = Color(0xFF2E7D6B);

  _AdviceLoadState _state = _AdviceLoadState.loading;
  Advice? _advice;

  @override
  void initState() {
    super.initState();
    _loadAdvice();
  }

  Future<void> _loadAdvice() async {
    setState(() => _state = _AdviceLoadState.loading);
    try {
      final advice = await AdviceService.fetchAdvice();
      if (!mounted) return;
      setState(() {
        _advice = advice;
        _state = _AdviceLoadState.success;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _AdviceLoadState.error);
    }
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _AdviceLoadState.loading:
        return Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _mint),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading reminder...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _darkGreen.withValues(alpha: 0.7)),
            ),
          ],
        );
      case _AdviceLoadState.error:
        return Text(
          "Unable to load today's reminder.",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: _darkGreen.withValues(alpha: 0.7)),
        );
      case _AdviceLoadState.success:
        return Text(
          '"${_advice!.advice}"',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _darkGreen,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _mintBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -8,
            child: Icon(
              Icons.eco_outlined,
              size: 90,
              color: _mint.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: _darkGreen,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Daily Recovery Reminder',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: _darkGreen,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'New',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: _mint,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _state == _AdviceLoadState.loading
                        ? null
                        : _loadAdvice,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 16, color: _mint),
                          const SizedBox(width: 4),
                          Text(
                            'New Advice',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: _mint,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildBody(context),
              const SizedBox(height: 8),
              Text(
                "Keep going, you've got this.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mint,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
