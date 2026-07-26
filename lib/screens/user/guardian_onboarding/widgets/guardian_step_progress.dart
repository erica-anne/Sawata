import 'package:flutter/material.dart';

/// 4-step progress indicator for the Add Guardian wizard: numbered circles
/// connected by lines, with a label under each step.
class GuardianStepProgress extends StatelessWidget {
  const GuardianStepProgress({super.key, required this.currentStep});

  /// 0-based index of the active step.
  final int currentStep;

  static const _steps = ['Guardian Info', 'Review', 'Invite', 'Done'];

  static const _accent = Color(0xFF2E7D6B);
  static const _muted = Color(0xFF8EA198);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Divider(
                          height: 2,
                          thickness: 2,
                          color: i <= currentStep
                              ? _accent
                              : const Color(0xFFDDE5E1),
                        ),
                      ),
                    _StepCircle(
                      number: i + 1,
                      state: i < currentStep
                          ? _StepState.done
                          : i == currentStep
                          ? _StepState.active
                          : _StepState.upcoming,
                    ),
                    if (i < _steps.length - 1)
                      Expanded(
                        child: Divider(
                          height: 2,
                          thickness: 2,
                          color: i < currentStep
                              ? _accent
                              : const Color(0xFFDDE5E1),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == currentStep
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: i == currentStep ? _accent : _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

enum _StepState { done, active, upcoming }

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.number, required this.state});

  final int number;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final isFilled =
        state == _StepState.done || state == _StepState.active;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isFilled ? GuardianStepProgress._accent : Colors.white,
        shape: BoxShape.circle,
        border: isFilled
            ? null
            : Border.all(color: const Color(0xFFDDE5E1), width: 1.5),
      ),
      alignment: Alignment.center,
      child: state == _StepState.done
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: state == _StepState.active
                    ? Colors.white
                    : GuardianStepProgress._muted,
              ),
            ),
    );
  }
}
