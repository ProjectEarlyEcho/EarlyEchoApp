import 'dart:ui';

/// Keyed UI strings for both supported languages.
///
/// Hindi is the primary language for the Anganwadi worker audience; every
/// entry must carry `hi`, with `en` as the alternate. `tr` falls back to
/// Hindi for missing keys or unsupported locales so a partial table can
/// never blank the UI.
class AppStrings {
  AppStrings._();

  static const _table = <String, Map<String, String>>{
    // ── Language picker ──
    'language_title': {'hi': 'भाषा चुनें', 'en': 'Choose your language'},
    'language_subtitle': {
      'hi':
          'ऐप हिन्दी या English में इस्तेमाल करें — बाद में सेटिंग्स से बदल सकते हैं।',
      'en':
          'Use the app in Hindi or English — you can change it later in Settings.',
    },
    'language_hindi_name': {'hi': 'हिन्दी', 'en': 'Hindi (हिन्दी)'},
    'language_english_name': {'hi': 'English', 'en': 'English'},
    'continue': {'hi': 'जारी रखें', 'en': 'Continue'},

    // ── Step indicator ──
    'step_label': {
      'hi': 'चरण {n}/{total} • {name}',
      'en': 'Step {n}/{total} • {name}',
    },
    'step1_name': {'hi': 'बच्चे की जानकारी', 'en': 'Child details'},
    'step2_name': {'hi': 'विकास लक्ष्य', 'en': 'Developmental goals'},
    'step3_name': {
      'hi': 'प्रश्नावली (वैकल्पिक)',
      'en': 'Questionnaire (optional)',
    },
    'step4_name': {'hi': 'सहमति', 'en': 'Consent'},
    'step5_name': {'hi': 'ध्वनि प्रेरण', 'en': 'Sound elicitation'},
    'step6_name': {'hi': 'विश्लेषण', 'en': 'Analysis'},
    'step7_name': {'hi': 'परिणाम', 'en': 'Result'},
    'step8_name': {'hi': 'रेफरल', 'en': 'Referral'},

    // ── Screen titles ──
    'title_child_profile': {'hi': 'बच्चे की जानकारी', 'en': 'Child details'},
    'title_questionnaire': {'hi': 'प्रश्नावली', 'en': 'Questionnaire'},
    'title_goals': {'hi': 'विकास लक्ष्य', 'en': 'Developmental goals'},
    'title_consent': {'hi': 'सहमति', 'en': 'Consent'},
    'title_elicitation': {'hi': 'ध्वनि प्रेरण', 'en': 'Sound elicitation'},
    'title_processing': {'hi': 'विश्लेषण', 'en': 'Analysis'},
    'title_result': {'hi': 'परिणाम', 'en': 'Result'},
    'title_referral': {'hi': 'रेफरल', 'en': 'Referral'},
    'title_history': {'hi': 'पुरानी जाँचें', 'en': 'Past screenings'},
    'title_settings': {'hi': 'सेटिंग्स', 'en': 'Settings'},

    // ── Home ──
    'home_greeting': {'hi': 'नमस्ते!', 'en': 'Hello!'},
    'home_greeting_sub': {
      'hi':
          'बच्चे की आवाज़ से विकास की शुरुआती जाँच — ध्वनि-आधारित स्क्रीनिंग।',
      'en':
          "Early developmental screening from the child's voice — an acoustic check.",
    },
    'home_hero_title': {
      'hi': 'ध्वनि-आधारित विकास जाँच',
      'en': 'Voice-based developmental screening',
    },
    'home_hero_body': {
      'hi':
          'तीन छोटी गतिविधियों में बच्चे की आवाज़ रिकॉर्ड होती है। यह निदान नहीं, केवल शुरुआती जाँच है।',
      'en':
          "The child's voice is recorded during three short activities. This is not a diagnosis — only an early check.",
    },
    'home_privacy_title': {'hi': 'निजता पहले', 'en': 'Privacy first'},
    'home_privacy_body': {
      'hi':
          'ऑडियो इसी फ़ोन पर जाँचा जाता है — रिकॉर्डिंग फ़ोन से बाहर नहीं जाती।',
      'en':
          'Audio is analysed on this phone — recordings never leave the device.',
    },
    'home_new_screening': {
      'hi': 'नई स्क्रीनिंग शुरू करें',
      'en': 'Start new screening',
    },
    'home_view_history': {
      'hi': 'पुरानी जाँचें देखें',
      'en': 'View past screenings',
    },
    'tooltip_history': {'hi': 'पुरानी जाँचें', 'en': 'Past screenings'},
    'tooltip_settings': {'hi': 'सेटिंग्स', 'en': 'Settings'},

    // ── Child profile (step 1) ──
    'cp_header': {
      'hi': 'बच्चे का विवरण भरें',
      'en': 'Fill in the child and worker details',
    },
    'cp_header_sub': {
      'hi': 'बच्चे और कार्यकर्ता का विवरण भरें। नाम वैकल्पिक है।',
      'en': 'Fill in the child and worker details. The name is optional.',
    },
    'cp_section_child': {'hi': 'बच्चे का विवरण', 'en': 'Child details'},
    'cp_child_name': {
      'hi': 'बच्चे का नाम (वैकल्पिक)',
      'en': 'Child name (optional)',
    },
    'cp_child_name_hint': {
      'hi': 'बच्चे का नाम — वैकल्पिक',
      'en': 'Child name — optional',
    },
    'cp_age': {'hi': 'उम्र (महीनों में)', 'en': 'Age (months)'},
    'cp_age_hint': {
      'hi': 'उम्र महीनों में, 12–60',
      'en': 'Age in months, 12–60',
    },
    'cp_age_required': {
      'hi': 'बच्चे की उम्र दर्ज करें',
      'en': "Enter the child's age",
    },
    'cp_age_number': {
      'hi': 'उम्र पूरे महीनों में संख्या लिखें',
      'en': 'Enter age as a whole number of months',
    },
    'cp_age_range': {
      'hi': 'उम्र {min}–{max} महीनों के बीच होनी चाहिए',
      'en': 'Age must be between {min}–{max} months',
    },
    'cp_section_location': {
      'hi': 'स्क्रीनिंग स्थान',
      'en': 'Screening location',
    },
    'cp_anganwadi': {'hi': 'आंगनबाड़ी आईडी', 'en': 'Anganwadi ID'},
    'cp_anganwadi_hint': {
      'hi': 'आंगनबाड़ी आईडी, जैसे IN-MP-042',
      'en': 'Anganwadi ID, e.g. IN-MP-042',
    },
    'cp_anganwadi_required': {
      'hi': 'आंगनबाड़ी आईडी आवश्यक है',
      'en': 'Anganwadi ID is required',
    },
    'cp_state': {'hi': 'राज्य', 'en': 'State'},
    'cp_state_hint': {'hi': 'राज्य का चयन करें', 'en': 'State'},
    'cp_state_required': {'hi': 'राज्य चुनें', 'en': 'Select a state'},
    'cp_district': {'hi': 'जिला', 'en': 'District'},
    'cp_district_hint': {'hi': 'जिला का नाम', 'en': 'District'},
    'cp_district_required': {
      'hi': 'जिला दर्ज करें',
      'en': 'Enter the district',
    },
    'cp_section_worker': {'hi': 'कार्यकर्ता', 'en': 'Worker'},
    'cp_worker': {'hi': 'कार्यकर्ता का नाम', 'en': 'Worker name'},
    'cp_worker_hint': {'hi': 'कार्यकर्ता का नाम लिखें', 'en': 'Worker name'},
    'cp_worker_required': {
      'hi': 'कार्यकर्ता का नाम दर्ज करें',
      'en': "Enter the worker's name",
    },
    'cp_next': {
      'hi': 'प्रश्नावली की ओर बढ़ें',
      'en': 'Continue to questionnaire',
    },

    // ── Questionnaire (step 2) ──
    'q_skip': {'hi': 'छोड़ें', 'en': 'Skip'},
    'q_next': {'hi': 'सहमति की ओर बढ़ें', 'en': 'Continue to consent'},
    'q_load_failed': {
      'hi': 'सवाल लोड नहीं हो पाए। कृपया आगे बढ़ें।',
      'en': 'Questions could not be loaded. Please continue.',
    },
    'q_none': {
      'hi': 'इस उम्र के लिए कोई सवाल उपलब्ध नहीं है।',
      'en': 'No questions are available for this age.',
    },
    'q_progress': {
      'hi': '{n}/{total} उत्तर दिए गए',
      'en': '{n}/{total} answered',
    },
    'q_context_note': {
      'hi': 'ये सवाल केवल संदर्भ के लिए हैं — असली जाँच ध्वनि-आधारित है।',
      'en':
          'These questions are for context only — the actual screening is acoustic.',
    },
    'q_question_n': {'hi': 'सवाल {n}', 'en': 'Question {n}'},
    'q_yes': {'hi': 'हाँ', 'en': 'Yes'},
    'q_no': {'hi': 'नहीं', 'en': 'No'},
    'q_previous': {'hi': 'पिछला', 'en': 'Previous'},
    'q_next_question': {'hi': 'अगला', 'en': 'Next'},
    'goals_intro': {
      'hi':
          '{age} के लिए CDC के {count} विकास लक्ष्य देखें। जो बच्चा आमतौर पर करता है, उसे चुनें।',
      'en':
          'Review the CDC {count} developmental goals for {age}. Tick skills the child usually does.',
    },
    'goals_continue': {
      'hi': 'प्रश्नावली की ओर बढ़ें',
      'en': 'Continue to questionnaire',
    },
    'goals_disclaimer': {
      'hi':
          'यह विकास की निगरानी है, निदान या मान्य स्क्रीनिंग परीक्षण नहीं। किसी कौशल के छूटने, पहले सीखे कौशल के खोने या चिंता होने पर डॉक्टर से बात करें।',
      'en':
          'This is developmental monitoring, not a diagnosis or a validated screening tool. If a child has not reached a goal, has lost a skill, or you are concerned, discuss it with a doctor.',
    },
    'goals_source': {
      'hi': 'CDC माइलस्टोन स्रोत देखें',
      'en': 'View CDC milestone source',
    },

    // ── Consent (step 3) ──
    'consent_heading': {'hi': 'अभिभावक की सहमति', 'en': 'Parental consent'},
    'consent_body': {
      'hi':
          'रिकॉर्डिंग शुरू करने से पहले अभिभावक को हिन्दी सहमति संदेश सुनाएँ।',
      'en':
          'Play the English consent statement to the parent before recording starts.',
    },
    'consent_playing': {
      'hi': 'सहमति ऑडियो चल रहा है…',
      'en': 'Playing consent audio…',
    },
    'consent_stop': {'hi': 'रोकें', 'en': 'Stop'},
    'consent_replay': {'hi': 'फिर से सुनाएँ', 'en': 'Play again'},
    'consent_play': {'hi': 'सहमति का ऑडियो सुनाएँ', 'en': 'Play consent audio'},
    'consent_played': {
      'hi': 'ऑडियो सुनाया जा चुका है',
      'en': 'Audio has been played',
    },
    'consent_audio_error': {
      'hi':
          'ऑडियो नहीं चल पाया। कृपया अभिभावक को सहमति का वाक्य पढ़कर सुनाएँ और फिर से प्रयास करें।',
      'en':
          'Audio could not be played. Please read the consent statement to the parent and try again.',
    },
    'consent_save_error': {
      'hi': 'सहमति दर्ज नहीं हो पाई। कृपया फिर से प्रयास करें।',
      'en': 'Consent could not be recorded. Please try again.',
    },
    'consent_privacy': {
      'hi': 'ऑडियो कभी सहेजा या भेजा नहीं जाता। यह जाँच निदान नहीं है।',
      'en': 'Audio is never saved or sent. This check is not a diagnosis.',
    },
    'consent_confirm': {
      'hi': 'माता-पिता ने सहमति दी',
      'en': 'Parents gave consent',
    },

    // ── Elicitation (step 4) ──
    'el_protocol_progress': {'hi': 'प्रोटोकॉल {n}/3', 'en': 'Protocol {n}/3'},
    'el_total_time': {
      'hi': 'कुल समय: {elapsed} / ~{total} सेकंड',
      'en': 'Total time: {elapsed} / ~{total} s',
    },
    'el_all_done': {
      'hi': 'सभी गतिविधियाँ पूर्ण — विश्लेषण की ओर बढ़ रहे हैं…',
      'en': 'All activities complete — moving to analysis…',
    },
    'el_recording_note': {
      'hi':
          'रिकॉर्डिंग चल रही है — गतिविधि जारी रखें, टाइमर अपने आप आगे बढ़ेगा।',
      'en':
          'Recording in progress — keep the activity going; the timer advances automatically.',
    },
    'el_start': {'hi': 'रिकॉर्डिंग शुरू करें', 'en': 'Start recording'},
    'el_next_activity': {
      'hi': 'अगली गतिविधि शुरू करें',
      'en': 'Start next activity',
    },
    'el_skip_activity': {'hi': 'गतिविधि छोड़ें', 'en': 'Skip activity'},
    'el_mic_unavailable': {
      'hi': 'माइक्रोफ़ोन उपलब्ध नहीं है — रिकॉर्डिंग के बिना जारी।',
      'en': 'Microphone unavailable — continuing without recording.',
    },
    'waveform_active': {
      'hi': 'रिकॉर्डिंग तरंग सक्रिय',
      'en': 'Recording waveform active',
    },
    'waveform_idle': {
      'hi': 'रिकॉर्डिंग तरंग रुकी हुई',
      'en': 'Recording waveform idle',
    },
    'proto_replay': {'hi': 'निर्देश फिर सुनाएँ', 'en': 'Replay instruction'},
    'proto_seconds_left': {'hi': 'सेकंड शेष', 'en': 'seconds left'},
    'proto_recording': {'hi': 'रिकॉर्डिंग चल रही है', 'en': 'Recording'},
    'proto_ready': {'hi': 'शुरू करने को तैयार', 'en': 'Ready to start'},
    'proto_rattle_title': {'hi': 'रैटल', 'en': 'Rattle'},
    'proto_rattle_instruction': {
      'hi': 'इस बच्चे को रैटल की आवाज़ सुनाएँ',
      'en': 'Play the rattle sound for the child',
    },
    'proto_toy_title': {'hi': 'खिलौना छुपाना', 'en': 'Toy hide'},
    'proto_toy_instruction': {
      'hi': 'यह रहा! यह रहा खिलौना!',
      'en': 'Here it is! Here is the toy!',
    },
    'proto_imitate_title': {'hi': 'अनुकरण', 'en': 'Imitation'},
    'proto_imitate_instruction': {
      'hi': 'आ... आ... आ...',
      'en': 'Ah... ah... ah...',
    },

    // ── Processing (step 5) ──
    'proc_title': {'hi': 'ऑडियो विश्लेषण', 'en': 'Audio analysis'},
    'proc_body': {
      'hi':
          'रिकॉर्ड की गई आवाज़ इसी फ़ोन पर जाँची जा रही है — इसमें 8 से 30 सेकंड लग सकते हैं। ऑडियो कभी फ़ोन से बाहर नहीं जाता।',
      'en':
          'The recorded voice is being analysed on this phone — this can take 8 to 30 seconds. Audio never leaves the device.',
    },
    'proc_failed': {
      'hi': 'विश्लेषण पूरा नहीं हो सका।',
      'en': 'Analysis could not be completed.',
    },
    'proc_retry': {'hi': 'दोबारा प्रयास करें', 'en': 'Try again'},

    // ── Result (step 6) ──
    'result_none_title': {
      'hi': 'कोई परिणाम उपलब्ध नहीं',
      'en': 'No result available',
    },
    'result_none_body': {
      'hi': 'पहले स्क्रीनिंग पूरी करें — विश्लेषण के बाद परिणाम यहाँ दिखेगा।',
      'en':
          'Complete a screening first — the result will appear here after analysis.',
    },
    'result_incomplete_title': {
      'hi': 'विश्लेषण अधूरा रहा',
      'en': 'Analysis incomplete',
    },
    'result_incomplete_body': {
      'hi': 'ऑडियो विश्लेषण अधूरा रहा। कृपया दोबारा स्क्रीनिंग करें।',
      'en':
          'The audio analysis was incomplete. Please run the screening again.',
    },
    'result_quality': {'hi': 'गुणवत्ता कारण', 'en': 'Quality reasons'},
    'result_rescreen': {'hi': 'दोबारा स्क्रीनिंग करें', 'en': 'Screen again'},
    'result_referral': {'hi': 'रेफरल बनाएँ', 'en': 'Generate referral'},
    'result_home': {'hi': 'होम पर जाएँ', 'en': 'Go home'},
    'result_green': {
      'hi': 'हरा — सामान्य विकास',
      'en': 'Green — typical development',
    },
    'result_yellow': {
      'hi': 'पीला — एक चिंता का संकेत',
      'en': 'Yellow — one sign of concern',
    },
    'result_red': {
      'hi': 'लाल — DEIC रेफरल की सलाह',
      'en': 'Red — DEIC referral advised',
    },
    'result_green_expl': {
      'hi': 'इस बच्चे का भाषा विकास उम्र के अनुसार है।',
      'en': "This child's language development is on track for their age.",
    },
    'result_yellow_expl': {
      'hi':
          'एक बायोमार्कर चिंता का संकेत देता है। 3 महीने में दोबारा स्क्रीनिंग की सलाह दी जाती है।',
      'en':
          'One biomarker is a sign of concern. Rescreening in 3 months is advised.',
    },
    'result_red_expl': {
      'hi': 'इस बच्चे के लिए शीघ्र DEIC मूल्यांकन की सलाह दी जाती है।',
      'en': 'Prompt DEIC evaluation is advised for this child.',
    },
    'chip_normal': {'hi': 'सामान्य', 'en': 'Normal'},
    'chip_flagged': {'hi': 'चिन्हित', 'en': 'Flagged'},

    // ── Referral (step 7) ──
    'ref_title': {'hi': 'DEIC रेफरल पत्र', 'en': 'DEIC referral letter'},
    'ref_body': {
      'hi':
          'रेफरल पत्र में बच्चे की उम्र, जाँच की तारीख, बायोमार्कर मान और निकटतम DEIC (जिला प्रारंभिक हस्तक्षेप केंद्र) का संपर्क शामिल होगा। पत्र WhatsApp के माध्यम से साझा किया जा सकेगा।',
      'en':
          "The referral letter includes the child's age, screening date, biomarker values and the nearest DEIC (District Early Intervention Centre) contact. The letter can be shared via WhatsApp.",
    },
    'ref_home': {'hi': 'होम पर लौटें', 'en': 'Back to home'},

    // ── History ──
    'hist_title': {'hi': 'सहेजी गई जाँचें', 'en': 'Saved screenings'},
    'hist_body': {
      'hi':
          'पूरी हुई स्क्रीनिंग यहाँ दिखेगी — बच्चे की उम्र, जाँच की तारीख और जोखिम श्रेणी (हरा/पीला/लाल) के साथ। केवल संख्यात्मक परिणाम सहेजे जाते हैं, ऑडियो नहीं।',
      'en':
          "Completed screenings will appear here — with the child's age, screening date and risk band (green/yellow/red). Only numeric results are stored, never audio.",
    },

    // ── Settings ──
    'settings_title': {
      'hi': 'कार्यकर्ता व डिवाइस सेटिंग्स',
      'en': 'Worker and device settings',
    },
    'settings_body': {
      'hi':
          'यहाँ कार्यकर्ता का नाम, डिफ़ॉल्ट आंगनबाड़ी आईडी, डेमो मोड और सिंक सेटिंग्स रखी जाएंगी।',
      'en':
          'Worker name, default Anganwadi ID, demo mode and sync preferences will live here.',
    },
    'settings_language': {'hi': 'भाषा', 'en': 'Language'},
    'settings_language_change': {'hi': 'बदलें', 'en': 'Change'},
    'settings_account': {'hi': 'खाता', 'en': 'Account'},
    'settings_not_signed_in': {'hi': 'साइन इन नहीं है', 'en': 'Not signed in'},
    'settings_signed_in': {'hi': 'साइन इन है', 'en': 'Signed in'},
    'settings_sign_in': {'hi': 'साइन इन करें', 'en': 'Sign in'},
    'settings_sign_out': {'hi': 'साइन आउट करें', 'en': 'Sign out'},
    'settings_role_parent': {'hi': 'अभिभावक', 'en': 'Parent'},
    'settings_role_care_worker': {
      'hi': 'देखभाल कार्यकर्ता',
      'en': 'Care worker',
    },
    'settings_role_admin': {'hi': 'प्रशासक', 'en': 'Administrator'},
  };

  /// Looks up [key] for [locale]; Hindi is the default and the fallback for
  /// missing keys or unsupported languages.
  static String tr(String key, Locale? locale) {
    final entry = _table[key];
    if (entry == null) return key;
    if (locale?.languageCode == 'hi') return entry['hi'] ?? entry['en'] ?? key;
    return entry['en'] ?? entry['hi'] ?? key;
  }

  /// [tr] with `{placeholder}` substitution, e.g.
  /// `trf('step_label', l10n, {'n': '1', 'total': '7', 'name': …})`.
  static String trf(String key, Locale? locale, Map<String, String> args) {
    var value = tr(key, locale);
    args.forEach((name, arg) => value = value.replaceAll('{$name}', arg));
    return value;
  }

  /// Convenience for the shared step indicator label.
  static String stepLabel(int step, int total, String name, Locale? locale) =>
      trf('step_label', locale, {
        'n': '$step',
        'total': '$total',
        'name': name,
      });
}
