import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../widgets/exercise/answer_action_bar.dart';
import '../widgets/exercise/answer_slot_line.dart';
import '../widgets/exercise/answer_tile.dart';
import '../widgets/exercise/audio_play_button.dart';
import '../widgets/exercise/exercise_layout.dart';
import 'component_gallery.dart';
import 'gallery_surfaces.dart';

void _noop() {}

/// The question kit: the frame, the prompt, the answer tile in every state
/// and shape, the play button, the answer line and the action bar, with
/// small working demos where the state changes under a finger.
class ExerciseGallerySection extends StatelessWidget {
  const ExerciseGallerySection({super.key});

  @override
  Widget build(BuildContext context) {
    return const GallerySection(
      title: 'Question kit',
      note:
          'Every question type is built from these pieces, so the top bar, '
          'prompt, tiles and bottom button look and move the same in all of '
          'them.',
      children: [
        GalleryCase(
          label: 'ExerciseLayout: tap an answer (the first is right)',
          child: GalleryPhoneFrame(child: _LayoutDemo()),
        ),
        _PromptCases(),
        _TileCases(),
        _AudioCases(),
        _SlotLineCases(),
        _ActionBarCases(),
      ],
    );
  }
}

/// A whole multiple-choice question that grades on the tap, as the lesson
/// does.
class _LayoutDemo extends StatefulWidget {
  const _LayoutDemo();

  @override
  State<_LayoutDemo> createState() => _LayoutDemoState();
}

class _LayoutDemoState extends State<_LayoutDemo> {
  static const _options = ['Coffee', 'Tea', 'Water'];
  int? _chosen;

  AnswerGrade? get _grade => _chosen == null
      ? null
      : _chosen == 0
      ? AnswerGrade.correct
      : AnswerGrade.incorrect;

  @override
  Widget build(BuildContext context) {
    final grade = _grade;
    return ExerciseLayout(
      onClose: _noop,
      progress: 0.4,
      beans: 3,
      beansMax: 5,
      prompt: const QuestionPrompt(
        instruction: 'What does this mean?',
        question: 'ቡና',
        pronunciation: 'buna',
        onPlayAudio: _noop,
      ),
      answers: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
              child: AnswerTile(
                label: _options[i],
                state: _chosen != i
                    ? AnswerTileState.idle
                    : grade == AnswerGrade.correct
                    ? AnswerTileState.correct
                    : AnswerTileState.incorrect,
                onTap: grade == null ? () => setState(() => _chosen = i) : null,
              ),
            ),
        ],
      ),
      actionBar: AnswerActionBar(
        grade: grade,
        onContinue: () => setState(() => _chosen = null),
      ),
    );
  }
}

class _PromptCases extends StatelessWidget {
  const _PromptCases();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryCase(
          label: 'QuestionPrompt: instruction only (it becomes the headline)',
          child: QuestionPrompt(instruction: 'Match each word to its meaning'),
        ),
        GalleryCase(
          label: 'instruction and a Latin question',
          child: QuestionPrompt(
            instruction: 'Complete the sentence',
            question: 'I want coffee',
          ),
        ),
        GalleryCase(
          label: 'Fidel question, speaker chip, pronunciation, translation',
          child: QuestionPrompt(
            instruction: 'What does this mean?',
            question: 'ቡና እፈልጋለሁ',
            pronunciation: 'buna efellegalehu',
            translation: 'I want coffee',
            onPlayAudio: _noop,
          ),
        ),
        GalleryCase(
          label: 'a long Fidel question wraps; nothing is clipped',
          child: QuestionPrompt(
            instruction: 'Translate this sentence',
            question: 'እንደምን አደርክ? ዛሬ ጠዋት ቡና ጠጥተሃል ወይስ ሻይ?',
          ),
        ),
        GalleryCase(
          label: 'Afaan Oromo question with a translation',
          child: QuestionPrompt(
            instruction: 'Hiiki',
            question: 'Buna maaloo',
            translation: 'Coffee, please',
          ),
        ),
      ],
    );
  }
}

class _TileCases extends StatefulWidget {
  const _TileCases();

  @override
  State<_TileCases> createState() => _TileCasesState();
}

class _TileCasesState extends State<_TileCases> {
  bool _wrong = false;

  static const _states = AnswerTileState.values;

