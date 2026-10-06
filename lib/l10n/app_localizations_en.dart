// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appLanguageTitle => 'App language';

  @override
  String get close => 'Close';

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get continueButton => 'Continue';

  @override
  String get retry => 'Retry';

  @override
  String get getStarted => 'Get Started';

  @override
  String get comingSoonBadge => 'COMING SOON';

  @override
  String minutesPerDay(int minutes) {
    return '$minutes min/day';
  }

  @override
  String xpPerDay(int xp) {
    return '+$xp XP/day';
  }

  @override
  String get goalCasual => 'Casual';

  @override
  String get goalCasualDescription => 'Gentle warm up';

  @override
  String get goalRegular => 'Regular';

  @override
  String get goalRegularDescription => 'Steady progress';

  @override
  String get goalSerious => 'Serious';

  @override
  String get goalSeriousDescription => 'Fast retention';

  @override
  String get goalIntense => 'Intense';

  @override
  String get goalIntenseDescription => 'Speed fluency';

  @override
  String get splashTagline => 'Learn Amharic, One Sip at a Time.';

  @override
  String get splashBrewing => 'Brewing your lessons...';

  @override
  String get onboardingSlide1Title => 'Bite-Sized Amharic';

  @override
  String get onboardingSlide1Body =>
      'Master Fidel syllabaries and confident daily conversations in just 5 minutes a day.';

  @override
  String get onboardingSlide2Title => 'Stay Motivated with Streaks';

  @override
  String get onboardingSlide2Body =>
      'Earn XP, keep your streak alive, and climb the Highlands map as you learn.';

  @override
  String get onboardingSlide3Title => 'Learn Real Dialects';

  @override
  String get onboardingSlide3Body =>
      'Practice with authentic native-speaker audio from Addis Ababa\'s Merkato market.';

  @override
  String get skip => 'Skip';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get logIn => 'Log In';

  @override
  String get learnQuestion => 'What do you want to learn?';

  @override
  String get learnSubtitle =>
      'Choose your journey to connect with heritage & family.';

  @override
  String forSpeakers(String language) {
    return 'For $language speakers';
  }

  @override
  String get switchCoursesAnytime =>
      'You can always switch courses anytime from the home screen or your settings.';

  @override
  String get coursesLoadFailed => 'Couldn\'t load the courses.';

  @override
  String get noCoursesYet => 'No courses are available yet.';

  @override
  String get joinWaitlist => 'Join Waitlist';

  @override
  String onWaitlist(String language) {
    return 'You\'re on the waitlist for $language.';
  }

  @override
  String get chooseDailyGoal => 'Choose your daily goal';

  @override
  String get dailyGoalQuestion =>
      'How much time do you want to dedicate to Habesha languages each day?';

  @override
  String get recommendedBadge => 'RECOMMENDED';

  @override
  String get dailyGoalTip =>
      'Tip: Studying during your morning Buna ritual boosts long-term recall.';

  @override
  String get changeGoalAnytime =>
      'You can change your goal anytime in Settings.';

  @override
  String get createAccountTitle => 'Create your free account';

  @override
  String get createAccountBody =>
      'Save your streak, sync your progress across devices, and start speaking Amharic today.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get termsNote =>
      'By continuing you agree to our Terms of Service & Privacy Policy.';

  @override
  String get signInCancelled => 'Sign-in was cancelled';

  @override
  String get signInFailed => 'Something went wrong — try again';

  @override
  String get back => 'Back';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLoadFailed => 'Couldn\'t load your settings';

  @override
  String get saveFailedCheckConnection =>
      'Couldn\'t save. Check your connection.';

  @override
  String get saveChangeFailed =>
      'Couldn\'t save your change. Please try again.';

  @override
  String get logOutQuestion => 'Log out?';

  @override
  String get logOutMessage =>
      'You\'ll need to sign in again to continue learning.';

  @override
  String get logOut => 'Log out';

  @override
  String get unknown => 'Unknown';

  @override
  String get signedInWithGoogle => 'Signed in with Google';

  @override
  String get signedInWithApple => 'Signed in with Apple';

  @override
  String get signedIn => 'Signed in';

  @override
  String get sectionLearning => 'Learning';

  @override
  String get dailyGoal => 'Daily goal';

  @override
  String get course => 'Course';

  @override
  String get sectionPreferences => 'Preferences';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle =>
      'A reminder at 8 pm if you haven\'t practised';

  @override
  String get notificationsBlocked => 'Blocked in your phone\'s settings';

  @override
  String get notificationsAllow => 'Tap to allow notifications';

  @override
  String get sound => 'Sound';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceSystem => 'System';

  @override
  String get appearanceSystemDescription => 'Match your phone';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceLightDescription => 'Always light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceDarkDescription => 'Always dark';

  @override
  String get sectionLeague => 'League';

  @override
  String get showInLeagues => 'Show me in leagues';

  @override
  String get showInLeaguesSubtitle =>
      'Others in your league see your first name';

  @override
  String get sectionAbout => 'About';

  @override
  String get sendFeedback => 'Send feedback';

  @override
  String get sendFeedbackSubtitle => 'Report a problem or share an idea';

  @override
  String get licences => 'Licences';

  @override
  String get licencesSubtitle => 'Open-source software and picture credits';

  @override
  String get feedbackBug => 'Something broke';

  @override
  String get feedbackBugHint =>
      'What happened, and what were you doing just before?';

  @override
  String get feedbackContent => 'A lesson mistake';

  @override
  String get feedbackContentHint =>
      'Which lesson, and what is wrong: a word, a translation, the audio?';

  @override
  String get feedbackIdea => 'An idea';

  @override
  String get feedbackIdeaHint => 'What would make Buna better for you?';

  @override
  String get feedbackOther => 'Something else';

  @override
  String get feedbackOtherHint => 'Tell us anything.';

  @override
  String get feedbackTooMany =>
      'That\'s plenty for today. Thank you! Try again tomorrow.';

  @override
  String get feedbackSendFailed =>
      'Couldn\'t send. Check your connection and try again.';

  @override
  String get done => 'Done';

  @override
  String get send => 'Send';

  @override
  String get feedbackIntro =>
      'Tell us what\'s working and what isn\'t. We read every message.';

  @override
  String get feedbackAbout => 'What is it about?';

  @override
  String get feedbackRating => 'How do you like Buna?';

  @override
  String get feedbackMessage => 'Your message';

  @override
  String get feedbackPickFirst => 'Pick what it is about, then write here.';

  @override
  String get feedbackSentWith =>
      'Sent with your account and current course, so we can follow up.';

  @override
  String get thankYou => 'Thank you!';

  @override
  String get feedbackOnItsWay =>
      'Your feedback is on its way to the Buna team.';

  @override
  String rateStars(int stars) {
    return 'Rate $stars out of 5';
  }

  @override
  String get courses => 'Courses';

  @override
  String courseLabel(String course) {
    return 'Course: $course';
  }

  @override
  String get courseSettings => 'Course settings';

  @override
  String get manageDownloads => 'Manage downloads';

  @override
  String get weeklyLeague => 'Weekly league';

  @override
  String get coursesLoadFailedShort => 'Couldn\'t load your courses';

  @override
  String currentCourse(String language) {
    return '$language, current course';
  }

  @override
  String switchToCourse(String language, String from) {
    return 'Switch to $language from $from';
  }

  @override
  String fromLanguage(String language) {
    return 'from $language';
  }

  @override
  String get addCourse => 'Add a course';

  @override
  String get courseOpenOfflineFirst =>
      'Connect to the internet to open this course for the first time.';

  @override
  String get courseSwitchFailed => 'Couldn\'t switch course. Please try again.';

  @override
  String get chooseCourse => 'Choose a course';

  @override
  String courseComingSoon(String course) {
    return '$course · Coming soon';
  }

  @override
  String skillsProgress(int done, int total) {
    return '$done of $total skills';
  }

  @override
  String deleteDownloadQuestion(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get deleteDownloadPending =>
      'This lesson has progress that hasn\'t synced yet. Deleting the download won\'t affect that pending sync -- it only removes the offline copy.';

  @override
  String get deleteDownloadMessage =>
      'This removes the downloaded content and audio from your device. Your synced progress is not affected.';

  @override
  String get delete => 'Delete';

  @override
  String deleteDownloadTooltip(String title) {
    return 'Delete \"$title\"';
  }

  @override
  String get noDownloads => 'No downloaded lessons yet.';

  @override
  String get noDownloadsMessage =>
      'Lessons you download from the path show up here, ready to play offline.';

  @override
  String get practice => 'Practice';

  @override
  String get jumpToCurrentLesson => 'Jump to your current lesson';

  @override
  String get practiceOffline => 'Offline -- Practice needs a connection';

  @override
  String wordsToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words to review today',
      one: '1 word to review today',
    );
    return '$_temp0';
  }

  @override
  String get allCaughtUp => 'You\'re all caught up -- nothing due today';

  @override
  String get joinThisWeeksLeague => 'Join this week\'s league';

  @override
  String leaguePlace(String place, int size, int xp) {
    return '$place of $size · $xp XP this week';
  }

  @override
  String earnXpToJoin(String tier) {
    return 'Earn XP to join · $tier';
  }

  @override
  String get downloadedOffline => 'Downloaded for offline use';

  @override
  String get downloading => 'Downloading';

  @override
  String get downloadFailed => 'Download failed, tap to try again';

  @override
  String get downloadForOffline => 'Download for offline use';

  @override
  String get offlineSavedProgress => 'Offline, showing saved progress';

  @override
  String get signInAgainTitle => 'Please sign in again';

  @override
  String get signInAgainMessage =>
      'Your session has ended. Your progress is saved to your account and will be back once you sign in.';

  @override
  String get signIn => 'Sign in';

  @override
  String get skillTreeLoadFailed => 'Couldn\'t load your skill tree';

  @override
  String get checkConnection => 'Check your connection and try again.';

  @override
  String get loadingLesson => 'Loading lesson';

  @override
  String get lessonLoadFailed => 'Couldn\'t load this lesson.';

  @override
  String get exitLesson => 'Exit lesson';

  @override
  String get youreOffline => 'You\'re offline';

  @override
  String get downloadWhileOnline =>
      'Download this lesson while online to take it offline.';

  @override
  String get goBack => 'Go back';

  @override
  String mistakesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mistakes',
      one: '1 mistake',
    );
    return '$_temp0';
  }

  @override
  String get reviewMistakesTitle => 'Let\'s review your mistakes';

  @override
  String reviewMistakesBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You missed $count questions earlier. Let\'s get them right this time!',
      one: 'You missed 1 question earlier. Let\'s get it right this time!',
    );
    return '$_temp0';
  }

  @override
  String get progressSaveFailed =>
      'Couldn\'t save your progress. Tap Continue to try again.';

  @override
  String get tapToPlay => 'Tap to play/replay';

  @override
  String get translateSentence => 'Translate this sentence';

  @override
  String get reviewComplete => 'Review Complete!';

  @override
  String get lessonComplete => 'Lesson Complete!';

  @override
  String get xpEarned => 'XP EARNED';

  @override
  String get syncsWhenOnline => 'SYNCS WHEN ONLINE';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Days',
      one: '1 Day',
    );
    return '$_temp0';
  }

  @override
  String get streakLabel => 'STREAK';

  @override
  String get plusOneToday => '+1 Today';

  @override
  String get accuracy => 'ACCURACY';

  @override
  String get correctLabel => 'CORRECT';

  @override
  String get dailyGoalProgress => 'Daily Goal Progress';

  @override
  String get offlineXpWillSync =>
      'You\'re offline -- this lesson\'s XP will sync and count toward today\'s goal once you\'re back online.';

  @override
  String xpToday(int total, int target) {
    return '$total / $target XP today';
  }

  @override
  String finishedSkill(String skill) {
    return 'You finished $skill!';
  }

  @override
  String skillUnlocked(String skill) {
    return '$skill is now unlocked.';
  }

  @override
  String allLessonsDone(int count) {
    return 'All $count lessons done.';
  }

  @override
  String lessonNofMDone(int number, int count) {
    return 'Lesson $number of $count done';
  }

  @override
  String lessonsLeftInSkill(int count, String skill) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more lessons to finish $skill.',
      one: '1 more lesson to finish $skill.',
    );
    return '$_temp0';
  }

  @override
  String lessonsDoneIn(String skill) {
    return 'Lessons done in $skill';
  }

  @override
  String get reviewsNoXp =>
      'Reviews don\'t earn XP or use beans. They keep what you\'ve already learned fresh.';

  @override
  String get tierGreenBean => 'Green Bean';

  @override
  String get tierLightRoast => 'Light Roast';

  @override
  String get tierMediumRoast => 'Medium Roast';

  @override
  String get tierDarkRoast => 'Dark Roast';

  @override
  String get tierGoldenCup => 'Golden Cup';

  @override
  String ordinal(int n) {
    return '${n}th';
  }

  @override
  String tierLeague(String tier) {
    return '$tier league';
  }

  @override
  String movedUpTo(String tier) {
    return 'You moved up to $tier!';
  }

  @override
  String droppedTo(String tier) {
    return 'You dropped to $tier';
  }

  @override
  String stayedIn(String tier) {
    return 'You stayed in $tier';
  }

  @override
  String finishedPlace(String place, int size, int xp) {
    return 'You finished $place of $size with $xp XP.';
  }

  @override
  String get leftBeforeEnd => 'You had left the league before the week ended.';

  @override
  String get climbBack => 'Climb back this week!';

  @override
  String amoleAmount(String amount) {
    return '$amount Amole';
  }

  @override
  String memberYou(String name) {
    return '$name (You)';
  }

  @override
  String memberRowLabel(int place, String name, int xp) {
    return 'Place $place, $name, $xp XP';
  }

  @override
  String memberRowReward(int amole) {
    return ', $amole Amole if the week ended now';
  }

  @override
  String xpAmount(String xp) {
    return '$xp XP';
  }

  @override
  String get movingUp => 'Moving up';

  @override
  String get movingDown => 'Moving down';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String hoursLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours left',
      one: '1 hour left',
    );
    return '$_temp0';
  }

  @override
  String get endsSoon => 'Ends soon';

  @override
  String zoneTop(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Top $count move up',
      one: 'Top 1 moves up',
    );
    return '$_temp0';
  }

  @override
  String zoneBottom(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bottom $count move down',
      one: 'Bottom 1 moves down',
    );
    return '$_temp0';
  }

  @override
  String zoneBottomAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bottom $count move down',
      one: 'bottom 1 moves down',
    );
    return '$_temp0';
  }

  @override
  String get updatedJustNow => 'updated just now';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'updated $minutes min ago';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'updated $hours h ago';
  }

  @override
  String updatedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'updated $count days ago',
      one: 'updated 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String offlineWith(String detail) {
    return 'Offline · $detail';
  }

  @override
  String get connectToSeeLeague => 'Connect to see your league';

  @override
  String get leagueShowsOnline => 'Your league shows here once you are online.';

  @override
  String get earnXpThisWeekToJoin => 'Earn XP this week to join';

  @override
  String get joinLeagueExplain =>
      'Your first lesson or practice this week puts you in a group of up to 30 learners in your league.';

  @override
  String get startALesson => 'Start a lesson';

  @override
  String get notInLeague => 'You\'re not in a league';

  @override
  String get notInLeagueExplain =>
      '\"Show me in leagues\" is off, so nobody sees your name and you are not ranked.';

  @override
  String get stayOutAnytime =>
      'You can stay out of leagues at any time in Settings.';

  @override
  String get stayOut => 'Stay out';

  @override
  String get gotIt => 'Got it';

  @override
  String get monthNames =>
      'January,February,March,April,May,June,July,August,September,October,November,December';

  @override
  String get monthShortNames =>
      'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String get weekdayInitials => 'M,T,W,T,F,S,S';

  @override
  String dayMonth(int day, String month) {
    return '$day $month';
  }

  @override
  String monthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get dayPractised => 'practised';

  @override
  String get dayNotPractised => 'not practised';

  @override
  String get dayNotYet => 'not yet';

  @override
  String get dayBeforeJoining => 'before you joined';

  @override
  String get today => 'today';

  @override
  String get notEnoughAmoleRefill => 'Not enough Amole for a refill.';

  @override
  String get refillFailed =>
      'Couldn\'t refill. Check your connection and try again.';

  @override
  String get xpExplain =>
      'You earn XP for every answer you get right in lessons and Practice.';

  @override
  String dayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count day streak',
      one: '1 day streak',
    );
    return '$_temp0';
  }

  @override
  String get dayCounts => 'A day counts when you finish a lesson.';

  @override
  String longestStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Longest: $count days',
      one: 'Longest: 1 day',
    );
    return '$_temp0';
  }

  @override
  String get amoleExplain =>
      'Earned by lessons, perfect lessons, streak milestones and Practice. Spent on bean refills.';

  @override
  String get calendarNeedsConnection =>
      'The calendar needs a connection. Connect to see it.';

  @override
  String get calendarLoadFailed => 'Couldn\'t load the calendar';

  @override
  String get listNeedsConnection =>
      'The list needs a connection. Connect to see it.';

  @override
  String get listLoadFailed => 'Couldn\'t load the list';

  @override
  String get beansFull => 'Your beans are full';

  @override
  String beansExplainEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Each wrong answer in a lesson uses a bean. They come back on their own, one every $count minutes.',
      one: 'Each wrong answer in a lesson uses a bean. They come back on their own, one every 1 minute.',
    );
    return '$_temp0';
  }

  @override
  String get beansExplainSlowly =>
      'Each wrong answer in a lesson uses a bean. They come back on their own over time.';

  @override
  String get refillNeedsConnection => 'Refill needs a connection';

  @override
  String get refillWithAmole => 'Refill with Amole';

  @override
  String get notEnoughAmole => 'Not enough Amole';

  @override
  String get beans => 'Beans';

  @override
  String get beansExplainRefill =>
      'Each wrong answer in a lesson uses a bean. They come back on their own, or you can refill them now with Amole.';

  @override
  String get nextBeanIn => 'Next bean in';

  @override
  String nextBeanInTime(String time) {
    return 'Next bean in $time';
  }

  @override
  String refillsEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Refills 1 bean every $count minutes',
      one: 'Refills 1 bean every 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get nextBean => 'Next bean';

  @override
  String get outOfBeans => 'Out of Beans!';

  @override
  String get outOfBeansBody =>
      'Don\'t worry, mistakes help you brew fluency! Beans refill automatically over time so you can continue your lessons.';

  @override
  String get notNow => 'Not now';

  @override
  String get streakFreezeUnlocked => 'Streak Freeze Unlocked!';

  @override
  String get crownLevelUp => 'Crown Level Up!';

  @override
  String levelShort(int level) {
    return 'Lv $level';
  }

  @override
  String reachedCrownLevel(String level) {
    return 'You reached crown level $level';
  }

  @override
  String andUnlocked(String skill) {
    return ' and unlocked $skill';
  }

  @override
  String get freeStreakFreeze =>
      '. A free streak freeze protects one missed day.';

  @override
  String get fullStop => '.';

  @override
  String get leavePractice => 'Leave this practice?';

  @override
  String get leaveLesson => 'Leave this lesson?';

  @override
  String get practiceNotSaved =>
      'Your progress in this practice won\'t be saved.';

  @override
  String get lessonNotSaved => 'Your progress in this lesson won\'t be saved.';

  @override
  String get keepLearning => 'Keep learning';

  @override
  String get leave => 'Leave';

  @override
  String lessonsDoneOfCount(int done, int count) {
    return '$done of $count lessons done';
  }

  @override
  String get start => 'Start';

  @override
  String get review => 'Review';

  @override
  String get nodeLocked => 'locked';

  @override
  String get nodeActive => 'active, tap to start';

  @override
  String get nodeCompleted => 'completed, tap to review';

  @override
  String get finishSkillsAbove => 'Finish the skills above to unlock this one.';

  @override
  String lessonNofM(int number, int count) {
    return 'Lesson $number of $count';
  }

  @override
  String get readyWhenYouAre => 'Ready when you are.';

  @override
  String get skillCompletedNote =>
      'You\'ve completed this skill. Reviews don\'t earn XP or use beans.';

  @override
  String get finishLessonAbove => 'Finish the lesson above to unlock this one.';

  @override
  String get lessonDonePlayAgain =>
      'You\'ve done this lesson. Play it again any time.';

  @override
  String inSkill(String skill) {
    return 'in $skill';
  }

  @override
  String get locked => 'Locked';

  @override
  String completedOfTotal(int completed, int total) {
    return '$completed of $total completed';
  }

  @override
  String completedCount(int completed, int total) {
    return '$completed/$total Completed';
  }

  @override
  String get synced => 'Synced';

  @override
  String get offlineDownloadsAvailable =>
      'Offline -- downloaded lessons available';

  @override
  String get offlineNothingDownloaded => 'Offline -- nothing downloaded';

  @override
  String get syncing => 'Syncing your offline progress...';

  @override
  String get syncFailedRetrying => 'Sync failed -- retrying...';

  @override
  String unsyncedLong(String status) {
    return '$status (unsynced for 30+ days -- please reconnect soon)';
  }

  @override
  String get noAmoleYet => 'No Amole yet';

  @override
  String amoleEntryLabel(
    String reason,
    String sign,
    String amount,
    String date,
  ) {
    return '$reason, $sign $amount Amole, $date';
  }

  @override
  String get plus => 'plus';

  @override
  String get minus => 'minus';

  @override
  String get reasonWelcome => 'Welcome bonus';

  @override
  String get reasonStartingBalance => 'Starting balance';

  @override
  String get reasonLessonFinished => 'Lesson finished';

  @override
  String get reasonPerfectLesson => 'Perfect lesson';

  @override
  String get reasonStreak7 => '7-day streak';

  @override
  String get reasonStreak30 => '30-day streak';

  @override
  String get reasonBeanRefill => 'Bean refill';

  @override
  String get reasonPractice => 'Practice session';

  @override
  String get reasonLeagueReward => 'League reward';

  @override
  String get amole => 'Amole';

  @override
  String get spellHint => 'Tap the characters below to spell it';

  @override
  String pillStreak(int count) {
    return '$count day streak';
  }

  @override
  String pillBeans(int count) {
    return '$count beans';
  }

  @override
  String pillBeansOf(int count, int max) {
    return '$count of $max beans remaining';
  }

  @override
  String pillXp(int count) {
    return '$count total XP';
  }

  @override
  String pillAmole(int count) {
    return '$count Amole';
  }

  @override
  String pageOf(int page, int count) {
    return 'Page $page of $count';
  }

  @override
  String get tryAgain => 'Try again';

  @override
  String get loading => 'Loading';

  @override
  String get cancel => 'Cancel';

  @override
  String get check => 'Check';

  @override
  String get correct => 'Correct!';

  @override
  String get notQuite => 'Not quite';

  @override
  String get buildAnswerHint => 'Tap words below to build your answer';

  @override
  String get blank => 'blank';

  @override
  String blankFilled(String word) {
    return 'blank, filled with $word';
  }

  @override
  String get playAudio => 'Play audio';

  @override
  String get playingAudio => 'Playing audio';

  @override
  String get lessonProgress => 'Lesson progress';

  @override
  String pictureN(int number) {
    return 'Picture $number';
  }

  @override
  String get reminderTitleToday => 'Time for today\'s lesson';

  @override
  String get reminderBodyToday => 'A quick lesson keeps you going.';

  @override
  String reminderTitleStreak(int count) {
    return 'Keep your $count-day streak going';
  }

  @override
  String get reminderBodyStreak => 'A quick lesson is enough.';

  @override
  String get updateRequiredTitle => 'Update needed';

  @override
  String get updateRequiredBody =>
      'This version of Buna is too old to keep working. Update it to keep learning. Your progress is saved.';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateStoreFailed =>
      'Couldn\'t open the store. Update Buna from the store app.';

  @override
  String get updateAvailable => 'A new version of Buna is available.';

  @override
  String get updateAction => 'Update';

  @override
  String get updateDownloaded => 'The update is ready.';

  @override
  String get updateRestart => 'Restart';

  @override
  String get tabLearn => 'Learn';

  @override
  String get tabSounds => 'Sounds';

  @override
  String get tabLeague => 'League';

  @override
  String get tabDownloads => 'Downloads';

  @override
  String get tabSettings => 'Settings';

  @override
  String soundsSubtitle(String language, String script) {
    return '$language · $script';
  }

  @override
  String get soundsTapToHear => 'Tap a letter to hear it.';

  @override
  String get soundsPlay => 'Play';

  @override
  String get soundsSlow => 'Slow';

  @override
  String soundsSameAs(String glyph) {
    return 'Sounds the same as $glyph';
  }

  @override
  String get soundsExample => 'Example';

  @override
  String soundsRecordedBy(String names) {
    return 'Recorded by $names';
  }

  @override
  String get soundsOffline =>
      'Connect to the internet once to load the sounds. After that they work offline.';

  @override
  String get soundsLoadFailed => 'Couldn\'t load the sounds';

  @override
  String get soundsCantPlay => 'Couldn\'t play this sound.';

  @override
  String get soundsNone => 'There is no sounds chart for this course yet.';

  @override
  String soundsLetterLabel(String glyph, String romanization) {
    return '$glyph, $romanization';
  }

  @override
  String get soundsVowel => 'Vowel';

  @override
  String get soundsConsonant => 'Consonant';
}
