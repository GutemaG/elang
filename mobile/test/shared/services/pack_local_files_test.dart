// `packLocalFiles`: the device files a downloaded pack refers to, which
// deleting a pack removes and its size counts (019-image-choice-exercise-
// types, bolt 054, story 003). Before, both only knew listening clips.

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/lesson_pack_store.dart';

const _dir = '/data/user/0/app/lesson_packs/l-1';

LessonContent _pack(List<Exercise> exercises) => LessonContent(
  lessonId: 'l-1',
  skillId: 's-1',
  title: 'Pack',
  beansAtStart: 5,
  beansMax: 5,
  exercises: exercises,
);

void main() {
  test('lists every clip and picture of every kind, each once', () {
    final files = packLocalFiles(
      _pack(const [
        ListeningExercise(
          id: 'li',
          audioUrl: '$_dir/li.mp3',
          instruction: 'Tap what you hear',
          options: ['a', 'b'],
          correctOptionIndex: 0,
        ),
        ImageChoiceExercise(
          id: 'ic',
          prompt: 'Choose',
          choices: [
            PictureChoice(imageUrl: '$_dir/ic-picture-0.webp', altText: 'A'),
            PictureChoice(imageUrl: '$_dir/ic-picture-1.webp', altText: 'B'),
          ],
          correctOptionIndex: 0,
        ),
        AudioImageChoiceExercise(
          id: 'aic',
          audioUrl: '$_dir/aic.m4a',
          instruction: 'Tap the picture you hear',
          choices: [
            // Shared with the image question: listed once.
            PictureChoice(imageUrl: '$_dir/ic-picture-1.webp', altText: 'B'),
            PictureChoice(imageUrl: '$_dir/aic-picture-1.png', altText: 'C'),
          ],
          correctOptionIndex: 1,
        ),
      ]),
    );

    expect(files, {
      '$_dir/li.mp3',
      '$_dir/ic-picture-0.webp',
      '$_dir/ic-picture-1.webp',
      '$_dir/aic.m4a',
      '$_dir/aic-picture-1.png',
    });
  });

  test('web addresses and bundled assets are not the pack\'s files', () {
    final files = packLocalFiles(
      _pack(const [
        ImageChoiceExercise(
          id: 'ic',
          prompt: 'Choose',
          choices: [
            PictureChoice(imageUrl: 'https://pub.r2.dev/a.webp', altText: 'A'),
            PictureChoice(
              imageUrl: 'http://localhost:8000/b.webp',
              altText: 'B',
            ),
            PictureChoice(imageUrl: 'assets/pictures/dog.webp', altText: 'C'),
            PictureChoice(imageUrl: '$_dir/ic-picture-3.webp', altText: 'D'),
          ],
          correctOptionIndex: 0,
        ),
        AudioImageChoiceExercise(
          id: 'aic',
          audioUrl: 'https://pub.r2.dev/a.m4a',
          instruction: 'Tap the picture you hear',
          choices: [
            PictureChoice(imageUrl: 'assets/pictures/cat.webp', altText: 'A'),
            PictureChoice(imageUrl: 'assets/pictures/sun.webp', altText: 'B'),
          ],
          correctOptionIndex: 0,
        ),
      ]),
    );

    expect(files, {'$_dir/ic-picture-3.webp'});
  });

  test('a pack with no clips or pictures has no files', () {
    expect(
      packLocalFiles(
        _pack(const [
          MultipleChoiceExercise(
            id: 'mc',
            prompt: 'ቡና',
            promptTranslation: 'What does this word mean?',
            options: ['Coffee', 'Tea'],
            correctOptionIndex: 0,
          ),
          SentenceConstructionExercise(
            id: 'sc',
            promptTranslation: 'I want coffee',
            wordBank: ['እኔ', 'ቡና'],
            correctSentence: ['እኔ', 'ቡና'],
          ),
          MatchPairsExercise(
            id: 'mp',
            prompt: 'Match',
            leftTiles: [MatchPairsTile(id: 'l', text: 'ቡና')],
            rightTiles: [MatchPairsTile(id: 'r', text: 'Coffee')],
            correctPairs: {'l': 'r'},
          ),
          GapFillExercise(
            id: 'gf',
            prompt: 'Complete',
            sentenceBefore: 'እኔ',
            sentenceAfter: 'እፈልጋለሁ',
            options: ['ቡና'],
            correctOptionIndex: 0,
          ),
        ]),
      ),
      isEmpty,
    );
  });

  test('survives the pack\'s JSON round trip unchanged', () {
    final pack = _pack(const [
      AudioImageChoiceExercise(
        id: 'aic',
        audioUrl: '$_dir/aic.m4a',
        instruction: 'Tap the picture you hear',
        choices: [
          PictureChoice(imageUrl: '$_dir/aic-picture-0.webp', altText: 'A'),
          PictureChoice(imageUrl: '$_dir/aic-picture-1.webp', altText: 'B'),
        ],
        correctOptionIndex: 1,
      ),
    ]);

    final restored = packContentFromJson(packContentToJson(pack));

    expect(packLocalFiles(restored), packLocalFiles(pack));
    expect(packLocalFiles(restored), hasLength(3));
  });
}
