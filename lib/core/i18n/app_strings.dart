/// Every user-visible string in the app, in one place per language.
///
/// The base class *is* Hinglish — the voice the screens were designed in — so
/// a new language only has to override what it actually translates and never
/// risks rendering a blank label. Bhojpuri extends Hindi rather than the base,
/// since the two are close enough that an untranslated string reads better in
/// Devanagari than in Latin script.
///
/// Resolved from the `language` wire code carried on the user record
/// (`users.language`), which is why [AppStrings.forCode] takes a raw string
/// instead of the `AppLanguage` enum — that enum lives in the data layer, and
/// this file must not depend on it.
library;

class AppStrings {
  const AppStrings();

  /// Maps a `users.language` value onto a string table. Unknown or missing
  /// codes fall back to Hinglish, which is what the UI was written in.
  static const AppStrings hinglish = AppStrings();
  static const AppStrings hindi = _Hindi();
  static const AppStrings english = _English();
  static const AppStrings bhojpuri = _Bhojpuri();

  static AppStrings forCode(String? code) => switch (code) {
    'hi' => hindi,
    'en' => english,
    'bho' => bhojpuri,
    _ => hinglish,
  };

  // ── Brand ─────────────────────────────────────────────────────────────────

  /// The product name is not translated; it is the brand.
  String get appName => 'KaamWala';
  String get tagline => 'Book labour instantly';

  // ── Generic actions & errors ──────────────────────────────────────────────

  String get back => 'Wapas';
  String get save => 'Save karein';
  String get cancel => 'Cancel';
  String get confirm => 'Confirm';
  String get retry => 'Dobara try karein';
  String get keepIt => 'Rehne dein';
  String get reset => 'Reset';
  String get optional => 'optional';

  String get errorOffline => 'Internet nahi mil raha';
  String get errorGeneric => 'Kuch galat ho gaya';
  String get errorTryAgain => 'Dobara try karein.';
  String get errorGenericFull => 'Kuch galat ho gaya. Dobara try karein.';
  String get errNetwork =>
      'Internet nahi mil raha. Connection check karke dobara try karein.';
  String get errTimeout => 'Server jawab nahi de raha. Dobara try karein.';
  String get errParse => 'Server se galat jawab aaya. Dobara try karein.';
  String get errUnauthorized => 'Session khatam ho gaya. Dobara login karein.';

  /// `<Feature> jald aayega` — the placeholder every not-yet-built row uses.
  String comingSoon(String what) => '$what jald aayega';

  // ── Bottom navigation ─────────────────────────────────────────────────────

  String get navSearch => 'Search';
  String get navBookings => 'Bookings';
  String get navProfile => 'Profile';
  String get navAccount => 'Account';

  // ── Login ─────────────────────────────────────────────────────────────────

  String get loginWelcome => 'Welcome back 👋';
  String get loginSubtitle => 'Apna phone number enter karein, OTP aayega';
  String get phoneNumber => 'Phone Number';
  String get phoneHint => '98765 43210';
  String get sendOtp => 'OTP Bhejo';
  String get phoneInvalid => 'Poora 10-digit number daalein';
  String get newUserPrompt => 'Naya user? ';
  String get register => 'Register karein';
  String get registration => 'Registration';
  String get or => 'ya';
  String get googleLogin => 'Google se login karein';
  String get googleSignIn => 'Google Sign-In';
  String get termsLine =>
      'Aage badhne ka matlab hai aap Terms aur Privacy Policy se sehmat hain';

  // ── OTP ───────────────────────────────────────────────────────────────────

  String get otpTitle => 'OTP Verify karein';
  String get otpSentLine => '6-digit code bheja gaya hai';
  String get otpVerify => 'Verify & Login';
  String get otpResend => 'Dobara OTP bhejein';
  String get otpResendIn => 'Resend in ';
  String get otpResent => 'Naya OTP bhej diya';
  String get otpLoggedIn => 'Login ho gaya!';
  String get otpInfo =>
      'OTP SMS ya WhatsApp pe aayega. Kisi ko share mat karein.';

  // ── Search ────────────────────────────────────────────────────────────────

  String get yourLocation => 'Aapka location';
  String get setLocation => 'Location set karein';
  String get searchHint => 'Electrician, Plumber dhundein...';
  String get filter => 'Filter';
  String get searching => 'Dhoond rahe hain...';
  String get noneFound => 'Koi nahi mila';
  String labourFound(int count) => '$count kaam wale milein paas mein';
  String get noLabourTitle => 'Koi kaam wala nahi mila';
  String get noLabourMessage =>
      'Filter thoda kam karein ya doosra skill try karein.';
  String get clearFilters => 'Filter hatao';
  String get pickLabourTitle => 'Kisi kaam wale ko chunein';
  String get pickLabourMessage =>
      'List ya map se select karein, detail yahan khulegi.';
  String get notifications => 'Notifications';
  String get noNotifications => 'Abhi koi naya notification nahi';
  String get changeRadius => 'Search radius badlein';
  String get connect => 'Connect';
  String get perDayToday => '/ din aaj';
  String get youAreHere => 'Aap yahan hain';
  String get mapNotLoaded => 'Map load nahi hua';
  String get mapsKeyMissing => 'Map ke liye Google Maps key chahiye';

  // ── Filter / sort / radius sheets ─────────────────────────────────────────

  String get filterTitle => 'Filter karein';
  String get workType => 'Kaam ka type';
  String get skillsNotLoaded => 'Skill list load nahi hui';
  String get maxRate => 'Zyada se zyada rate';
  String get noLimit => 'Koi limit nahi';
  String get howFar => 'Kitni door tak';
  String get onlyAvailable => 'Sirf available';
  String get onDutyNow => 'Jo abhi duty pe hain';
  String get applyFilter => 'Filter lagao';
  String get searchThisArea => 'Is area mein dhoondein';
  String get sortTitle => 'Sort karein';
  String get sortDistance => 'Sabse paas';
  String get sortRating => 'Rating zyada';
  String get sortPriceLow => 'Rate kam';
  String get sortPriceHigh => 'Rate zyada';

  // ── Labour detail ─────────────────────────────────────────────────────────

  String get labourDetail => 'Labour Detail';
  String get saveToList => 'Save karein';
  String get removeFromSaved => 'Saved list se hatao';
  String get share => 'Share karein';
  String get shareLinkCopied => 'Share link copy ho gaya';
  String savedAdded(String name) => '$name saved list mein add hua';
  String savedRemoved(String name) => '$name saved list se hata diya';
  String get statYearsExperience => 'Saal ka anubhav';
  String get statJobsDone => 'Kaam kiye';
  String get statReviewsGot => 'Reviews mile';
  String get locationAddress => 'Location / Address';
  String awayFromYou(String distance) => 'Aapse $distance';
  String metresAway(int metres) => '$metres m door';
  String kmAway(String km) => '$km km door';
  String get todayRate => 'Aaj ki rate';
  String get perDay => '/ din';
  String get skills => 'Skills';
  String get availabilityToday => 'Availability aaj';
  String get availableCallNow => 'Available – turant bulao';
  String get notOnDuty => 'Abhi duty pe nahi';
  String timingLine(String timing) => 'Timing: $timing';
  String get experience => 'Experience';
  String years(int count) => '$count saal';
  String get contact => 'Contact';
  String get contactAfterBooking => 'Book karne ke baad milega';
  String get aboutMe => 'Apne baare mein';
  String get recentReviews => 'Recent Reviews';
  String get reviewsLoading => 'Reviews load ho rahe hain...';
  String get noReviewsYet => 'Abhi tak koi review nahi aaya';
  String reviewsCount(int count) => '($count reviews)';
  String get bookingSent => 'Booking bhej di';
  String bookNow(int price) => 'Book Now – ₹$price / din';
  String get available => 'Available';
  String get busy => 'Busy';
  String get workGeneric => 'Kaam';
  String get labourGeneric => 'Kaam wala';

  // ── Booking sheet ─────────────────────────────────────────────────────────

