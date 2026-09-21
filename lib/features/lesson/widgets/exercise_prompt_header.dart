import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// A prompt split into what to do and what to do it to.
class PromptParts {
  const PromptParts({required this.instruction, this.content});

  /// The kind of question, e.g. "Complete the sentence" or "Hiiki".
  final String instruction;

  /// The question itself, e.g. "I want coffee"; `null` when the prompt is
  /// only an instruction.
  final String? content;
}

/// Seeded prompts read `Instruction: 'content'` in every course language
/// ("Complete the sentence: 'I want coffee'", "Hiiki: 'Buna maaloo'"), so
/// the two halves can be shown on their own lines. Any other shape is kept
/// whole as the instruction.
PromptParts splitPrompt(String prompt) {
  final match = _instructionThenQuoted.firstMatch(prompt.trim());
  if (match == null) return PromptParts(instruction: prompt.trim());
  return PromptParts(
    instruction: match.group(1)!.trim(),
    content: match.group(2)!.trim(),
  );
}

final _instructionThenQuoted = RegExp(r'''^(.+?):\s*["'‘“](.+)["'’”]$''');

/// The top of an exercise: the kind of question on one line, and the
/// question itself on its own line below it, larger and bold.
class ExercisePromptHeader extends StatelessWidget {
  const ExercisePromptHeader({super.key, required this.parts});

  final PromptParts parts;

  @override
  Widget build(BuildContext context) {
    final content = parts.content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.instruction,
          style: content == null
              ? AppTypography.headlineMd.copyWith(color: AppColors.onSurface)
              : AppTypography.labelLg.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
        ),
        if (content != null) ...[
          const SizedBox(height: AppSpacing.space2xs),
          Text(
            content,
            style: AppTypography.headlineMd.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