  Widget _tile(AnswerTileState state, AnswerTileShape shape, String label) =>
      AnswerTile(
        label: label,
        state: state,
        shape: shape,
        onTap:
            state == AnswerTileState.used || state == AnswerTileState.disabled
            ? null
            : _noop,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryCase(
          label:
              'AnswerTile row: idle, selected, correct, incorrect, used, '
              'disabled',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final state in _states)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
                  child: _tile(state, AnswerTileShape.row, state.name),
                ),
            ],
          ),
        ),
        GalleryCase(
          label: 'pill: every state, Latin and Fidel line up',
          child: Wrap(
            spacing: AppSpacing.spaceXs,
            runSpacing: AppSpacing.spaceXs,
            children: [
              for (final state in _states)
                _tile(
                  state,
                  AnswerTileShape.pill,
                  state.index.isEven ? state.name : 'ቡና',
                ),
            ],
          ),
        ),
        GalleryCase(
          label: 'cell: every state, in two match columns',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final column in [0, 1]) ...[
                if (column == 1) const SizedBox(width: AppSpacing.spaceSm),
                Expanded(
                  child: Column(
                    children: [
                      for (final state in _states.skip(column * 3).take(3))
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.spaceSm,
                          ),
                          child: _tile(
                            state,
                            AnswerTileShape.cell,
                            column == 0 ? state.name : 'ሻይ',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        GalleryCase(
          label: 'tap to grade it wrong: it shakes once',
          child: AnswerTile(
            label: 'ውሃ',
            state: _wrong ? AnswerTileState.incorrect : AnswerTileState.idle,
            onTap: () => setState(() => _wrong = !_wrong),
          ),
        ),
      ],
    );
  }
}

class _AudioCases extends StatefulWidget {
  const _AudioCases();

  @override
  State<_AudioCases> createState() => _AudioCasesState();
}

class _AudioCasesState extends State<_AudioCases> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    return GalleryCase(
      label:
          'AudioPlayButton: tap the first to toggle playing; large and '
          'small at rest and playing; disabled',
      child: Wrap(
        spacing: AppSpacing.spaceMd,
        runSpacing: AppSpacing.spaceMd,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AudioPlayButton(
            playing: _playing,
            onPressed: () => setState(() => _playing = !_playing),
          ),
          const AudioPlayButton(playing: true, onPressed: _noop),
          const AudioPlayButton(
            size: AudioPlayButtonSize.small,
            onPressed: _noop,
          ),
          const AudioPlayButton(
            size: AudioPlayButtonSize.small,
            playing: true,
            onPressed: _noop,
          ),
          const AudioPlayButton(onPressed: null),
        ],
      ),
    );
  }
}

class _SlotLineCases extends StatefulWidget {
  const _SlotLineCases();

  @override
  State<_SlotLineCases> createState() => _SlotLineCasesState();
}

class _SlotLineCasesState extends State<_SlotLineCases> {
  static const _bank = ['እኔ', 'ቡና', 'እፈልጋለሁ', 'ሻይ', 'ውሃ'];
  static const _target = ['እኔ', 'ቡና', 'እፈልጋለሁ'];
  static const _gapOptions = ['ቡና', 'ሻይ', 'ውሃ'];

  final List<String> _built = [];
  AnswerGrade? _sentenceGrade;
  int? _gapChoice;

  void _toggle(String word) => setState(() {
    _built.contains(word) ? _built.remove(word) : _built.add(word);
  });

  void _check() => setState(() {
    _sentenceGrade = _built.join(' ') == _target.join(' ')
        ? AnswerGrade.correct
        : AnswerGrade.incorrect;
  });

  void _reset() => setState(() {
    _built.clear();
    _sentenceGrade = null;
  });

  AnswerGrade? get _gapGrade => _gapChoice == null
      ? null
      : _gapChoice == 0
      ? AnswerGrade.correct
      : AnswerGrade.incorrect;