  String get whichDay => 'Kis din chahiye';
  String get howMuchWork => 'Kitna kaam';
  String get fullDay => 'Full day';
  String get halfDay => 'Half day';
  String get eightHours => '8 ghante';
  String get fourHours => '4 ghante';
  String get fullDayBooking => 'Full day booking';
  String get halfDayBooking => 'Half day booking';
  String get whereIsWork => 'Kaam kahan hai';
  String get addressHint => 'Address daalein';
  String get addressRequired => 'Kaam ka address daalein';
  String get bookingNotesHint => 'Kuch batana hai? (optional)';
  String get total => 'Total';
  String get confirmBooking => 'Booking confirm karein';
  String get today => 'Aaj';
  String get tomorrow => 'Kal';

  /// Monday-first, matching `DateTime.weekday`.
  List<String> get weekdaysShort => const [
    'Som',
    'Mangal',
    'Budh',
    'Guru',
    'Shukr',
    'Shani',
    'Ravi',
  ];

  List<String> get monthsShort => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  List<String> get monthsLong => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // ── Bookings list ─────────────────────────────────────────────────────────

  String get myBookings => 'Meri Bookings';
  String bookingsSummary(int active, int done) =>
      '$active active · $done completed';
  String get tabAll => 'Sab';
  String get tabActive => 'Active';
  String get tabPending => 'Pending';
  String get tabDone => 'Done';
  String get cancelBookingTitle => 'Booking cancel karein?';
  String cancelBookingMessage(String name) =>
      '$name ki booking cancel ho jaayegi. '
      'Baar baar cancel karne se rating gir sakti hai.';
  String get yesCancel => 'Haan, cancel karein';
  String get bookingCancelled => 'Booking cancel ho gayi';
  String reviewSubmitted(String name) => '$name ko review de diya';
  String get statusConfirmed => 'Confirmed';
  String get statusPending => 'Pending';
  String get statusCompleted => 'Completed';
  String get statusCancelled => 'Cancelled';
  String get statusDeclined => 'Declined';
  String get liveTrack => 'Live track';
  String get call => 'Call';
  String get details => 'Details';
  String get reviewDone => 'Review diya';
  String get giveReview => 'Review do';
  String get bookAgain => 'Dobara book karein';
  String numberAfterAccept(String name) =>
      '$name ka number booking accept hone par milega';
  String get emptyAllTitle => 'Abhi koi booking nahi';
  String get emptyAllMessage =>
      'Search se kaam wala chunein aur pehli booking karein.';
  String get emptyActiveTitle => 'Koi active booking nahi';
  String get emptyActiveMessage => 'Confirmed bookings yahan dikhengi.';
  String get emptyPendingTitle => 'Kuch pending nahi';
  String get emptyPendingMessage =>
      'Jo request abhi accept nahi hui, wo yahan aayegi.';
  String get emptyDoneTitle => 'Abhi tak kuch complete nahi hua';
  String get emptyDoneMessage => 'Poore hue kaam yahan history mein rahenge.';
  String get findLabour => 'Kaam wale dhundein';

  // ── Review sheet ──────────────────────────────────────────────────────────

  String get howWasWork => 'Kaam kaisa laga?';
  List<String> get ratingLabels => const [
    'Bilkul theek nahi',
    'Theek nahi tha',
    'Chalega',
    'Achha kaam',
    'Bahut badhiya!',
  ];
  String get reviewCommentHint => 'Kuch likhna hai? (optional)';
  String get sendReview => 'Review bhejein';

  // ── Job stages & tracking ─────────────────────────────────────────────────

  String get stagePending => 'Pending';
  String get stageOnTheWay => 'Raaste mein';
  String get stageWorking => 'Kaam chal raha';
  String get stageCompleted => 'Poora hua';

  String get stepAccept => 'Accept';
  String get stepOnTheWay => 'Raaste mein';
  String get stepWorking => 'Kaam';
  String get stepDone => 'Poora';

  String get liveTracking => 'Live tracking';
  String get waitingForAccept => 'Accept ka intezaar';
  String get workStarted => 'Kaam shuru ho gaya';
  String get workFinished => 'Kaam poora hua';
  String get onTheWay => 'Raaste mein';
  String get almostThere => 'Bas pahunchne wala hai';
  String minutesAway(int minutes) => '$minutes min door';
  String get trackingStalled =>
      'Location update nahi ho pa raha — dobara koshish jaari hai';
  String get requestSent => 'Request bhej di gayi';
  String awaitingAccept(String name) =>
      '$name ke accept karte hi live location yahan dikhne lagegi.';
  String get workerMarker => 'Kaam wala';
  String get siteMarker => 'Kaam ki jagah';

  // ── Profile ───────────────────────────────────────────────────────────────

  String get shareProfile => 'Profile share karein';
  String get referralCodeSoon => 'Referral code jald aayega';
  String referralCodeIs(String code) => 'Referral code: $code';
  String get editProfile => 'Profile Edit karein';
  String get statTotalBookings => 'Total Bookings';
  String get statTotalSpend => 'Total Spend';
  String get statReviewsGiven => 'Reviews Diye';
  String get myActivity => 'Meri Activity';
  String get activeBookings => 'Active Bookings';
  String get noBookingsYet => 'Abhi koi booking nahi';
  String bookingsRunning(int count) => '$count bookings chal rahi hain';
  String get savedLabour => 'Saved Labour';
  String savedLabourCount(int count) => '$count log saved hain';
  String get myReviews => 'Meri Reviews';
  String reviewsGivenCount(int count) => '$count reviews diye hain';
  String get savedListSoon => 'Saved list jald aayegi';
  String get reviewsPageSoon => 'Reviews page jald aayega';
  String get addressSection => 'Address';
  String get addNewAddress => 'Naya address add karein';
  String get addressAddSoon => 'Address add jald aayega';
  String editAddressPrompt(String label) => '$label edit karein';

  // ── Profile edit ──────────────────────────────────────────────────────────

  String get editProfileTitle => 'Profile edit karein';
  String get nameLabel => 'Poora naam';
  String get nameHint => 'Jaise: Amit Khurana';
  String get nameRequired => 'Naam daalein';
  String get emailLabel => 'Email (optional)';
  String get emailHint => 'aap@example.com';
  String get emailInvalid => 'Sahi email daalein';
  String get cityLabel => 'Sheher';
  String get cityHint => 'Jaise: Gurgaon';
  String get addressLabel => 'Address';
  String get profileAddressHint => 'Ghar ya site ka address';
  String get saveChanges => 'Save karein';
  String get profileUpdated => 'Profile update ho gaya';

  // ── Location picker ───────────────────────────────────────────────────────

  String get locationTitle => 'Location set karein';
  String get locationSubtitle =>
      'Yahan se hi aas-paas ke kaam wale dhoonde jaayenge.';
  String get savedAddresses => 'Saved addresses';
  String get noSavedAddresses => 'Koi saved address nahi';
  String get pickOnMap => 'Map par point karein';
  String get pickOnMapHint => 'Map ko hilaakar pin sahi jagah par le jaayein';
  String get typeAddress => 'Address type karein';
  String get useThisLocation => 'Yahi location use karein';
  String get locationSaved => 'Location save ho gaya';
  String get locationNeedsAddress => 'Address ya sheher daalein';
  String get currentPin => 'Chuna hua point';
  String get defaultBadge => 'Default';

  // ── Account settings ──────────────────────────────────────────────────────

  String get accountSettings => 'Account Settings';
  String get preferences => 'Preferences';
  String get whatsappAlerts => 'WhatsApp Alerts';
  String get smsAlerts => 'SMS Alerts';
  String get languageRow => 'Language / Bhasha';
  String get chooseLanguage => 'Bhasha chunein';
  String get payment => 'Payment';
  String get paymentMethods => 'Payment Methods';
  String get paymentMethodsSoon => 'Payment methods jald aayenge';
  String get paymentHistory => 'Payment History';
  String get paymentHistorySoon => 'Payment history jald aayegi';
  String get referEarn => 'Refer & Earn';
  String get badgeNew => 'New';
  String get privacySecurity => 'Privacy & Security';
  String get privacySettings => 'Privacy Settings';
  String get privacySettingsSoon => 'Privacy settings jald aayengi';
  String get accountSecurity => 'Account Security';
  String get accountSecuritySoon => 'Account security jald aayegi';
  String get help => 'Help';
  String get helpSupport => 'Help & Support';
  String get supportLine => 'Support: 1800-123-4567';
  String get terms => 'Terms & Conditions';
  String get appVersion => 'App Version';
  String get logout => 'Logout';
  String get logoutTitle => 'Logout karein?';
  String get logoutMessage => 'Aapko dobara OTP se login karna padega.';
}

