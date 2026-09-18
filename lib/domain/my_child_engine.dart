enum MyChildState { normal, precaution, warning, flag, regression }

enum MyChildAnswer { achieved, notYet, unsure, skipped }

enum MyChildSeverity { normal, reminder, watch, precaution, warning, flag }

enum MyChildDomainStatus {
  normal,
  insufficientEvidence,
  watch,
  lowConcern,
  moderateConcern,
  highConcern,
}

class MonitoringQuestion {
  final String id, prompt, domain;
  final List<String> tags;
  final int minAge, maxAge, normativeAgeMonths;
  final String evidenceStrength, weight, escalationRule, actionProfile;
  final List<String> probes;
  final bool isMchatQuestion, mchatConcernWhenYes;
  final String? subtext,
      malayalam,
      malayalamSubtext,
      citationSource,
      citationReference;
  const MonitoringQuestion({
    required this.id,
    required this.prompt,
    required this.domain,
    required this.tags,
    required this.minAge,
    required this.maxAge,
    required this.normativeAgeMonths,
    required this.evidenceStrength,
    required this.weight,
    required this.escalationRule,
    required this.actionProfile,
    this.probes = const [],
    this.isMchatQuestion = false,
    this.mchatConcernWhenYes = false,
    this.subtext,
    this.malayalam,
    this.malayalamSubtext,
    this.citationSource,
    this.citationReference,
  });

  bool get isUniversalRedFlag => tags.contains('RF') && normativeAgeMonths == 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': prompt,
    'text_ml': malayalam,
    'subtext': subtext,
    'subtext_ml': malayalamSubtext,
    'tags': tags,
    'min_age_months': minAge,
    'max_age_months': maxAge,
    'normative_age_months': normativeAgeMonths,
    'evidence_strength': evidenceStrength,
    'weight': weight,
    'escalation_rule': escalationRule,
    'action_profile': actionProfile,
    'probes': probes,
    'screening_tool': isMchatQuestion ? 'M-CHAT-R' : 'MyChild',
    if (isMchatQuestion) 'concern_when': mchatConcernWhenYes ? 'yes' : 'no',
    'citation_source': citationSource,
    'citation_reference': citationReference,
  };
}

class MyChildQuestionResult {
  final MonitoringQuestion question;
  final MyChildAnswer? answer;
  final MyChildSeverity severity;
  final String explanation;
  final MyChildExplanation detail;
  final bool regressionDetected;
  const MyChildQuestionResult({
    required this.question,
    required this.answer,
    required this.severity,
    required this.explanation,
    required this.detail,
    this.regressionDetected = false,
  });
  Map<String, dynamic> toJson() => {
    'question': question.toJson(),
    'answer': answer?.name,
    'severity': severity.name,
    'explanation': explanation,
    'detail': detail.toJson(),
    'regression_detected': regressionDetected,
  };
}

class MyChildExplanation {
  final String questionId;
  final List<String> inputFactors;
  final String appliedRule;
  final String outputSeverity;
  final String whyThisAgeMatters;
  final String recommendedAction;
  final int nextCheckWeeks;
  const MyChildExplanation({
    required this.questionId,
    required this.inputFactors,
    required this.appliedRule,
    required this.outputSeverity,
    required this.whyThisAgeMatters,
    required this.recommendedAction,
    required this.nextCheckWeeks,
  });
  Map<String, dynamic> toJson() => {
    'question_id': questionId,
    'input_factors': inputFactors,
    'applied_rule': appliedRule,
    'output_severity': outputSeverity,
    'why_this_age_matters': whyThisAgeMatters,
    'recommended_action': recommendedAction,
    'next_check_weeks': nextCheckWeeks,
  };
}

class MyChildDomainAssessment {
  final String domainTag, domain, status, explanation, confidence;
  final int flagCount,
      warningCount,
      precautionCount,
      streakMissed,
      questionCount;
  final double totalWeightedPoints;
  final List<String> triggeringMilestones;
  const MyChildDomainAssessment({
    required this.domainTag,
    required this.domain,
    required this.status,
    required this.explanation,
    required this.confidence,
    required this.flagCount,
    required this.warningCount,
    required this.precautionCount,
    required this.streakMissed,
    required this.questionCount,
    required this.totalWeightedPoints,
    this.triggeringMilestones = const [],
  });
  Map<String, dynamic> toJson() => {
    'domain_tag': domainTag,
    'domain': domain,
    'status': status,
    'explanation': explanation,
    'confidence': confidence,
    'vector': {
      'flag_count': flagCount,
      'warning_count': warningCount,
      'precaution_count': precautionCount,
      'streak_missed': streakMissed,
      'total_weighted_points': totalWeightedPoints,
    },
    'triggering_milestones': triggeringMilestones,
    'question_count': questionCount,
  };
}

class MyChildEvaluation {
  final MyChildState state;
  final String tier;
  final String globalLevel;
  final String message;
  final List<MyChildQuestionResult> questions;
  final Map<String, MyChildDomainAssessment> domains;
  final List<String> nextActions;
  final bool correctedAgeUsed;
  final double effectiveAgeMonths;
  const MyChildEvaluation({
    required this.state,
    required this.tier,
    required this.globalLevel,
    required this.message,
    required this.questions,
    required this.domains,
    required this.nextActions,
    required this.correctedAgeUsed,
    required this.effectiveAgeMonths,
  });
  Map<String, dynamic> toJson() => {
    'engine_version': MyChildEngine.engineVersion,
    'ruleset': 'hypothesis-v2-cdc2022-aligned+compact-parent-check',
    'state': state.name,
    'tier': tier,
    'global_level': globalLevel,
    'message': message,
    'effective_age_months': effectiveAgeMonths,
    'corrected_age_used': correctedAgeUsed,
    'questions': questions.map((q) => q.toJson()).toList(),
    'domains': domains.map((key, value) => MapEntry(key, value.toJson())),
    'next_actions': nextActions,
    'disclaimer':
        'Developmental monitoring signal only. This is not a diagnosis.',
  };
}

