// Every exercise type survives the offline pack's JSON round trip
// (015-gap-fill-exercise-type, bolt 031).
//
// This is the one seam a new exercise type touches that the compiler does
// not guard in both directions. `packExerciseToJson` is a switch over the
// sealed `Exercise`, so a missing type will not compile; `packExerciseFromJson`
// is a switch over a *string*, so a missing case throws at runtime — inside
// a downloaded pack, offline, which is the worst place to discover it.
//
// The round trip had no test at all before this bolt, for any type, because
// the mapping was private to a sqflite-backed store a `flutter test` cannot
// open. It is top-level now for exactly this reason.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/lesson_pack_store.dart';

const _image = ImageChoiceExercise(
  id: 'ic-1',
  prompt: "Choose the picture: 'ውሻ'",
  choices: [
    PictureChoice(imageUrl: 'https://pub.r2.dev/cat.webp', altText: 'A cat'),
    PictureChoice(
      imageUrl: 'http://localhost:8000/media/images/samples/dog.webp',
      altText: 'A dog',
    ),
    PictureChoice(imageUrl: 'assets/pictures/house.webp', altText: 'A house'),
  ],
  correctOptionIndex: 1,
);

const _audioImage = AudioImageChoiceExercise(
  id: 'aic-1',
  audioUrl: 'https://pub.r2.dev/audio/one.m4a',
  instruction: 'Tap the picture you hear',
  choices: [
    PictureChoice(imageUrl: 'https://pub.r2.dev/two.webp', altText: 'Two'),
    PictureChoice(imageUrl: 'https://pub.r2.dev/one.webp', altText: 'One'),
  ],
  correctOptionIndex: 1,
);

// `Maaloo` ("please"): two `a` tiles and two `o` tiles, plus distractors.
// A round trip of a word with no repeats would pass even if the ids were
// dropped and tiles looked up by text -- the failure this is here to catch.
const _spell = SpellTilesExercise(
  id: 'st-1',
  prompt: "Spell 'Please'",
  tiles: [
    SpellTile(id: 't1', text: 'a'),
    SpellTile(id: 't2', text: 'l'),
    SpellTile(id: 't3', text: 'M'),
    SpellTile(id: 't4', text: 'e'),
    SpellTile(id: 't5', text: 'o'),
    SpellTile(id: 't6', text: 'i'),
    SpellTile(id: 't7', text: 'a'),
    SpellTile(id: 't8', text: 'o'),
  ],
  correctSequence: ['t3', 't1', 't7', 't2', 't5', 't8'],
);

const _exercises = <Exercise>[
  MultipleChoiceExercise(
    id: 'mc-1',
    prompt: 'ሰላም',
    promptTranslation: 'Hello',
    options: ['Hello', 'Goodbye'],
    correctOptionIndex: 0,
  ),
  ListeningExercise(
    id: 'listen-1',
    audioUrl: '/tmp/audio.mp3',
    instruction: 'Tap what you hear',
    options: ['ሰላም', 'ደህና'],
    correctOptionIndex: 1,
  ),
  SentenceConstructionExercise(
    id: 'sc-1',
    promptTranslation: 'I am fine',
    wordBank: ['ደህና', 'ነኝ', 'ጥሩ'],
    correctSentence: ['ደህና', 'ነኝ'],
  ),
  MatchPairsExercise(
    id: 'mp-1',
    prompt: 'Match each word to its meaning',
    leftTiles: [
      MatchPairsTile(id: 'l1', text: 'ቡና'),
      MatchPairsTile(id: 'l2', text: 'ሻይ'),
    ],
    rightTiles: [
      MatchPairsTile(id: 'r1', text: 'Coffee'),
      MatchPairsTile(id: 'r2', text: 'Tea'),
    ],
    correctPairs: {'l1': 'r1', 'l2': 'r2'},
  ),
  _image,
  _audioImage,
  _spell,
  // Last: the gap-fill tests below read `_exercises.last`.
  GapFillExercise(
    id: 'gf-1',
    prompt: "Complete the sentence: 'I want bread'",
    sentenceBefore: '',
    sentenceAfter: 'እፈልጋለሁ',
    options: ['ዳቦ', 'ምግብ', 'ውሃ'],
    correctOptionIndex: 0,
  ),
];