// ── Hindi ───────────────────────────────────────────────────────────────────

class _Hindi extends AppStrings {
  const _Hindi();

  @override
  String get tagline => 'तुरंत मज़दूर बुक करें';

  @override
  String get back => 'वापस';
  @override
  String get save => 'सेव करें';
  @override
  String get cancel => 'रद्द करें';
  @override
  String get confirm => 'कन्फर्म';
  @override
  String get retry => 'दोबारा कोशिश करें';
  @override
  String get keepIt => 'रहने दें';
  @override
  String get reset => 'रीसेट';
  @override
  String get optional => 'ज़रूरी नहीं';

  @override
  String get errorOffline => 'इंटरनेट नहीं मिल रहा';
  @override
  String get errorGeneric => 'कुछ गड़बड़ हो गई';
  @override
  String get errorTryAgain => 'दोबारा कोशिश करें।';
  @override
  String get errorGenericFull => 'कुछ गड़बड़ हो गई। दोबारा कोशिश करें।';
  @override
  String get errNetwork =>
      'इंटरनेट नहीं मिल रहा। कनेक्शन जाँचकर दोबारा कोशिश करें।';
  @override
  String get errTimeout => 'सर्वर जवाब नहीं दे रहा। दोबारा कोशिश करें।';
  @override
  String get errParse => 'सर्वर से ग़लत जवाब आया। दोबारा कोशिश करें।';
  @override
  String get errUnauthorized => 'सेशन ख़त्म हो गया। दोबारा लॉगिन करें।';

  @override
  String comingSoon(String what) => '$what जल्द आएगा';

  @override
  String get navSearch => 'खोजें';
  @override
  String get navBookings => 'बुकिंग';
  @override
  String get navProfile => 'प्रोफ़ाइल';
  @override
  String get navAccount => 'अकाउंट';

  @override
  String get loginWelcome => 'वापस स्वागत है 👋';
  @override
  String get loginSubtitle => 'अपना फ़ोन नंबर डालें, OTP आएगा';
  @override
  String get phoneNumber => 'फ़ोन नंबर';
  @override
  String get sendOtp => 'OTP भेजें';
  @override
  String get phoneInvalid => 'पूरा 10 अंकों का नंबर डालें';
  @override
  String get newUserPrompt => 'नए यूज़र हैं? ';
  @override
  String get register => 'रजिस्टर करें';
  @override
  String get registration => 'रजिस्ट्रेशन';
  @override
  String get or => 'या';
  @override
  String get googleLogin => 'Google से लॉगिन करें';
  @override
  String get termsLine =>
      'आगे बढ़ने का मतलब है आप Terms और Privacy Policy से सहमत हैं';

  @override
  String get otpTitle => 'OTP वेरिफ़ाई करें';
  @override
  String get otpSentLine => '6 अंकों का कोड भेजा गया है';
  @override
  String get otpVerify => 'वेरिफ़ाई और लॉगिन';
  @override
  String get otpResend => 'दोबारा OTP भेजें';
  @override
  String get otpResendIn => 'दोबारा भेजें ';
  @override
  String get otpResent => 'नया OTP भेज दिया';
  @override
  String get otpLoggedIn => 'लॉगिन हो गया!';
  @override
  String get otpInfo => 'OTP SMS या WhatsApp पर आएगा। किसी को शेयर न करें।';

  @override
  String get yourLocation => 'आपका लोकेशन';
  @override
  String get setLocation => 'लोकेशन सेट करें';
  @override
  String get searchHint => 'इलेक्ट्रीशियन, प्लंबर खोजें...';
  @override
  String get filter => 'फ़िल्टर';
  @override
  String get searching => 'खोज रहे हैं...';
  @override
  String get noneFound => 'कोई नहीं मिला';
  @override
  String labourFound(int count) => 'आस-पास $count कारीगर मिले';
  @override
  String get noLabourTitle => 'कोई कारीगर नहीं मिला';
  @override
  String get noLabourMessage => 'फ़िल्टर थोड़ा कम करें या दूसरा स्किल चुनें।';
  @override
  String get clearFilters => 'फ़िल्टर हटाएँ';
  @override
  String get pickLabourTitle => 'कोई कारीगर चुनें';
  @override
  String get pickLabourMessage =>
      'लिस्ट या मैप से चुनें, डिटेल यहाँ खुलेगी।';
  @override
  String get notifications => 'नोटिफ़िकेशन';
  @override
  String get noNotifications => 'अभी कोई नया नोटिफ़िकेशन नहीं';
  @override
  String get changeRadius => 'खोज का दायरा बदलें';
  @override
  String get connect => 'कनेक्ट';
  @override
  String get perDayToday => '/ दिन आज';
  @override
  String get youAreHere => 'आप यहाँ हैं';
  @override
  String get mapNotLoaded => 'मैप लोड नहीं हुआ';
  @override
  String get mapsKeyMissing => 'मैप के लिए Google Maps key चाहिए';

  @override
  String get filterTitle => 'फ़िल्टर करें';
  @override
  String get workType => 'काम का प्रकार';
  @override
  String get skillsNotLoaded => 'स्किल लिस्ट लोड नहीं हुई';
  @override
  String get maxRate => 'ज़्यादा से ज़्यादा रेट';
  @override
  String get noLimit => 'कोई सीमा नहीं';
  @override
  String get howFar => 'कितनी दूर तक';
  @override
  String get onlyAvailable => 'सिर्फ़ उपलब्ध';
  @override
  String get onDutyNow => 'जो अभी ड्यूटी पर हैं';
  @override
  String get applyFilter => 'फ़िल्टर लगाएँ';
  @override
  String get searchThisArea => 'इस इलाक़े में खोजें';
  @override
  String get sortTitle => 'क्रम बदलें';
  @override
  String get sortDistance => 'सबसे पास';
  @override
  String get sortRating => 'रेटिंग ज़्यादा';
  @override
  String get sortPriceLow => 'रेट कम';
  @override
  String get sortPriceHigh => 'रेट ज़्यादा';

  @override
  String get labourDetail => 'कारीगर की जानकारी';
  @override
  String get saveToList => 'सेव करें';
  @override
  String get removeFromSaved => 'सेव लिस्ट से हटाएँ';
  @override
  String get share => 'शेयर करें';
  @override
  String get shareLinkCopied => 'शेयर लिंक कॉपी हो गया';
  @override
  String savedAdded(String name) => '$name सेव लिस्ट में जुड़ गए';
  @override
  String savedRemoved(String name) => '$name सेव लिस्ट से हट गए';
  @override
  String get statYearsExperience => 'साल का अनुभव';
  @override
  String get statJobsDone => 'काम किए';
  @override
  String get statReviewsGot => 'रिव्यू मिले';
  @override
  String get locationAddress => 'लोकेशन / पता';
  @override
  String awayFromYou(String distance) => 'आपसे $distance';
  @override
  String metresAway(int metres) => '$metres मी दूर';
  @override
  String kmAway(String km) => '$km किमी दूर';
  @override
  String get todayRate => 'आज की रेट';
  @override
  String get perDay => '/ दिन';
  @override
  String get skills => 'स्किल';
  @override
  String get availabilityToday => 'आज उपलब्धता';
  @override
  String get availableCallNow => 'उपलब्ध – तुरंत बुलाएँ';
  @override
  String get notOnDuty => 'अभी ड्यूटी पर नहीं';
  @override
  String timingLine(String timing) => 'समय: $timing';
  @override
  String get experience => 'अनुभव';
  @override
  String years(int count) => '$count साल';
  @override
  String get contact => 'संपर्क';
  @override
  String get contactAfterBooking => 'बुक करने के बाद मिलेगा';
  @override
  String get aboutMe => 'अपने बारे में';
  @override
  String get recentReviews => 'हाल के रिव्यू';
  @override
  String get reviewsLoading => 'रिव्यू लोड हो रहे हैं...';
  @override
  String get noReviewsYet => 'अभी तक कोई रिव्यू नहीं आया';
  @override
  String reviewsCount(int count) => '($count रिव्यू)';
  @override
  String get bookingSent => 'बुकिंग भेज दी';
  @override
  String bookNow(int price) => 'अभी बुक करें – ₹$price / दिन';
  @override
  String get available => 'उपलब्ध';
  @override
  String get busy => 'व्यस्त';
  @override
  String get workGeneric => 'काम';
  @override
  String get labourGeneric => 'कारीगर';