class MyChildEngine {
  static const engineVersion = 'mychild-cdc2022-v2';
  static const compactQuestionLimit = 20;
  static const _compactGroupLimit = 3;
  static const _compactGroupOrder = <String>[
    'Social connection',
    'Communication',
    'Learning and play',
    'Movement and hand skills',
    'Everyday skills',
  ];
  static const questions = <MonitoringQuestion>[
    MonitoringQuestion(
      id: "rf_01",
      prompt: "Has your child lost any skill they could do before?",
      domain: "RF",
      tags: ['RF'],
      minAge: 0,
      maxAge: 36,
      normativeAgeMonths: 0,
      evidenceStrength: "High",
      weight: "RF",
      escalationRule: "R3",
      actionProfile: "AP-RF",
      probes: ['P3', 'P5'],
      subtext: "Stopped saying words? Stopped walking? Stopped using hands?",
      malayalam:
          "മുമ്പ് ചെയ്യാനായിരുന്ന ഏതെങ്കിലും കഴിവ് കുട്ടിക്ക് ഇപ്പോൾ നഷ്ടപ്പെട്ടിട്ടുണ്ടോ?",
      malayalamSubtext:
          "സംസാരിക്കൽ നിർത്തിയോ? നടക്കൽ നിർത്തിയോ? കൈകൾ ഉപയോഗിക്കൽ കുറഞ്ഞോ?",
      citationSource:
          "CDC 2022 developmental surveillance red flags + AAP guidelines",
      citationReference:
          "Zubler et al., Pediatrics 2022;149(3):e2021052138; Lipkin & Macias, Pediatrics 2020;145(1):e20193449",
    ),
    MonitoringQuestion(
      id: "rf_02",
      prompt: "Does your child respond to loud sounds?",
      domain: "VH/RF",
      tags: ['VH', 'RF'],
      minAge: 0,
      maxAge: 36,
      normativeAgeMonths: 0,
      evidenceStrength: "High",
      weight: "RF",
      escalationRule: "R2",
      actionProfile: "AP-SENS",
      probes: ['P2', 'P5'],
      subtext: "Startle, turn, pause, or look.",
      malayalam: "വലിയ ശബ്ദം കേൾക്കുമ്പോൾ കുട്ടി പ്രതികരിക്കുന്നുണ്ടോ?",
      malayalamSubtext:
          "വിറയ്ക്കുക, തിരിഞ്ഞുനോക്കുക, നിമിഷം നിൽക്കുക, അല്ലെങ്കിൽ നോക്കുക.",
      citationSource:
          "CDC 2022 developmental surveillance red flags + AAP guidelines",
      citationReference:
          "Zubler et al., Pediatrics 2022;149(3):e2021052138; Lipkin & Macias, Pediatrics 2020;145(1):e20193449",
    ),
    MonitoringQuestion(
      id: "rf_03",
      prompt: "Does your child look at you when you talk or play?",
      domain: "SE",
      tags: ['SE'],
      minAge: 0,
      maxAge: 36,
      normativeAgeMonths: 0,
      evidenceStrength: "Moderate",
      weight: "RF",
      escalationRule: "R1_R2",
      actionProfile: "AP-STD / AP-LANG depending on cluster",
      probes: ['P2', 'P3', 'P5'],
      subtext: "Eye contact/attention to face.",
      malayalam:
          "നിങ്ങൾ സംസാരിക്കുമ്പോഴും കളിക്കുമ്പോഴും കുട്ടി നിങ്ങളുടെ മുഖത്തേക്ക് നോക്കുന്നുണ്ടോ?",
      malayalamSubtext: "മുഖശ്രദ്ധയും കണ്ണോട്ടവും ശ്രദ്ധിക്കുക.",
      citationSource:
          "CDC 2022 developmental surveillance red flags + AAP guidelines",
      citationReference:
          "Zubler et al., Pediatrics 2022;149(3):e2021052138; Lipkin & Macias, Pediatrics 2020;145(1):e20193449",
    ),
    MonitoringQuestion(
      id: "rf_04",
      prompt: "When you call your child's name, do they look?",
      domain: "RL/SE",
      tags: ['RL', 'SE'],
      minAge: 0,
      maxAge: 36,
      normativeAgeMonths: 0,
      evidenceStrength: "High",
      weight: "RF",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P5'],
      subtext: null,
      malayalam:
          "കുട്ടിയുടെ പേര് വിളിക്കുമ്പോൾ കുട്ടി തിരിഞ്ഞുനോക്കുകയോ ശ്രദ്ധിക്കുകയോ ചെയ്യുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource:
          "CDC 2022 developmental surveillance red flags + AAP guidelines",
      citationReference:
          "Zubler et al., Pediatrics 2022;149(3):e2021052138; Lipkin & Macias, Pediatrics 2020;145(1):e20193449",
    ),
    MonitoringQuestion(
      id: "rf_05",
      prompt: "Does your child point to show interest?",
      domain: "SE/EL",
      tags: ['SE', 'EL'],
      minAge: 0,
      maxAge: 36,
      normativeAgeMonths: 0,
      evidenceStrength: "High",
      weight: "RF",
      escalationRule: "R2",
      actionProfile: "AP-LANG / AP-STD",
      probes: ['P2', 'P3'],
      subtext: "Pointing to share, not only to request.",
      malayalam: "താൽപര്യം കാണിക്കാൻ കുട്ടി വിരൽചൂണ്ടുന്നുണ്ടോ?",
      malayalamSubtext:
          "ആവശ്യപ്പെടാൻ മാത്രം അല്ല, പങ്കുവെക്കാനും കാണിക്കാനും വിരൽചൂണ്ടൽ.",
      citationSource:
          "CDC 2022 developmental surveillance red flags + AAP guidelines",
      citationReference:
          "Zubler et al., Pediatrics 2022;149(3):e2021052138; Lipkin & Macias, Pediatrics 2020;145(1):e20193449",
    ),
    MonitoringQuestion(
      id: "q_12_14m_01",
      prompt: "Does your child play games with you, like pat-a-cake?",
      domain: "SE",
      tags: ['SE'],
      minAge: 12,
      maxAge: 15,
      normativeAgeMonths: 12,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "പാറ്റ്-എ-കേക്ക് പോലുള്ള കൈകളി നിങ്ങളോടൊപ്പം കുട്ടി കളിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 12 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_12_14m_02",
      prompt: "Does your child wave bye-bye?",
      domain: "EL/SE",
      tags: ['EL', 'SE'],
      minAge: 12,
      maxAge: 15,
      normativeAgeMonths: 12,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "കുട്ടി കൈവീശി ബൈ-ബൈ പറയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 12 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_12_14m_03",
      prompt:
          "Does your child call a parent mama, dada, or another special name?",
      domain: "EL",
      tags: ['EL'],
      minAge: 12,
      maxAge: 15,
      normativeAgeMonths: 12,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3', 'P5'],
      subtext: null,
      malayalam:
          "അമ്മ, അച്ഛൻ, അല്ലെങ്കിൽ മാതാപിതാവിനുള്ള പ്രത്യേക പേര് കുട്ടി വിളിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 12 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_12_14m_04",
      prompt: "Does your child understand 'no'?",
      domain: "RL",
      tags: ['RL'],
      minAge: 12,
      maxAge: 15,
      normativeAgeMonths: 12,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P5'],
      subtext: "Pauses or stops briefly.",
      malayalam: "“ഇല്ല” എന്ന് പറഞ്ഞാൽ കുട്ടി മനസ്സിലാക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 12 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_12_14m_05",
      prompt: "Can your child put a toy into a container?",
      domain: "FM/CP",
      tags: ['FM', 'CP'],
      minAge: 12,
      maxAge: 15,
      normativeAgeMonths: 12,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "ഒരു കളിപ്പാട്ടം ഒരു പാത്രത്തിലേക്ക് ഇടാൻ കുട്ടിക്ക് കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 12 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_12_14m_06",
      prompt:
          "Does your child look for things you hide, like a toy under a cloth?",
      domain: "CP",
      tags: ['CP'],
      minAge: 12,
      maxAge: 15,
      normativeAgeMonths: 12,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "തുണിക്കു കീഴിൽ ഒളിപ്പിച്ച കളിപ്പാട്ടം പോലുള്ള വസ്തുക്കൾ കുട്ടി അന്വേഷിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 12 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_12_14m_07",
      prompt: "Does your child pull to stand?",
      domain: "GM",
      tags: ['GM'],
      minAge: 9,
      maxAge: 15,
      normativeAgeMonths: 9,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-MOTOR",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "കുട്ടി പിടിച്ച് എഴുന്നേറ്റുനിൽക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 12 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_12_14m_08",
      prompt: "Does your child walk while holding furniture (cruising)?",
      domain: "GM",
      tags: ['GM'],
      minAge: 12,
      maxAge: 15,
      normativeAgeMonths: 12,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1_R2",
      actionProfile: "AP-MOTOR",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "ഫർണിച്ചർ പിടിച്ച് കുട്ടി നടക്കാൻ ശ്രമിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 12 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_01",
      prompt: "Does your child copy other children while playing?",
      domain: "SE",
      tags: ['SE'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "Low",
      weight: "L",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "കളിക്കുമ്പോൾ മറ്റ് കുട്ടികളെ കുട്ടി അനുകരിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_02",
      prompt: "Does your child show you an object they like?",
      domain: "SE/EL",
      tags: ['SE', 'EL'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3'],
      subtext: null,
      malayalam: "ഇഷ്ടമുള്ള ഒരു വസ്തു കുട്ടി നിങ്ങളെ കാണിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_03",
      prompt: "Does your child clap when excited?",
      domain: "SE",
      tags: ['SE'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "Low",
      weight: "L",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P2'],
      subtext: null,
      malayalam: "സന്തോഷം തോന്നുമ്പോൾ കുട്ടി കൈയടിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_04",
      prompt: "Does your child hug a doll or toy?",
      domain: "SE/CP",
      tags: ['SE', 'CP'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "Low",
      weight: "L",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "പാവയെയോ കളിപ്പാട്ടത്തെയോ കുട്ടി ചേർത്തുപിടിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_05",
      prompt: "Does your child show affection?",
      domain: "SE",
      tags: ['SE'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "Low",
      weight: "L",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P2', 'P5'],
      subtext: "For example: hugging, cuddling, or kissing.",
      malayalam: "കുട്ടി സ്നേഹം പ്രകടിപ്പിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_06",
      prompt: "Does your child try to say 1 or 2 words besides mama and dada?",
      domain: "EL",
      tags: ['EL'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3', 'P5'],
      subtext: null,
      malayalam:
          "അമ്മ/അച്ഛൻ എന്നതിനു പുറമെ 1 അല്ലെങ്കിൽ 2 വാക്കുകൾ പറയാൻ കുട്ടി ശ്രമിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_07",
      prompt: "If you name an object, does your child look at it?",
      domain: "RL",
      tags: ['RL'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P5'],
      subtext: null,
      malayalam:
          "ഒരു വസ്തുവിന്റെ പേര് പറഞ്ഞാൽ കുട്ടി അതിലേക്കു നോക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_08",
      prompt:
          "If you say 'Give me the toy' and show your hand, does your child follow the instruction?",
      domain: "RL",
      tags: ['RL'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P5'],
      subtext: null,
      malayalam:
          "“കളിപ്പാട്ടം തരൂ” എന്ന് പറഞ്ഞു കൈ കാണിച്ചാൽ കുട്ടി നിർദേശം പാലിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_09",
      prompt: "Does your child point to ask for something or for help?",
      domain: "EL/SE",
      tags: ['EL', 'SE'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3'],
      subtext: null,
      malayalam:
          "എന്തെങ്കിലും വേണമെന്നോ സഹായം വേണമെന്നോ പറയാൻ കുട്ടി വിരൽചൂണ്ടുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_10",
      prompt: "Does your child use objects the right way?",
      domain: "CP",
      tags: ['CP'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext:
          "For example: using a toy phone to talk, a cup to drink, or a book to look at.",
      malayalam: "വസ്തുക്കൾ ശരിയായ രീതിയിൽ കുട്ടി ഉപയോഗിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_11",
      prompt: "Can your child stack 2 small objects?",
      domain: "FM/CP",
      tags: ['FM', 'CP'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "രണ്ട് ചെറിയ വസ്തുക്കൾ ഒന്ന് മുകളിലേക്ക് ഒന്ന് വെക്കാൻ കുട്ടിക്ക് കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_12",
      prompt: "Does your child take a few steps alone?",
      domain: "GM",
      tags: ['GM'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-MOTOR",
      probes: ['P1', 'P2', 'P5'],
      subtext: null,
      malayalam: "കുട്ടി ഒറ്റയ്ക്ക് കുറച്ച് ചുവടുകൾ നടക്കുന്നതുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_15_17m_13",
      prompt: "Does your child use their fingers to feed themselves some food?",
      domain: "SH/FM",
      tags: ['SH', 'FM'],
      minAge: 15,
      maxAge: 18,
      normativeAgeMonths: 15,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-ADAPT",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "കുട്ടി വിരലുകൾ ഉപയോഗിച്ച് ചില ഭക്ഷണം സ്വയം കഴിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 15 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_01",
      prompt:
          "Does your child move away from you to play but check that you are still close?",
      domain: "SE",
      tags: ['SE'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "Low",
      weight: "L",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P2'],
      subtext: null,
      malayalam:
          "കളിക്കാൻ നിങ്ങളിൽ നിന്ന് മാറിപ്പോയാലും നിങ്ങൾ അടുത്തുണ്ടോ എന്ന് കുട്ടി നോക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_02",
      prompt: "Does your child point to show you something interesting?",
      domain: "SE/EL",
      tags: ['SE', 'EL'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3'],
      subtext: null,
      malayalam: "രസകരമായ ഒന്നിനെ കാണിക്കാൻ കുട്ടി വിരൽചൂണ്ടുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_03",
      prompt: "Does your child put their hands out for you to wash them?",
      domain: "SH/SE",
      tags: ['SH', 'SE'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "Low",
      weight: "L",
      escalationRule: "R1",
      actionProfile: "AP-ADAPT",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "കൈ കഴുകാൻ പറയുമ്പോൾ കുട്ടി കൈകൾ നീട്ടിക്കൊടുക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_04",
      prompt: "Does your child look at a few pages in a book with you?",
      domain: "SE/RL",
      tags: ['SE', 'RL'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "നിങ്ങളോടൊപ്പം പുസ്തകത്തിലെ കുറച്ച് പേജുകൾ കുട്ടി നോക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_05",
      prompt: "Does your child help you when dressing them?",
      domain: "SH",
      tags: ['SH'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-ADAPT",
      probes: ['P2'],
      subtext: "For example: pushing arm through a sleeve or lifting a foot.",
      malayalam: "വസ്ത്രം ഇടുമ്പോൾ കുട്ടി നിങ്ങളെ സഹായിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_06",
      prompt:
          "Does your child try to say 3 or more words besides mama and dada?",
      domain: "EL",
      tags: ['EL'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3', 'P5'],
      subtext: null,
      malayalam:
          "അമ്മ/അച്ഛൻ എന്നതിനു പുറമെ മൂന്ന് അല്ലെങ്കിൽ കൂടുതൽ വാക്കുകൾ പറയാൻ കുട്ടി ശ്രമിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_07",
      prompt: "Can your child follow a one-step instruction without a gesture?",
      domain: "RL",
      tags: ['RL'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P5'],
      subtext: null,
      malayalam:
          "കൈസൂചന ഇല്ലാതെ ഒരു ഘട്ടമുള്ള നിർദേശം കുട്ടി പാലിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_08",
      prompt: "Does your child copy household chores?",
      domain: "CP/SE",
      tags: ['CP', 'SE'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: "For example: trying to sweep.",
      malayalam: "വീട്ടുപണികൾ കുട്ടി അനുകരിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_09",
      prompt: "Does your child play with toys in a simple way?",
      domain: "CP",
      tags: ['CP'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: "For example: pushing a toy car.",
      malayalam: "കളിപ്പാട്ടങ്ങളുമായി ലളിതമായി കുട്ടി കളിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_10",
      prompt: "Does your child walk without holding on?",
      domain: "GM",
      tags: ['GM'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-MOTOR",
      probes: ['P1', 'P2', 'P5'],
      subtext: null,
      malayalam: "പിടിക്കാതെ കുട്ടി നടക്കുന്നതുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_11",
      prompt: "Does your child scribble with a crayon or pen?",
      domain: "FM",
      tags: ['FM'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "ക്രയോൺ അല്ലെങ്കിൽ പേന കൊണ്ട് കുട്ടി വരയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_12",
      prompt:
          "Can your child drink from a cup without a lid (spills are okay)?",
      domain: "SH",
      tags: ['SH'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-ADAPT",
      probes: ['P2'],
      subtext: null,
      malayalam:
          "മൂടിയില്ലാത്ത കപ്പിൽ നിന്ന് കുട്ടിക്ക് കുടിക്കാൻ കഴിയുന്നുണ്ടോ? കുറച്ച് ചോർന്നാലും പ്രശ്നമില്ല.",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_13",
      prompt: "Does your child feed themselves with their fingers?",
      domain: "SH",
      tags: ['SH'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-ADAPT",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "കുട്ടി വിരലുകൾ ഉപയോഗിച്ച് സ്വയം ഭക്ഷണം കഴിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_14",
      prompt: "Does your child try to use a spoon?",
      domain: "SH/FM",
      tags: ['SH', 'FM'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-ADAPT",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "കുട്ടി സ്പൂൺ ഉപയോഗിക്കാൻ ശ്രമിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_18_20m_15",
      prompt: "Can your child climb on and off a couch or chair without help?",
      domain: "GM",
      tags: ['GM'],
      minAge: 18,
      maxAge: 21,
      normativeAgeMonths: 18,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-MOTOR",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "സഹായമില്ലാതെ കസേരയിലോ സോഫയിലോ കയറാനും ഇറങ്ങാനും കുട്ടിക്ക് കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 18 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_01",
      prompt: "Does your child notice when others are hurt or upset?",
      domain: "SE",
      tags: ['SE'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Low",
      weight: "L",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P2', 'P3'],
      subtext: null,
      malayalam:
          "മറ്റുള്ളവർക്ക് വേദനയോ വിഷമമോ ഉണ്ടെന്ന് കുട്ടി ശ്രദ്ധിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_02",
      prompt:
          "In a new situation, does your child look at your face to know how to react?",
      domain: "SE",
      tags: ['SE'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P2', 'P3'],
      subtext: null,
      malayalam:
          "പുതിയ സാഹചര്യത്തിൽ എങ്ങനെ പ്രതികരിക്കണം എന്ന് അറിയാൻ കുട്ടി നിങ്ങളുടെ മുഖത്തേക്ക് നോക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_03",
      prompt:
          "When you ask about a picture, does your child point to it in a book?",
      domain: "RL",
      tags: ['RL'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "പുസ്തകത്തിലെ ചിത്രത്തെക്കുറിച്ച് ചോദിച്ചാൽ കുട്ടി അതിലേക്ക് വിരൽചൂണ്ടുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_04",
      prompt: "Does your child put 2 words together?",
      domain: "EL",
      tags: ['EL'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3', 'P5'],
      subtext: "For example: 'more milk'.",
      malayalam: "കുട്ടി രണ്ട് വാക്കുകൾ ചേർത്തുപറയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_05",
      prompt: "If you ask, can your child point to 2 body parts?",
      domain: "RL",
      tags: ['RL'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "ചോദിച്ചാൽ ശരീരത്തിന്റെ രണ്ട് ഭാഗങ്ങൾ കുട്ടി കാണിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_06",
      prompt: "Does your child use gestures beyond waving and pointing?",
      domain: "EL/SE",
      tags: ['EL', 'SE'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P1', 'P2'],
      subtext: "For example: nodding or blowing a kiss.",
      malayalam:
          "കൈവീശലും വിരൽചൂണ്ടലും കൂടാതെ മറ്റു കൈസൂചനകൾ കുട്ടി ഉപയോഗിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_07",
      prompt: "Can your child hold a container and take the lid off?",
      domain: "FM/CP",
      tags: ['FM', 'CP'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "ഒരു പാത്രം പിടിച്ച് അതിന്റെ മൂടി തുറക്കാൻ കുട്ടിക്ക് കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_08",
      prompt: "Does your child try out switches, knobs, or buttons on a toy?",
      domain: "CP",
      tags: ['CP'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Low",
      weight: "L",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "കളിപ്പാട്ടത്തിലെ സ്വിച്ച്, നോബ്, ബട്ടൺ എന്നിവ കുട്ടി പരീക്ഷിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_09",
      prompt: "Does your child play with 2 toys together?",
      domain: "CP",
      tags: ['CP'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Low",
      weight: "L",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: "For example: using toy food with a plate.",
      malayalam:
          "രണ്ട് കളിപ്പാട്ടങ്ങൾ ഒരുമിച്ച് ഉപയോഗിച്ച് കുട്ടി കളിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_10",
      prompt: "Can your child kick a ball?",
      domain: "GM",
      tags: ['GM'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-MOTOR",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "കുട്ടിക്ക് പന്ത് കാൽകൊണ്ട് അടിക്കാൻ കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_11",
      prompt: "Can your child run?",
      domain: "GM",
      tags: ['GM'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-MOTOR",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "കുട്ടിക്ക് ഓടാൻ കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_12",
      prompt:
          "Can your child walk up a few stairs (not climb them), with or without help?",
      domain: "GM",
      tags: ['GM'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-MOTOR",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "സഹായത്തോടെയോ സഹായമില്ലാതെയോ കുറച്ച് പടികൾ മുകളിലേക്ക് നടക്കാൻ കുട്ടിക്ക് കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_21_23m_13",
      prompt: "Does your child eat with a spoon?",
      domain: "SH/FM",
      tags: ['SH', 'FM'],
      minAge: 21,
      maxAge: 24,
      normativeAgeMonths: 21,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-ADAPT",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "കുട്ടി സ്പൂൺ ഉപയോഗിച്ച് ഭക്ഷണം കഴിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_01",
      prompt: "Does your child put 2 words together?",
      domain: "EL",
      tags: ['EL'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 24,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3', 'P5'],
      subtext: null,
      malayalam: "കുട്ടി രണ്ട് വാക്കുകൾ ചേർത്തുപറയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_02",
      prompt: "Does your child say about 50 words?",
      domain: "EL",
      tags: ['EL'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 24,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3', 'P5'],
      subtext: null,
      malayalam: "കുട്ടി ഏകദേശം 50 വാക്കുകൾ പറയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_03",
      prompt:
          "Does your child say 2 or more words together including an action word?",
      domain: "EL",
      tags: ['EL'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 24,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3'],
      subtext: "For example: 'doggie run'.",
      malayalam:
          "പ്രവർത്തന വാക്ക് ഉൾപ്പെടെ രണ്ട് അല്ലെങ്കിൽ കൂടുതൽ വാക്കുകൾ കുട്ടി ചേർത്തുപറയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_04",
      prompt: "Can your child name things in a book when you point to them?",
      domain: "EL/RL",
      tags: ['EL', 'RL'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 24,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "പുസ്തകത്തിൽ നിങ്ങൾ വിരൽചൂണ്ടുന്ന വസ്തുക്കളുടെ പേര് കുട്ടി പറയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_05",
      prompt: "Does your child use words like I, me, or we?",
      domain: "EL",
      tags: ['EL'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 30,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3'],
      subtext: null,
      malayalam:
          "ഞാൻ, എനിക്ക്, നാം പോലുള്ള വാക്കുകൾ കുട്ടി ഉപയോഗിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_06",
      prompt:
          "Does your child play next to other children and sometimes play with them?",
      domain: "SE",
      tags: ['SE'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 24,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "മറ്റ് കുട്ടികളുടെ അടുത്ത് കളിക്കുകയും ചിലപ്പോൾ അവരോടൊപ്പം കളിക്കുകയും കുട്ടി ചെയ്യുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_07",
      prompt: "Does your child use pretend play?",
      domain: "CP",
      tags: ['CP'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 24,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: "For example: feeding a block to a doll as if it were food.",
      malayalam: "നടിക്കുന്ന കളി കുട്ടി കളിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_08",
      prompt: "Can your child follow 2-step instructions?",
      domain: "RL/CP",
      tags: ['RL', 'CP'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 24,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P5'],
      subtext: null,
      malayalam:
          "രണ്ട് ഘട്ടങ്ങളുള്ള നിർദേശങ്ങൾ കുട്ടിക്ക് പാലിക്കാൻ കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_09",
      prompt: "Does your child know at least one colour?",
      domain: "RL/CP",
      tags: ['RL', 'CP'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 33,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: "For example: can they point to something red when asked?",
      malayalam: "കുറഞ്ഞത് ഒരു നിറമെങ്കിലും കുട്ടി അറിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_10",
      prompt: "Can your child twist things?",
      domain: "FM",
      tags: ['FM'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 24,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: "For example: turning a knob or unscrewing a lid.",
      malayalam:
          "തിരിച്ച് തുറക്കേണ്ട വസ്തുക്കൾ കുട്ടിക്ക് തിരിക്കാൻ കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_11",
      prompt: "Can your child take off some of their own clothes?",
      domain: "SH",
      tags: ['SH'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 24,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-ADAPT",
      probes: ['P2'],
      subtext: "For example: loose pants or an open jacket.",
      malayalam: "സ്വന്തം ചില വസ്ത്രങ്ങൾ കുട്ടിക്ക് അഴിക്കാനാകുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_12",
      prompt: "Can your child jump off the ground with both feet?",
      domain: "GM",
      tags: ['GM'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 24,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-MOTOR",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "രണ്ട് കാലും ഒരുമിച്ച് നിലത്ത് നിന്ന് ഉയർത്തി ചാടാൻ കുട്ടിക്ക് കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_13",
      prompt: "Does your child turn book pages one at a time?",
      domain: "FM",
      tags: ['FM'],
      minAge: 24,
      maxAge: 30,
      normativeAgeMonths: 24,
      evidenceStrength: "Low",
      weight: "L",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "പുസ്തകത്തിന്റെ പേജുകൾ ഒന്ന് വീതം തിരിക്കാൻ കുട്ടിക്ക് കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_24_29m_14",
      prompt: "Is your child showing signs of toilet readiness?",
      domain: "SH",
      tags: ['SH'],
      minAge: 24,
      maxAge: 36,
      normativeAgeMonths: 27,
      evidenceStrength: "Low",
      weight: "L",
      escalationRule: "R1",
      actionProfile: "AP-TOILET",
      probes: ['P2', 'P3'],
      subtext:
          "For example: staying dry for about 2 hours, telling you when they need to go, or being able to pull their pants up and down.",
      malayalam:
          "ടോയ്ലറ്റ് തയ്യാറെടുപ്പിന്റെ ലക്ഷണങ്ങൾ കുട്ടി കാണിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 2 Years / 30 Months",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_01",
      prompt:
          "Does your child calm down within 10 minutes after you leave, such as at a childcare drop-off?",
      domain: "SE",
      tags: ['SE'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P2', 'P5'],
      subtext: null,
      malayalam:
          "കുട്ടിയെ വിട്ടുപോയതിന് ശേഷം, ഉദാഹരണത്തിന് ആംഗൻവാടിയിൽ, 10 മിനിറ്റിനകം കുട്ടി ശാന്തമാകുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_02",
      prompt: "Does your child notice other children and join them to play?",
      domain: "SE",
      tags: ['SE'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1_R2",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "മറ്റ് കുട്ടികളെ ശ്രദ്ധിച്ച് അവരോടൊപ്പം കളിക്കാൻ കുട്ടി ചേരുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_03",
      prompt:
          "Can your child have a back-and-forth conversation with at least 2 exchanges?",
      domain: "EL/RL",
      tags: ['EL', 'RL'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P3', 'P5'],
      subtext: null,
      malayalam:
          "കുറഞ്ഞത് രണ്ട് മറുപടികൾ ഉൾപ്പെടുന്ന മുന്നോട്ടും പിന്നോട്ടുമുള്ള സംഭാഷണം കുട്ടിക്ക് നടത്താനാകുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_04",
      prompt: "Does your child ask who, what, where, or why questions?",
      domain: "EL",
      tags: ['EL'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P2'],
      subtext: null,
      malayalam:
          "ആർ, എന്ത്, എവിടെ, എന്തുകൊണ്ട് തുടങ്ങിയ ചോദ്യങ്ങൾ കുട്ടി ചോദിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_05",
      prompt:
          "If you ask about a picture, can your child say what action is happening?",
      domain: "EL/CP",
      tags: ['EL', 'CP'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P1', 'P2'],
      subtext: "For example: 'running' or 'eating'.",
      malayalam:
          "ഒരു ചിത്രം കാണിച്ച് ചോദിച്ചാൽ അതിൽ എന്ത് പ്രവർത്തനമാണ് നടക്കുന്നതെന്ന് കുട്ടി പറയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_06",
      prompt: "Does your child use words to describe actions in daily life?",
      domain: "EL/CP",
      tags: ['EL', 'CP'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P1', 'P2'],
      subtext:
          "For example: saying 'running' or 'eating' while doing those things.",
      malayalam:
          "ദൈനംദിന ജീവിതത്തിലെ പ്രവർത്തനങ്ങൾ വിവരിക്കാൻ കുട്ടി വാക്കുകൾ ഉപയോഗിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_07",
      prompt: "Can your child say their first name when asked?",
      domain: "EL",
      tags: ['EL'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-LANG",
      probes: ['P2', 'P5'],
      subtext: null,
      malayalam: "ചോദിച്ചാൽ സ്വന്തം ആദ്യ പേര് കുട്ടിക്ക് പറയാൻ കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_08",
      prompt: "Do others understand your child's speech most of the time?",
      domain: "EL",
      tags: ['EL'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "High",
      weight: "H",
      escalationRule: "R2",
      actionProfile: "AP-LANG",
      probes: ['P3', 'P5'],
      subtext: null,
      malayalam:
          "കുട്ടിയുടെ സംസാരത്തെ മറ്റുള്ളവർ കൂടുതലായും മനസ്സിലാക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_09",
      prompt: "Can your child draw a circle when you show them how?",
      domain: "FM/CP",
      tags: ['FM', 'CP'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 36,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam:
          "കാണിച്ചു കൊടുത്താൽ കുട്ടിക്ക് ഒരു വട്ടം വരയ്ക്കാനാകുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_10",
      prompt: "If you warn your child 'hot', do they avoid touching it?",
      domain: "CP/SH",
      tags: ['CP', 'SH'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-ADAPT",
      probes: ['P2', 'P3'],
      subtext: null,
      malayalam:
          "“ചൂടാണ്” എന്ന് മുന്നറിയിപ്പ് നൽകിയാൽ കുട്ടി അത് തൊടാതെ ഒഴിവാക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_11",
      prompt: "Can your child string items together?",
      domain: "FM",
      tags: ['FM'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-STD",
      probes: ['P1', 'P2'],
      subtext: "For example: large beads or macaroni.",
      malayalam:
          "മുത്തുകൾ പോലുള്ള വസ്തുക്കൾ നൂലിൽ കോർക്കാൻ കുട്ടിക്ക് കഴിയുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_12",
      prompt: "Can your child put on some of their own clothes?",
      domain: "SH",
      tags: ['SH'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-ADAPT",
      probes: ['P2'],
      subtext: "For example: loose pants or a jacket.",
      malayalam: "സ്വന്തം ചില വസ്ത്രങ്ങൾ കുട്ടിക്ക് ധരിക്കാനാകുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    MonitoringQuestion(
      id: "q_30_36m_13",
      prompt: "Does your child use a fork?",
      domain: "SH/FM",
      tags: ['SH', 'FM'],
      minAge: 30,
      maxAge: 36,
      normativeAgeMonths: 30,
      evidenceStrength: "Moderate",
      weight: "M",
      escalationRule: "R1",
      actionProfile: "AP-ADAPT",
      probes: ['P1', 'P2'],
      subtext: null,
      malayalam: "കുട്ടി ഫോർക്കുപയോഗിക്കുന്നുണ്ടോ?",
      malayalamSubtext: null,
      citationSource: "CDC 2022 Milestones by 30 Months / 3 Years",
      citationReference: "Zubler et al., Pediatrics 2022;149(3):e2021052138",
    ),
    // M-CHAT-R caregiver screen. These items are shown only from 16–30 months
    // and are scored separately from the age-based developmental milestones.
    MonitoringQuestion(
      id: "mchat_01",
      prompt:
          "If you point at something across the room, does your child look at it?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext:
          "For example, if you point at a toy or an animal, does your child look at the toy or animal?",
      malayalam:
          "മുറിക്കപ്പുറത്തുള്ള എന്തെങ്കിലും നിങ്ങൾ വിരൽചൂണ്ടിക്കാണിച്ചാൽ കുട്ടി അതിലേക്ക് നോക്കുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, ഒരു കളിപ്പാട്ടമോ മൃഗമോ ചൂണ്ടിക്കാണിച്ചാൽ കുട്ടി അതിലേക്കോ അതിനെക്കോ നോക്കുന്നുണ്ടോ?",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_02",
      prompt: "Have you ever wondered if your child might be deaf?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      mchatConcernWhenYes: true,
      malayalam:
          "നിങ്ങളുടെ കുട്ടിക്ക് കേൾവിക്കുറവുണ്ടാകാമോ എന്ന് നിങ്ങൾക്ക് എപ്പോഴെങ്കിലും സംശയം തോന്നിയിട്ടുണ്ടോ?",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_03",
      prompt: "Does your child play pretend or make-believe?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext:
          "For example, pretend to drink from an empty cup, talk on a phone, or feed a doll or stuffed animal.",
      malayalam:
          "കുട്ടി നടിക്കുന്നതോ സാങ്കൽപ്പികമായതോ ആയ കളികൾ കളിക്കുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, ഒഴിഞ്ഞ കപ്പിൽ നിന്ന് കുടിക്കുന്നതായി നടിക്കുക, ഫോണിൽ സംസാരിക്കുന്നതായി നടിക്കുക, അല്ലെങ്കിൽ പാവയ്ക്കോ കളിപ്പാട്ട മൃഗത്തിനോ ഭക്ഷണം കൊടുക്കുന്നതായി നടിക്കുക.",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_04",
      prompt: "Does your child like climbing on things?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext: "For example, furniture, playground equipment, or stairs.",
      malayalam: "കുട്ടിക്ക് വസ്തുക്കളിൽ കയറാൻ ഇഷ്ടമാണോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, ഫർണിച്ചറിലോ കളിസ്ഥലത്തെ ഉപകരണങ്ങളിലോ പടികളിലോ കയറുന്നത്.",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_05",
      prompt:
          "Does your child make unusual finger movements near his or her eyes?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      mchatConcernWhenYes: true,
      subtext:
          "For example, does your child wiggle his or her fingers close to his or her eyes?",
      malayalam:
          "കുട്ടി കണ്ണുകൾക്ക് സമീപം അസാധാരണമായ വിരൽചലനങ്ങൾ കാണിക്കുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, കണ്ണുകൾക്ക് വളരെ അടുത്ത് വിരലുകൾ ഇളക്കുകയോ വിറപ്പിക്കുകയോ ചെയ്യുന്നുണ്ടോ?",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_06",
      prompt:
          "Does your child point with one finger to ask for something or to get help?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext: "For example, pointing to a snack or toy that is out of reach.",
      malayalam:
          "എന്തെങ്കിലും ചോദിക്കാനോ സഹായം തേടാനോ കുട്ടി ഒരു വിരൽ കൊണ്ട് ചൂണ്ടിക്കാണിക്കുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, എത്തിപ്പിടിക്കാൻ കഴിയാത്ത ലഘുഭക്ഷണമോ കളിപ്പാട്ടമോ ചൂണ്ടിക്കാണിക്കുന്നത്.",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_07",
      prompt:
          "Does your child point with one finger to show you something interesting?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext:
          "For example, pointing to an airplane in the sky or a big truck in the road.",
      malayalam:
          "രസകരമായ എന്തെങ്കിലും നിങ്ങൾക്ക് കാണിച്ചുതരാൻ കുട്ടി ഒരു വിരൽ കൊണ്ട് ചൂണ്ടിക്കാണിക്കുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, ആകാശത്തിലെ വിമാനമോ റോഡിലെ വലിയ ലോറിയോ ചൂണ്ടിക്കാണിക്കുന്നത്.",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_08",
      prompt: "Is your child interested in other children?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext:
          "For example, does your child watch other children, smile at them, or go to them?",
      malayalam: "കുട്ടിക്ക് മറ്റ് കുട്ടികളിൽ താൽപര്യമുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, മറ്റ് കുട്ടികളെ നോക്കുക, അവരെ നോക്കി പുഞ്ചിരിക്കുക, അല്ലെങ്കിൽ അവരുടെ അടുത്തേക്ക് പോകുക.",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_09",
      prompt:
          "Does your child show you things by bringing them to you or holding them up for you to see—not to get help, but just to share?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext:
          "For example, showing you a flower, a stuffed animal, or a toy truck.",
      malayalam:
          "സഹായം തേടാനല്ലാതെ, പങ്കുവെക്കാനായി മാത്രം, കുട്ടി വസ്തുക്കൾ കൊണ്ടുവന്ന് കാണിക്കുകയോ ഉയർത്തിപ്പിടിച്ച് കാണിക്കുകയോ ചെയ്യുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, ഒരു പൂവോ കളിപ്പാട്ട മൃഗമോ കളിപ്പാട്ട ലോറിയോ കാണിക്കുന്നത്.",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_10",
      prompt: "Does your child respond when you call his or her name?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext:
          "For example, does your child look up, talk or babble, or stop what he or she is doing when called?",
      malayalam: "കുട്ടിയുടെ പേര് വിളിക്കുമ്പോൾ കുട്ടി പ്രതികരിക്കുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, മുകളിലേക്ക് നോക്കുക, സംസാരിക്കുകയോ ശബ്ദമുണ്ടാക്കുകയോ ചെയ്യുക, അല്ലെങ്കിൽ ചെയ്തുകൊണ്ടിരുന്നത് നിർത്തുക.",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_11",
      prompt: "When you smile at your child, does he or she smile back at you?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      malayalam:
          "നിങ്ങൾ കുട്ടിയെ നോക്കി പുഞ്ചിരിക്കുമ്പോൾ കുട്ടി തിരികെ പുഞ്ചിരിക്കുന്നുണ്ടോ?",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_12",
      prompt: "Does your child get upset by everyday noises?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      mchatConcernWhenYes: true,
      subtext:
          "For example, does your child scream or cry to noise such as a vacuum cleaner or loud music?",
      malayalam: "ദൈനംദിന ശബ്ദങ്ങൾ കേൾക്കുമ്പോൾ കുട്ടി അസ്വസ്ഥനാകുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, വാക്വം ക്ലീനറിന്റെയോ ഉച്ചത്തിലുള്ള സംഗീതത്തിന്റെയോ ശബ്ദം കേട്ട് കുട്ടി നിലവിളിക്കുകയോ കരയുകയോ ചെയ്യുന്നുണ്ടോ?",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_13",
      prompt: "Does your child walk?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      malayalam: "കുട്ടി നടക്കുന്നുണ്ടോ?",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_14",
      prompt:
          "Does your child look you in the eye when you are talking to him or her, playing with him or her, or dressing him or her?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      malayalam:
          "നിങ്ങൾ കുട്ടിയോട് സംസാരിക്കുമ്പോഴോ കളിക്കുമ്പോഴോ വസ്ത്രം ധരിപ്പിക്കുമ്പോഴോ കുട്ടി നിങ്ങളുടെ കണ്ണുകളിലേക്ക് നോക്കുന്നുണ്ടോ?",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_15",
      prompt: "Does your child try to copy what you do?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext:
          "For example, wave bye-bye, clap, or make a funny noise when you do.",
      malayalam: "നിങ്ങൾ ചെയ്യുന്നത് അനുകരിക്കാൻ കുട്ടി ശ്രമിക്കുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, നിങ്ങൾ ചെയ്യുമ്പോൾ കൈവീശുക, കൈയടിക്കുക, അല്ലെങ്കിൽ രസകരമായ ശബ്ദം ഉണ്ടാക്കുക.",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_16",
      prompt:
          "If you turn your head to look at something, does your child look around to see what you are looking at?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      malayalam:
          "നിങ്ങൾ എന്തെങ്കിലും കാണാൻ തല തിരിക്കുമ്പോൾ, നിങ്ങൾ എന്താണ് നോക്കുന്നതെന്ന് കാണാൻ കുട്ടി ചുറ്റും നോക്കുന്നുണ്ടോ?",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_17",
      prompt: "Does your child try to get you to watch him or her?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext:
          "For example, does your child look at you for praise, or say 'look' or 'watch me'?",
      malayalam:
          "തന്നെ നോക്കാൻ കുട്ടി നിങ്ങളെ പ്രേരിപ്പിക്കാൻ ശ്രമിക്കുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, പ്രശംസയ്ക്കായി നിങ്ങളെ നോക്കുക, അല്ലെങ്കിൽ “നോക്കൂ”, “എന്നെ നോക്കൂ” എന്ന് പറയുക.",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_18",
      prompt:
          "Does your child understand when you tell him or her to do something?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext:
          "For example, if you do not point, can your child understand 'put the book on the chair' or 'bring me the blanket'?",
      malayalam:
          "ഒരു കാര്യം ചെയ്യാൻ പറയുമ്പോൾ കുട്ടിക്ക് അത് മനസ്സിലാകുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, വിരൽചൂണ്ടാതെ “പുസ്തകം കസേരയിൽ വയ്ക്കൂ” അല്ലെങ്കിൽ “പുതപ്പ് കൊണ്ടുവരൂ” എന്ന് പറഞ്ഞാൽ കുട്ടിക്ക് മനസ്സിലാകുന്നുണ്ടോ?",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_19",
      prompt:
          "If something new happens, does your child look at your face to see how you feel about it?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext:
          "For example, if your child hears a strange or funny noise, or sees a new toy, will they look at your face?",
      malayalam:
          "പുതിയതായി എന്തെങ്കിലും സംഭവിക്കുമ്പോൾ, അതിനെക്കുറിച്ച് നിങ്ങൾക്ക് എങ്ങനെ തോന്നുന്നു എന്ന് അറിയാൻ കുട്ടി നിങ്ങളുടെ മുഖത്തേക്ക് നോക്കുന്നുണ്ടോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, വിചിത്രമോ രസകരമോ ആയ ശബ്ദം കേൾക്കുമ്പോഴോ പുതിയ കളിപ്പാട്ടം കാണുമ്പോഴോ കുട്ടി നിങ്ങളുടെ മുഖത്തേക്ക് നോക്കുന്നുണ്ടോ?",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
    MonitoringQuestion(
      id: "mchat_20",
      prompt: "Does your child like movement activities?",
      domain: "M-CHAT-R",
      tags: ['MCHAT'],
      minAge: 16,
      maxAge: 30,
      normativeAgeMonths: 16,
      evidenceStrength: "M-CHAT-R caregiver screen",
      weight: "MCHAT",
      escalationRule: "MCHAT",
      actionProfile: "AP-MCHAT",
      isMchatQuestion: true,
      subtext: "For example, being swung or bounced on your knee.",
      malayalam: "ചലനമുള്ള പ്രവർത്തനങ്ങൾ കുട്ടിക്ക് ഇഷ്ടമാണോ?",
      malayalamSubtext:
          "ഉദാഹരണത്തിന്, ആട്ടുക അല്ലെങ്കിൽ മടിയിലിരുത്തി കുലുക്കുക.",
      citationSource: "M-CHAT-R/F",
      citationReference: "Robins et al., Pediatrics 2014;133(1):37-45",
    ),
  ];
  static const _domainNames = {
    'GM': 'Gross Motor',
    'FM': 'Fine Motor',
    'RL': 'Receptive Language',
    'EL': 'Expressive Language',
    'SE': 'Social-Emotional',
    'CP': 'Cognitive / Play',
    'SH': 'Self-Help / Adaptive',
    'VH': 'Vision / Hearing',
    'RF': 'Red Flags',
    'MCHAT': 'M-CHAT-R',
  };
  static const _probeMalayalam = {
    'P1': 'കുട്ടിക്ക് ഇത് ചെയ്യാൻ അവസരം ലഭിച്ചിട്ടുണ്ടോ?',
    'P2': 'കഴിഞ്ഞ 7 ദിവസത്തിനുള്ളിൽ ഇത് കുറഞ്ഞത് ഒരിക്കൽ കണ്ടിട്ടുണ്ടോ?',
    'P3': 'കുട്ടി ചെയ്തത് കുറിച്ച് ഒരു ചെറിയ ഉദാഹരണം പറയാമോ?',
    'P4': 'നിങ്ങൾക്ക് ഉറപ്പാണോ, അല്ലെങ്കിൽ സംശയമാണോ?',
    'P5':
        'നോക്കിയ സമയത്ത് കുട്ടിക്ക് അസുഖമോ ഉറക്കമോ അസ്വസ്ഥതയോ ശ്രദ്ധതിരിവോ ഉണ്ടായിരുന്നോ?',
  };
  static const _statusOrder = {
    'normal': 0,
    'insufficient_evidence': 1,
    'watch': 2,
    'low_concern': 3,
    'moderate_concern': 4,
    'high_concern': 5,
  };

  /// Returns a compact parent check with no more than 20 prompts.
  ///
  /// The official M-CHAT-R/F is a 20-item licensed instrument and must not be
  /// shortened or scored as a modified version. It is therefore excluded from
  /// this compact developmental check.
  static List<MonitoringQuestion> forAge(int months) {
    if (months < 12 || months > 36) return const [];

    final due = questions
        .where(
          (q) => months >= q.minAge && months <= q.maxAge && !q.isMchatQuestion,
        )
        .toList();
    final safetyChecks = due.where(_isSafetyCheck).toList();
    final compact = <MonitoringQuestion>[...safetyChecks];

    for (final group in _compactGroupOrder) {
      final representatives =
          due
              .where((q) => !_isSafetyCheck(q) && questionGroupFor(q) == group)
              .toList()
            ..sort(
              (a, b) => (a.normativeAgeMonths - months).abs().compareTo(
                (b.normativeAgeMonths - months).abs(),
              ),
            );
      compact.addAll(representatives.take(_compactGroupLimit));
    }

    return compact.take(compactQuestionLimit).toList();
  }

  static bool _isSafetyCheck(MonitoringQuestion question) =>
      question.id.startsWith('rf_');

  static String questionGroupFor(MonitoringQuestion question) {
    if (_isSafetyCheck(question)) return 'Safety and sensory';
    if (question.tags.contains('SE')) return 'Social connection';
    if (question.tags.contains('EL') || question.tags.contains('RL')) {
      return 'Communication';
    }
    if (question.tags.contains('CP')) return 'Learning and play';
    if (question.tags.contains('GM') || question.tags.contains('FM')) {
      return 'Movement and hand skills';
    }
    return 'Everyday skills';
  }

  static MyChildState evaluate(
    Map<String, bool> answers, {
    MyChildState? previous,
  }) {
    final failed = answers.values.where((v) => !v).length;
    if (previous != null && previous != MyChildState.normal && failed == 0) {
      return MyChildState.regression;
    }
    if (failed >= 3) return MyChildState.flag;
    if (failed >= 2) return MyChildState.warning;
    if (failed == 1) return MyChildState.precaution;
    return MyChildState.normal;
  }

  static MyChildEvaluation evaluateDetailed({
    required int ageMonths,
    required Map<String, MyChildAnswer> answers,
    DateTime? birthDate,
    int? gestationalWeeks,
    Map<String, List<MyChildAnswer>> answerHistory = const {},
    DateTime? now,
  }) {
    final effective = _effectiveAge(
      ageMonths,
      birthDate,
      gestationalWeeks,
      now,
    );
    final effectiveAge = effective.$1;
    final corrected = effective.$2;
    final due = forAge(effectiveAge.floor().clamp(12, 36));
    final results = due
        .map(
          (q) => _evaluateQuestion(
            q,
            effectiveAge,
            corrected,
            gestationalWeeks,
            answers[q.id],
            answerHistory[q.id] ?? const [],
          ),
        )
        .toList();
    final domains = _scoreDomains(results);
    final highest = domains.values.fold(
      0,
      (max, d) => (_statusOrder[d.status] ?? 0) > max
          ? (_statusOrder[d.status] ?? 0)
          : max,
    );
    final state = highest >= 5
        ? MyChildState.flag
        : highest >= 4
        ? MyChildState.warning
        : highest >= 3
        ? MyChildState.precaution
        : MyChildState.normal;
    final level = state == MyChildState.flag || state == MyChildState.warning
        ? 'red'
        : state == MyChildState.precaution
        ? 'yellow'
        : 'green';
    final message = switch (level) {
      'red' =>
        'One or more developmental areas need prompt discussion with a clinician.',
      'yellow' => 'Some milestones need closer monitoring and re-check.',
      _ => 'Development appears on track in the answered domains.',
    };
    return MyChildEvaluation(
      state: state,
      tier: tier(state),
      globalLevel: level,
      message: message,
      questions: results,
      domains: domains,
      nextActions: _nextActions(results, domains),
      correctedAgeUsed: corrected,
      effectiveAgeMonths: effectiveAge,
    );
  }

  static String tier(MyChildState state) => switch (state) {
    MyChildState.normal => 'GREEN',
    MyChildState.precaution => 'YELLOW',
    MyChildState.warning ||
    MyChildState.flag ||
    MyChildState.regression => 'RED',
  };

  static bool isDraftMalayalam(String locale) => false;
  static List<String> probesMalayalam(MonitoringQuestion q) =>
      q.probes.map((p) => _probeMalayalam[p] ?? p).toList();

  static (double, bool) _effectiveAge(
    int ageMonths,
    DateTime? birthDate,
    int? gestationalWeeks,
    DateTime? now,
  ) {
    if (birthDate == null) return (ageMonths.toDouble(), false);
    final ref = now ?? DateTime.now();
    final chronologicalDays = ref.difference(birthDate).inDays.clamp(0, 2000);
    final chronologicalMonths = chronologicalDays / 30.4375;
    final weeksEarly = gestationalWeeks == null || gestationalWeeks >= 37
        ? 0
        : 40 - gestationalWeeks;
    final correctedMonths = (chronologicalDays - weeksEarly * 7) / 30.4375;
    final useCorrected = weeksEarly > 0 && chronologicalMonths < 24;
    return (
      (useCorrected ? correctedMonths : chronologicalMonths).clamp(0, 36),
      useCorrected,
    );
  }

  static MyChildQuestionResult _evaluateQuestion(
    MonitoringQuestion q,
    double age,
    bool corrected,
    int? gestationalWeeks,
    MyChildAnswer? answer,
    List<MyChildAnswer> history,
  ) {
    final severity = _severityFor(q, age, answer);
    final regression =
        history.contains(MyChildAnswer.achieved) &&
        (answer == MyChildAnswer.notYet || answer == MyChildAnswer.unsure);
    final effectiveSeverity =
        regression &&
            _severityRank(severity) < _severityRank(MyChildSeverity.warning)
        ? MyChildSeverity.warning
        : severity;
    final inputFactors = <String>[
      'Child age used for scoring: ${age.toStringAsFixed(1)} months ${corrected ? '(corrected)' : '(chronological/manual)'}',
      'Milestone normative age: ${q.normativeAgeMonths > 0 ? '${q.normativeAgeMonths} months' : 'N/A (universal red flag)'}',
      'Answer recorded: ${answer?.name ?? 'not answered'}',
      'Evidence strength: ${q.evidenceStrength}',
      'Domain(s): ${q.tags.join(', ')}',
      'Weight class: ${q.weight}',
    ];
    if (gestationalWeeks != null && gestationalWeeks < 37) {
      inputFactors.add(
        'Preterm adjustment: born at $gestationalWeeks weeks; corrected age used until 24 months.',
      );
    }
    final detail = MyChildExplanation(
      questionId: q.id,
      inputFactors: inputFactors,
      appliedRule: _appliedRule(effectiveSeverity),
      outputSeverity: effectiveSeverity.name,
      whyThisAgeMatters: _whyAgeMatters(q),
      recommendedAction: _recommendedAction(effectiveSeverity),
      nextCheckWeeks: _nextCheckWeeks(effectiveSeverity, age < 12),
    );
    final text = regression
        ? 'A previously achieved milestone is now not clearly present; this regression pattern escalates concern.'
        : _questionExplanation(q, effectiveSeverity, age);
    return MyChildQuestionResult(
      question: q,
      answer: answer,
      severity: effectiveSeverity,
      explanation: text,
      detail: detail,
      regressionDetected: regression,
    );
  }

  static MyChildSeverity _severityFor(
    MonitoringQuestion q,
    double age,
    MyChildAnswer? answer,
  ) {
    if (answer == null || answer == MyChildAnswer.skipped) {
      return MyChildSeverity.reminder;
    }
    if (q.isMchatQuestion) {
      if (answer == MyChildAnswer.unsure) {
        return MyChildSeverity.watch;
      }
      final answeredYes = answer == MyChildAnswer.achieved;
      final isConcern = q.mchatConcernWhenYes ? answeredYes : !answeredYes;
      return isConcern ? MyChildSeverity.warning : MyChildSeverity.normal;
    }
    if (answer == MyChildAnswer.achieved) return MyChildSeverity.normal;
    if (answer == MyChildAnswer.unsure) return MyChildSeverity.watch;
    if (q.isUniversalRedFlag) return MyChildSeverity.flag;
    final baseGrace = age < 12 ? 4.0 : 6.0;
    final grace = switch (q.weight) {
      'RF' => 0.0,
      'H' => baseGrace,
      'M' => baseGrace + 2,
      'L' => baseGrace + 4,
      _ => baseGrace,
    };
    if (age < q.normativeAgeMonths) return MyChildSeverity.reminder;
    final overGraceMonths = age - (q.normativeAgeMonths + grace / 4.34524);
    if (overGraceMonths <= 0) return MyChildSeverity.precaution;
    if (overGraceMonths < 1) return MyChildSeverity.warning;
    return MyChildSeverity.flag;
  }

  static Map<String, MyChildDomainAssessment> _scoreDomains(
    List<MyChildQuestionResult> results,
  ) {
    final out = <String, MyChildDomainAssessment>{};
    for (final tag in const [
      'GM',
      'FM',
      'RL',
      'EL',
      'SE',
      'CP',
      'SH',
      'VH',
      'RF',
      'MCHAT',
    ]) {
      final domainResults =
          results.where((r) => r.question.tags.contains(tag)).toList()..sort(
            (a, b) => a.question.normativeAgeMonths.compareTo(
              b.question.normativeAgeMonths,
            ),
          );
      if (domainResults.isEmpty) continue;
      if (tag == 'MCHAT') {
        final concerns = domainResults
            .where((r) => r.severity == MyChildSeverity.warning)
            .toList();
        final unsure = domainResults
            .where((r) => r.severity == MyChildSeverity.watch)
            .length;
        final answered = domainResults
            .where((r) => r.severity != MyChildSeverity.reminder)
            .length;
        final score = concerns.length;
        final status = score >= 8
            ? 'high_concern'
            : score >= 3
            ? 'low_concern'
            : unsure > 0
            ? 'insufficient_evidence'
            : 'normal';
        final explanation = score >= 8
            ? 'M-CHAT-R has $score responses of concern. This is a high-risk result and needs prompt clinical referral.'
            : score >= 3
            ? 'M-CHAT-R has $score responses of concern. Complete the M-CHAT-R Follow-Up interview before interpreting this as a positive screen.'
            : unsure > 0
            ? 'M-CHAT-R has $unsure unsure response(s). Record a Yes or No answer for every item before interpreting the screen.'
            : 'M-CHAT-R has $score responses of concern; routine re-screening is appropriate.';
        out[tag] = MyChildDomainAssessment(
          domainTag: tag,
          domain: _domainNames[tag]!,
          status: status,
          explanation: explanation,
          confidence: answered == domainResults.length ? 'high' : 'low',
          flagCount: score >= 8 ? score : 0,
          warningCount: score < 8 ? score : 0,
          precautionCount: 0,
          streakMissed: 0,
          questionCount: domainResults.length,
          totalWeightedPoints: score.toDouble(),
          triggeringMilestones: concerns
              .map((r) => r.question.malayalam ?? r.question.prompt)
              .toList(),
        );
        continue;
      }
      var flag = 0,
          warning = 0,
          precaution = 0,
          answered = 0,
          currentStreak = 0,
          maxStreak = 0;
      var weighted = 0.0;
      final triggers = <String>[];
      for (final r in domainResults) {
        if (r.severity != MyChildSeverity.reminder) answered++;
        final mul = switch (r.question.weight) {
          'RF' => 2.0,
          'H' => 1.5,
          'L' => .5,
          _ => 1.0,
        };
        if (r.severity == MyChildSeverity.flag) {
          flag++;
          weighted += 3 * mul;
          currentStreak++;
          triggers.add(r.question.malayalam ?? r.question.prompt);
        } else if (r.severity == MyChildSeverity.warning) {
          warning++;
          weighted += 2 * mul;
          currentStreak++;
          triggers.add(r.question.malayalam ?? r.question.prompt);
        } else if (r.severity == MyChildSeverity.precaution) {
          precaution++;
          weighted += mul;
          currentStreak++;
        } else {
          if (currentStreak > maxStreak) maxStreak = currentStreak;
          currentStreak = 0;
        }
      }
      if (currentStreak > maxStreak) maxStreak = currentStreak;
      final confidence = answered >= 3
          ? 'high'
          : answered >= 2
          ? 'medium'
          : answered == 1
          ? 'low'
          : 'low';
      final hasRegression = domainResults.any((r) => r.regressionDetected);
      String status, explanation;
      final name = _domainNames[tag]!;
      if (answered < 2 && flag == 0 && warning == 0 && !hasRegression) {
        status = 'insufficient_evidence';
        explanation =
            'Not enough observations to assess $name reliably. Answer at least 2 questions in this domain.';
      } else if (hasRegression || flag > 0) {
        status = tag == 'RF' || flag > 1 || hasRegression
            ? 'high_concern'
            : 'low_concern';
        explanation = hasRegression
            ? '$name shows possible loss of a previously achieved skill. Prompt clinical discussion is recommended.'
            : '$name has $flag flagged milestone(s) that need follow-up.';
      } else if (warning >= 1 ||
          maxStreak >= 2 ||
          precaution >= 3 ||
          weighted >= 2) {
        status = warning >= 1 ? 'moderate_concern' : 'low_concern';
        explanation =
            '$name has milestones delayed or approaching their grace window. Monitor closely and discuss if concerns persist.';
      } else if (precaution >= 1) {
        status = 'watch';
        explanation =
            '$name has one milestone approaching its grace window. Re-check soon.';
      } else {
        status = 'normal';
        explanation = '$name is progressing as expected in answered items.';
      }
      out[tag] = MyChildDomainAssessment(
        domainTag: tag,
        domain: name,
        status: status,
        explanation: explanation,
        confidence: confidence,
        flagCount: flag,
        warningCount: warning,
        precautionCount: precaution,
        streakMissed: maxStreak,
        questionCount: domainResults.length,
        totalWeightedPoints: weighted,
        triggeringMilestones: triggers,
      );
    }
    return out;
  }

  static List<String> _nextActions(
    List<MyChildQuestionResult> results,
    Map<String, MyChildDomainAssessment> domains,
  ) {
    final actions = <String>[];
    final mchat = domains['MCHAT'];
    if (mchat?.status == 'high_concern') {
      actions.add(
        'M-CHAT-R high-risk score: discuss prompt referral with a doctor or DEIC clinician.',
      );
    }
    if (mchat?.status == 'low_concern') {
      actions.add(
        'M-CHAT-R score is 3–7: complete the official Follow-Up interview before making a referral decision.',
      );
    }
    if (domains.values.any((d) => d.status == 'high_concern')) {
      actions.add(
        'Discuss the flagged developmental area with a doctor or DEIC clinician soon.',
      );
    }
    if (results.any((r) => r.regressionDetected)) {
      actions.add(
        'Skill loss was reported; do not wait for routine follow-up.',
      );
    }
    if (domains.values.any(
      (d) => d.status == 'moderate_concern' || d.status == 'low_concern',
    )) {
      actions.add(
        'Re-check delayed milestones in 2-4 weeks and record examples from home.',
      );
    }
    if (results.any((r) => r.severity == MyChildSeverity.watch)) {
      actions.add('Use the suggested probes to clarify unsure answers.');
    }
    if (actions.isEmpty) {
      actions.add(
        'Continue routine developmental monitoring through play and daily routines.',
      );
    }
    return actions;
  }

  static int _severityRank(MyChildSeverity s) => switch (s) {
    MyChildSeverity.normal => 0,
    MyChildSeverity.reminder => 1,
    MyChildSeverity.watch => 2,
    MyChildSeverity.precaution => 3,
    MyChildSeverity.warning => 4,
    MyChildSeverity.flag => 5,
  };
  static String _appliedRule(MyChildSeverity s) => switch (s) {
    MyChildSeverity.normal => 'Answer was achieved; no concern for this item.',
    MyChildSeverity.reminder =>
      'Question was not answered or milestone is not yet expected.',
    MyChildSeverity.watch =>
      'Caregiver was unsure; probes are suggested before re-evaluation.',
    MyChildSeverity.precaution =>
      'Not yet and child is within the weight-adjusted grace window.',
    MyChildSeverity.warning =>
      'Not yet and child is just past the grace window.',
    MyChildSeverity.flag =>
      'Not yet and child is significantly past the grace window, or this is a universal red flag.',
  };
  static String _recommendedAction(MyChildSeverity s) => switch (s) {
    MyChildSeverity.normal =>
      'No action required for this item. Continue normal developmental play.',
    MyChildSeverity.reminder => 'Ask again at the next check-in.',
    MyChildSeverity.watch => 'Use probes and re-check within 2 weeks.',
    MyChildSeverity.precaution =>
      'Offer practice opportunities and re-check in 2-4 weeks.',
    MyChildSeverity.warning =>
      'Monitor closely and mention this at the next doctor visit if still not achieved.',
    MyChildSeverity.flag =>
      'Discuss this milestone with a doctor or DEIC clinician soon.',
  };
  static int _nextCheckWeeks(MyChildSeverity s, bool infant) => switch (s) {
    MyChildSeverity.normal => 12,
    MyChildSeverity.reminder => 4,
    MyChildSeverity.watch => 2,
    MyChildSeverity.precaution || MyChildSeverity.warning => infant ? 2 : 4,
    MyChildSeverity.flag => 2,
  };
  static String _whyAgeMatters(MonitoringQuestion q) =>
      q.normativeAgeMonths == 0
      ? 'This is monitored throughout 0-36 months because it can signal a need for prompt follow-up.'
      : 'This milestone is usually expected around ${q.normativeAgeMonths} months and supports later developmental skills.';
  static String _questionExplanation(
    MonitoringQuestion q,
    MyChildSeverity s,
    double age,
  ) => switch (s) {
    MyChildSeverity.normal => 'Milestone achieved.',
    MyChildSeverity.reminder =>
      'This item is not yet answered or is still inside the expected age window.',
    MyChildSeverity.watch => 'Caregiver is unsure; use probes to clarify.',
    MyChildSeverity.precaution =>
      'Child is within the grace window for this milestone.',
    MyChildSeverity.warning =>
      'Child is slightly past the grace window for this milestone.',
    MyChildSeverity.flag =>
      q.isUniversalRedFlag
          ? 'Universal red-flag item was answered not yet.'
          : 'Child is significantly past the grace window for this milestone.',
  };
}

class CombinedScreeningResult {
  final String tier;
  final bool audioIncomplete;
  final MyChildState questionnaireState;
  const CombinedScreeningResult(
    this.tier,
    this.audioIncomplete,
    this.questionnaireState,
  );

  factory CombinedScreeningResult.combine({
    required MyChildState questionnaire,
    required String acousticTier,
    required bool audioQualityPassed,
  }) {
    const order = {'GREEN': 0, 'YELLOW': 1, 'RED': 2};
    final q = MyChildEngine.tier(questionnaire);
    final acoustic = order.containsKey(acousticTier) ? acousticTier : 'GREEN';
    return CombinedScreeningResult(
      (order[q]! >= order[acoustic]! ? q : acoustic),
      false,
      questionnaire,
    );
  }
}
