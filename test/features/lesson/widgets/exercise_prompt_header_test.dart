// `splitPrompt` separates a seeded prompt's instruction from its quoted
// content, in every course language, and leaves anything else whole.

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/widgets/exercise_prompt_header.dart';

void main() {
  test('splits "Instruction: \'content\'"', () {
    final parts = splitPrompt("Complete the sentence: 'I want coffee'");

    expect(parts.instruction, 'Complete the sentence');
    expect(parts.content, 'I want coffee');
  });

  test('works for other course languages and quote styles', () {
    expect(splitPrompt("Hiiki: 'Buna maaloo'").instruction, 'Hiiki');
    expect(splitPrompt("Hiiki: 'Buna maaloo'").content, 'Buna maaloo');
    expect(
      splitPrompt('Translate: “Coffee, please”').content,
      'Coffee, please',
    );
  });

  test('keeps a comma or colon inside the quoted content', () {
    expect(
      splitPrompt("Translate: 'Galatoomi, nagaatti'").content,
      'Galatoomi, nagaatti',
    );
  });

  test('a prompt without that shape stays whole as the instruction', () {
    for (final prompt in [
      'Match each word to its meaning',
      "'Lakki' ምን ማለት ነው?",
      'Translate: I am fine',
    ]) {
      final parts = splitPrompt(prompt);
      expect(parts.instruction, prompt);
      expect(parts.content, isNull);
    }
  });
}