  @override
  String get whichDay => 'किस दिन चाहिए';
  @override
  String get howMuchWork => 'कितना काम';
  @override
  String get fullDay => 'पूरा दिन';
  @override
  String get halfDay => 'आधा दिन';
  @override
  String get eightHours => '8 घंटे';
  @override
  String get fourHours => '4 घंटे';
  @override
  String get fullDayBooking => 'पूरे दिन की बुकिंग';
  @override
  String get halfDayBooking => 'आधे दिन की बुकिंग';
  @override
  String get whereIsWork => 'काम कहाँ है';
  @override
  String get addressHint => 'पता डालें';
  @override
  String get addressRequired => 'काम का पता डालें';
  @override
  String get bookingNotesHint => 'कुछ बताना है? (ज़रूरी नहीं)';
  @override
  String get total => 'कुल';
  @override
  String get confirmBooking => 'बुकिंग कन्फर्म करें';
  @override
  String get today => 'आज';
  @override
  String get tomorrow => 'कल';

  @override
  List<String> get weekdaysShort => const [
    'सोम',
    'मंगल',
    'बुध',
    'गुरु',
    'शुक्र',
    'शनि',
    'रवि',
  ];

  @override
  List<String> get monthsShort => const [
    'जन',
    'फ़र',
    'मार्च',
    'अप्रै',
    'मई',
    'जून',
    'जुल',
    'अग',
    'सित',
    'अक्तू',
    'नव',
    'दिस',
  ];

  @override
  List<String> get monthsLong => const [
    'जनवरी',
    'फ़रवरी',
    'मार्च',
    'अप्रैल',
    'मई',
    'जून',
    'जुलाई',
    'अगस्त',
    'सितंबर',
    'अक्तूबर',
    'नवंबर',
    'दिसंबर',
  ];

  @override
  String get myBookings => 'मेरी बुकिंग';
  @override
  String bookingsSummary(int active, int done) =>
      '$active चालू · $done पूरी';
  @override
  String get tabAll => 'सब';
  @override
  String get tabActive => 'चालू';
  @override
  String get tabPending => 'बाक़ी';
  @override
  String get tabDone => 'पूरी';
  @override
  String get cancelBookingTitle => 'बुकिंग रद्द करें?';
  @override
  String cancelBookingMessage(String name) =>
      '$name की बुकिंग रद्द हो जाएगी। '
      'बार-बार रद्द करने से रेटिंग गिर सकती है।';
  @override
  String get yesCancel => 'हाँ, रद्द करें';
  @override
  String get bookingCancelled => 'बुकिंग रद्द हो गई';
  @override
  String reviewSubmitted(String name) => '$name को रिव्यू दे दिया';
  @override
  String get statusConfirmed => 'कन्फर्म';
  @override
  String get statusPending => 'बाक़ी';
  @override
  String get statusCompleted => 'पूरी';
  @override
  String get statusCancelled => 'रद्द';
  @override
  String get statusDeclined => 'मना किया';
  @override
  String get liveTrack => 'लाइव ट्रैक';
  @override
  String get call => 'कॉल';
  @override
  String get details => 'जानकारी';
  @override
  String get reviewDone => 'रिव्यू दिया';
  @override
  String get giveReview => 'रिव्यू दें';
  @override
  String get bookAgain => 'दोबारा बुक करें';
  @override
  String numberAfterAccept(String name) =>
      '$name का नंबर बुकिंग एक्सेप्ट होने पर मिलेगा';
  @override
  String get emptyAllTitle => 'अभी कोई बुकिंग नहीं';
  @override
  String get emptyAllMessage =>
      'खोज से कारीगर चुनें और पहली बुकिंग करें।';
  @override
  String get emptyActiveTitle => 'कोई चालू बुकिंग नहीं';
  @override
  String get emptyActiveMessage => 'कन्फर्म बुकिंग यहाँ दिखेंगी।';
  @override
  String get emptyPendingTitle => 'कुछ बाक़ी नहीं';
  @override
  String get emptyPendingMessage =>
      'जो रिक्वेस्ट अभी एक्सेप्ट नहीं हुई, वो यहाँ आएगी।';
  @override
  String get emptyDoneTitle => 'अभी तक कुछ पूरा नहीं हुआ';
  @override
  String get emptyDoneMessage => 'पूरे हुए काम यहाँ इतिहास में रहेंगे।';
  @override
  String get findLabour => 'कारीगर खोजें';

  @override
  String get howWasWork => 'काम कैसा लगा?';
  @override
  List<String> get ratingLabels => const [
    'बिलकुल ठीक नहीं',
    'ठीक नहीं था',
    'चलेगा',
    'अच्छा काम',
    'बहुत बढ़िया!',
  ];
  @override
  String get reviewCommentHint => 'कुछ लिखना है? (ज़रूरी नहीं)';
  @override
  String get sendReview => 'रिव्यू भेजें';

  @override
  String get stagePending => 'बाक़ी';
  @override
  String get stageOnTheWay => 'रास्ते में';
  @override
  String get stageWorking => 'काम चल रहा';
  @override
  String get stageCompleted => 'पूरा हुआ';

  @override
  String get stepAccept => 'एक्सेप्ट';
  @override
  String get stepOnTheWay => 'रास्ते में';
  @override
  String get stepWorking => 'काम';
  @override
  String get stepDone => 'पूरा';

  @override
  String get liveTracking => 'लाइव ट्रैकिंग';
  @override
  String get waitingForAccept => 'एक्सेप्ट का इंतज़ार';
  @override
  String get workStarted => 'काम शुरू हो गया';
  @override
  String get workFinished => 'काम पूरा हुआ';
  @override
  String get onTheWay => 'रास्ते में';
  @override
  String get almostThere => 'बस पहुँचने वाले हैं';
  @override
  String minutesAway(int minutes) => '$minutes मिनट दूर';
  @override
  String get trackingStalled =>
      'लोकेशन अपडेट नहीं हो पा रही — कोशिश जारी है';
  @override
  String get requestSent => 'रिक्वेस्ट भेज दी गई';
  @override
  String awaitingAccept(String name) =>
      '$name के एक्सेप्ट करते ही लाइव लोकेशन यहाँ दिखने लगेगी।';
  @override
  String get workerMarker => 'कारीगर';
  @override
  String get siteMarker => 'काम की जगह';

  @override
  String get shareProfile => 'प्रोफ़ाइल शेयर करें';
  @override
  String get referralCodeSoon => 'रेफ़रल कोड जल्द आएगा';
  @override
  String referralCodeIs(String code) => 'रेफ़रल कोड: $code';
  @override
  String get editProfile => 'प्रोफ़ाइल एडिट करें';
  @override
  String get statTotalBookings => 'कुल बुकिंग';
  @override
  String get statTotalSpend => 'कुल खर्च';
  @override
  String get statReviewsGiven => 'रिव्यू दिए';
  @override
  String get myActivity => 'मेरी गतिविधि';
  @override
  String get activeBookings => 'चालू बुकिंग';
  @override
  String get noBookingsYet => 'अभी कोई बुकिंग नहीं';
  @override
  String bookingsRunning(int count) => '$count बुकिंग चल रही हैं';
  @override
  String get savedLabour => 'सेव किए कारीगर';
  @override
  String savedLabourCount(int count) => '$count लोग सेव हैं';
  @override
  String get myReviews => 'मेरे रिव्यू';
  @override
  String reviewsGivenCount(int count) => '$count रिव्यू दिए हैं';
  @override
  String get savedListSoon => 'सेव लिस्ट जल्द आएगी';
  @override
  String get reviewsPageSoon => 'रिव्यू पेज जल्द आएगा';
  @override
  String get addressSection => 'पता';
  @override
  String get addNewAddress => 'नया पता जोड़ें';
  @override
  String get addressAddSoon => 'पता जोड़ना जल्द आएगा';
  @override
  String editAddressPrompt(String label) => '$label एडिट करें';