LessonContent _packOf(List<Exercise> exercises) => LessonContent(
  lessonId: 'lesson-1',
  skillId: 'skill-1',
  title: 'Round Trip',
  beansAtStart: 5,
  beansMax: 5,
  exercises: exercises,
);

/// Through real JSON text, not just the maps — a pack is stored as an
/// encoded string, so anything that survives the maps but not `jsonEncode`
/// would still break on a device.
LessonContent _roundTrip(LessonContent content) => packContentFromJson(
  jsonDecode(jsonEncode(packContentToJson(content))) as Map<String, dynamic>,
);

void main() {
  test('the fixture covers every exercise type', () {
    // Guards the round-trip tests below: a sixth type must be added here or
    // the coverage silently stops being total. There is no exhaustiveness
    // check available on a list, so this is the check.
    final types = _exercises.map((e) => e.runtimeType.toString()).toSet();
    expect(types, hasLength(_exercises.length));
    expect(
      types,
      containsAll([
        'MultipleChoiceExercise',
        'ListeningExercise',
        'SentenceConstructionExercise',
        'MatchPairsExercise',
        'GapFillExercise',
        'ImageChoiceExercise',
        'AudioImageChoiceExercise',
        'SpellTilesExercise',
      ]),
    );
  });

  test('a pack containing every exercise type round-trips', () {
    final restored = _roundTrip(_packOf(_exercises));

    expect(restored.exercises, hasLength(_exercises.length));
    expect(
      restored.exercises.map((e) => e.runtimeType),
      _exercises.map((e) => e.runtimeType),
    );
    expect(restored.lessonId, 'lesson-1');
  });

  group('gap fill', () {
    test('keeps both sides of the gap, its options and its answer', () {
      final restored = _roundTrip(_packOf([_exercises.last]));

      final gap = restored.exercises.single as GapFillExercise;
      expect(gap.id, 'gf-1');
      expect(gap.prompt, "Complete the sentence: 'I want bread'");
      expect(gap.sentenceBefore, '');
      expect(gap.sentenceAfter, 'እፈልጋለሁ');
      expect(gap.options, ['ዳቦ', 'ምግብ', 'ውሃ']);
      expect(gap.correctOptionIndex, 0);
    });

    test('an empty side stays an empty string, not null', () {
      // `sentenceBefore` is non-nullable; a null coming back out of JSON
      // would throw on cast rather than degrade, so pin the empty case.
      final restored = _roundTrip(_packOf([_exercises.last]));

      final gap = restored.exercises.single as GapFillExercise;
      expect(gap.sentenceBefore, isEmpty);
      expect(gap.sentenceBefore, isNotNull);
    });

    test('a gap in the middle of a sentence round-trips', () {
      final restored = _roundTrip(
        _packOf([
          const GapFillExercise(
            id: 'gf-2',
            prompt: "Complete the sentence: 'I want coffee'",
            sentenceBefore: 'እኔ',
            sentenceAfter: 'እፈልጋለሁ',
            options: ['ቡና', 'ሻይ'],
            correctOptionIndex: 0,
          ),
        ]),
      );

      final gap = restored.exercises.single as GapFillExercise;
      expect(gap.sentenceBefore, 'እኔ');
      expect(gap.sentenceAfter, 'እፈልጋለሁ');
    });

    test('it still grades correctly after the round trip', () {
      final restored = _roundTrip(_packOf([_exercises.last]));

      final gap = restored.exercises.single;
      expect(isAnswerCorrect(gap, 0), isTrue);
      expect(isAnswerCorrect(gap, 1), isFalse);
    });
  });

  group('pictures', () {
    ({String url, String alt}) plain(PictureChoice p) =>
        (url: p.imageUrl, alt: p.altText);

    test('an image choice question keeps its prompt, every picture in '
        'order, and its answer', () {
      final restored = _roundTrip(_packOf([_image]));

      final image = restored.exercises.single as ImageChoiceExercise;
      expect(image.id, 'ic-1');
      expect(image.prompt, "Choose the picture: 'ውሻ'");
      expect(image.choices.map(plain), _image.choices.map(plain));
      expect(image.correctOptionIndex, 1);
      expect(isAnswerCorrect(image, 1), isTrue);
      expect(isAnswerCorrect(image, 0), isFalse);
    });

    test('an audio image choice question keeps its clip, instruction, '
        'pictures and answer', () {
      final restored = _roundTrip(_packOf([_audioImage]));

      final audio = restored.exercises.single as AudioImageChoiceExercise;
      expect(audio.id, 'aic-1');
      expect(audio.audioUrl, 'https://pub.r2.dev/audio/one.m4a');
      expect(audio.instruction, 'Tap the picture you hear');
      expect(audio.choices.map(plain), _audioImage.choices.map(plain));
      expect(audio.correctOptionIndex, 1);
      expect(isAnswerCorrect(audio, 1), isTrue);
    });

    test('the stored shape names each type, so an older reader refuses it '
        'rather than misreading it', () {
      final json = [_image, _audioImage].map(packExerciseToJson).toList();
      expect(json.map((j) => j['type']), [
        'image_choice',
        'audio_image_choice',
      ]);
      expect((json.first['choices'] as List).first, {
        'imageUrl': 'https://pub.r2.dev/cat.webp',
        'altText': 'A cat',
      });
    });
  });

  group('spell tiles', () {
    SpellTilesExercise restored() =>
        _roundTrip(_packOf([_spell])).exercises.single as SpellTilesExercise;

    test('a word with repeated characters keeps every tile, each with its '
        'own id, in order', () {
      final back = restored();
      expect(back.id, 'st-1');
      expect(back.prompt, "Spell 'Please'");
      expect(
        back.tiles.map((t) => (t.id, t.text)),
        _spell.tiles.map((t) => (t.id, t.text)),
      );
      // Both twins survive as themselves, not collapsed into one.
      expect(back.tiles.where((t) => t.text == 'a').map((t) => t.id), [
        't1',
        't7',
      ]);
      expect(back.correctSequence, ['t3', 't1', 't7', 't2', 't5', 't8']);
    });

    test('it still grades after the round trip, twins either way round', () {
      final back = restored();
      expect(isAnswerCorrect(back, ['t3', 't1', 't7', 't2', 't5', 't8']), true);
      // The other `a` first and the other `o` first: the same word.
      expect(isAnswerCorrect(back, ['t3', 't7', 't1', 't2', 't8', 't5']), true);
      expect(
        isAnswerCorrect(back, ['t3', 't1', 't2', 't7', 't5', 't8']),
        false,
      );
    });

    test('is stored under its own type name, with the ids beside the text', () {
      final json = packExerciseToJson(_spell);
      expect(json['type'], 'spell_tiles');
      expect((json['tiles'] as List).first, {'id': 't1', 'text': 'a'});
      expect(json['correctSequence'], _spell.correctSequence);
    });

    test('tile ids belong to their own exercise: two spellings in one pack '
        'that reuse the same ids both round-trip and grade', () {
      const other = SpellTilesExercise(
        id: 'st-2',
        prompt: "Spell 'Coffee'",
        tiles: [
          SpellTile(id: 't1', text: 'n'),
          SpellTile(id: 't2', text: 'B'),
          SpellTile(id: 't3', text: 'a'),
          SpellTile(id: 't4', text: 'u'),
        ],
        correctSequence: ['t2', 't4', 't1', 't3'],
      );
      final back = _roundTrip(_packOf([_spell, other])).exercises;
      expect(
        isAnswerCorrect(back[0], ['t3', 't1', 't7', 't2', 't5', 't8']),
        true,
      );
      expect(isAnswerCorrect(back[1], ['t2', 't4', 't1', 't3']), true);
    });
  });

  test('an unknown type in a stored pack fails loudly', () {
    // A pack written by a newer build and read by an older one. Better a
    // clear StateError than a silently missing exercise.
    expect(
      () => packContentFromJson({
        'lessonId': 'l',
        'skillId': 's',
        'title': 't',
        'beansAtStart': 5,
        'beansMax': 5,
        'contentVersion': null,
        'exercises': [
          {'type': 'speak_check', 'id': 'x'},
        ],
      }),
      throwsStateError,
    );
  });
}
