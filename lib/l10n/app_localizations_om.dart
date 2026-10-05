// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Oromo (`om`).
class AppLocalizationsOm extends AppLocalizations {
  AppLocalizationsOm([String locale = 'om']) : super(locale);

  @override
  String get appLanguageTitle => 'Afaan appii';

  @override
  String get close => 'Cufi';

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'guyyoota $count',
      one: 'guyyaa 1',
    );
    return '$_temp0';
  }

  @override
  String get continueButton => 'Itti fufi';

  @override
  String get retry => 'Irra deebi\'i yaali';

  @override
  String get getStarted => 'Jalqabi';

  @override
  String get comingSoonBadge => 'DHIHOOTTI';

  @override
  String minutesPerDay(int minutes) {
    return 'daqiiqaa $minutes/guyyaatti';
  }

  @override
  String xpPerDay(int xp) {
    return '+$xp XP/guyyaatti';
  }

  @override
  String get goalCasual => 'Salphaa';

  @override
  String get goalCasualDescription => 'Ho\'isuu laafaa';

  @override
  String get goalRegular => 'Idilee';

  @override
  String get goalRegularDescription => 'Guddina itti fufaa';

  @override
  String get goalSerious => 'Cimaa';

  @override
  String get goalSeriousDescription => 'Yaadachuu saffisaa';

  @override
  String get goalIntense => 'Jabaa';

  @override
  String get goalIntenseDescription => 'Dandeettii saffisaa';

  @override
  String get splashTagline => 'Afaan Amaaraa siiqqee siiqqeen baradhu.';

  @override
  String get splashBrewing => 'Barnoonni kee qophaa\'aa jira...';

  @override
  String get onboardingSlide1Title => 'Afaan Amaaraa xiqqoo xiqqoon';

  @override
  String get onboardingSlide1Body =>
      'Qubee Fidalii fi haasaa guyyaa guyyaa daqiiqaa 5 qofaan guyyaatti baradhu.';

  @override
  String get onboardingSlide2Title => 'Walitti fufiinsaan kakaatee turi';

  @override
  String get onboardingSlide2Body =>
      'XP argadhu, walitti fufiinsa kee eegi, yeroo barattus kaartaa gaaraa ol ba\'i.';

  @override
  String get onboardingSlide3Title => 'Loqoda dhugaa baradhu';

  @override
  String get onboardingSlide3Body =>
      'Sagalee dubbattoota afaan dhalootaa gabaa Merkaatoo Finfinnee irraa waraabameen shaakali.';

  @override
  String get skip => 'Darbi';

  @override
  String get alreadyHaveAccount => 'Herrega qabdaa?';

  @override
  String get logIn => 'Seeni';

  @override
  String get learnQuestion => 'Maal barachuu barbaadda?';

  @override
  String get learnSubtitle =>
      'Aadaa fi maatii kee waliin walitti hidhamuuf imala kee filadhu.';

  @override
  String forSpeakers(String language) {
    return '$language dubbattootaaf';
  }

  @override
  String get switchCoursesAnytime =>
      'Koorsii yeroo barbaadde fuula jalqabaa ykn qindaa\'ina kee irraa jijjiiruu dandeessa.';

  @override
  String get coursesLoadFailed => 'Koorsiiwwan fe\'uun hin danda\'amne.';

  @override
  String get noCoursesYet => 'Ammaaf koorsiin hin jiru.';

  @override
  String get joinWaitlist => 'Tarree eeggataa makami';

  @override
  String onWaitlist(String language) {
    return 'Tarree eeggataa $language keessa jirta.';
  }

  @override
  String get chooseDailyGoal => 'Galma guyyaa kee filadhu';

  @override
  String get dailyGoalQuestion =>
      'Guyyaa guyyaan afaanota Habashaaf yeroo hammamii kennuu barbaadda?';

  @override
  String get recommendedBadge => 'KAN GORFAMU';

  @override
  String get dailyGoalTip =>
      'Gorsa: Yeroo sirna buna ganamaa kee qo\'achuun yaadannoo yeroo dheeraa cimsa.';

  @override
  String get changeGoalAnytime =>
      'Galma kee yeroo barbaadde Qindaa\'ina keessatti jijjiiruu dandeessa.';

  @override
  String get createAccountTitle => 'Herrega kee bilisaa uumi';

  @override
  String get createAccountBody =>
      'Walitti fufiinsa kee olkaa\'i, guddina kee meeshaalee hunda irratti walsimsiisi, har\'uma Afaan Amaaraa dubbachuu jalqabi.';

  @override
  String get continueWithGoogle => 'Google\'n itti fufi';

  @override
  String get continueWithApple => 'Apple\'n itti fufi';

  @override
  String get termsNote =>
      'Itti fufuun Haalawwan Tajaajilaa fi Imaammata Iccitii keenya ni fudhatta.';

  @override
  String get signInCancelled => 'Seenuun haqameera';

  @override
  String get signInFailed => 'Wanti tokko dogoggoreera — irra deebi\'ii yaali';

  @override
  String get back => 'Deebi\'i';

  @override
  String get settingsTitle => 'Qindaa\'ina';

  @override
  String get settingsLoadFailed => 'Qindaa\'ina kee fe\'uun hin danda\'amne';

  @override
  String get saveFailedCheckConnection =>
      'Olkaa\'uun hin danda\'amne. Walqunnamtii kee mirkaneeffadhu.';

  @override
  String get saveChangeFailed =>
      'Jijjiirama kee olkaa\'uun hin danda\'amne. Maaloo irra deebi\'ii yaali.';

  @override
  String get logOutQuestion => 'Ba\'uu?';

  @override
  String get logOutMessage =>
      'Barachuu itti fufuuf irra deebi\'ii seenuu qabda.';

  @override
  String get logOut => 'Ba\'i';

  @override
  String get unknown => 'Hin beekamu';

  @override
  String get signedInWithGoogle => 'Google\'n seenteetta';

  @override
  String get signedInWithApple => 'Apple\'n seenteetta';

  @override
  String get signedIn => 'Seenteetta';

  @override
  String get sectionLearning => 'Barachuu';

  @override
  String get dailyGoal => 'Galma guyyaa';

  @override
  String get course => 'Koorsii';

  @override
  String get sectionPreferences => 'Filannoowwan';

  @override
  String get notifications => 'Beeksisa';

  @override
  String get notificationsSubtitle =>
      'Yoo hin shaakalin sa\'aatii 2 galgalaa yaadachiisa';

  @override
  String get notificationsBlocked => 'Qindaa\'ina bilbila keetiin dhorkameera';

  @override
  String get notificationsAllow => 'Beeksisa hayyamuuf tuqi';

  @override
  String get sound => 'Sagalee';

  @override
  String get appearance => 'Bifa';

  @override
  String get appearanceSystem => 'Sirna';

  @override
  String get appearanceSystemDescription => 'Akka bilbila keetii';

  @override
  String get appearanceLight => 'Ifaa';

  @override
  String get appearanceLightDescription => 'Yeroo hunda ifaa';

  @override
  String get appearanceDark => 'Dukkana';

  @override
  String get appearanceDarkDescription => 'Yeroo hunda dukkana';

  @override
  String get sectionLeague => 'Liigii';

  @override
  String get showInLeagues => 'Liigii keessatti na agarsiisi';

  @override
  String get showInLeaguesSubtitle =>
      'Warri liigii kee keessa jiran maqaa kee isa jalqabaa ni argu';

  @override
  String get sectionAbout => 'Waa\'ee';

  @override
  String get sendFeedback => 'Yaada ergi';

  @override
  String get sendFeedbackSubtitle => 'Rakkoo gabaasi ykn yaada qoodi';

  @override
  String get licences => 'Hayyamoota';

  @override
  String get licencesSubtitle => 'Sooftiweerii madda banaa fi galata suuraalee';

  @override
  String get feedbackBug => 'Wanti tokko caccabeera';

  @override
  String get feedbackBugHint =>
      'Maaltu uumame, duraan dura maal hojjechaa turte?';

  @override
  String get feedbackContent => 'Dogoggora barnootaa';

  @override
  String get feedbackContentHint =>
      'Barnoota kam, maaltu dogoggora: jecha, hiika moo sagalee?';

  @override
  String get feedbackIdea => 'Yaada';

  @override
  String get feedbackIdeaHint => 'Maaltu Buna siif fooyyessa?';

  @override
  String get feedbackOther => 'Waan biraa';

  @override
  String get feedbackOtherHint => 'Waan barbaadde nutti himi.';

  @override
  String get feedbackTooMany =>
      'Har\'aaf gahaadha. Galatoomi! Boru irra deebi\'ii yaali.';

  @override
  String get feedbackSendFailed =>
      'Erguun hin danda\'amne. Walqunnamtii kee mirkaneeffadhuu irra deebi\'ii yaali.';

  @override
  String get done => 'Xumurameera';

  @override
  String get send => 'Ergi';

  @override
  String get feedbackIntro =>
      'Maaltu hojjeta, maaltu hin hojjetu nutti himi. Ergaa hunda ni dubbisna.';

  @override
  String get feedbackAbout => 'Waa\'ee maalii?';

  @override
  String get feedbackRating => 'Buna akkam jaallatte?';

  @override
  String get feedbackMessage => 'Ergaa kee';

  @override
  String get feedbackPickFirst =>
      'Jalqaba waa\'ee maalii akka ta\'e filadhu, achii as barreessi.';

  @override
  String get feedbackSentWith =>
      'Akka hordofnuuf herrega kee fi koorsii ammaa wajjin ergama.';

  @override
  String get thankYou => 'Galatoomi!';

  @override
  String get feedbackOnItsWay => 'Yaadni kee gara garee Buna deemaa jira.';

  @override
  String rateStars(int stars) {
    return 'Shan keessaa $stars kenni';
  }

  @override
  String get courses => 'Koorsiiwwan';

  @override
  String courseLabel(String course) {
    return 'Koorsii: $course';
  }

  @override
  String get courseSettings => 'Qindaa\'ina koorsii';

  @override
  String get manageDownloads => 'Buufamoota bulchi';

  @override
  String get weeklyLeague => 'Liigii torbanii';

  @override
  String get coursesLoadFailedShort =>
      'Koorsiiwwan kee fe\'uun hin danda\'amne';

  @override
  String currentCourse(String language) {
    return '$language, koorsii ammaa';
  }

  @override
  String switchToCourse(String language, String from) {
    return 'Gara $language $from irraa jijjiiri';
  }

  @override
  String fromLanguage(String language) {
    return '$language irraa';
  }

  @override
  String get addCourse => 'Koorsii dabali';

  @override
  String get courseOpenOfflineFirst =>
      'Koorsii kana yeroo jalqabaaf banuuf interneetii wajjin walqunnami.';

  @override
  String get courseSwitchFailed =>
      'Koorsii jijjiiruun hin danda\'amne. Maaloo irra deebi\'ii yaali.';

  @override
  String get chooseCourse => 'Koorsii filadhu';

  @override
  String courseComingSoon(String course) {
    return '$course · Dhihootti';
  }

  @override
  String skillsProgress(int done, int total) {
    return 'Dandeettii $total keessaa $done';
  }

  @override
  String deleteDownloadQuestion(String title) {
    return '\"$title\" haquu?';
  }

  @override
  String get deleteDownloadPending =>
      'Barnoonni kun guddina ammallee hin walsimsiifamne qaba. Buufama haquun sana hin tuqu — garagalcha toora malee jiru qofa haqa.';

  @override
  String get deleteDownloadMessage =>
      'Kun qabiyyee fi sagalee buufame meeshaa kee irraa haqa. Guddinni kee walsimsiifame hin tuqamu.';

  @override
  String get delete => 'Haqi';

  @override
  String deleteDownloadTooltip(String title) {
    return '\"$title\" haqi';
  }

  @override
  String get noDownloads => 'Ammaaf barnoonni buufame hin jiru.';

  @override
  String get noDownloadsMessage =>
      'Barnoonni karaa irraa buufatte as mul\'atu, toora malee taphachuuf qophaa\'anii.';

  @override
  String get practice => 'Shaakala';

  @override
  String get jumpToCurrentLesson => 'Gara barnoota kee ammaa deemi';

  @override
  String get practiceOffline => 'Toora malee — Shaakalli walqunnamtii barbaada';

  @override
  String wordsToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Jechoota $count har\'a irra deebi\'aman',
      one: 'Jecha 1 har\'a irra deebi\'amu',
    );
    return '$_temp0';
  }

  @override
  String get allCaughtUp =>
      'Hunda xumurteetta — har\'a waanti irra deebi\'amu hin jiru';

  @override
  String get joinThisWeeksLeague => 'Liigii torban kanaa makami';

  @override
  String leaguePlace(String place, int size, int xp) {
    return '$size keessaa $place · torban kana XP $xp';
  }

  @override
  String earnXpToJoin(String tier) {
    return 'Makamuuf XP argadhu · $tier';
  }

  @override
  String get downloadedOffline => 'Toora malee itti fayyadamuuf buufameera';

  @override
  String get downloading => 'Buufachaa jira';

  @override
  String get downloadFailed => 'Buufachuun hin milkoofne, irra deebi\'uuf tuqi';

  @override
  String get downloadForOffline => 'Toora malee itti fayyadamuuf buufadhu';

  @override
  String get offlineSavedProgress =>
      'Toora malee, guddina olkaa\'ame agarsiisaa jira';

  @override
  String get signInAgainTitle => 'Maaloo irra deebi\'ii seeni';

  @override
  String get signInAgainMessage =>
      'Yeroon seensa keetii xumurameera. Guddinni kee herrega kee irratti olkaa\'ameera, yeroo seentu ni deebi\'a.';

  @override
  String get signIn => 'Seeni';

  @override
  String get skillTreeLoadFailed =>
      'Muka dandeettii kee fe\'uun hin danda\'amne';

  @override
  String get checkConnection =>
      'Walqunnamtii kee mirkaneeffadhuu irra deebi\'ii yaali.';

  @override
  String get loadingLesson => 'Barnoota fe\'aa jira';

  @override
  String get lessonLoadFailed => 'Barnoota kana fe\'uun hin danda\'amne.';

  @override
  String get exitLesson => 'Barnoota keessaa ba\'i';

  @override
  String get youreOffline => 'Toora malee jirta';

  @override
  String get downloadWhileOnline =>
      'Toora malee fudhachuuf barnoota kana yeroo toora irra jirtu buufadhu.';

  @override
  String get goBack => 'Deebi\'i';

  @override
  String mistakesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dogoggora $count',
      one: 'dogoggora 1',
    );
    return '$_temp0';
  }

  @override
  String get reviewMistakesTitle => 'Dogoggora kee haa irra deebinu';

  @override
  String reviewMistakesBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Duraan gaaffilee $count dogoggorte. Yeroo kana sirriitti haa deebisnu!',
      one: 'Duraan gaaffii 1 dogoggorte. Yeroo kana sirriitti haa deebisnu!',
    );
    return '$_temp0';
  }

  @override
  String get progressSaveFailed =>
      'Guddina kee olkaa\'uun hin danda\'amne. Irra deebi\'uuf Itti fufi tuqi.';

  @override
  String get tapToPlay => 'Taphachiisuuf/irra deebi\'anii taphachiisuuf tuqi';

  @override
  String get translateSentence => 'Hima kana hiiki';

  @override
  String get reviewComplete => 'Irra deebiin xumurameera!';

  @override
  String get lessonComplete => 'Barnoonni xumurameera!';

  @override
  String get xpEarned => 'XP ARGAME';

  @override
  String get syncsWhenOnline => 'YEROO TOORA IRRA JIRTU WALSIMA';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Guyyoota $count',
      one: 'Guyyaa 1',
    );
    return '$_temp0';
  }

  @override
  String get streakLabel => 'WALITTI FUFIINSA';

  @override
  String get plusOneToday => '+1 Har\'a';

  @override
  String get accuracy => 'SIRRUMMAA';

  @override
  String get correctLabel => 'SIRRII';

  @override
  String get dailyGoalProgress => 'Guddina galma guyyaa';

  @override
  String get offlineXpWillSync =>
      'Toora malee jirta — XP barnoota kanaa yeroo toora irratti deebitu walsimee galma har\'aatiif lakkaa\'ama.';

  @override
  String xpToday(int total, int target) {
    return 'Har\'a XP $total / $target';
  }

  @override
  String finishedSkill(String skill) {
    return '$skill xumurte!';
  }

  @override
  String skillUnlocked(String skill) {
    return '$skill amma baneera.';
  }

  @override
  String allLessonsDone(int count) {
    return 'Barnoonni $count hundi xumuramaniiru.';
  }

  @override
  String lessonNofMDone(int number, int count) {
    return 'Barnoota $count keessaa ${number}ffaan xumurame';
  }

  @override
  String lessonsLeftInSkill(int count, String skill) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$skill xumuruuf barnoota $count dabalataa.',
      one: '$skill xumuruuf barnoota 1 dabalataa.',
    );
    return '$_temp0';
  }

  @override
  String lessonsDoneIn(String skill) {
    return 'Barnoota $skill keessatti xumuraman';
  }

  @override
  String get reviewsNoXp =>
      'Irra deebiin XP hin argamsiisu, ija bunaas hin fayyadamu. Waan barattee haaraa godhee tiksa.';

  @override
  String get tierGreenBean => 'Ija Magariisa';

  @override
  String get tierLightRoast => 'Akaawwii Salphaa';

  @override
  String get tierMediumRoast => 'Akaawwii Giddugaleessaa';

  @override
  String get tierDarkRoast => 'Akaawwii Gurraacha';

  @override
  String get tierGoldenCup => 'Siinii Warqee';

  @override
  String ordinal(int n) {
    return '${n}ffaa';
  }

  @override
  String tierLeague(String tier) {
    return 'Liigii $tier';
  }

  @override
  String movedUpTo(String tier) {
    return 'Gara $tier ol guddatte!';
  }

  @override
  String droppedTo(String tier) {
    return 'Gara $tier gadi buute';
  }

  @override
  String stayedIn(String tier) {
    return '$tier keessa turte';
  }

  @override
  String finishedPlace(String place, int size, int xp) {
    return '$size keessaa $place taatee XP ${xp}n xumurte.';
  }

  @override
  String get leftBeforeEnd =>
      'Torbanni osoo hin xumuramin liigii dhiiftee turte.';

  @override
  String get climbBack => 'Torban kana deebi\'ii ol ba\'i!';

  @override
  String amoleAmount(String amount) {
    return 'Amole $amount';
  }

  @override
  String memberYou(String name) {
    return '$name (Ati)';
  }

  @override
  String memberRowLabel(int place, String name, int xp) {
    return 'Sadarkaa $place, $name, XP $xp';
  }

  @override
  String memberRowReward(int amole) {
    return ', yoo torbanni amma xumurame Amole $amole';
  }

  @override
  String xpAmount(String xp) {
    return 'XP $xp';
  }

  @override
  String get movingUp => 'Kan ol guddatan';

  @override
  String get movingDown => 'Kan gadi bu\'an';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Guyyoota $count hafan',
      one: 'Guyyaa 1 hafe',
    );
    return '$_temp0';
  }

  @override
  String hoursLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sa\'aatii $count hafan',
      one: 'Sa\'aatii 1 hafe',
    );
    return '$_temp0';
  }

  @override
  String get endsSoon => 'Dhihootti xumurama';

  @override
  String zoneTop(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gubbaa $count ol guddatu',
      one: 'Gubbaa 1 ol guddata',
    );
    return '$_temp0';
  }

  @override
  String zoneBottom(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Jalaa $count gadi bu\'u',
      one: 'Jalaa 1 gadi bu\'a',
    );
    return '$_temp0';
  }

  @override
  String zoneBottomAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'jalaa $count gadi bu\'u',
      one: 'jalaa 1 gadi bu\'a',
    );
    return '$_temp0';
  }

  @override
  String get updatedJustNow => 'amma haaromfame';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'daqiiqaa $minutes dura haaromfame';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'sa\'aatii $hours dura haaromfame';
  }

  @override
  String updatedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'guyyoota $count dura haaromfame',
      one: 'guyyaa 1 dura haaromfame',
    );
    return '$_temp0';
  }

  @override
  String offlineWith(String detail) {
    return 'Toora malee · $detail';
  }

  @override
  String get connectToSeeLeague => 'Liigii kee arguuf walqunnami';

  @override
  String get leagueShowsOnline =>
      'Yeroo toora irra jirtu liigiin kee as mul\'ata.';

  @override
  String get earnXpThisWeekToJoin => 'Makamuuf torban kana XP argadhu';

  @override
  String get joinLeagueExplain =>
      'Barnoonni ykn shaakalli kee jalqabaa torban kanaa garee barattoota hanga 30 liigii kee keessa jiru keessa si galcha.';

  @override
  String get startALesson => 'Barnoota jalqabi';

  @override
  String get notInLeague => 'Liigii keessa hin jirtu';

  @override
  String get notInLeagueExplain =>
      '\"Liigii keessatti na agarsiisi\" cufameera, kanaaf namni maqaa kee hin argu, sadarkaas hin qabaattu.';

  @override
  String get stayOutAnytime =>
      'Yeroo kamiyyuu Qindaa\'ina keessatti liigii keessaa ba\'uu dandeessa.';

  @override
  String get stayOut => 'Alaa tura';

  @override
  String get gotIt => 'Hubadheera';

  @override
  String get monthNames =>
      'Amajjii,Guraandhala,Bitootessa,Elba,Caamsaa,Waxabajjii,Adooleessa,Hagayya,Fulbaana,Onkoloolessa,Sadaasa,Muddee';

  @override
  String get monthShortNames =>
      'Ama,Gur,Bit,Elb,Caa,Wax,Ado,Hag,Ful,Onk,Sad,Mud';

  @override
  String get weekdayInitials => 'W,Q,R,K,J,S,D';

  @override
  String dayMonth(int day, String month) {
    return '$month $day';
  }

  @override
  String monthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String get previousMonth => 'Ji\'a darbe';

  @override
  String get nextMonth => 'Ji\'a itti aanu';

  @override
  String get dayPractised => 'shaakalte';

  @override
  String get dayNotPractised => 'hin shaakalle';

  @override
  String get dayNotYet => 'ammallee';

  @override
  String get dayBeforeJoining => 'osoo hin makamin dura';

  @override
  String get today => 'har\'a';

  @override
  String get notEnoughAmoleRefill => 'Guutuuf Amole gahaan hin jiru.';

  @override
  String get refillFailed =>
      'Guutuun hin danda\'amne. Walqunnamtii kee mirkaneeffadhuu irra deebi\'ii yaali.';

  @override
  String get xpExplain =>
      'Deebii sirrii barnootaa fi shaakala keessatti kenniteef XP argatta.';

  @override
  String dayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Walitti fufiinsa guyyoota $count',
      one: 'Walitti fufiinsa guyyaa 1',
    );
    return '$_temp0';
  }

  @override
  String get dayCounts => 'Guyyaan kan lakkaa\'amu yeroo barnoota xumurtu.';

  @override
  String longestStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Isa dheeraa: guyyoota $count',
      one: 'Isa dheeraa: guyyaa 1',
    );
    return '$_temp0';
  }

  @override
  String get amoleExplain =>
      'Barnootaan, barnoota guutuun, galmoota walitti fufiinsaa fi shaakalaan argama. Ija guutuuf oola.';

  @override
  String get calendarNeedsConnection =>
      'Kaalaandariin walqunnamtii barbaada. Arguuf walqunnami.';

  @override
  String get calendarLoadFailed => 'Kaalaandarii fe\'uun hin danda\'amne';

  @override
  String get listNeedsConnection =>
      'Tarreen walqunnamtii barbaada. Arguuf walqunnami.';

  @override
  String get listLoadFailed => 'Tarree fe\'uun hin danda\'amne';

  @override
  String get beansFull => 'Iji bunaa kee guutuu dha';

  @override
  String beansExplainEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Deebiin dogoggoraa barnoota keessatti ija tokko fayyadama. Daqiiqaa $count hundatti tokko tokkoon ofumaan deebi\'u.',
      one: 'Deebiin dogoggoraa barnoota keessatti ija tokko fayyadama. Daqiiqaa hundatti tokko tokkoon ofumaan deebi\'u.',
    );
    return '$_temp0';
  }

  @override
  String get beansExplainSlowly =>
      'Deebiin dogoggoraa barnoota keessatti ija tokko fayyadama. Yeroo booda ofumaan deebi\'u.';

  @override
  String get refillNeedsConnection => 'Guutuun walqunnamtii barbaada';

  @override
  String get refillWithAmole => 'Amoleen guuti';

  @override
  String get notEnoughAmole => 'Amole gahaan hin jiru';

  @override
  String get beans => 'Ija bunaa';

  @override
  String get beansExplainRefill =>
      'Deebiin dogoggoraa barnoota keessatti ija tokko fayyadama. Ofumaan deebi\'u, ykn amma Amoleen guutuu dandeessa.';

  @override
  String get nextBeanIn => 'Iji itti aanu';

  @override
  String nextBeanInTime(String time) {
    return 'Iji itti aanu $time keessatti';
  }

  @override
  String refillsEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Daqiiqaa $count hundatti ija 1 guuta',
      one: 'Daqiiqaa hundatti ija 1 guuta',
    );
    return '$_temp0';
  }

  @override
  String get nextBean => 'Iji itti aanu';

  @override
  String get outOfBeans => 'Iji bunaa dhumeera!';

  @override
  String get outOfBeansBody =>
      'Hin yaaddin, dogoggorri dandeettii kee bilcheessa! Akka barnoota kee itti fuftuuf iji bunaa yeroo booda ofumaan guutama.';

  @override
  String get notNow => 'Amma miti';

  @override
  String get streakFreezeUnlocked => 'Eegumsi walitti fufiinsaa baneera!';

  @override
  String get crownLevelUp => 'Sadarkaan gonfoo ol ka\'eera!';

  @override
  String levelShort(int level) {
    return 'S$level';
  }

  @override
  String reachedCrownLevel(String level) {
    return 'Sadarkaa gonfoo $level geessee';
  }

  @override
  String andUnlocked(String skill) {
    return ' $skill illee banite';
  }

  @override
  String get freeStreakFreeze =>
      '. Eegumsi walitti fufiinsaa bilisaa guyyaa tokko darbe eega.';

  @override
  String get fullStop => '.';

  @override
  String get leavePractice => 'Shaakala kana dhiisuu?';

  @override
  String get leaveLesson => 'Barnoota kana dhiisuu?';

  @override
  String get practiceNotSaved =>
      'Guddinni kee shaakala kana keessaa hin olkaa\'amu.';

  @override
  String get lessonNotSaved =>
      'Guddinni kee barnoota kana keessaa hin olkaa\'amu.';

  @override
  String get keepLearning => 'Barachuu itti fufi';

  @override
  String get leave => 'Dhiisi';

  @override
  String lessonsDoneOfCount(int done, int count) {
    return 'Barnoota $count keessaa $done xumuraman';
  }

  @override
  String get start => 'Jalqabi';

  @override
  String get review => 'Irra deebi\'i';

  @override
  String get nodeLocked => 'cufameera';

  @override
  String get nodeActive => 'banaa, jalqabuuf tuqi';

  @override
  String get nodeCompleted => 'xumurameera, irra deebi\'uuf tuqi';

  @override
  String get finishSkillsAbove =>
      'Kana banuuf dandeettiiwwan gubbaa jiran xumuri.';

  @override
  String lessonNofM(int number, int count) {
    return 'Barnoota $count keessaa ${number}ffaa';
  }

  @override
  String get readyWhenYouAre => 'Yeroo qophoofte jalqabna.';

  @override
  String get skillCompletedNote =>
      'Dandeettii kana xumurteetta. Irra deebiin XP hin argamsiisu, ija bunaas hin fayyadamu.';

  @override
  String get locked => 'Cufameera';

  @override
  String completedOfTotal(int completed, int total) {
    return '$total keessaa $completed xumuraman';
  }

  @override
  String completedCount(int completed, int total) {
    return '$completed/$total Xumurame';
  }

  @override
  String get synced => 'Walsimeera';

  @override
  String get offlineDownloadsAvailable =>
      'Toora malee — barnoonni buufaman jiru';

  @override
  String get offlineNothingDownloaded => 'Toora malee — homaa hin buufamne';

  @override
  String get syncing => 'Guddina kee toora malee walsimsiisaa jira...';

  @override
  String get syncFailedRetrying =>
      'Walsimsiisuun hin milkoofne — irra deebi\'ee yaalaa jira...';

  @override
  String unsyncedLong(String status) {
    return '$status (guyyoota 30 ol hin walsimne — maaloo dhihootti walqunnami)';
  }

  @override
  String get noAmoleYet => 'Ammaaf Amole hin jiru';

  @override
  String amoleEntryLabel(
    String reason,
    String sign,
    String amount,
    String date,
  ) {
    return '$reason, $sign Amole $amount, $date';
  }

  @override
  String get plus => 'dabalata';

  @override
  String get minus => 'hir\'isa';

  @override
  String get reasonWelcome => 'Kennaa baga nagaan dhuftan';

  @override
  String get reasonStartingBalance => 'Haftee jalqabaa';

  @override
  String get reasonLessonFinished => 'Barnoonni xumurame';

  @override
  String get reasonPerfectLesson => 'Barnoota guutuu';

  @override
  String get reasonStreak7 => 'Walitti fufiinsa guyyaa 7';

  @override
  String get reasonStreak30 => 'Walitti fufiinsa guyyaa 30';

  @override
  String get reasonBeanRefill => 'Ija guutuu';

  @override
  String get reasonPractice => 'Yeroo shaakalaa';

  @override
  String get reasonLeagueReward => 'Badhaasa liigii';

  @override
  String get amole => 'Amole';

  @override
  String get spellHint => 'Barreessuuf qubeewwan armaan gadii tuqi';

  @override
  String pillStreak(int count) {
    return 'Walitti fufiinsa guyyaa $count';
  }

  @override
  String pillBeans(int count) {
    return 'Ija bunaa $count';
  }

  @override
  String pillBeansOf(int count, int max) {
    return 'Ija bunaa $max keessaa $count hafe';
  }

  @override
  String pillXp(int count) {
    return 'Waliigala XP $count';
  }

  @override
  String pillAmole(int count) {
    return 'Amole $count';
  }

  @override
  String pageOf(int page, int count) {
    return 'Fuula $count keessaa $page';
  }

  @override
  String get tryAgain => 'Irra deebi\'ii yaali';

  @override
  String get loading => 'Fe\'aa jira';

  @override
  String get cancel => 'Haqi';

  @override
  String get check => 'Mirkaneessi';

  @override
  String get correct => 'Sirrii!';

  @override
  String get notQuite => 'Sirrii miti';

  @override
  String get buildAnswerHint =>
      'Deebii kee ijaaruuf jechoota armaan gadii tuqi';

  @override
  String get blank => 'duwwaa';

  @override
  String blankFilled(String word) {
    return 'duwwaa, ${word}n guutame';
  }

  @override
  String get playAudio => 'Sagalee taphachiisi';

  @override
  String get playingAudio => 'Sagalee taphachiisaa jira';

  @override
  String get lessonProgress => 'Guddina barnootaa';

  @override
  String pictureN(int number) {
    return 'Suuraa $number';
  }

  @override
  String get reminderTitleToday => 'Yeroon barnoota har\'aa gaheera';

  @override
  String get reminderBodyToday => 'Barnoonni gabaabaan si itti fufsiisa.';

  @override
  String reminderTitleStreak(int count) {
    return 'Walitti fufiinsa guyyaa $count kee itti fufsiisi';
  }

  @override
  String get reminderBodyStreak => 'Barnoonni gabaabaan gahaadha.';

  @override
  String get updateRequiredTitle => 'Haaromsuun barbaachisa';

  @override
  String get updateRequiredBody =>
      'Gosti Buna kun baay\'ee dulloomeera, hojjechuu hin danda\'u. Barachuu itti fufuuf haaromsi. Guddinni kee olkaa\'ameera.';

  @override
  String get updateNow => 'Amma haaromsi';

  @override
  String get updateStoreFailed =>
      'Suuqii banuun hin danda\'amne. Buna appii suuqii irraa haaromsi.';

  @override
  String get updateAvailable => 'Gosti Buna haaraan jira.';

  @override
  String get updateAction => 'Haaromsi';

  @override
  String get updateDownloaded => 'Haaromsichi qophaa\'eera.';

  @override
  String get updateRestart => 'Irra deebi\'ii jalqabi';

  @override
  String get tabLearn => 'Barnoota';

  @override
  String get tabSounds => 'Sagaleewwan';

  @override
  String get tabLeague => 'Liigii';

  @override
  String get tabDownloads => 'Buufamoota';

  @override
  String get tabSettings => 'Qindaa\'ina';

  @override
  String soundsSubtitle(String language, String script) {
    return '$language · $script';
  }

  @override
  String get soundsTapToHear => 'Dhaggeeffachuuf qubee tuqi.';

  @override
  String get soundsPlay => 'Taphachiisi';

  @override
  String get soundsSlow => 'Suuta';

  @override
  String soundsSameAs(String glyph) {
    return 'Akkuma $glyph dubbatama';
  }

  @override
  String get soundsExample => 'Fakkeenya';

  @override
  String soundsRecordedBy(String names) {
    return 'Kan waraabe: $names';
  }

  @override
  String get soundsOffline =>
      'Sagaleewwan fe\'uuf yeroo tokko interneetii wajjin walqunnami. Achii booda interneetii malee hojjetu.';

  @override
  String get soundsLoadFailed => 'Sagaleewwan fe\'uun hin danda\'amne';

  @override
  String get soundsCantPlay => 'Sagalee kana taphachiisuun hin danda\'amne.';

  @override
  String get soundsNone => 'Koorsii kanaaf ammaaf chaartiin sagalee hin jiru.';

  @override
  String soundsLetterLabel(String glyph, String romanization) {
    return '$glyph, $romanization';
  }

  @override
  String get soundsVowel => 'Dubbachiiftuu';

  @override
  String get soundsConsonant => 'Dubbifamaa';
}