  @override
  String get editProfileTitle => 'प्रोफ़ाइल एडिट करें';
  @override
  String get nameLabel => 'पूरा नाम';
  @override
  String get nameHint => 'जैसे: अमित खुराना';
  @override
  String get nameRequired => 'नाम डालें';
  @override
  String get emailLabel => 'ईमेल (ज़रूरी नहीं)';
  @override
  String get emailInvalid => 'सही ईमेल डालें';
  @override
  String get cityLabel => 'शहर';
  @override
  String get cityHint => 'जैसे: गुड़गाँव';
  @override
  String get addressLabel => 'पता';
  @override
  String get profileAddressHint => 'घर या साइट का पता';
  @override
  String get saveChanges => 'सेव करें';
  @override
  String get profileUpdated => 'प्रोफ़ाइल अपडेट हो गई';

  @override
  String get locationTitle => 'लोकेशन सेट करें';
  @override
  String get locationSubtitle =>
      'यहीं से आस-पास के कारीगर खोजे जाएँगे।';
  @override
  String get savedAddresses => 'सेव किए पते';
  @override
  String get noSavedAddresses => 'कोई सेव किया पता नहीं';
  @override
  String get pickOnMap => 'मैप पर चुनें';
  @override
  String get pickOnMapHint => 'मैप हिलाकर पिन सही जगह ले जाएँ';
  @override
  String get typeAddress => 'पता टाइप करें';
  @override
  String get useThisLocation => 'यही लोकेशन इस्तेमाल करें';
  @override
  String get locationSaved => 'लोकेशन सेव हो गया';
  @override
  String get locationNeedsAddress => 'पता या शहर डालें';
  @override
  String get currentPin => 'चुना हुआ पॉइंट';
  @override
  String get defaultBadge => 'डिफ़ॉल्ट';

  @override
  String get accountSettings => 'अकाउंट सेटिंग';
  @override
  String get preferences => 'पसंद';
  @override
  String get whatsappAlerts => 'WhatsApp अलर्ट';
  @override
  String get smsAlerts => 'SMS अलर्ट';
  @override
  String get languageRow => 'भाषा / Language';
  @override
  String get chooseLanguage => 'भाषा चुनें';
  @override
  String get payment => 'भुगतान';
  @override
  String get paymentMethods => 'भुगतान के तरीक़े';
  @override
  String get paymentMethodsSoon => 'भुगतान के तरीक़े जल्द आएँगे';
  @override
  String get paymentHistory => 'भुगतान इतिहास';
  @override
  String get paymentHistorySoon => 'भुगतान इतिहास जल्द आएगा';
  @override
  String get referEarn => 'रेफ़र करें और कमाएँ';
  @override
  String get badgeNew => 'नया';
  @override
  String get privacySecurity => 'प्राइवेसी और सुरक्षा';
  @override
  String get privacySettings => 'प्राइवेसी सेटिंग';
  @override
  String get privacySettingsSoon => 'प्राइवेसी सेटिंग जल्द आएँगी';
  @override
  String get accountSecurity => 'अकाउंट सुरक्षा';
  @override
  String get accountSecuritySoon => 'अकाउंट सुरक्षा जल्द आएगी';
  @override
  String get help => 'मदद';
  @override
  String get helpSupport => 'मदद और सपोर्ट';
  @override
  String get supportLine => 'सपोर्ट: 1800-123-4567';
  @override
  String get terms => 'नियम और शर्तें';
  @override
  String get appVersion => 'ऐप वर्ज़न';
  @override
  String get logout => 'लॉगआउट';
  @override
  String get logoutTitle => 'लॉगआउट करें?';
  @override
  String get logoutMessage => 'आपको दोबारा OTP से लॉगिन करना पड़ेगा।';
}

// ── English ─────────────────────────────────────────────────────────────────

class _English extends AppStrings {
  const _English();

  @override
  String get tagline => 'Book labour instantly';

  @override
  String get back => 'Back';
  @override
  String get save => 'Save';
  @override
  String get cancel => 'Cancel';
  @override
  String get confirm => 'Confirm';
  @override
  String get retry => 'Try again';
  @override
  String get keepIt => 'Keep it';
  @override
  String get reset => 'Reset';
  @override
  String get optional => 'optional';

  @override
  String get errorOffline => 'No internet connection';
  @override
  String get errorGeneric => 'Something went wrong';
  @override
  String get errorTryAgain => 'Please try again.';
  @override
  String get errorGenericFull => 'Something went wrong. Please try again.';
  @override
  String get errNetwork =>
      'No internet connection. Check your network and try again.';
  @override
  String get errTimeout => 'The server is not responding. Please try again.';
  @override
  String get errParse => 'The server sent an unexpected reply. Try again.';
  @override
  String get errUnauthorized => 'Your session has expired. Please log in again.';

  @override
  String comingSoon(String what) => '$what is coming soon';

  @override
  String get navSearch => 'Search';
  @override
  String get navBookings => 'Bookings';
  @override
  String get navProfile => 'Profile';
  @override
  String get navAccount => 'Account';

  @override
  String get loginWelcome => 'Welcome back 👋';
  @override
  String get loginSubtitle => 'Enter your phone number and we will send an OTP';
  @override
  String get phoneNumber => 'Phone Number';
  @override
  String get sendOtp => 'Send OTP';
  @override
  String get phoneInvalid => 'Enter the full 10-digit number';
  @override
  String get newUserPrompt => 'New here? ';
  @override
  String get register => 'Register';
  @override
  String get registration => 'Registration';
  @override
  String get or => 'or';
  @override
  String get googleLogin => 'Continue with Google';
  @override
  String get termsLine =>
      'By continuing you agree to our Terms and Privacy Policy';

  @override
  String get otpTitle => 'Verify OTP';
  @override
  String get otpSentLine => 'We sent a 6-digit code to';
  @override
  String get otpVerify => 'Verify & Login';
  @override
  String get otpResend => 'Resend OTP';
  @override
  String get otpResendIn => 'Resend in ';
  @override
  String get otpResent => 'A new OTP has been sent';
  @override
  String get otpLoggedIn => 'Logged in!';
  @override
  String get otpInfo =>
      'The OTP arrives by SMS or WhatsApp. Never share it with anyone.';

  @override
  String get yourLocation => 'Your location';
  @override
  String get setLocation => 'Set your location';
  @override
  String get searchHint => 'Search electrician, plumber...';
  @override
  String get filter => 'Filter';
  @override
  String get searching => 'Searching...';
  @override
  String get noneFound => 'No one found';
  @override
  String labourFound(int count) => '$count workers found nearby';
  @override
  String get noLabourTitle => 'No workers found';
  @override
  String get noLabourMessage =>
      'Loosen the filters a little, or try another skill.';
  @override
  String get clearFilters => 'Clear filters';
  @override
  String get pickLabourTitle => 'Pick a worker';
  @override
  String get pickLabourMessage =>
      'Select from the list or the map — details open here.';
  @override
  String get notifications => 'Notifications';
  @override
  String get noNotifications => 'No new notifications';
  @override
  String get changeRadius => 'Change search radius';
  @override
  String get connect => 'Connect';
  @override
  String get perDayToday => '/ day today';
  @override
  String get youAreHere => 'You are here';
  @override
  String get mapNotLoaded => 'Map could not load';
  @override
  String get mapsKeyMissing => 'A Google Maps key is required for the map';

  @override
  String get filterTitle => 'Filters';
  @override
  String get workType => 'Type of work';
  @override
  String get skillsNotLoaded => 'Skill list did not load';
  @override
  String get maxRate => 'Maximum rate';
  @override
  String get noLimit => 'No limit';
  @override
  String get howFar => 'How far';
  @override
  String get onlyAvailable => 'Available only';
  @override
  String get onDutyNow => 'Workers on duty right now';
  @override
  String get applyFilter => 'Apply filters';
  @override
  String get searchThisArea => 'Search this area';
  @override
  String get sortTitle => 'Sort by';
  @override
  String get sortDistance => 'Nearest';
  @override
  String get sortRating => 'Top rated';
  @override
  String get sortPriceLow => 'Lowest rate';
  @override
  String get sortPriceHigh => 'Highest rate';

