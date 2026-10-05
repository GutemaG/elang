import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';
import 'app_localizations_om.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en'),
    Locale('om'),
  ];

  /// Settings: the row, and the title of the sheet it opens, for the language the app's own words are shown in.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguageTitle;

  /// Tooltip (read by screen readers) of the X button that closes a sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// A number of days, e.g. in time left or a streak length.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String dayCount(int count);

  /// Button: go on to the next screen or step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Button: try a failed action again.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Button on the splash screen and the last onboarding slide.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Badge (capitals) on a course that is not open yet.
  ///
  /// In en, this message translates to:
  /// **'COMING SOON'**
  String get comingSoonBadge;

  /// Daily goal length, e.g. "10 min/day".
  ///
  /// In en, this message translates to:
  /// **'{minutes} min/day'**
  String minutesPerDay(int minutes);

  /// XP a daily goal earns each day, e.g. "+20 XP/day".
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP/day'**
  String xpPerDay(int xp);

  /// Daily goal name: 5 minutes a day.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get goalCasual;

  /// Under the 5-minute daily goal.
  ///
  /// In en, this message translates to:
  /// **'Gentle warm up'**
  String get goalCasualDescription;

  /// Daily goal name: 10 minutes a day.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get goalRegular;

  /// Under the 10-minute daily goal.
  ///
  /// In en, this message translates to:
  /// **'Steady progress'**
  String get goalRegularDescription;

  /// Daily goal name: 15 minutes a day.
  ///
  /// In en, this message translates to:
  /// **'Serious'**
  String get goalSerious;

  /// Under the 15-minute daily goal.
  ///
  /// In en, this message translates to:
  /// **'Fast retention'**
  String get goalSeriousDescription;

  /// Daily goal name: 20 minutes a day.
  ///
  /// In en, this message translates to:
  /// **'Intense'**
  String get goalIntense;

  /// Under the 20-minute daily goal.
  ///
  /// In en, this message translates to:
  /// **'Speed fluency'**
  String get goalIntenseDescription;

  /// Splash screen line under the app name.
  ///
  /// In en, this message translates to:
  /// **'Learn Amharic, One Sip at a Time.'**
  String get splashTagline;

  /// Splash screen: shown while the app gets ready (a coffee pun).
  ///
  /// In en, this message translates to:
  /// **'Brewing your lessons...'**
  String get splashBrewing;

  /// Onboarding slide 1 title.
  ///
  /// In en, this message translates to:
  /// **'Bite-Sized Amharic'**
  String get onboardingSlide1Title;

  /// Onboarding slide 1 text.
  ///
  /// In en, this message translates to:
  /// **'Master Fidel syllabaries and confident daily conversations in just 5 minutes a day.'**
  String get onboardingSlide1Body;

  /// Onboarding slide 2 title.
  ///
  /// In en, this message translates to:
  /// **'Stay Motivated with Streaks'**
  String get onboardingSlide2Title;

  /// Onboarding slide 2 text.
  ///
  /// In en, this message translates to:
  /// **'Earn XP, keep your streak alive, and climb the Highlands map as you learn.'**
  String get onboardingSlide2Body;

  /// Onboarding slide 3 title.
  ///
  /// In en, this message translates to:
  /// **'Learn Real Dialects'**
  String get onboardingSlide3Title;

  /// Onboarding slide 3 text.
  ///
  /// In en, this message translates to:
  /// **'Practice with authentic native-speaker audio from Addis Ababa\'s Merkato market.'**
  String get onboardingSlide3Body;

  /// Button: skip the onboarding slides.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Onboarding: before the Log In button.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Button: sign in to an existing account.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// Heading of the course choice at sign-up, in the language of the open section.
  ///
  /// In en, this message translates to:
  /// **'What do you want to learn?'**
  String get learnQuestion;

  /// Under the course-choice heading.
  ///
  /// In en, this message translates to:
  /// **'Choose your journey to connect with heritage & family.'**
  String get learnSubtitle;

  /// Heading over the courses taught from a language. {language} is the language's own name (English, አማርኛ, Afaan Oromoo).
  ///
  /// In en, this message translates to:
  /// **'For {language} speakers'**
  String forSpeakers(String language);

  /// Note under the course choice at sign-up.
  ///
  /// In en, this message translates to:
  /// **'You can always switch courses anytime from the home screen or your settings.'**
  String get switchCoursesAnytime;

  /// Error when the course list fails to load at sign-up.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the courses.'**
  String get coursesLoadFailed;

  /// Shown when no course is open yet.
  ///
  /// In en, this message translates to:
  /// **'No courses are available yet.'**
  String get noCoursesYet;

  /// Button on a coming-soon course.
  ///
  /// In en, this message translates to:
  /// **'Join Waitlist'**
  String get joinWaitlist;

  /// Message after joining a course's waitlist. {language} is the language's name.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the waitlist for {language}.'**
  String onWaitlist(String language);

  /// Daily goal screen heading.
  ///
  /// In en, this message translates to:
  /// **'Choose your daily goal'**
  String get chooseDailyGoal;

  /// Daily goal screen: under the heading.
  ///
  /// In en, this message translates to:
  /// **'How much time do you want to dedicate to Habesha languages each day?'**
  String get dailyGoalQuestion;

  /// Badge (capitals) on the suggested daily goal.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDED'**
  String get recommendedBadge;

  /// Tip on the daily goal screen (Buna = coffee).
  ///
  /// In en, this message translates to:
  /// **'Tip: Studying during your morning Buna ritual boosts long-term recall.'**
  String get dailyGoalTip;

  /// Note under the Continue button on the daily goal screen.
  ///
  /// In en, this message translates to:
  /// **'You can change your goal anytime in Settings.'**
  String get changeGoalAnytime;

  /// Sign-in screen heading.
  ///
  /// In en, this message translates to:
  /// **'Create your free account'**
  String get createAccountTitle;

  /// Sign-in screen: under the heading.
  ///
  /// In en, this message translates to:
  /// **'Save your streak, sync your progress across devices, and start speaking Amharic today.'**
  String get createAccountBody;

  /// Sign-in button.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Sign-in button.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// Small print under the sign-in buttons.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to our Terms of Service & Privacy Policy.'**
  String get termsNote;

  /// Sign-in: the learner closed the Google or Apple window.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled'**
  String get signInCancelled;

  /// Sign-in failed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong — try again'**
  String get signInFailed;

  /// Tooltip (read by screen readers) of the back arrow.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Settings screen title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Error when Settings fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your settings'**
  String get settingsLoadFailed;

  /// Message when a setting could not be saved.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check your connection.'**
  String get saveFailedCheckConnection;

  /// Message when a Settings change (goal, notifications, sound) could not be saved.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your change. Please try again.'**
  String get saveChangeFailed;

  /// Title of the log-out confirmation.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logOutQuestion;

  /// Text of the log-out confirmation.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to sign in again to continue learning.'**
  String get logOutMessage;

  /// Button: sign out.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// Shown when a value is not known.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// Settings profile: how the learner signed in.
  ///
  /// In en, this message translates to:
  /// **'Signed in with Google'**
  String get signedInWithGoogle;

  /// Settings profile: how the learner signed in.
  ///
  /// In en, this message translates to:
  /// **'Signed in with Apple'**
  String get signedInWithApple;

  /// Settings profile: signed in (provider unknown).
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedIn;

  /// Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get sectionLearning;

  /// Settings row and sheet title: the daily goal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get dailyGoal;

  /// Settings row: the active course.
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get course;

  /// Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get sectionPreferences;

  /// Settings switch: the daily reminder.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Under the Notifications switch (8 pm; Ethiopian time 2 in the evening).
  ///
  /// In en, this message translates to:
  /// **'A reminder at 8 pm if you haven\'t practised'**
  String get notificationsSubtitle;

  /// Settings row when the phone blocks notifications.
  ///
  /// In en, this message translates to:
  /// **'Blocked in your phone\'s settings'**
  String get notificationsBlocked;

  /// Under the blocked-notifications row.
  ///
  /// In en, this message translates to:
  /// **'Tap to allow notifications'**
  String get notificationsAllow;

  /// Settings switch: sounds when answering.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// Settings row and sheet title: light or dark look.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Appearance choice: follow the phone.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appearanceSystem;

  /// Under the System appearance choice.
  ///
  /// In en, this message translates to:
  /// **'Match your phone'**
  String get appearanceSystemDescription;

  /// Appearance choice: light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// Under the Light appearance choice.
  ///
  /// In en, this message translates to:
  /// **'Always light'**
  String get appearanceLightDescription;

  /// Appearance choice: dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// Under the Dark appearance choice.
  ///
  /// In en, this message translates to:
  /// **'Always dark'**
  String get appearanceDarkDescription;

  /// Settings section heading: the weekly league.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get sectionLeague;

  /// Settings switch: take part in weekly leagues.
  ///
  /// In en, this message translates to:
  /// **'Show me in leagues'**
  String get showInLeagues;

  /// Under the Show me in leagues switch.
  ///
  /// In en, this message translates to:
  /// **'Others in your league see your first name'**
  String get showInLeaguesSubtitle;

  /// Settings section heading: about the app.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// Settings row and the feedback screen title.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get sendFeedback;

  /// Under the Send feedback row.
  ///
  /// In en, this message translates to:
  /// **'Report a problem or share an idea'**
  String get sendFeedbackSubtitle;

  /// Settings row: open-source licences.
  ///
  /// In en, this message translates to:
  /// **'Licences'**
  String get licences;

  /// Under the Licences row.
  ///
  /// In en, this message translates to:
  /// **'Open-source software and picture credits'**
  String get licencesSubtitle;

  /// Feedback kind: a bug.
  ///
  /// In en, this message translates to:
  /// **'Something broke'**
  String get feedbackBug;

  /// Hint in the message box for a bug.
  ///
  /// In en, this message translates to:
  /// **'What happened, and what were you doing just before?'**
  String get feedbackBugHint;

  /// Feedback kind: a mistake in a lesson.
  ///
  /// In en, this message translates to:
  /// **'A lesson mistake'**
  String get feedbackContent;

  /// Hint in the message box for a lesson mistake.
  ///
  /// In en, this message translates to:
  /// **'Which lesson, and what is wrong: a word, a translation, the audio?'**
  String get feedbackContentHint;

  /// Feedback kind: an idea.
  ///
  /// In en, this message translates to:
  /// **'An idea'**
  String get feedbackIdea;

  /// Hint in the message box for an idea.
  ///
  /// In en, this message translates to:
  /// **'What would make Buna better for you?'**
  String get feedbackIdeaHint;

  /// Feedback kind: anything else.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get feedbackOther;

  /// Hint in the message box for anything else.
  ///
  /// In en, this message translates to:
  /// **'Tell us anything.'**
  String get feedbackOtherHint;

  /// Feedback: too many sent today.
  ///
  /// In en, this message translates to:
  /// **'That\'s plenty for today. Thank you! Try again tomorrow.'**
  String get feedbackTooMany;

  /// Feedback: sending failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Check your connection and try again.'**
  String get feedbackSendFailed;

  /// Button: close a finished screen.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Button: send the feedback.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Feedback screen: the first line.
  ///
  /// In en, this message translates to:
  /// **'Tell us what\'s working and what isn\'t. We read every message.'**
  String get feedbackIntro;

  /// Feedback screen: heading over the kinds.
  ///
  /// In en, this message translates to:
  /// **'What is it about?'**
  String get feedbackAbout;

  /// Feedback screen: heading over the stars.
  ///
  /// In en, this message translates to:
  /// **'How do you like Buna?'**
  String get feedbackRating;

  /// Feedback screen: heading over the message box.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get feedbackMessage;

  /// Hint in the message box before a kind is chosen.
  ///
  /// In en, this message translates to:
  /// **'Pick what it is about, then write here.'**
  String get feedbackPickFirst;

  /// Feedback screen: note under the message box.
  ///
  /// In en, this message translates to:
  /// **'Sent with your account and current course, so we can follow up.'**
  String get feedbackSentWith;

  /// Feedback screen after sending.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get thankYou;

  /// Feedback screen after sending.
  ///
  /// In en, this message translates to:
  /// **'Your feedback is on its way to the Buna team.'**
  String get feedbackOnItsWay;

  /// Tooltip of each rating star.
  ///
  /// In en, this message translates to:
  /// **'Rate {stars} out of 5'**
  String rateStars(int stars);

  /// Dashboard course button before a course is known.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get courses;

  /// Screen-reader label of the dashboard course button.
  ///
  /// In en, this message translates to:
  /// **'Course: {course}'**
  String courseLabel(String course);

  /// Course panel row: open Settings.
  ///
  /// In en, this message translates to:
  /// **'Course settings'**
  String get courseSettings;

  /// Course panel row and the downloads screen title.
  ///
  /// In en, this message translates to:
  /// **'Manage downloads'**
  String get manageDownloads;

  /// Course panel row: open the league.
  ///
  /// In en, this message translates to:
  /// **'Weekly league'**
  String get weeklyLeague;

  /// Error when the course list fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your courses'**
  String get coursesLoadFailedShort;

  /// Screen-reader label of the active course tile.
  ///
  /// In en, this message translates to:
  /// **'{language}, current course'**
  String currentCourse(String language);

  /// Screen-reader label of another course tile.
  ///
  /// In en, this message translates to:
  /// **'Switch to {language} from {from}'**
  String switchToCourse(String language, String from);

  /// Under a course tile: the language it is taught from.
  ///
  /// In en, this message translates to:
  /// **'from {language}'**
  String fromLanguage(String language);

  /// Screen-reader label of the add-course tile.
  ///
  /// In en, this message translates to:
  /// **'Add a course'**
  String get addCourse;

  /// Course switch failed offline.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to open this course for the first time.'**
  String get courseOpenOfflineFirst;

  /// Course switch failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t switch course. Please try again.'**
  String get courseSwitchFailed;

  /// Course picker title.
  ///
  /// In en, this message translates to:
  /// **'Choose a course'**
  String get chooseCourse;

  /// Course picker: a course not open yet.
  ///
  /// In en, this message translates to:
  /// **'{course} · Coming soon'**
  String courseComingSoon(String course);

  /// Screen-reader label of a course progress bar.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} skills'**
  String skillsProgress(int done, int total);

  /// Title of the delete-download confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String deleteDownloadQuestion(String title);

  /// Delete-download confirmation when progress has not synced.
  ///
  /// In en, this message translates to:
  /// **'This lesson has progress that hasn\'t synced yet. Deleting the download won\'t affect that pending sync -- it only removes the offline copy.'**
  String get deleteDownloadPending;

  /// Delete-download confirmation.
  ///
  /// In en, this message translates to:
  /// **'This removes the downloaded content and audio from your device. Your synced progress is not affected.'**
  String get deleteDownloadMessage;

  /// Button: delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Tooltip of the delete button on a downloaded lesson.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"'**
  String deleteDownloadTooltip(String title);

  /// Downloads screen when empty.
  ///
  /// In en, this message translates to:
  /// **'No downloaded lessons yet.'**
  String get noDownloads;

  /// Downloads screen when empty.
  ///
  /// In en, this message translates to:
  /// **'Lessons you download from the path show up here, ready to play offline.'**
  String get noDownloadsMessage;

  /// The Practice card on the dashboard, and the title of a practice session.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get practice;

  /// Tooltip of the dashboard button that scrolls to the current lesson.
  ///
  /// In en, this message translates to:
  /// **'Jump to your current lesson'**
  String get jumpToCurrentLesson;

  /// Practice card when offline.
  ///
  /// In en, this message translates to:
  /// **'Offline -- Practice needs a connection'**
  String get practiceOffline;

  /// Practice card: how many words are due.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word to review today} other{{count} words to review today}}'**
  String wordsToReview(int count);

  /// Practice card when nothing is due.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up -- nothing due today'**
  String get allCaughtUp;

  /// Dashboard league card before joining.
  ///
  /// In en, this message translates to:
  /// **'Join this week\'s league'**
  String get joinThisWeeksLeague;

  /// Dashboard league card: place, group size and weekly XP.
  ///
  /// In en, this message translates to:
  /// **'{place} of {size} · {xp} XP this week'**
  String leaguePlace(String place, int size, int xp);

  /// Dashboard league card before joining; {tier} is the league tier name.
  ///
  /// In en, this message translates to:
  /// **'Earn XP to join · {tier}'**
  String earnXpToJoin(String tier);

  /// Lesson popover: the lesson is downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded for offline use'**
  String get downloadedOffline;

  /// Lesson popover: the lesson is downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloading;

  /// Lesson popover: download failed.
  ///
  /// In en, this message translates to:
  /// **'Download failed, tap to try again'**
  String get downloadFailed;

  /// Lesson popover: download the lesson.
  ///
  /// In en, this message translates to:
  /// **'Download for offline use'**
  String get downloadForOffline;

  /// Dashboard note when offline.
  ///
  /// In en, this message translates to:
  /// **'Offline, showing saved progress'**
  String get offlineSavedProgress;

  /// Dashboard when the session has ended.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again'**
  String get signInAgainTitle;

  /// Dashboard when the session has ended.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Your progress is saved to your account and will be back once you sign in.'**
  String get signInAgainMessage;

  /// Button: sign in again.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// Dashboard load error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your skill tree'**
  String get skillTreeLoadFailed;

  /// Under a load error.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get checkConnection;

  /// While a lesson loads.
  ///
  /// In en, this message translates to:
  /// **'Loading lesson'**
  String get loadingLesson;

  /// Lesson load error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this lesson.'**
  String get lessonLoadFailed;

  /// Tooltip of the X that leaves a lesson.
  ///
  /// In en, this message translates to:
  /// **'Exit lesson'**
  String get exitLesson;

  /// A lesson that needs a connection.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get youreOffline;

  /// A lesson that needs a connection.
  ///
  /// In en, this message translates to:
  /// **'Download this lesson while online to take it offline.'**
  String get downloadWhileOnline;

  /// Button: leave the screen.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// Badge on the review-your-mistakes screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 mistake} other{{count} mistakes}}'**
  String mistakesCount(int count);

  /// Screen before the missed questions come back.
  ///
  /// In en, this message translates to:
  /// **'Let\'s review your mistakes'**
  String get reviewMistakesTitle;

  /// Screen before the missed questions come back.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You missed 1 question earlier. Let\'s get it right this time!} other{You missed {count} questions earlier. Let\'s get them right this time!}}'**
  String reviewMistakesBody(int count);

  /// Lesson end: saving failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your progress. Tap Continue to try again.'**
  String get progressSaveFailed;

  /// Under the big play button of a listening question.
  ///
  /// In en, this message translates to:
  /// **'Tap to play/replay'**
  String get tapToPlay;

  /// Instruction of a translation question.
  ///
  /// In en, this message translates to:
  /// **'Translate this sentence'**
  String get translateSentence;

  /// Title after a review.
  ///
  /// In en, this message translates to:
  /// **'Review Complete!'**
  String get reviewComplete;

  /// Title after a lesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson Complete!'**
  String get lessonComplete;

  /// Stat card label (capitals).
  ///
  /// In en, this message translates to:
  /// **'XP EARNED'**
  String get xpEarned;

  /// Stat card label (capitals) when offline.
  ///
  /// In en, this message translates to:
  /// **'SYNCS WHEN ONLINE'**
  String get syncsWhenOnline;

  /// Stat card value: the streak length.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Day} other{{count} Days}}'**
  String streakDays(int count);

  /// Stat card label (capitals).
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get streakLabel;

  /// Ribbon on the streak card when it grew today.
  ///
  /// In en, this message translates to:
  /// **'+1 Today'**
  String get plusOneToday;

  /// Stat card label (capitals).
  ///
  /// In en, this message translates to:
  /// **'ACCURACY'**
  String get accuracy;

  /// Stat card label (capitals).
  ///
  /// In en, this message translates to:
  /// **'CORRECT'**
  String get correctLabel;

  /// Card title after a lesson.
  ///
  /// In en, this message translates to:
  /// **'Daily Goal Progress'**
  String get dailyGoalProgress;

  /// After a lesson finished offline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline -- this lesson\'s XP will sync and count toward today\'s goal once you\'re back online.'**
  String get offlineXpWillSync;

  /// Daily goal progress after a lesson.
  ///
  /// In en, this message translates to:
  /// **'{total} / {target} XP today'**
  String xpToday(int total, int target);

  /// After the last lesson of a skill.
  ///
  /// In en, this message translates to:
  /// **'You finished {skill}!'**
  String finishedSkill(String skill);

  /// After a skill opens the next.
  ///
  /// In en, this message translates to:
  /// **'{skill} is now unlocked.'**
  String skillUnlocked(String skill);

  /// After the last lesson of a skill.
  ///
  /// In en, this message translates to:
  /// **'All {count} lessons done.'**
  String allLessonsDone(int count);

  /// After a lesson in a skill.
  ///
  /// In en, this message translates to:
  /// **'Lesson {number} of {count} done'**
  String lessonNofMDone(int number, int count);

  /// After a lesson: lessons left in the skill.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more lesson to finish {skill}.} other{{count} more lessons to finish {skill}.}}'**
  String lessonsLeftInSkill(int count, String skill);

  /// Screen-reader label of the skill progress bar.
  ///
  /// In en, this message translates to:
  /// **'Lessons done in {skill}'**
  String lessonsDoneIn(String skill);

  /// Note after a review.
  ///
  /// In en, this message translates to:
  /// **'Reviews don\'t earn XP or use beans. They keep what you\'ve already learned fresh.'**
  String get reviewsNoXp;

  /// League tier 1 (lowest): an unroasted coffee bean.
  ///
  /// In en, this message translates to:
  /// **'Green Bean'**
  String get tierGreenBean;

  /// League tier 2: lightly roasted coffee.
  ///
  /// In en, this message translates to:
  /// **'Light Roast'**
  String get tierLightRoast;

  /// League tier 3: medium roasted coffee.
  ///
  /// In en, this message translates to:
  /// **'Medium Roast'**
  String get tierMediumRoast;

  /// League tier 4: dark roasted coffee.
  ///
  /// In en, this message translates to:
  /// **'Dark Roast'**
  String get tierDarkRoast;

  /// League tier 5 (highest): a golden coffee cup.
  ///
  /// In en, this message translates to:
  /// **'Golden Cup'**
  String get tierGoldenCup;

  /// A place in a ranking: 1st, 2nd... (English is worked out in code; this is the other languages' form).
  ///
  /// In en, this message translates to:
  /// **'{n}th'**
  String ordinal(int n);

  /// A league by its tier name, e.g. "Green Bean league".
  ///
  /// In en, this message translates to:
  /// **'{tier} league'**
  String tierLeague(String tier);

  /// Last week's result: promoted.
  ///
  /// In en, this message translates to:
  /// **'You moved up to {tier}!'**
  String movedUpTo(String tier);

  /// Last week's result: demoted.
  ///
  /// In en, this message translates to:
  /// **'You dropped to {tier}'**
  String droppedTo(String tier);

  /// Last week's result: stayed.
  ///
  /// In en, this message translates to:
  /// **'You stayed in {tier}'**
  String stayedIn(String tier);

  /// Last week's result: the place.
  ///
  /// In en, this message translates to:
  /// **'You finished {place} of {size} with {xp} XP.'**
  String finishedPlace(String place, int size, int xp);

  /// Last week's result: the learner had left.
  ///
  /// In en, this message translates to:
  /// **'You had left the league before the week ended.'**
  String get leftBeforeEnd;

  /// Last week's result after a drop.
  ///
  /// In en, this message translates to:
  /// **'Climb back this week!'**
  String get climbBack;

  /// An amount of Amole (the app's coins). {amount} is already formatted.
  ///
  /// In en, this message translates to:
  /// **'{amount} Amole'**
  String amoleAmount(String amount);

  /// The learner's own row in the league.
  ///
  /// In en, this message translates to:
  /// **'{name} (You)'**
  String memberYou(String name);

  /// Screen-reader label of a league row.
  ///
  /// In en, this message translates to:
  /// **'Place {place}, {name}, {xp} XP'**
  String memberRowLabel(int place, String name, int xp);

  /// Added to a league row's screen-reader label.
  ///
  /// In en, this message translates to:
  /// **', {amole} Amole if the week ended now'**
  String memberRowReward(int amole);

  /// An amount of XP.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP'**
  String xpAmount(String xp);

  /// League divider over the places that move up.
  ///
  /// In en, this message translates to:
  /// **'Moving up'**
  String get movingUp;

  /// League divider over the places that move down.
  ///
  /// In en, this message translates to:
  /// **'Moving down'**
  String get movingDown;

  /// Time left in the league week.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left} other{{count} days left}}'**
  String daysLeft(int count);

  /// Time left in the league week.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour left} other{{count} hours left}}'**
  String hoursLeft(int count);

  /// League week in its last hour.
  ///
  /// In en, this message translates to:
  /// **'Ends soon'**
  String get endsSoon;

  /// League: how many move up.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Top 1 moves up} other{Top {count} move up}}'**
  String zoneTop(int count);

  /// League: how many move down, as a sentence of its own.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Bottom 1 moves down} other{Bottom {count} move down}}'**
  String zoneBottom(int count);

  /// League: how many move down, after "Top 2 move up · ".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{bottom 1 moves down} other{bottom {count} move down}}'**
  String zoneBottomAfter(int count);

  /// When the saved league was last updated.
  ///
  /// In en, this message translates to:
  /// **'updated just now'**
  String get updatedJustNow;

  /// When the saved league was last updated.
  ///
  /// In en, this message translates to:
  /// **'updated {minutes} min ago'**
  String updatedMinutesAgo(int minutes);

  /// When the saved league was last updated.
  ///
  /// In en, this message translates to:
  /// **'updated {hours} h ago'**
  String updatedHoursAgo(int hours);

  /// When the saved league was last updated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{updated 1 day ago} other{updated {count} days ago}}'**
  String updatedDaysAgo(int count);

  /// League screen offline note, e.g. "Offline · updated 5 min ago".
  ///
  /// In en, this message translates to:
  /// **'Offline · {detail}'**
  String offlineWith(String detail);

  /// League screen offline with no saved copy.
  ///
  /// In en, this message translates to:
  /// **'Connect to see your league'**
  String get connectToSeeLeague;

  /// League screen offline with no saved copy.
  ///
  /// In en, this message translates to:
  /// **'Your league shows here once you are online.'**
  String get leagueShowsOnline;

  /// League screen before joining.
  ///
  /// In en, this message translates to:
  /// **'Earn XP this week to join'**
  String get earnXpThisWeekToJoin;

  /// League screen before joining.
  ///
  /// In en, this message translates to:
  /// **'Your first lesson or practice this week puts you in a group of up to 30 learners in your league.'**
  String get joinLeagueExplain;

  /// Button on the league screen before joining.
  ///
  /// In en, this message translates to:
  /// **'Start a lesson'**
  String get startALesson;

  /// League screen when the learner stays out.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in a league'**
  String get notInLeague;

  /// League screen when the learner stays out.
  ///
  /// In en, this message translates to:
  /// **'\"Show me in leagues\" is off, so nobody sees your name and you are not ranked.'**
  String get notInLeagueExplain;

  /// League notice about names.
  ///
  /// In en, this message translates to:
  /// **'You can stay out of leagues at any time in Settings.'**
  String get stayOutAnytime;

  /// Button: leave leagues.
  ///
  /// In en, this message translates to:
  /// **'Stay out'**
  String get stayOut;

  /// Button: close a notice.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// The twelve Gregorian month names, January first, separated by commas (no spaces).
  ///
  /// In en, this message translates to:
  /// **'January,February,March,April,May,June,July,August,September,October,November,December'**
  String get monthNames;

  /// The twelve month names shortened, January first, separated by commas.
  ///
  /// In en, this message translates to:
  /// **'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'**
  String get monthShortNames;

  /// One letter per weekday, Monday first, separated by commas (streak calendar).
  ///
  /// In en, this message translates to:
  /// **'M,T,W,T,F,S,S'**
  String get weekdayInitials;

  /// A date: day and month name, e.g. "3 March".
  ///
  /// In en, this message translates to:
  /// **'{day} {month}'**
  String dayMonth(int day, String month);

  /// A month and year, e.g. "March 2026" (the year without separators).
  ///
  /// In en, this message translates to:
  /// **'{month} {year}'**
  String monthYear(String month, String year);

  /// Tooltip of the calendar arrow.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// Tooltip of the calendar arrow.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// Screen-reader state of a calendar day.
  ///
  /// In en, this message translates to:
  /// **'practised'**
  String get dayPractised;

  /// Screen-reader state of a calendar day.
  ///
  /// In en, this message translates to:
  /// **'not practised'**
  String get dayNotPractised;

  /// Screen-reader state of a future calendar day.
  ///
  /// In en, this message translates to:
  /// **'not yet'**
  String get dayNotYet;

  /// Screen-reader state of a calendar day before sign-up.
  ///
  /// In en, this message translates to:
  /// **'before you joined'**
  String get dayBeforeJoining;

  /// Screen-reader: the day is today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get today;

  /// Bean refill failed.
  ///
  /// In en, this message translates to:
  /// **'Not enough Amole for a refill.'**
  String get notEnoughAmoleRefill;

  /// Bean refill failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refill. Check your connection and try again.'**
  String get refillFailed;

  /// Stat sheet: what XP is.
  ///
  /// In en, this message translates to:
  /// **'You earn XP for every answer you get right in lessons and Practice.'**
  String get xpExplain;

  /// Stat sheet title and streak pill label.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day streak} other{{count} day streak}}'**
  String dayStreak(int count);

  /// Stat sheet: how a streak day counts.
  ///
  /// In en, this message translates to:
  /// **'A day counts when you finish a lesson.'**
  String get dayCounts;

  /// Stat sheet: the longest streak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Longest: 1 day} other{Longest: {count} days}}'**
  String longestStreak(int count);

  /// Stat sheet: what Amole is.
  ///
  /// In en, this message translates to:
  /// **'Earned by lessons, perfect lessons, streak milestones and Practice. Spent on bean refills.'**
  String get amoleExplain;

  /// Stat sheet offline: the streak calendar.
  ///
  /// In en, this message translates to:
  /// **'The calendar needs a connection. Connect to see it.'**
  String get calendarNeedsConnection;

  /// Stat sheet: the streak calendar failed to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the calendar'**
  String get calendarLoadFailed;

  /// Stat sheet offline: the Amole list.
  ///
  /// In en, this message translates to:
  /// **'The list needs a connection. Connect to see it.'**
  String get listNeedsConnection;

  /// Stat sheet: the Amole list failed to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the list'**
  String get listLoadFailed;

  /// Stat sheet when all beans are there.
  ///
  /// In en, this message translates to:
  /// **'Your beans are full'**
  String get beansFull;

  /// Stat sheet: how beans work, with the refill time.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Each wrong answer in a lesson uses a bean. They come back on their own, one every 1 minute.} other{Each wrong answer in a lesson uses a bean. They come back on their own, one every {count} minutes.}}'**
  String beansExplainEvery(int count);

  /// Stat sheet: how beans work.
  ///
  /// In en, this message translates to:
  /// **'Each wrong answer in a lesson uses a bean. They come back on their own over time.'**
  String get beansExplainSlowly;

  /// Refill button when offline.
  ///
  /// In en, this message translates to:
  /// **'Refill needs a connection'**
  String get refillNeedsConnection;

  /// Button: refill beans with Amole.
  ///
  /// In en, this message translates to:
  /// **'Refill with Amole'**
  String get refillWithAmole;

  /// Refill button when the learner cannot pay.
  ///
  /// In en, this message translates to:
  /// **'Not enough Amole'**
  String get notEnoughAmole;

  /// Stat sheet title: beans (the lives spent on wrong answers).
  ///
  /// In en, this message translates to:
  /// **'Beans'**
  String get beans;

  /// Stat sheet: how beans work, with the refill.
  ///
  /// In en, this message translates to:
  /// **'Each wrong answer in a lesson uses a bean. They come back on their own, or you can refill them now with Amole.'**
  String get beansExplainRefill;

  /// Bean timer: before the countdown.
  ///
  /// In en, this message translates to:
  /// **'Next bean in'**
  String get nextBeanIn;

  /// Screen-reader: the bean countdown.
  ///
  /// In en, this message translates to:
  /// **'Next bean in {time}'**
  String nextBeanInTime(String time);

  /// Under the bean timer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Refills 1 bean every 1 minute} other{Refills 1 bean every {count} minutes}}'**
  String refillsEvery(int count);

  /// Screen-reader label of the bean timer bar.
  ///
  /// In en, this message translates to:
  /// **'Next bean'**
  String get nextBean;

  /// Sheet title when no beans are left.
  ///
  /// In en, this message translates to:
  /// **'Out of Beans!'**
  String get outOfBeans;

  /// Sheet when no beans are left.
  ///
  /// In en, this message translates to:
  /// **'Don\'t worry, mistakes help you brew fluency! Beans refill automatically over time so you can continue your lessons.'**
  String get outOfBeansBody;

  /// Button: dismiss.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// Level-up sheet title when a streak freeze is earned.
  ///
  /// In en, this message translates to:
  /// **'Streak Freeze Unlocked!'**
  String get streakFreezeUnlocked;

  /// Level-up sheet title.
  ///
  /// In en, this message translates to:
  /// **'Crown Level Up!'**
  String get crownLevelUp;

  /// A crown level, short, e.g. "Lv 3".
  ///
  /// In en, this message translates to:
  /// **'Lv {level}'**
  String levelShort(int level);

  /// Level-up sheet text.
  ///
  /// In en, this message translates to:
  /// **'You reached crown level {level}'**
  String reachedCrownLevel(String level);

  /// Added to the level-up text when a skill opened.
  ///
  /// In en, this message translates to:
  /// **' and unlocked {skill}'**
  String andUnlocked(String skill);

  /// Ends the level-up text when a streak freeze is earned.
  ///
  /// In en, this message translates to:
  /// **'. A free streak freeze protects one missed day.'**
  String get freeStreakFreeze;

  /// Ends a sentence.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get fullStop;

  /// Exit sheet title in practice.
  ///
  /// In en, this message translates to:
  /// **'Leave this practice?'**
  String get leavePractice;

  /// Exit sheet title in a lesson.
  ///
  /// In en, this message translates to:
  /// **'Leave this lesson?'**
  String get leaveLesson;

  /// Exit sheet text in practice.
  ///
  /// In en, this message translates to:
  /// **'Your progress in this practice won\'t be saved.'**
  String get practiceNotSaved;

  /// Exit sheet text in a lesson.
  ///
  /// In en, this message translates to:
  /// **'Your progress in this lesson won\'t be saved.'**
  String get lessonNotSaved;

  /// Exit sheet: stay.
  ///
  /// In en, this message translates to:
  /// **'Keep learning'**
  String get keepLearning;

  /// Exit sheet: leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// Screen-reader label of a skill node.
  ///
  /// In en, this message translates to:
  /// **'{done} of {count} lessons done'**
  String lessonsDoneOfCount(int done, int count);

  /// The bubble over the current skill, and the button in its popover.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// Button in a completed skill's popover.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// Screen-reader state of a skill node.
  ///
  /// In en, this message translates to:
  /// **'locked'**
  String get nodeLocked;

  /// Screen-reader state of a skill node.
  ///
  /// In en, this message translates to:
  /// **'active, tap to start'**
  String get nodeActive;

  /// Screen-reader state of a skill node.
  ///
  /// In en, this message translates to:
  /// **'completed, tap to review'**
  String get nodeCompleted;

  /// Popover of a locked skill.
  ///
  /// In en, this message translates to:
  /// **'Finish the skills above to unlock this one.'**
  String get finishSkillsAbove;

  /// Popover of a skill: where the learner is.
  ///
  /// In en, this message translates to:
  /// **'Lesson {number} of {count}'**
  String lessonNofM(int number, int count);

  /// Popover of a one-lesson skill.
  ///
  /// In en, this message translates to:
  /// **'Ready when you are.'**
  String get readyWhenYouAre;

  /// Popover of a completed skill.
  ///
  /// In en, this message translates to:
  /// **'You\'ve completed this skill. Reviews don\'t earn XP or use beans.'**
  String get skillCompletedNote;

  /// Popover badge of a locked skill.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// Screen-reader label of a section banner.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} completed'**
  String completedOfTotal(int completed, int total);

  /// Badge on a section banner, e.g. "1/3 Completed".
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} Completed'**
  String completedCount(int completed, int total);

  /// Sync banner: everything is saved.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// Sync banner.
  ///
  /// In en, this message translates to:
  /// **'Offline -- downloaded lessons available'**
  String get offlineDownloadsAvailable;

  /// Sync banner.
  ///
  /// In en, this message translates to:
  /// **'Offline -- nothing downloaded'**
  String get offlineNothingDownloaded;

  /// Sync banner.
  ///
  /// In en, this message translates to:
  /// **'Syncing your offline progress...'**
  String get syncing;

  /// Sync banner.
  ///
  /// In en, this message translates to:
  /// **'Sync failed -- retrying...'**
  String get syncFailedRetrying;

  /// Sync banner when progress has waited a month.
  ///
  /// In en, this message translates to:
  /// **'{status} (unsynced for 30+ days -- please reconnect soon)'**
  String unsyncedLong(String status);

  /// Amole list when empty.
  ///
  /// In en, this message translates to:
  /// **'No Amole yet'**
  String get noAmoleYet;

  /// Screen-reader label of an Amole entry.
  ///
  /// In en, this message translates to:
  /// **'{reason}, {sign} {amount} Amole, {date}'**
  String amoleEntryLabel(
    String reason,
    String sign,
    String amount,
    String date,
  );

  /// Screen-reader: Amole earned.
  ///
  /// In en, this message translates to:
  /// **'plus'**
  String get plus;

  /// Screen-reader: Amole spent.
  ///
  /// In en, this message translates to:
  /// **'minus'**
  String get minus;

  /// Amole entry: the first Amole.
  ///
  /// In en, this message translates to:
  /// **'Welcome bonus'**
  String get reasonWelcome;

  /// Amole entry: the balance an older account started with.
  ///
  /// In en, this message translates to:
  /// **'Starting balance'**
  String get reasonStartingBalance;

  /// Amole entry.
  ///
  /// In en, this message translates to:
  /// **'Lesson finished'**
  String get reasonLessonFinished;

  /// Amole entry: a lesson with no mistakes.
  ///
  /// In en, this message translates to:
  /// **'Perfect lesson'**
  String get reasonPerfectLesson;

  /// Amole entry.
  ///
  /// In en, this message translates to:
  /// **'7-day streak'**
  String get reasonStreak7;

  /// Amole entry.
  ///
  /// In en, this message translates to:
  /// **'30-day streak'**
  String get reasonStreak30;

  /// Amole entry: spent on beans.
  ///
  /// In en, this message translates to:
  /// **'Bean refill'**
  String get reasonBeanRefill;

  /// Amole entry.
  ///
  /// In en, this message translates to:
  /// **'Practice session'**
  String get reasonPractice;

  /// Amole entry.
  ///
  /// In en, this message translates to:
  /// **'League reward'**
  String get reasonLeagueReward;

  /// The app's coins (a name; usually kept as is).
  ///
  /// In en, this message translates to:
  /// **'Amole'**
  String get amole;

  /// Hint over a spell-from-tiles answer.
  ///
  /// In en, this message translates to:
  /// **'Tap the characters below to spell it'**
  String get spellHint;

  /// Screen-reader label of the streak pill.
  ///
  /// In en, this message translates to:
  /// **'{count} day streak'**
  String pillStreak(int count);

  /// Screen-reader label of the beans pill.
  ///
  /// In en, this message translates to:
  /// **'{count} beans'**
  String pillBeans(int count);

  /// Screen-reader label of the beans pill.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} beans remaining'**
  String pillBeansOf(int count, int max);

  /// Screen-reader label of the XP pill.
  ///
  /// In en, this message translates to:
  /// **'{count} total XP'**
  String pillXp(int count);

  /// Screen-reader label of the Amole pill.
  ///
  /// In en, this message translates to:
  /// **'{count} Amole'**
  String pillAmole(int count);

  /// Screen-reader label of the page dots.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String pageOf(int page, int count);

  /// Button on an error.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Screen-reader label while something loads.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// Button: cancel a confirmation.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Button: check an answer.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// After a right answer.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get correct;

  /// After a wrong answer.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get notQuite;

  /// Hint over a sentence-building answer.
  ///
  /// In en, this message translates to:
  /// **'Tap words below to build your answer'**
  String get buildAnswerHint;

  /// Screen-reader: the empty gap in a sentence.
  ///
  /// In en, this message translates to:
  /// **'blank'**
  String get blank;

  /// Screen-reader: the gap with a chosen word.
  ///
  /// In en, this message translates to:
  /// **'blank, filled with {word}'**
  String blankFilled(String word);

  /// Screen-reader label of a play button.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get playAudio;

  /// Screen-reader label while audio plays.
  ///
  /// In en, this message translates to:
  /// **'Playing audio'**
  String get playingAudio;

  /// Screen-reader label of the lesson progress bar.
  ///
  /// In en, this message translates to:
  /// **'Lesson progress'**
  String get lessonProgress;

  /// A picture with no description, by its place.
  ///
  /// In en, this message translates to:
  /// **'Picture {number}'**
  String pictureN(int number);

  /// Daily reminder notification title.
  ///
  /// In en, this message translates to:
  /// **'Time for today\'s lesson'**
  String get reminderTitleToday;

  /// Daily reminder notification text.
  ///
  /// In en, this message translates to:
  /// **'A quick lesson keeps you going.'**
  String get reminderBodyToday;

  /// Daily reminder title when there is a streak.
  ///
  /// In en, this message translates to:
  /// **'Keep your {count}-day streak going'**
  String reminderTitleStreak(int count);

  /// Daily reminder text when there is a streak.
  ///
  /// In en, this message translates to:
  /// **'A quick lesson is enough.'**
  String get reminderBodyStreak;

  /// Title of the screen shown when this version of the app is too old to run.
  ///
  /// In en, this message translates to:
  /// **'Update needed'**
  String get updateRequiredTitle;

  /// Text of the screen shown when this version of the app is too old to run.
  ///
  /// In en, this message translates to:
  /// **'This version of Buna is too old to keep working. Update it to keep learning. Your progress is saved.'**
  String get updateRequiredBody;

  /// Button on the update-needed screen that opens the store's update.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// Shown when the update-needed button could not open the store.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the store. Update Buna from the store app.'**
  String get updateStoreFailed;

  /// Message offering an optional app update.
  ///
  /// In en, this message translates to:
  /// **'A new version of Buna is available.'**
  String get updateAvailable;

  /// Action on the message offering an optional app update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateAction;

  /// Message shown once an app update has downloaded in the background.
  ///
  /// In en, this message translates to:
  /// **'The update is ready.'**
  String get updateDownloaded;

  /// Action that installs a downloaded app update by restarting the app.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get updateRestart;

  /// Bottom bar tab: the learning path.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get tabLearn;

  /// Bottom bar tab, and its screen's title: the letters of the language being learned and how they sound.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get tabSounds;

  /// Bottom bar tab: the weekly league.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get tabLeague;

  /// Bottom bar tab: lessons downloaded for offline use.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get tabDownloads;

  /// Bottom bar tab: settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// Under the Sounds title: the language and its script, e.g. "Amharic · Fidel".
  ///
  /// In en, this message translates to:
  /// **'{language} · {script}'**
  String soundsSubtitle(String language, String script);

  /// Hint at the top of the Sounds screen.
  ///
  /// In en, this message translates to:
  /// **'Tap a letter to hear it.'**
  String get soundsTapToHear;

  /// Button in a letter's sheet that plays its sound.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get soundsPlay;

  /// Button in a letter's sheet that plays its sound slowly.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get soundsSlow;

  /// In a letter's sheet: another letter that is said the same way.
  ///
  /// In en, this message translates to:
  /// **'Sounds the same as {glyph}'**
  String soundsSameAs(String glyph);

  /// Heading of a letter's example word.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get soundsExample;

  /// Credit for the speakers who recorded the sounds.
  ///
  /// In en, this message translates to:
  /// **'Recorded by {names}'**
  String soundsRecordedBy(String names);

  /// Shown when the Sounds chart has never been downloaded and the phone is offline.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet once to load the sounds. After that they work offline.'**
  String get soundsOffline;

  /// Title when the Sounds chart could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the sounds'**
  String get soundsLoadFailed;

  /// Shown when a letter's sound could not be played.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play this sound.'**
  String get soundsCantPlay;

  /// Shown when the Sounds tab's chart was removed.
  ///
  /// In en, this message translates to:
  /// **'There is no sounds chart for this course yet.'**
  String get soundsNone;

  /// What a screen reader says for a letter tile.
  ///
  /// In en, this message translates to:
  /// **'{glyph}, {romanization}'**
  String soundsLetterLabel(String glyph, String romanization);

  /// Sounds tab: a letter that is a vowel (A E I O U in Qubee).
  ///
  /// In en, this message translates to:
  /// **'Vowel'**
  String get soundsVowel;

  /// Sounds tab: a letter that is a consonant.
  ///
  /// In en, this message translates to:
  /// **'Consonant'**
  String get soundsConsonant;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en', 'om'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
    case 'om':
      return AppLocalizationsOm();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