  @override
  Widget build(BuildContext context) {
    final graded = _sentenceGrade != null;
    final gapGrade = _gapGrade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryCase(
          label: 'AnswerSlotLine.sentence: build "I want coffee", then Check',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnswerSlotLine.sentence(
                grade: _sentenceGrade,
                children: [
                  for (final word in _built)
                    AnswerTile(
                      label: word,
                      shape: AnswerTileShape.pill,
                      state: switch (_sentenceGrade) {
                        null => AnswerTileState.idle,
                        AnswerGrade.correct => AnswerTileState.correct,
                        AnswerGrade.incorrect => AnswerTileState.incorrect,
                      },
                      onTap: graded ? null : () => _toggle(word),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              Wrap(
                spacing: AppSpacing.spaceXs,
                runSpacing: AppSpacing.spaceXs,
                children: [
                  for (final word in _bank)
                    AnswerTile(
                      label: word,
                      shape: AnswerTileShape.pill,
                      state: _built.contains(word)
                          ? AnswerTileState.used
                          : AnswerTileState.idle,
                      onTap: graded || _built.contains(word)
                          ? null
                          : () => _toggle(word),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              AnswerActionBar(
                grade: _sentenceGrade,
                onCheck: _check,
                canCheck: _built.isNotEmpty,
                onContinue: _reset,
              ),
            ],
          ),
        ),
        const GalleryCase(
          label: 'graded right, graded wrong: placed words take the grade',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnswerSlotLine.sentence(
                grade: AnswerGrade.correct,
                children: [
                  AnswerTile(
                    label: 'እኔ',
                    shape: AnswerTileShape.pill,
                    state: AnswerTileState.correct,
                  ),
                  AnswerTile(
                    label: 'ቡና',
                    shape: AnswerTileShape.pill,
                    state: AnswerTileState.correct,
                  ),
                  AnswerTile(
                    label: 'እፈልጋለሁ',
                    shape: AnswerTileShape.pill,
                    state: AnswerTileState.correct,
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.spaceMd),
              AnswerSlotLine.sentence(
                grade: AnswerGrade.incorrect,
                children: [
                  AnswerTile(
                    label: 'Buna',
                    shape: AnswerTileShape.pill,
                    state: AnswerTileState.incorrect,
                  ),
                  AnswerTile(
                    label: 'maaloo',
                    shape: AnswerTileShape.pill,
                    state: AnswerTileState.incorrect,
                  ),
                ],
              ),
            ],
          ),
        ),
        GalleryCase(
          label: 'AnswerSlotLine.gap: pick a word (the first is right)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnswerSlotLine.gap(
                before: 'እኔ',
                after: 'እፈልጋለሁ',
                options: _gapOptions,
                filled: _gapChoice == null ? null : _gapOptions[_gapChoice!],
                grade: gapGrade,
              ),
              const SizedBox(height: AppSpacing.spaceLg),
              for (var i = 0; i < _gapOptions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
                  child: AnswerTile(
                    label: _gapOptions[i],
                    state: _gapChoice != i
                        ? AnswerTileState.idle
                        : gapGrade == AnswerGrade.correct
                        ? AnswerTileState.correct
                        : AnswerTileState.incorrect,
                    onTap: gapGrade == null
                        ? () => setState(() => _gapChoice = i)
                        : null,
                  ),
                ),
              AnswerActionBar(
                grade: gapGrade,
                onContinue: () => setState(() => _gapChoice = null),
              ),
            ],
          ),
        ),
        const GalleryCase(
          label: 'gap empty, and Latin graded wrong',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnswerSlotLine.gap(
                before: 'Ani',
                after: 'barbada',
                options: ['buna', 'shaayii'],
              ),
              SizedBox(height: AppSpacing.spaceMd),
              AnswerSlotLine.gap(
                before: 'Ani',
                after: 'barbada',
                options: ['buna', 'shaayii'],
                filled: 'shaayii',
                grade: AnswerGrade.incorrect,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionBarCases extends StatelessWidget {
  const _ActionBarCases();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GalleryCase(
          label: "AnswerActionBar: no Check needed (its space is held)",
          child: AnswerActionBar(),
        ),
        GalleryCase(
          label: 'Check, nothing to check yet',
          child: AnswerActionBar(onCheck: _noop),
        ),
        GalleryCase(
          label: 'Check, ready',
          child: AnswerActionBar(onCheck: _noop, canCheck: true),
        ),
        GalleryCase(
          label: 'graded right',
          child: AnswerActionBar(grade: AnswerGrade.correct, onContinue: _noop),
        ),
        GalleryCase(
          label: 'graded wrong',
          child: AnswerActionBar(
            grade: AnswerGrade.incorrect,
            onContinue: _noop,
          ),
        ),
        GalleryCase(
          label: 'with a notice',
          child: AnswerActionBar(
            grade: AnswerGrade.correct,
            onContinue: _noop,
            notice: "Couldn't save your progress. Tap Continue to try again.",
          ),
        ),
      ],
    );
  }
}