  @override
  String get labourDetail => 'Worker details';
  @override
  String get saveToList => 'Save';
  @override
  String get removeFromSaved => 'Remove from saved';
  @override
  String get share => 'Share';
  @override
  String get shareLinkCopied => 'Share link copied';
  @override
  String savedAdded(String name) => '$name added to your saved list';
  @override
  String savedRemoved(String name) => '$name removed from your saved list';
  @override
  String get statYearsExperience => 'Years of experience';
  @override
  String get statJobsDone => 'Jobs done';
  @override
  String get statReviewsGot => 'Reviews received';
  @override
  String get locationAddress => 'Location / Address';
  @override
  String awayFromYou(String distance) => '$distance from you';
  @override
  String metresAway(int metres) => '$metres m away';
  @override
  String kmAway(String km) => '$km km away';
  @override
  String get todayRate => "Today's rate";
  @override
  String get perDay => '/ day';
  @override
  String get skills => 'Skills';
  @override
  String get availabilityToday => 'Availability today';
  @override
  String get availableCallNow => 'Available – call now';
  @override
  String get notOnDuty => 'Not on duty right now';
  @override
  String timingLine(String timing) => 'Timing: $timing';
  @override
  String get experience => 'Experience';
  @override
  String years(int count) => count == 1 ? '1 year' : '$count years';
  @override
  String get contact => 'Contact';
  @override
  String get contactAfterBooking => 'Shown after you book';
  @override
  String get aboutMe => 'About';
  @override
  String get recentReviews => 'Recent reviews';
  @override
  String get reviewsLoading => 'Loading reviews...';
  @override
  String get noReviewsYet => 'No reviews yet';
  @override
  String reviewsCount(int count) => '($count reviews)';
  @override
  String get bookingSent => 'Booking sent';
  @override
  String bookNow(int price) => 'Book Now – ₹$price / day';
  @override
  String get available => 'Available';
  @override
  String get busy => 'Busy';
  @override
  String get workGeneric => 'Work';
  @override
  String get labourGeneric => 'Worker';

  @override
  String get whichDay => 'Which day';
  @override
  String get howMuchWork => 'How much work';
  @override
  String get fullDay => 'Full day';
  @override
  String get halfDay => 'Half day';
  @override
  String get eightHours => '8 hours';
  @override
  String get fourHours => '4 hours';
  @override
  String get fullDayBooking => 'Full day booking';
  @override
  String get halfDayBooking => 'Half day booking';
  @override
  String get whereIsWork => 'Where is the work';
  @override
  String get addressHint => 'Enter the address';
  @override
  String get addressRequired => 'Enter the work address';
  @override
  String get bookingNotesHint => 'Anything to add? (optional)';
  @override
  String get total => 'Total';
  @override
  String get confirmBooking => 'Confirm booking';
  @override
  String get today => 'Today';
  @override
  String get tomorrow => 'Tomorrow';

  @override
  List<String> get weekdaysShort => const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  String get myBookings => 'My bookings';
  @override
  String bookingsSummary(int active, int done) =>
      '$active active · $done completed';
  @override
  String get tabAll => 'All';
  @override
  String get tabActive => 'Active';
  @override
  String get tabPending => 'Pending';
  @override
  String get tabDone => 'Done';
  @override
  String get cancelBookingTitle => 'Cancel this booking?';
  @override
  String cancelBookingMessage(String name) =>
      "$name's booking will be cancelled. "
      'Cancelling often can pull your rating down.';
  @override
  String get yesCancel => 'Yes, cancel';
  @override
  String get bookingCancelled => 'Booking cancelled';
  @override
  String reviewSubmitted(String name) => 'Review sent to $name';
  @override
  String get statusConfirmed => 'Confirmed';
  @override
  String get statusPending => 'Pending';
  @override
  String get statusCompleted => 'Completed';
  @override
  String get statusCancelled => 'Cancelled';
  @override
  String get statusDeclined => 'Declined';
  @override
  String get liveTrack => 'Live track';
  @override
  String get call => 'Call';
  @override
  String get details => 'Details';
  @override
  String get reviewDone => 'Review given';
  @override
  String get giveReview => 'Write a review';
  @override
  String get bookAgain => 'Book again';
  @override
  String numberAfterAccept(String name) =>
      "$name's number appears once the booking is accepted";
  @override
  String get emptyAllTitle => 'No bookings yet';
  @override
  String get emptyAllMessage =>
      'Find a worker from Search and make your first booking.';
  @override
  String get emptyActiveTitle => 'No active bookings';
  @override
  String get emptyActiveMessage => 'Confirmed bookings will show up here.';
  @override
  String get emptyPendingTitle => 'Nothing pending';
  @override
  String get emptyPendingMessage =>
      'Requests waiting to be accepted will appear here.';
  @override
  String get emptyDoneTitle => 'Nothing completed yet';
  @override
  String get emptyDoneMessage => 'Finished jobs stay here as history.';
  @override
  String get findLabour => 'Find workers';

  @override
  String get howWasWork => 'How was the work?';
  @override
  List<String> get ratingLabels => const [
    'Not good at all',
    'Below par',
    'It was okay',
    'Good work',
    'Excellent!',
  ];
  @override
  String get reviewCommentHint => 'Want to add a note? (optional)';
  @override
  String get sendReview => 'Send review';

  @override
  String get stagePending => 'Pending';
  @override
  String get stageOnTheWay => 'On the way';
  @override
  String get stageWorking => 'Work in progress';
  @override
  String get stageCompleted => 'Completed';

  @override
  String get stepAccept => 'Accept';
  @override
  String get stepOnTheWay => 'On the way';
  @override
  String get stepWorking => 'Working';
  @override
  String get stepDone => 'Done';

  @override
  String get liveTracking => 'Live tracking';
  @override
  String get waitingForAccept => 'Waiting to be accepted';
  @override
  String get workStarted => 'Work has started';
  @override
  String get workFinished => 'Work finished';
  @override
  String get onTheWay => 'On the way';
  @override
  String get almostThere => 'Almost there';
  @override
  String minutesAway(int minutes) => '$minutes min away';
  @override
  String get trackingStalled =>
      'Location is not updating — still retrying';
  @override
  String get requestSent => 'Request sent';
  @override
  String awaitingAccept(String name) =>
      'Once $name accepts, their live location will show up here.';
  @override
  String get workerMarker => 'Worker';
  @override
  String get siteMarker => 'Work site';

  @override
  String get shareProfile => 'Share profile';
  @override
  String get referralCodeSoon => 'Referral codes are coming soon';
  @override
  String referralCodeIs(String code) => 'Referral code: $code';
  @override
  String get editProfile => 'Edit profile';
  @override
  String get statTotalBookings => 'Total bookings';
  @override
  String get statTotalSpend => 'Total spend';
  @override
  String get statReviewsGiven => 'Reviews given';
  @override
  String get myActivity => 'My activity';
  @override
  String get activeBookings => 'Active bookings';
  @override
  String get noBookingsYet => 'No bookings yet';
  @override
  String bookingsRunning(int count) =>
      count == 1 ? '1 booking in progress' : '$count bookings in progress';
  @override
  String get savedLabour => 'Saved workers';
  @override
  String savedLabourCount(int count) =>
      count == 1 ? '1 person saved' : '$count people saved';
  @override
  String get myReviews => 'My reviews';
  @override
  String reviewsGivenCount(int count) =>
      count == 1 ? '1 review given' : '$count reviews given';
  @override
  String get savedListSoon => 'The saved list is coming soon';
  @override
  String get reviewsPageSoon => 'The reviews page is coming soon';
  @override
  String get addressSection => 'Addresses';
  @override
  String get addNewAddress => 'Add a new address';
  @override
  String get addressAddSoon => 'Adding addresses is coming soon';
  @override
  String editAddressPrompt(String label) => 'Edit $label';

