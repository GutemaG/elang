// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appLanguageTitle => 'የመተግበሪያ ቋንቋ';

  @override
  String get close => 'ዝጋ';

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ቀናት',
      one: '1 ቀን',
    );
    return '$_temp0';
  }

  @override
  String get continueButton => 'ቀጥል';

  @override
  String get retry => 'እንደገና ሞክር';

  @override
  String get getStarted => 'እንጀምር';

  @override
  String get comingSoonBadge => 'በቅርቡ';

  @override
  String minutesPerDay(int minutes) {
    return '$minutes ደቂቃ/በቀን';
  }

  @override
  String xpPerDay(int xp) {
    return '+$xp XP/በቀን';
  }

  @override
  String get goalCasual => 'ቀላል';

  @override
  String get goalCasualDescription => 'ቀስ ያለ ማሟሟቂያ';

  @override
  String get goalRegular => 'መደበኛ';

  @override
  String get goalRegularDescription => 'የማያቋርጥ እድገት';

  @override
  String get goalSerious => 'ቁም ነገር';

  @override
  String get goalSeriousDescription => 'ፈጣን ማስታወስ';

  @override
  String get goalIntense => 'ጠንካራ';

  @override
  String get goalIntenseDescription => 'ፈጣን ቅልጥፍና';

  @override
  String get splashTagline => 'አማርኛን በእያንዳንዱ ፉት ይማሩ።';

  @override
  String get splashBrewing => 'ትምህርቶችዎ እየተፈሉ ነው...';

  @override
  String get onboardingSlide1Title => 'አማርኛ በትንሽ በትንሹ';

  @override
  String get onboardingSlide1Body =>
      'ፊደልን እና የዕለት ተዕለት ንግግርን በቀን 5 ደቂቃ ብቻ ይቆጣጠሩ።';

  @override
  String get onboardingSlide2Title => 'በተከታታይ ቀናት ተነሳሽ ይሁኑ';

  @override
  String get onboardingSlide2Body =>
      'XP ያግኙ፣ ተከታታይ ቀናትዎን ይጠብቁ፣ እና እየተማሩ የደጋውን ካርታ ይውጡ።';

  @override
  String get onboardingSlide3Title => 'እውነተኛ አነጋገርን ይማሩ';

  @override
  String get onboardingSlide3Body =>
      'ከአዲስ አበባ መርካቶ በተቀዳ የአፍ መፍቻ ተናጋሪዎች ድምፅ ይለማመዱ።';

  @override
  String get skip => 'ዝለል';

  @override
  String get alreadyHaveAccount => 'መለያ አለዎት?';

  @override
  String get logIn => 'ግባ';

  @override
  String get learnQuestion => 'ምን መማር ይፈልጋሉ?';

  @override
  String get learnSubtitle => 'ከቅርስዎ እና ከቤተሰብዎ ጋር ለመገናኘት ጉዞዎን ይምረጡ።';

  @override
  String forSpeakers(String language) {
    return 'ለ$language ተናጋሪዎች';
  }

  @override
  String get switchCoursesAnytime =>
      'ኮርሶችን በማንኛውም ጊዜ ከመነሻ ገጹ ወይም ከቅንብሮችዎ መቀየር ይችላሉ።';

  @override
  String get coursesLoadFailed => 'ኮርሶቹን መጫን አልተቻለም።';

  @override
  String get noCoursesYet => 'እስካሁን ምንም ኮርስ የለም።';

  @override
  String get joinWaitlist => 'የተጠባባቂ ዝርዝሩን ተቀላቀል';

  @override
  String onWaitlist(String language) {
    return 'ለ$language የተጠባባቂ ዝርዝር ውስጥ ገብተዋል።';
  }

  @override
  String get chooseDailyGoal => 'ዕለታዊ ግብዎን ይምረጡ';

  @override
  String get dailyGoalQuestion => 'በየቀኑ ለሐበሻ ቋንቋዎች ምን ያህል ጊዜ መስጠት ይፈልጋሉ?';

  @override
  String get recommendedBadge => 'የሚመከር';

  @override
  String get dailyGoalTip =>
      'ጠቃሚ ምክር፦ በጠዋት የቡና ሥነ ሥርዓትዎ ወቅት ማጥናት የረጅም ጊዜ ማስታወስን ያጠናክራል።';

  @override
  String get changeGoalAnytime => 'ግብዎን በማንኛውም ጊዜ በቅንብሮች ውስጥ መቀየር ይችላሉ።';

  @override
  String get createAccountTitle => 'ነፃ መለያዎን ይፍጠሩ';

  @override
  String get createAccountBody =>
      'ተከታታይ ቀናትዎን ያስቀምጡ፣ እድገትዎን በሁሉም መሣሪያዎች ያመሳስሉ፣ እና ዛሬውኑ አማርኛ መናገር ይጀምሩ።';

  @override
  String get continueWithGoogle => 'በGoogle ይቀጥሉ';

  @override
  String get continueWithApple => 'በApple ይቀጥሉ';

  @override
  String get termsNote => 'በመቀጠል በአገልግሎት ውላችን እና በግላዊነት ፖሊሲያችን ይስማማሉ።';

  @override
  String get signInCancelled => 'መግባት ተሰርዟል';

  @override
  String get signInFailed => 'የሆነ ችግር ተፈጥሯል — እንደገና ይሞክሩ';

  @override
  String get back => 'ተመለስ';

  @override
  String get settingsTitle => 'ቅንብሮች';

  @override
  String get settingsLoadFailed => 'ቅንብሮችዎን መጫን አልተቻለም';

  @override
  String get saveFailedCheckConnection => 'ማስቀመጥ አልተቻለም። ግንኙነትዎን ያረጋግጡ።';

  @override
  String get saveChangeFailed => 'ለውጥዎን ማስቀመጥ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get logOutQuestion => 'ይውጡ?';

  @override
  String get logOutMessage => 'መማርዎን ለመቀጠል እንደገና መግባት ያስፈልግዎታል።';

  @override
  String get logOut => 'ውጣ';

  @override
  String get unknown => 'ያልታወቀ';

  @override
  String get signedInWithGoogle => 'በGoogle ገብተዋል';

  @override
  String get signedInWithApple => 'በApple ገብተዋል';

  @override
  String get signedIn => 'ገብተዋል';

  @override
  String get sectionLearning => 'መማር';

  @override
  String get dailyGoal => 'ዕለታዊ ግብ';

  @override
  String get course => 'ኮርስ';

  @override
  String get sectionPreferences => 'ምርጫዎች';

  @override
  String get notifications => 'ማሳወቂያዎች';

  @override
  String get notificationsSubtitle => 'ካልተለማመዱ ከምሽቱ 2 ሰዓት ላይ ማስታወሻ';

  @override
  String get notificationsBlocked => 'በስልክዎ ቅንብሮች ታግዷል';

  @override
  String get notificationsAllow => 'ማሳወቂያዎችን ለመፍቀድ ይንኩ';

  @override
  String get sound => 'ድምፅ';

  @override
  String get appearance => 'ገጽታ';

  @override
  String get appearanceSystem => 'ስርዓት';

  @override
  String get appearanceSystemDescription => 'እንደ ስልክዎ';

  @override
  String get appearanceLight => 'ብሩህ';

  @override
  String get appearanceLightDescription => 'ሁልጊዜ ብሩህ';

  @override
  String get appearanceDark => 'ጨለማ';

  @override
  String get appearanceDarkDescription => 'ሁልጊዜ ጨለማ';

  @override
  String get sectionLeague => 'ሊግ';

  @override
  String get showInLeagues => 'በሊጎች ውስጥ አሳየኝ';

  @override
  String get showInLeaguesSubtitle => 'በሊግዎ ያሉ ሌሎች የመጀመሪያ ስምዎን ያያሉ';

  @override
  String get sectionAbout => 'ስለ';

  @override
  String get sendFeedback => 'አስተያየት ይላኩ';

  @override
  String get sendFeedbackSubtitle => 'ችግርን ያሳውቁ ወይም ሐሳብ ያጋሩ';

  @override
  String get licences => 'ፈቃዶች';

  @override
  String get licencesSubtitle => 'ክፍት ምንጭ ሶፍትዌር እና የሥዕል ምስጋናዎች';

  @override
  String get feedbackBug => 'የሆነ ነገር ተበላሽቷል';

  @override
  String get feedbackBugHint => 'ምን ተፈጠረ፣ ከዚያ በፊት ምን እያደረጉ ነበር?';

  @override
  String get feedbackContent => 'የትምህርት ስህተት';

  @override
  String get feedbackContentHint =>
      'የትኛው ትምህርት፣ ምንድን ነው የተሳሳተው፦ ቃል፣ ትርጉም ወይስ ድምፅ?';

  @override
  String get feedbackIdea => 'ሐሳብ';

  @override
  String get feedbackIdeaHint => 'Bunaን ለእርስዎ የተሻለ የሚያደርገው ምንድን ነው?';

  @override
  String get feedbackOther => 'ሌላ ነገር';

  @override
  String get feedbackOtherHint => 'ማንኛውንም ይንገሩን።';

  @override
  String get feedbackTooMany => 'ለዛሬ በቂ ነው። እናመሰግናለን! ነገ እንደገና ይሞክሩ።';

  @override
  String get feedbackSendFailed => 'መላክ አልተቻለም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get done => 'ተጠናቋል';

  @override
  String get send => 'ላክ';

  @override
  String get feedbackIntro => 'የሚሠራውንና የማይሠራውን ይንገሩን። እያንዳንዱን መልእክት እናነባለን።';

  @override
  String get feedbackAbout => 'ስለ ምንድን ነው?';

  @override
  String get feedbackRating => 'Bunaን እንዴት ወደዱት?';

  @override
  String get feedbackMessage => 'መልእክትዎ';

  @override
  String get feedbackPickFirst => 'መጀመሪያ ስለ ምን እንደሆነ ይምረጡ፣ ከዚያ እዚህ ይጻፉ።';

  @override
  String get feedbackSentWith => 'እንድንከታተል ከመለያዎ እና አሁን ካሉበት ኮርስ ጋር ይላካል።';

  @override
  String get thankYou => 'እናመሰግናለን!';

  @override
  String get feedbackOnItsWay => 'አስተያየትዎ ወደ Buna ቡድን እየሄደ ነው።';

  @override
  String rateStars(int stars) {
    return 'ከ5 $stars ይስጡ';
  }

  @override
  String get courses => 'ኮርሶች';

  @override
  String courseLabel(String course) {
    return 'ኮርስ፦ $course';
  }

  @override
  String get courseSettings => 'የኮርስ ቅንብሮች';

  @override
  String get manageDownloads => 'ውርዶችን ያስተዳድሩ';

  @override
  String get weeklyLeague => 'ሳምንታዊ ሊግ';

  @override
  String get coursesLoadFailedShort => 'ኮርሶችዎን መጫን አልተቻለም';

  @override
  String currentCourse(String language) {
    return '$language፣ የአሁኑ ኮርስ';
  }

  @override
  String switchToCourse(String language, String from) {
    return 'ከ$from ወደ $language ይቀይሩ';
  }

  @override
  String fromLanguage(String language) {
    return 'ከ$language';
  }

  @override
  String get addCourse => 'ኮርስ ያክሉ';

  @override
  String get courseOpenOfflineFirst =>
      'ይህን ኮርስ ለመጀመሪያ ጊዜ ለመክፈት ከበይነመረብ ጋር ይገናኙ።';

  @override
  String get courseSwitchFailed => 'ኮርስ መቀየር አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get chooseCourse => 'ኮርስ ይምረጡ';

  @override
  String courseComingSoon(String course) {
    return '$course · በቅርቡ';
  }

  @override
  String skillsProgress(int done, int total) {
    return 'ከ$total ክህሎቶች $done';
  }

  @override
  String deleteDownloadQuestion(String title) {
    return '\"$title\" ይሰረዝ?';
  }

  @override
  String get deleteDownloadPending =>
      'ይህ ትምህርት ገና ያልተመሳሰለ እድገት አለው። ውርዱን መሰረዝ ያንን አይነካውም — ከመስመር ውጭ ያለውን ቅጂ ብቻ ያስወግዳል።';

  @override
  String get deleteDownloadMessage =>
      'ይህ የወረደውን ይዘትና ድምፅ ከመሣሪያዎ ያስወግዳል። የተመሳሰለ እድገትዎ አይነካም።';

  @override
  String get delete => 'ሰርዝ';

  @override
  String deleteDownloadTooltip(String title) {
    return '\"$title\" ሰርዝ';
  }

  @override
  String get noDownloads => 'እስካሁን የወረዱ ትምህርቶች የሉም።';

  @override
  String get noDownloadsMessage =>
      'ከመንገዱ የሚያወርዷቸው ትምህርቶች ከመስመር ውጭ ለመጫወት ዝግጁ ሆነው እዚህ ይታያሉ።';

  @override
  String get practice => 'ልምምድ';

  @override
  String get jumpToCurrentLesson => 'ወደ አሁኑ ትምህርትዎ ይሂዱ';

  @override
  String get practiceOffline => 'ከመስመር ውጭ — ልምምድ ግንኙነት ያስፈልገዋል';

  @override
  String wordsToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ዛሬ የሚከለሱ $count ቃላት',
      one: 'ዛሬ የሚከለስ 1 ቃል',
    );
    return '$_temp0';
  }

  @override
  String get allCaughtUp => 'ሁሉንም ጨርሰዋል — ዛሬ የሚከለስ የለም';

  @override
  String get joinThisWeeksLeague => 'የዚህን ሳምንት ሊግ ይቀላቀሉ';

  @override
  String leaguePlace(String place, int size, int xp) {
    return 'ከ$size $place · በዚህ ሳምንት $xp XP';
  }

  @override
  String earnXpToJoin(String tier) {
    return 'ለመቀላቀል XP ያግኙ · $tier';
  }

  @override
  String get downloadedOffline => 'ከመስመር ውጭ ለመጠቀም ወርዷል';

  @override
  String get downloading => 'በማውረድ ላይ';

  @override
  String get downloadFailed => 'ማውረድ አልተሳካም፣ እንደገና ለመሞከር ይንኩ';

  @override
  String get downloadForOffline => 'ከመስመር ውጭ ለመጠቀም ያውርዱ';

  @override
  String get offlineSavedProgress => 'ከመስመር ውጭ፣ የተቀመጠ እድገት እየታየ ነው';

  @override
  String get signInAgainTitle => 'እባክዎ እንደገና ይግቡ';

  @override
  String get signInAgainMessage =>
      'ክፍለ ጊዜዎ አብቅቷል። እድገትዎ በመለያዎ ተቀምጧል፣ ሲገቡም ይመለሳል።';

  @override
  String get signIn => 'ግባ';

  @override
  String get skillTreeLoadFailed => 'የክህሎት ዛፍዎን መጫን አልተቻለም';

  @override
  String get checkConnection => 'ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get loadingLesson => 'ትምህርት በመጫን ላይ';

  @override
  String get lessonLoadFailed => 'ይህን ትምህርት መጫን አልተቻለም።';

  @override
  String get exitLesson => 'ከትምህርቱ ውጣ';

  @override
  String get youreOffline => 'ከመስመር ውጭ ነዎት';

  @override
  String get downloadWhileOnline =>
      'ከመስመር ውጭ ለመውሰድ ይህን ትምህርት በመስመር ላይ ሳሉ ያውርዱ።';

  @override
  String get goBack => 'ተመለስ';

  @override
  String mistakesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ስህተቶች',
      one: '1 ስህተት',
    );
    return '$_temp0';
  }

  @override
  String get reviewMistakesTitle => 'ስህተቶችዎን እንከልስ';

  @override
  String reviewMistakesBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ቀደም ብለው $count ጥያቄዎችን ስተዋል። በዚህ ጊዜ በትክክል እንመልሳቸው!',
      one: 'ቀደም ብለው 1 ጥያቄ ስተዋል። በዚህ ጊዜ በትክክል እንመልሰው!',
    );
    return '$_temp0';
  }

  @override
  String get progressSaveFailed => 'እድገትዎን ማስቀመጥ አልተቻለም። እንደገና ለመሞከር ቀጥልን ይንኩ።';

  @override
  String get tapToPlay => 'ለማጫወት/ደግሞ ለማጫወት ይንኩ';

  @override
  String get translateSentence => 'ይህን ዓረፍተ ነገር ይተርጉሙ';

  @override
  String get reviewComplete => 'ክለሳው ተጠናቋል!';

  @override
  String get lessonComplete => 'ትምህርቱ ተጠናቋል!';

  @override
  String get xpEarned => 'የተገኘ XP';

  @override
  String get syncsWhenOnline => 'በመስመር ላይ ሲሆኑ ይመሳሰላል';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ቀናት',
      one: '1 ቀን',
    );
    return '$_temp0';
  }

  @override
  String get streakLabel => 'ተከታታይ ቀናት';

  @override
  String get plusOneToday => '+1 ዛሬ';

  @override
  String get accuracy => 'ትክክለኛነት';

  @override
  String get correctLabel => 'ትክክል';

  @override
  String get dailyGoalProgress => 'የዕለታዊ ግብ እድገት';

  @override
  String get offlineXpWillSync =>
      'ከመስመር ውጭ ነዎት — የዚህ ትምህርት XP ተመልሰው መስመር ላይ ሲሆኑ ተመሳስሎ ለዛሬው ግብ ይቆጠራል።';

  @override
  String xpToday(int total, int target) {
    return 'ዛሬ $total / $target XP';
  }

  @override
  String finishedSkill(String skill) {
    return '$skillን ጨርሰዋል!';
  }

  @override
  String skillUnlocked(String skill) {
    return '$skill አሁን ተከፍቷል።';
  }

  @override
  String allLessonsDone(int count) {
    return 'ሁሉም $count ትምህርቶች ተጠናቀዋል።';
  }

  @override
  String lessonNofMDone(int number, int count) {
    return 'ከ$count ትምህርት $numberኛው ተጠናቋል';
  }

  @override
  String lessonsLeftInSkill(int count, String skill) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$skillን ለመጨረስ $count ተጨማሪ ትምህርቶች።',
      one: '$skillን ለመጨረስ 1 ተጨማሪ ትምህርት።',
    );
    return '$_temp0';
  }

  @override
  String lessonsDoneIn(String skill) {
    return 'በ$skill የተጠናቀቁ ትምህርቶች';
  }

  @override
  String get reviewsNoXp =>
      'ክለሳዎች XP አያስገኙም ፍሬም አይጠቀሙም። የተማሩትን ትኩስ አድርገው ያቆያሉ።';

  @override
  String get tierGreenBean => 'አረንጓዴ ፍሬ';

  @override
  String get tierLightRoast => 'ቀላል ቁሌት';

  @override
  String get tierMediumRoast => 'መካከለኛ ቁሌት';

  @override
  String get tierDarkRoast => 'ጥቁር ቁሌት';

  @override
  String get tierGoldenCup => 'ወርቃማ ስኒ';

  @override
  String ordinal(int n) {
    return '$nኛ';
  }

  @override
  String tierLeague(String tier) {
    return 'የ$tier ሊግ';
  }

  @override
  String movedUpTo(String tier) {
    return 'ወደ $tier ከፍ ብለዋል!';
  }

  @override
  String droppedTo(String tier) {
    return 'ወደ $tier ወርደዋል';
  }

  @override
  String stayedIn(String tier) {
    return 'በ$tier ቆይተዋል';
  }

  @override
  String finishedPlace(String place, int size, int xp) {
    return 'ከ$size $place ሆነው በ$xp XP ጨርሰዋል።';
  }

  @override
  String get leftBeforeEnd => 'ሳምንቱ ከማለቁ በፊት ሊጉን ለቀው ነበር።';

  @override
  String get climbBack => 'በዚህ ሳምንት ተመልሰው ይውጡ!';

  @override
  String amoleAmount(String amount) {
    return '$amount Amole';
  }

  @override
  String memberYou(String name) {
    return '$name (እርስዎ)';
  }

  @override
  String memberRowLabel(int place, String name, int xp) {
    return 'ደረጃ $place፣ $name፣ $xp XP';
  }

  @override
  String memberRowReward(int amole) {
    return '፣ ሳምንቱ አሁን ቢያልቅ $amole Amole';
  }

  @override
  String xpAmount(String xp) {
    return '$xp XP';
  }

  @override
  String get movingUp => 'ከፍ የሚሉ';

  @override
  String get movingDown => 'የሚወርዱ';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ቀናት ቀርተዋል',
      one: '1 ቀን ቀርቷል',
    );
    return '$_temp0';
  }

  @override
  String hoursLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ሰዓታት ቀርተዋል',
      one: '1 ሰዓት ቀርቷል',
    );
    return '$_temp0';
  }

  @override
  String get endsSoon => 'በቅርቡ ያበቃል';

  @override
  String zoneTop(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ከላይ $count ከፍ ይላሉ',
      one: 'ከላይ 1 ከፍ ይላል',
    );
    return '$_temp0';
  }

  @override
  String zoneBottom(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ከታች $count ይወርዳሉ',
      one: 'ከታች 1 ይወርዳል',
    );
    return '$_temp0';
  }

  @override
  String zoneBottomAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ከታች $count ይወርዳሉ',
      one: 'ከታች 1 ይወርዳል',
    );
    return '$_temp0';
  }

  @override
  String get updatedJustNow => 'አሁን ተዘምኗል';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'ከ$minutes ደቂቃ በፊት ተዘምኗል';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'ከ$hours ሰዓት በፊት ተዘምኗል';
  }

  @override
  String updatedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ከ$count ቀናት በፊት ተዘምኗል',
      one: 'ከ1 ቀን በፊት ተዘምኗል',
    );
    return '$_temp0';
  }

  @override
  String offlineWith(String detail) {
    return 'ከመስመር ውጭ · $detail';
  }

  @override
  String get connectToSeeLeague => 'ሊግዎን ለማየት ይገናኙ';

  @override
  String get leagueShowsOnline => 'መስመር ላይ ሲሆኑ ሊግዎ እዚህ ይታያል።';

  @override
  String get earnXpThisWeekToJoin => 'ለመቀላቀል በዚህ ሳምንት XP ያግኙ';

  @override
  String get joinLeagueExplain =>
      'በዚህ ሳምንት የመጀመሪያ ትምህርትዎ ወይም ልምምድዎ በሊግዎ እስከ 30 ተማሪዎች ባለው ቡድን ውስጥ ያስገባዎታል።';

  @override
  String get startALesson => 'ትምህርት ይጀምሩ';

  @override
  String get notInLeague => 'በሊግ ውስጥ አይደሉም';

  @override
  String get notInLeagueExplain =>
      '\"በሊጎች ውስጥ አሳየኝ\" ጠፍቷል፣ ስለዚህ ማንም ስምዎን አያይም፣ ደረጃም አይሰጥዎትም።';

  @override
  String get stayOutAnytime => 'በማንኛውም ጊዜ በቅንብሮች ውስጥ ከሊጎች መውጣት ይችላሉ።';

  @override
  String get stayOut => 'ውጭ ልቆይ';

  @override
  String get gotIt => 'ገባኝ';

  @override
  String get monthNames =>
      'ጃንዋሪ,ፌብሩዋሪ,ማርች,ኤፕሪል,ሜይ,ጁን,ጁላይ,ኦገስት,ሴፕቴምበር,ኦክቶበር,ኖቬምበር,ዲሴምበር';

  @override
  String get monthShortNames => 'ጃን,ፌብ,ማር,ኤፕ,ሜይ,ጁን,ጁላ,ኦገ,ሴፕ,ኦክ,ኖቬ,ዲሴ';

  @override
  String get weekdayInitials => 'ሰ,ማ,ረ,ሐ,ዓ,ቅ,እ';

  @override
  String dayMonth(int day, String month) {
    return '$month $day';
  }

  @override
  String monthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String get previousMonth => 'ያለፈው ወር';

  @override
  String get nextMonth => 'የሚቀጥለው ወር';

  @override
  String get dayPractised => 'ተለማምደዋል';

  @override
  String get dayNotPractised => 'አልተለማመዱም';

  @override
  String get dayNotYet => 'ገና ነው';

  @override
  String get dayBeforeJoining => 'ከመቀላቀልዎ በፊት';

  @override
  String get today => 'ዛሬ';

  @override
  String get notEnoughAmoleRefill => 'ለመሙላት በቂ Amole የለም።';

  @override
  String get refillFailed => 'መሙላት አልተቻለም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get xpExplain => 'በትምህርቶችና በልምምድ ለሚመልሱት እያንዳንዱ ትክክለኛ መልስ XP ያገኛሉ።';

  @override
  String dayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ተከታታይ ቀናት',
      one: '1 ተከታታይ ቀን',
    );
    return '$_temp0';
  }

  @override
  String get dayCounts => 'አንድ ቀን የሚቆጠረው ትምህርት ሲጨርሱ ነው።';

  @override
  String longestStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ረጅሙ፦ $count ቀናት',
      one: 'ረጅሙ፦ 1 ቀን',
    );
    return '$_temp0';
  }

  @override
  String get amoleExplain =>
      'በትምህርቶች፣ ፍጹም ትምህርቶች፣ በተከታታይ ቀናት ምዕራፎች እና በልምምድ ይገኛል። ፍሬ ለመሙላት ይውላል።';

  @override
  String get calendarNeedsConnection => 'ቀን መቁጠሪያው ግንኙነት ያስፈልገዋል። ለማየት ይገናኙ።';

  @override
  String get calendarLoadFailed => 'ቀን መቁጠሪያውን መጫን አልተቻለም';

  @override
  String get listNeedsConnection => 'ዝርዝሩ ግንኙነት ያስፈልገዋል። ለማየት ይገናኙ።';

  @override
  String get listLoadFailed => 'ዝርዝሩን መጫን አልተቻለም';

  @override
  String get beansFull => 'ፍሬዎችዎ ሞልተዋል';

  @override
  String beansExplainEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'በትምህርት ውስጥ እያንዳንዱ የተሳሳተ መልስ አንድ ፍሬ ይጠቀማል። በየ$count ደቂቃው አንድ እያሉ በራሳቸው ይመለሳሉ።',
      one: 'በትምህርት ውስጥ እያንዳንዱ የተሳሳተ መልስ አንድ ፍሬ ይጠቀማል። በየደቂቃው አንድ እያሉ በራሳቸው ይመለሳሉ።',
    );
    return '$_temp0';
  }

  @override
  String get beansExplainSlowly =>
      'በትምህርት ውስጥ እያንዳንዱ የተሳሳተ መልስ አንድ ፍሬ ይጠቀማል። ከጊዜ በኋላ በራሳቸው ይመለሳሉ።';

  @override
  String get refillNeedsConnection => 'መሙላት ግንኙነት ያስፈልገዋል';

  @override
  String get refillWithAmole => 'በAmole ይሙሉ';

  @override
  String get notEnoughAmole => 'በቂ Amole የለም';

  @override
  String get beans => 'ፍሬዎች';

  @override
  String get beansExplainRefill =>
      'በትምህርት ውስጥ እያንዳንዱ የተሳሳተ መልስ አንድ ፍሬ ይጠቀማል። በራሳቸው ይመለሳሉ፣ ወይም አሁን በAmole መሙላት ይችላሉ።';

  @override
  String get nextBeanIn => 'ቀጣዩ ፍሬ በ';

  @override
  String nextBeanInTime(String time) {
    return 'ቀጣዩ ፍሬ በ$time';
  }

  @override
  String refillsEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'በየ$count ደቂቃው 1 ፍሬ ይሞላል',
      one: 'በየደቂቃው 1 ፍሬ ይሞላል',
    );
    return '$_temp0';
  }

  @override
  String get nextBean => 'ቀጣዩ ፍሬ';

  @override
  String get outOfBeans => 'ፍሬዎች አልቀዋል!';

  @override
  String get outOfBeansBody =>
      'አይጨነቁ፣ ስህተቶች ቅልጥፍናን ለማፍላት ይረዳሉ! ትምህርቶችዎን እንዲቀጥሉ ፍሬዎች ከጊዜ በኋላ በራሳቸው ይሞላሉ።';

  @override
  String get notNow => 'አሁን አይደለም';

  @override
  String get streakFreezeUnlocked => 'የተከታታይ ቀናት ጥበቃ ተከፍቷል!';

  @override
  String get crownLevelUp => 'የዘውድ ደረጃ ጨምሯል!';

  @override
  String levelShort(int level) {
    return 'ደ$level';
  }

  @override
  String reachedCrownLevel(String level) {
    return 'የዘውድ ደረጃ $level ደርሰዋል';
  }

  @override
  String andUnlocked(String skill) {
    return ' እና $skillን ከፍተዋል';
  }

  @override
  String get freeStreakFreeze => '። ነፃ የተከታታይ ቀናት ጥበቃ አንድ ያመለጠ ቀን ይጠብቃል።';

  @override
  String get fullStop => '።';

  @override
  String get leavePractice => 'ይህን ልምምድ ይተዋሉ?';

  @override
  String get leaveLesson => 'ይህን ትምህርት ይተዋሉ?';

  @override
  String get practiceNotSaved => 'በዚህ ልምምድ ያለዎት እድገት አይቀመጥም።';

  @override
  String get lessonNotSaved => 'በዚህ ትምህርት ያለዎት እድገት አይቀመጥም።';

  @override
  String get keepLearning => 'መማር ቀጥል';

  @override
  String get leave => 'ተው';

  @override
  String lessonsDoneOfCount(int done, int count) {
    return 'ከ$count ትምህርቶች $done ተጠናቀዋል';
  }

  @override
  String get start => 'ጀምር';

  @override
  String get review => 'ከልስ';

  @override
  String get nodeLocked => 'ተቆልፏል';

  @override
  String get nodeActive => 'ንቁ፣ ለመጀመር ይንኩ';

  @override
  String get nodeCompleted => 'ተጠናቋል፣ ለመከለስ ይንኩ';

  @override
  String get finishSkillsAbove => 'ይህን ለመክፈት ከላይ ያሉትን ክህሎቶች ይጨርሱ።';

  @override
  String lessonNofM(int number, int count) {
    return 'ከ$count ትምህርት $numberኛው';
  }

  @override
  String get readyWhenYouAre => 'ሲዘጋጁ እንጀምራለን።';

  @override
  String get skillCompletedNote =>
      'ይህን ክህሎት አጠናቀዋል። ክለሳዎች XP አያስገኙም ፍሬም አይጠቀሙም።';

  @override
  String get locked => 'ተቆልፏል';

  @override
  String completedOfTotal(int completed, int total) {
    return 'ከ$total $completed ተጠናቀዋል';
  }

  @override
  String completedCount(int completed, int total) {
    return '$completed/$total ተጠናቀዋል';
  }

  @override
  String get synced => 'ተመሳስሏል';

  @override
  String get offlineDownloadsAvailable => 'ከመስመር ውጭ — የወረዱ ትምህርቶች አሉ';

  @override
  String get offlineNothingDownloaded => 'ከመስመር ውጭ — ምንም አልወረደም';

  @override
  String get syncing => 'ከመስመር ውጭ ያለዎትን እድገት በማመሳሰል ላይ...';

  @override
  String get syncFailedRetrying => 'ማመሳሰል አልተሳካም — እንደገና በመሞከር ላይ...';

  @override
  String unsyncedLong(String status) {
    return '$status (ከ30 ቀናት በላይ አልተመሳሰለም — እባክዎ በቅርቡ ይገናኙ)';
  }

  @override
  String get noAmoleYet => 'እስካሁን Amole የለም';

  @override
  String amoleEntryLabel(
    String reason,
    String sign,
    String amount,
    String date,
  ) {
    return '$reason፣ $sign $amount Amole፣ $date';
  }

  @override
  String get plus => 'ተጨማሪ';

  @override
  String get minus => 'ቅናሽ';

  @override
  String get reasonWelcome => 'የእንኳን ደህና መጡ ስጦታ';

  @override
  String get reasonStartingBalance => 'የመነሻ ቀሪ ሂሳብ';

  @override
  String get reasonLessonFinished => 'ትምህርት ተጠናቋል';

  @override
  String get reasonPerfectLesson => 'ፍጹም ትምህርት';

  @override
  String get reasonStreak7 => 'የ7 ቀን ተከታታይነት';

  @override
  String get reasonStreak30 => 'የ30 ቀን ተከታታይነት';

  @override
  String get reasonBeanRefill => 'ፍሬ መሙላት';

  @override
  String get reasonPractice => 'የልምምድ ክፍለ ጊዜ';

  @override
  String get reasonLeagueReward => 'የሊግ ሽልማት';

  @override
  String get amole => 'Amole';

  @override
  String get spellHint => 'ለመጻፍ ከታች ያሉትን ፊደላት ይንኩ';

  @override
  String pillStreak(int count) {
    return '$count ተከታታይ ቀናት';
  }

  @override
  String pillBeans(int count) {
    return '$count ፍሬዎች';
  }

  @override
  String pillBeansOf(int count, int max) {
    return 'ከ$max $count ፍሬዎች ቀርተዋል';
  }

  @override
  String pillXp(int count) {
    return 'በአጠቃላይ $count XP';
  }

  @override
  String pillAmole(int count) {
    return '$count Amole';
  }

  @override
  String pageOf(int page, int count) {
    return 'ገጽ $page ከ$count';
  }

  @override
  String get tryAgain => 'እንደገና ይሞክሩ';

  @override
  String get loading => 'በመጫን ላይ';

  @override
  String get cancel => 'ይቅር';

  @override
  String get check => 'አረጋግጥ';

  @override
  String get correct => 'ትክክል!';

  @override
  String get notQuite => 'ልክ አይደለም';

  @override
  String get buildAnswerHint => 'መልስዎን ለመገንባት ከታች ያሉትን ቃላት ይንኩ';

  @override
  String get blank => 'ባዶ';

  @override
  String blankFilled(String word) {
    return 'ባዶ፣ በ$word የተሞላ';
  }

  @override
  String get playAudio => 'ድምፁን አጫውት';

  @override
  String get playingAudio => 'ድምፅ በመጫወት ላይ';

  @override
  String get lessonProgress => 'የትምህርት እድገት';

  @override
  String pictureN(int number) {
    return 'ሥዕል $number';
  }

  @override
  String get reminderTitleToday => 'የዛሬው ትምህርት ጊዜ ደርሷል';

  @override
  String get reminderBodyToday => 'ፈጣን ትምህርት ያስቀጥልዎታል።';

  @override
  String reminderTitleStreak(int count) {
    return 'የ$count ቀን ተከታታይነትዎን ያስቀጥሉ';
  }

  @override
  String get reminderBodyStreak => 'ፈጣን ትምህርት በቂ ነው።';

  @override
  String get updateRequiredTitle => 'ማዘመን ያስፈልጋል';

  @override
  String get updateRequiredBody =>
      'ይህ የቡና ስሪት በጣም ስለቆየ መስራት አይችልም። መማርዎን ለመቀጠል ያዘምኑት። እድገትዎ ተቀምጧል።';

  @override
  String get updateNow => 'አሁን ያዘምኑ';

  @override
  String get updateStoreFailed => 'መደብሩን መክፈት አልተቻለም። ቡናን ከመደብሩ መተግበሪያ ያዘምኑ።';

  @override
  String get updateAvailable => 'አዲስ የቡና ስሪት አለ።';

  @override
  String get updateAction => 'አዘምን';

  @override
  String get updateDownloaded => 'ማዘመኛው ዝግጁ ነው።';

  @override
  String get updateRestart => 'እንደገና ጀምር';

  @override
  String get tabLearn => 'ትምህርት';

  @override
  String get tabSounds => 'ድምጾች';

  @override
  String get tabLeague => 'ሊግ';

  @override
  String get tabDownloads => 'ውርዶች';

  @override
  String get tabSettings => 'ቅንብሮች';

  @override
  String soundsSubtitle(String language, String script) {
    return '$language · $script';
  }

  @override
  String get soundsTapToHear => 'ለመስማት ፊደሉን ይንኩ።';

  @override
  String get soundsPlay => 'አጫውት';

  @override
  String get soundsSlow => 'በዝግታ';

  @override
  String soundsSameAs(String glyph) {
    return 'ልክ እንደ $glyph ይነበባል';
  }

  @override
  String get soundsExample => 'ምሳሌ';

  @override
  String soundsRecordedBy(String names) {
    return 'የቀረጹት፦ $names';
  }

  @override
  String get soundsOffline =>
      'ድምጾቹን ለመጫን አንድ ጊዜ ከበይነመረብ ጋር ይገናኙ። ከዚያ ያለ በይነመረብ ይሰራሉ።';

  @override
  String get soundsLoadFailed => 'ድምጾቹን መጫን አልተቻለም';

  @override
  String get soundsCantPlay => 'ይህን ድምጽ ማጫወት አልተቻለም።';

  @override
  String get soundsNone => 'ለዚህ ኮርስ እስካሁን የድምጽ ሰንጠረዥ የለም።';

  @override
  String soundsLetterLabel(String glyph, String romanization) {
    return '$glyph፣ $romanization';
  }
}
