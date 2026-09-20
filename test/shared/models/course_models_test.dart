// Tests for the course models (010-multi-language-courses, bolt 026): parsing
// a backend course object, the active course of a list, the language display
// names, and the pending onboarding selection's from-language (including a
// selection stored before this intent existed).

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/language_names.dart';
import 'package:elang/shared/models/pending_onboarding_selection.dart';

void main() {
  group('Course.fromJson', () {
    test('parses a full signed-in list entry', () {
      final course = Course.fromJson({
        'id': 'c1',
        'learning_language': 'om',
        'from_language': 'am',
        'title': 'Amharic to Afaan Oromo',
        'status': 'available',
        'is_active': true,
        'completed_skills': 1,
        'total_skills': 2,
      })!;

      expect(course.id, 'c1');
      expect(course.learningLanguage, 'om');
      expect(course.fromLanguage, 'am');
      expect(course.title, 'Amharic to Afaan Oromo');
      expect(course.isAvailable, isTrue);
      expect(course.isActive, isTrue);
      expect((course.completedSkills, course.totalSkills), (1, 2));
    });

    test('a catalog entry has no per-user fields and defaults them', () {
      final course = Course.fromJson({
        'id': 'c1',
        'learning_language': 'am',
        'from_language': 'en',
        'title': 'English to Amharic',
        'status': 'coming_soon',
        'order_index': 1,
      })!;

      expect(course.status, CourseStatus.comingSoon);
      expect(course.isAvailable, isFalse);
      expect(course.isActive, isFalse);
      expect((course.completedSkills, course.totalSkills), (0, 0));
    });

    test('an embedded tree course with no status is treated as available', () {
      final course = Course.fromJson({
        'id': 'c1',
        'learning_language': 'am',
        'from_language': 'en',
        'title': 'English to Amharic',
      })!;

      expect(course.isAvailable, isTrue);
    });

    test('a missing or mistyped required field is rejected, not defaulted', () {
      expect(Course.fromJson({'id': 'c1'}), isNull);
      expect(
        Course.fromJson({
          'id': 'c1',
          'learning_language': 'am',
          'from_language': 'en',
          'title': 7,
        }),
        isNull,
      );
    });

    test('copyWith flips only the active flag', () {
      const course = Course(
        id: 'c1',
        learningLanguage: 'am',
        fromLanguage: 'en',
        title: 'English to Amharic',
        completedSkills: 2,
        totalSkills: 5,
      );

      final active = course.copyWith(isActive: true);

      expect(active.isActive, isTrue);
      expect(active.title, course.title);
      expect((active.completedSkills, active.totalSkills), (2, 5));
    });
  });

  group('CourseList', () {
    test('finds the active course, or null if the id is unknown', () {
      const a = Course(
        id: 'a',
        learningLanguage: 'am',
        fromLanguage: 'en',
        title: 'A',
      );
      const b = Course(
        id: 'b',
        learningLanguage: 'om',
        fromLanguage: 'en',
        title: 'B',
      );

      expect(
        const CourseList(activeCourseId: 'b', courses: [a, b]).activeCourse,
        b,
      );
      expect(
        const CourseList(activeCourseId: 'zzz', courses: [a, b]).activeCourse,
        isNull,
      );
    });
  });

  group('language names', () {
    test('know the three languages, in English and in their own', () {
      expect(languageName('am'), 'Amharic');
      expect(languageName('om'), 'Afaan Oromo');
      expect(languageName('en'), 'English');
      expect(languageNativeName('am'), 'አማርኛ');
      expect(languageNativeName('om'), 'Afaan Oromoo');
    });

    test('an unknown code is shown as itself', () {
      expect(languageName('xx'), 'xx');
      expect(languageNativeName('xx'), 'xx');
    });
  });

  group('PendingOnboardingSelection', () {
    test('round-trips both languages and the daily goal', () {
      const selection = PendingOnboardingSelection(
        languageCode: 'om',
        fromLanguageCode: 'am',
        dailyGoalMinutes: 15,
      );

      final restored = PendingOnboardingSelection.fromJson(selection.toJson())!;

      expect(restored.languageCode, 'om');
      expect(restored.fromLanguageCode, 'am');
      expect(restored.dailyGoalMinutes, 15);
    });

    test('defaults the from-language to English when none is given', () {
      const selection = PendingOnboardingSelection(
        languageCode: 'am',
        dailyGoalMinutes: 10,
      );

      expect(selection.fromLanguageCode, 'en');
    });

    test('a selection stored before courses existed reads as English', () {
      final restored = PendingOnboardingSelection.fromJson({
        'languageCode': 'am',
        'dailyGoalMinutes': 10,
      })!;

      expect(restored.fromLanguageCode, 'en');
    });

    test('a corrupt selection is rejected', () {
      expect(
        PendingOnboardingSelection.fromJson({'languageCode': 'am'}),
        isNull,
      );
    });
  });
}