  @override
  String get editProfileTitle => 'Edit profile';
  @override
  String get nameLabel => 'Full name';
  @override
  String get nameHint => 'e.g. Amit Khurana';
  @override
  String get nameRequired => 'Enter your name';
  @override
  String get emailLabel => 'Email (optional)';
  @override
  String get emailInvalid => 'Enter a valid email';
  @override
  String get cityLabel => 'City';
  @override
  String get cityHint => 'e.g. Gurgaon';
  @override
  String get addressLabel => 'Address';
  @override
  String get profileAddressHint => 'Home or site address';
  @override
  String get saveChanges => 'Save changes';
  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get locationTitle => 'Set your location';
  @override
  String get locationSubtitle =>
      'Nearby workers are searched from this point.';
  @override
  String get savedAddresses => 'Saved addresses';
  @override
  String get noSavedAddresses => 'No saved addresses';
  @override
  String get pickOnMap => 'Pick on the map';
  @override
  String get pickOnMapHint => 'Move the map to place the pin exactly';
  @override
  String get typeAddress => 'Type an address';
  @override
  String get useThisLocation => 'Use this location';
  @override
  String get locationSaved => 'Location saved';
  @override
  String get locationNeedsAddress => 'Enter an address or a city';
  @override
  String get currentPin => 'Selected point';
  @override
  String get defaultBadge => 'Default';

  @override
  String get accountSettings => 'Account settings';
  @override
  String get preferences => 'Preferences';
  @override
  String get whatsappAlerts => 'WhatsApp alerts';
  @override
  String get smsAlerts => 'SMS alerts';
  @override
  String get languageRow => 'Language';
  @override
  String get chooseLanguage => 'Choose a language';
  @override
  String get payment => 'Payment';
  @override
  String get paymentMethods => 'Payment methods';
  @override
  String get paymentMethodsSoon => 'Payment methods are coming soon';
  @override
  String get paymentHistory => 'Payment history';
  @override
  String get paymentHistorySoon => 'Payment history is coming soon';
  @override
  String get referEarn => 'Refer & Earn';
  @override
  String get badgeNew => 'New';
  @override
  String get privacySecurity => 'Privacy & security';
  @override
  String get privacySettings => 'Privacy settings';
  @override
  String get privacySettingsSoon => 'Privacy settings are coming soon';
  @override
  String get accountSecurity => 'Account security';
  @override
  String get accountSecuritySoon => 'Account security is coming soon';
  @override
  String get help => 'Help';
  @override
  String get helpSupport => 'Help & support';
  @override
  String get supportLine => 'Support: 1800-123-4567';
  @override
  String get terms => 'Terms & conditions';
  @override
  String get appVersion => 'App version';
  @override
  String get logout => 'Log out';
  @override
  String get logoutTitle => 'Log out?';
  @override
  String get logoutMessage => 'You will need to log in again with an OTP.';
}

// ── Bhojpuri ────────────────────────────────────────────────────────────────

/// Extends Hindi so anything not yet translated still renders in Devanagari
/// rather than dropping back to Latin-script Hinglish.
class _Bhojpuri extends _Hindi {
  const _Bhojpuri();

  @override
  String get tagline => 'तुरंते मजूर बुक करीं';

  @override
  String get back => 'पाछे';
  @override
  String get save => 'सेव करीं';
  @override
  String get cancel => 'रद्द करीं';
  @override
  String get retry => 'फेर से कोसिस करीं';
  @override
  String get keepIt => 'रहे दीं';

  @override
  String get errorOffline => 'इंटरनेट ना मिलत बा';
  @override
  String get errorGeneric => 'कुछ गड़बड़ हो गइल';
  @override
  String get errorTryAgain => 'फेर से कोसिस करीं।';
  @override
  String get errorGenericFull => 'कुछ गड़बड़ हो गइल। फेर से कोसिस करीं।';
  @override
  String get errNetwork =>
      'इंटरनेट ना मिलत बा। कनेक्शन देख के फेर से कोसिस करीं।';
  @override
  String get errTimeout => 'सरवर जवाब ना देत बा। फेर से कोसिस करीं।';
  @override
  String get errParse => 'सरवर से गलत जवाब आइल। फेर से कोसिस करीं।';
  @override
  String get errUnauthorized => 'सेशन खतम हो गइल। फेर से लॉगिन करीं।';

  @override
  String comingSoon(String what) => '$what जल्दिए आई';

  @override
  String get navSearch => 'खोजीं';
  @override
  String get navBookings => 'बुकिंग';
  @override
  String get navProfile => 'प्रोफ़ाइल';
  @override
  String get navAccount => 'अकाउंट';

  @override
  String get loginWelcome => 'फेर से स्वागत बा 👋';
  @override
  String get loginSubtitle => 'आपन फ़ोन नंबर डालीं, OTP आई';
  @override
  String get sendOtp => 'OTP भेजीं';
  @override
  String get phoneInvalid => 'पूरा 10 अंक के नंबर डालीं';
  @override
  String get newUserPrompt => 'नया बानी? ';
  @override
  String get register => 'रजिस्टर करीं';
  @override
  String get or => 'भा';
  @override
  String get googleLogin => 'Google से लॉगिन करीं';

  @override
  String get otpTitle => 'OTP वेरिफ़ाई करीं';
  @override
  String get otpSentLine => '6 अंक के कोड भेजल गइल बा';
  @override
  String get otpVerify => 'वेरिफ़ाई आ लॉगिन';
  @override
  String get otpResend => 'फेर से OTP भेजीं';
  @override
  String get otpResent => 'नया OTP भेज देले बानी';
  @override
  String get otpLoggedIn => 'लॉगिन हो गइल!';
  @override
  String get otpInfo => 'OTP SMS भा WhatsApp पर आई। केहू के मत बताईं।';

  @override
  String get yourLocation => 'रउरा लोकेशन';
  @override
  String get setLocation => 'लोकेशन सेट करीं';
  @override
  String get searchHint => 'बिजली मिस्त्री, प्लंबर खोजीं...';
  @override
  String get searching => 'खोजत बानी...';
  @override
  String get noneFound => 'केहू ना मिलल';
  @override
  String labourFound(int count) => 'लगे-बगल $count कारीगर मिललन';
  @override
  String get noLabourTitle => 'कवनो कारीगर ना मिलल';
  @override
  String get noLabourMessage => 'फ़िल्टर थोड़ा कम करीं भा दूसर स्किल देखीं।';
  @override
  String get clearFilters => 'फ़िल्टर हटाईं';
  @override
  String get pickLabourTitle => 'कवनो कारीगर चुनीं';
  @override
  String get pickLabourMessage => 'लिस्ट भा मैप से चुनीं, जानकारी इहाँ खुली।';
  @override
  String get noNotifications => 'अबहीं कवनो नया नोटिफ़िकेशन नइखे';
  @override
  String get connect => 'कनेक्ट';
  @override
  String get perDayToday => '/ दिन आज';
  @override
  String get youAreHere => 'रउरा इहाँ बानी';

  @override
  String get filterTitle => 'फ़िल्टर करीं';
  @override
  String get workType => 'काम के किसिम';
  @override
  String get maxRate => 'सबसे ढेर रेट';
  @override
  String get noLimit => 'कवनो सीमा ना';
  @override
  String get howFar => 'केतना दूर ले';
  @override
  String get onlyAvailable => 'खाली उपलब्ध';
  @override
  String get onDutyNow => 'जे अबहीं ड्यूटी पर बाड़न';
  @override
  String get applyFilter => 'फ़िल्टर लगाईं';
  @override
  String get searchThisArea => 'एह इलाका में खोजीं';
  @override
  String get sortTitle => 'क्रम बदलीं';
  @override
  String get sortDistance => 'सबसे लगे';
  @override
  String get sortRating => 'रेटिंग ढेर';
  @override
  String get sortPriceLow => 'रेट कम';
  @override
  String get sortPriceHigh => 'रेट ढेर';

  @override
  String get labourDetail => 'कारीगर के जानकारी';
  @override
  String get saveToList => 'सेव करीं';
  @override
  String get share => 'साझा करीं';
  @override
  String savedAdded(String name) => '$name सेव लिस्ट में जुड़ गइलन';
  @override
  String savedRemoved(String name) => '$name सेव लिस्ट से हट गइलन';
  @override
  String get statYearsExperience => 'साल के अनुभव';
  @override
  String get statJobsDone => 'काम कइल';
  @override
  String get statReviewsGot => 'रिव्यू मिलल';
  @override
  String get todayRate => 'आज के रेट';
  @override
  String get availabilityToday => 'आज उपलब्धता';
  @override
  String get availableCallNow => 'उपलब्ध – तुरंते बोलाईं';
  @override
  String get notOnDuty => 'अबहीं ड्यूटी पर नइखन';
  @override
  String get contactAfterBooking => 'बुक कइला के बाद मिली';
  @override
  String get aboutMe => 'आपन बारे में';
  @override
  String get recentReviews => 'हाल के रिव्यू';
  @override
  String get noReviewsYet => 'अबहीं ले कवनो रिव्यू ना आइल';
  @override
  String get bookingSent => 'बुकिंग भेज देले बानी';
  @override
  String bookNow(int price) => 'अबहीं बुक करीं – ₹$price / दिन';
  @override
  String get workGeneric => 'काम';
  @override
  String get labourGeneric => 'कारीगर';

