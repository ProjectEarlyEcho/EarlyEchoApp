/// Informational developmental-monitoring goals from CDC's Learn the Signs.
/// Act Early. milestone checklists (accessed July 2026).
///
/// CDC milestones describe skills that at least 75% of children can usually do
/// by a given age. They are not a diagnostic or validated screening tool.
class CdcDevelopmentalGoals {
  static const sourceUrl =
      'https://www.cdc.gov/act-early/milestones/index.html';

  static const ageGroups = <CdcAgeGroup>[
    CdcAgeGroup(
      ageMonths: 12,
      label: '1 year',
      categories: {
        'Social / emotional': ['Plays games with you, like pat-a-cake'],
        'Language / communication': [
          'Waves “bye-bye”',
          'Calls a parent “mama” or “dada” or another special name',
          'Understands “no” (pauses briefly or stops when you say it)',
        ],
        'Learning / thinking': [
          'Puts something in a container, like a block in a cup',
          'Looks for things they see you hide, like a toy under a blanket',
        ],
        'Movement / physical': [
          'Pulls up to stand',
          'Walks while holding on to furniture',
          'Drinks from a cup without a lid while you hold it',
          'Picks things up between thumb and pointer finger',
        ],
      },
    ),
    CdcAgeGroup(
      ageMonths: 15,
      label: '15 months',
      categories: {
        'Social / emotional': [
          'Copies other children while playing',
          'Shows you an object they like',
          'Claps when excited',
          'Hugs a stuffed doll or other toy',
          'Shows affection, such as hugs, cuddles, or kisses',
        ],
        'Language / communication': [
          'Tries to say one or two words besides “mama” or “dada”',
          'Looks at a familiar object when you name it',
          'Follows directions given with both a gesture and words',
          'Points to ask for something or get help',
        ],
        'Learning / thinking': [
          'Tries to use things the right way, like a phone, cup, or book',
          'Stacks at least two small objects, like blocks',
        ],
        'Movement / physical': [
          'Takes a few steps on their own',
          'Uses fingers to feed themself some food',
        ],
      },
    ),
    CdcAgeGroup(
      ageMonths: 18,
      label: '18 months',
      categories: {
        'Social / emotional': [
          'Moves away from you, but looks to make sure you are close by',
          'Points to show you something interesting',
          'Puts hands out for you to wash them',
          'Looks at a few pages in a book with you',
          'Helps you dress them by pushing an arm through a sleeve or lifting a foot',
        ],
        'Language / communication': [
          'Tries to say three or more words besides “mama” or “dada”',
          'Follows one-step directions without gestures',
        ],
        'Learning / thinking': [
          'Copies you doing chores, like sweeping with a broom',
          'Plays with toys in a simple way, like pushing a toy car',
        ],
        'Movement / physical': [
          'Walks without holding on to anyone or anything',
          'Scribbles',
          'Drinks from a cup without a lid and may spill sometimes',
          'Feeds themself with fingers',
          'Tries to use a spoon',
          'Climbs on and off a couch or chair without help',
        ],
      },
    ),
    CdcAgeGroup(
      ageMonths: 24,
      label: '2 years',
      categories: {
        'Social / emotional': [
          'Notices when others are hurt or upset',
          'Looks at your face to see how to react in a new situation',
        ],
        'Language / communication': [
          'Points to things in a book when you ask',
          'Says at least two words together, like “more milk”',
          'Points to at least two body parts when asked',
          'Uses gestures beyond waving and pointing, like blowing a kiss or nodding yes',
        ],
        'Learning / thinking': [
          'Holds something in one hand while using the other hand',
          'Tries switches, knobs, or buttons on a toy',
          'Plays with more than one toy at the same time',
        ],
        'Movement / physical': [
          'Kicks a ball',
          'Runs',
          'Walks up a few stairs with or without help',
          'Eats with a spoon',
        ],
      },
    ),
    CdcAgeGroup(
      ageMonths: 30,
      label: '30 months',
      categories: {
        'Social / emotional': [
          'Plays next to other children and sometimes plays with them',
          'Shows you what they can do by saying “Look at me!”',
          'Follows simple routines when told, like helping pick up toys',
        ],
        'Language / communication': [
          'Says about 50 words',
          'Says two or more words together with one action word',
          'Names things in a book when you point and ask',
          'Says words like “I,” “me,” or “we”',
        ],
        'Learning / thinking': [
          'Uses things to pretend, like feeding a block to a doll',
          'Shows simple problem-solving skills',
          'Follows two-step instructions',
          'Shows they know at least one colour',
        ],
        'Movement / physical': [
          'Uses hands to twist things, like turning doorknobs',
          'Takes some clothes off without help',
          'Jumps off the ground with both feet',
          'Turns book pages one at a time',
        ],
      },
    ),
    CdcAgeGroup(
      ageMonths: 36,
      label: '3 years',
      categories: {
        'Social / emotional': [
          'Calms down within 10 minutes after you leave them',
          'Notices other children and joins them to play',
        ],
        'Language / communication': [
          'Talks with you in a conversation using at least two back-and-forth exchanges',
          'Asks “who,” “what,” “where,” or “why” questions',
          'Says what action is happening in a picture or book when asked',
          'Says their first name when asked',
          'Talks well enough for others to understand most of the time',
        ],
        'Learning / thinking': [
          'Draws a circle when you show them how',
          'Avoids touching hot objects when you warn them',
        ],
        'Movement / physical': [
          'Strings items together, like large beads or macaroni',
          'Puts on some clothes without help',
          'Uses a fork',
        ],
      },
    ),
  ];

  /// Uses the latest CDC checkpoint at or below the child's current age.
  static CdcAgeGroup forAge(int ageMonths) => ageGroups.lastWhere(
    (group) => group.ageMonths <= ageMonths,
    orElse: () => ageGroups.first,
  );
}

class CdcAgeGroup {
  final int ageMonths;
  final String label;
  final Map<String, List<String>> categories;

  const CdcAgeGroup({
    required this.ageMonths,
    required this.label,
    required this.categories,
  });

  int get goalCount =>
      categories.values.fold(0, (total, goals) => total + goals.length);
}