  @override
  String get whichDay => 'कवन दिन चाहीं';
  @override
  String get howMuchWork => 'केतना काम';
  @override
  String get fullDay => 'पूरा दिन';
  @override
  String get halfDay => 'आधा दिन';
  @override
  String get eightHours => '8 घंटा';
  @override
  String get fourHours => '4 घंटा';
  @override
  String get fullDayBooking => 'पूरा दिन के बुकिंग';
  @override
  String get halfDayBooking => 'आधा दिन के बुकिंग';
  @override
  String get whereIsWork => 'काम कहाँ बा';
  @override
  String get addressHint => 'पता डालीं';
  @override
  String get addressRequired => 'काम के पता डालीं';
  @override
  String get bookingNotesHint => 'कुछ बतावे के बा? (जरूरी ना)';
  @override
  String get confirmBooking => 'बुकिंग कन्फर्म करीं';
  @override
  String get today => 'आज';
  @override
  String get tomorrow => 'काल्ह';

  @override
  String get myBookings => 'हमार बुकिंग';
  @override
  String get tabAll => 'सब';
  @override
  String get tabActive => 'चालू';
  @override
  String get tabPending => 'बाकी';
  @override
  String get tabDone => 'पूरा';
  @override
  String get cancelBookingTitle => 'बुकिंग रद्द करीं?';
  @override
  String cancelBookingMessage(String name) =>
      '$name के बुकिंग रद्द हो जाई। '
      'बार-बार रद्द कइला से रेटिंग गिर सकेला।';
  @override
  String get yesCancel => 'हँ, रद्द करीं';
  @override
  String get bookingCancelled => 'बुकिंग रद्द हो गइल';
  @override
  String reviewSubmitted(String name) => '$name के रिव्यू दे देले बानी';
  @override
  String get giveReview => 'रिव्यू दीं';
  @override
  String get reviewDone => 'रिव्यू देले बानी';
  @override
  String get bookAgain => 'फेर से बुक करीं';
  @override
  String numberAfterAccept(String name) =>
      '$name के नंबर बुकिंग एक्सेप्ट भइला पर मिली';
  @override
  String get emptyAllTitle => 'अबहीं कवनो बुकिंग नइखे';
  @override
  String get emptyAllMessage => 'खोज से कारीगर चुनीं आ पहिली बुकिंग करीं।';
  @override
  String get emptyActiveTitle => 'कवनो चालू बुकिंग नइखे';
  @override
  String get emptyActiveMessage => 'कन्फर्म बुकिंग इहाँ दिखी।';
  @override
  String get emptyPendingTitle => 'कुछ बाकी नइखे';
  @override
  String get emptyDoneTitle => 'अबहीं ले कुछ पूरा ना भइल';
  @override
  String get findLabour => 'कारीगर खोजीं';

  @override
  String get howWasWork => 'काम कइसन लागल?';
  @override
  List<String> get ratingLabels => const [
    'बिलकुल ठीक ना',
    'ठीक ना रहे',
    'चली',
    'बढ़िया काम',
    'बहुते बढ़िया!',
  ];
  @override
  String get reviewCommentHint => 'कुछ लिखे के बा? (जरूरी ना)';
  @override
  String get sendReview => 'रिव्यू भेजीं';

  @override
  String get stagePending => 'बाकी';
  @override
  String get stageOnTheWay => 'रस्ता में';
  @override
  String get stageWorking => 'काम चलत बा';
  @override
  String get stageCompleted => 'पूरा भइल';
  @override
  String get stepOnTheWay => 'रस्ता में';
  @override
  String get stepDone => 'पूरा';

  @override
  String get liveTracking => 'लाइव ट्रैकिंग';
  @override
  String get waitingForAccept => 'एक्सेप्ट के इंतजार';
  @override
  String get workStarted => 'काम शुरू हो गइल';
  @override
  String get workFinished => 'काम पूरा भइल';
  @override
  String get onTheWay => 'रस्ता में';
  @override
  String get almostThere => 'बस पहुँचे वाला बाड़न';
  @override
  String minutesAway(int minutes) => '$minutes मिनट दूर';
  @override
  String get requestSent => 'रिक्वेस्ट भेज देले बानी';
  @override
  String awaitingAccept(String name) =>
      '$name के एक्सेप्ट करते ही लाइव लोकेशन इहाँ लउके लागी।';
  @override
  String get workerMarker => 'कारीगर';
  @override
  String get siteMarker => 'काम के जगह';

  @override
  String get editProfile => 'प्रोफ़ाइल एडिट करीं';
  @override
  String get statTotalBookings => 'कुल बुकिंग';
  @override
  String get statTotalSpend => 'कुल खरचा';
  @override
  String get statReviewsGiven => 'रिव्यू देले';
  @override
  String get myActivity => 'हमार गतिविधि';
  @override
  String get activeBookings => 'चालू बुकिंग';
  @override
  String get noBookingsYet => 'अबहीं कवनो बुकिंग नइखे';
  @override
  String bookingsRunning(int count) => '$count बुकिंग चलत बा';
  @override
  String get savedLabour => 'सेव कइल कारीगर';
  @override
  String savedLabourCount(int count) => '$count लोग सेव बाड़न';
  @override
  String get myReviews => 'हमार रिव्यू';
  @override
  String reviewsGivenCount(int count) => '$count रिव्यू देले बानी';
  @override
  String get addressSection => 'पता';
  @override
  String get addNewAddress => 'नया पता जोड़ीं';
  @override
  String editAddressPrompt(String label) => '$label एडिट करीं';

  @override
  String get editProfileTitle => 'प्रोफ़ाइल एडिट करीं';
  @override
  String get nameLabel => 'पूरा नाँव';
  @override
  String get nameRequired => 'नाँव डालीं';
  @override
  String get cityLabel => 'शहर';
  @override
  String get addressLabel => 'पता';
  @override
  String get profileAddressHint => 'घर भा साइट के पता';
  @override
  String get saveChanges => 'सेव करीं';
  @override
  String get profileUpdated => 'प्रोफ़ाइल अपडेट हो गइल';

  @override
  String get locationTitle => 'लोकेशन सेट करीं';
  @override
  String get locationSubtitle => 'इहे से लगे-बगल के कारीगर खोजल जइहें।';
  @override
  String get savedAddresses => 'सेव कइल पता';
  @override
  String get noSavedAddresses => 'कवनो सेव कइल पता नइखे';
  @override
  String get pickOnMap => 'मैप पर चुनीं';
  @override
  String get pickOnMapHint => 'मैप हिला के पिन सही जगह ले जाईं';
  @override
  String get typeAddress => 'पता टाइप करीं';
  @override
  String get useThisLocation => 'इहे लोकेशन इस्तेमाल करीं';
  @override
  String get locationSaved => 'लोकेशन सेव हो गइल';
  @override
  String get locationNeedsAddress => 'पता भा शहर डालीं';

  @override
  String get accountSettings => 'अकाउंट सेटिंग';
  @override
  String get preferences => 'पसंद';
  @override
  String get chooseLanguage => 'भाषा चुनीं';
  @override
  String get payment => 'भुगतान';
  @override
  String get help => 'मदद';
  @override
  String get helpSupport => 'मदद आ सपोर्ट';
  @override
  String get terms => 'नियम आ सरत';
  @override
  String get appVersion => 'ऐप वर्जन';
  @override
  String get logout => 'लॉगआउट';
  @override
  String get logoutTitle => 'लॉगआउट करीं?';
  @override
  String get logoutMessage => 'रउरा फेर से OTP से लॉगिन करे के पड़ी।';
}
