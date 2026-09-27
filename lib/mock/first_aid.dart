/// First aid for each emergency situation: Do's and Don'ts, based on published WHO guidance.
///
/// This content is bundled in the app so it works with no internet.
///
/// Rules for this content (keep them when editing):
/// - Every point must come from the cited WHO source. No home remedies, no medicine doses.
/// - "Call 108 now if…" always comes first. First aid never replaces going to hospital.
/// - WHO does not approve third-party apps. We cite the WHO document each page is based on.
/// - TODO(before launch): a doctor checks every page word-by-word against its source, and fills
///   `reviewedBy`. Pages with `sourceToConfirm = true` must have their WHO source confirmed first.
library;

class FirstAidSource {
  const FirstAidSource(this.title, this.year, [this.url]);

  /// e.g. "WHO fact sheet: Snakebite envenoming"
  final String title;
  final int year;
  final String? url;
}

class FirstAidGuide {
  const FirstAidGuide({
    required this.kindId,
    required this.callNowIf,
    required this.dos,
    required this.donts,
    required this.sources,
    this.intro,
    this.signs = const [],
    this.sourceToConfirm = false,
    this.reviewedBy,
  });

  final String kindId;
  final String? intro;

  /// Signs that tell you this situation is happening (optional).
  final List<String> signs;
  final List<String> callNowIf;
  final List<String> dos;
  final List<String> donts;
  final List<FirstAidSource> sources;

  /// True while the exact WHO document for this page is still being confirmed.
  final bool sourceToConfirm;

  /// Doctor who checked this page against the source (null = not yet reviewed).
  final String? reviewedBy;
}

abstract final class FirstAid {
  static FirstAidGuide? forKind(String kindId) => guides.where((g) => g.kindId == kindId).firstOrNull;

  static const _whoSnake = FirstAidSource('WHO fact sheet: Snakebite envenoming', 2023,
      'https://www.who.int/news-room/fact-sheets/detail/snakebite-envenoming');
  static const _whoSearoSnake = FirstAidSource('WHO South-East Asia: Guidelines for the management of snakebites, 2nd edition', 2016);
  static const _whoRabies = FirstAidSource('WHO fact sheet: Rabies', 2024, 'https://www.who.int/news-room/fact-sheets/detail/rabies');
  static const _whoBurns = FirstAidSource('WHO fact sheet: Burns', 2023, 'https://www.who.int/news-room/fact-sheets/detail/burns');
  static const _whoCvd = FirstAidSource('WHO fact sheet: Cardiovascular diseases (CVDs)', 2021,
      'https://www.who.int/news-room/fact-sheets/detail/cardiovascular-diseases-(cvds)');
  static const _whoMhgap = FirstAidSource('WHO mhGAP Intervention Guide 2.0: Epilepsy / seizures', 2016);
  static const _whoEpilepsy = FirstAidSource('WHO fact sheet: Epilepsy', 2024, 'https://www.who.int/news-room/fact-sheets/detail/epilepsy');
  static const _whoAsthma = FirstAidSource('WHO fact sheet: Asthma', 2024, 'https://www.who.int/news-room/fact-sheets/detail/asthma');
  static const _whoImci = FirstAidSource('WHO Integrated Management of Childhood Illness (IMCI): Chart booklet', 2014);
  static const _whoPcpnc = FirstAidSource('WHO Pregnancy, childbirth, postpartum and newborn care: a guide for essential practice, 3rd edition', 2015);
  static const _whoBec = FirstAidSource('WHO/ICRC Basic Emergency Care: approach to the acutely ill and injured', 2018);
  static const _whoHeat = FirstAidSource('WHO fact sheet: Heat and health', 2024,
      'https://www.who.int/news-room/fact-sheets/detail/climate-change-heat-and-health');

  static const guides = <FirstAidGuide>[
    FirstAidGuide(
      kindId: 'snake',
      intro: 'Every snake bite needs a hospital, even if there is no pain or swelling. Antivenom is the only treatment.',
      callNowIf: [
        'Always. Call 108 or go to the nearest hospital now.',
        'Faster if: eyelids drooping, trouble swallowing or breathing, bleeding from gums or the bite, or very sleepy.',
      ],
      dos: [
        'Move away from the snake, calmly.',
        'Keep the person calm and as still as possible. Moving spreads the venom faster.',
        'Take off rings, bangles, anklets, watches and tight clothes near the bite, before swelling starts.',
        'Keep the bitten arm or leg still, like with a splint, and at the level of the heart.',
        'Take the person to hospital as fast as possible. Carry them if you can; do not let them walk or run.',
        'Note the time of the bite and tell the doctor about any new signs on the way.',
      ],
      donts: [
        'Do not tie a tight cloth, rope or band (tourniquet) around the limb.',
        'Do not cut the bite or try to suck out the venom.',
        'Do not put ice, herbs, chemicals, or any traditional remedy on the bite.',
        'Do not go to a traditional healer. It wastes time the person does not have.',
        'Do not try to catch or kill the snake. Only take a photo if it is completely safe.',
        'Do not give any medicine, painkiller or alcohol on your own.',
      ],
      sources: [_whoSnake, _whoSearoSnake],
    ),
    FirstAidGuide(
      kindId: 'animalbite',
      intro: 'Bites and scratches from dogs, cats, monkeys and other animals can cause rabies, which can be prevented with vaccine but is deadly once signs start.',
      callNowIf: [
        'The bite is deep, bleeding a lot, or on the face, head, neck or hands.',
        'Go to a hospital the same day for every bite or scratch that breaks the skin, and for licks on broken skin.',
      ],
      dos: [
        'Wash the wound straight away with soap and plenty of running water for about 15 minutes.',
        'After washing, put on an antiseptic such as povidone-iodine if you have it.',
        'Go to a hospital or health centre the same day for the anti-rabies vaccine.',
        'Tell the doctor which animal it was and whether it has been vaccinated.',
        'Take every vaccine dose on the dates the doctor gives you.',
      ],
      donts: [
        'Do not wait to see if the animal falls sick before getting the vaccine.',
        'Do not skip the vaccine because the bite looks small.',
        'Do not put anything else on the wound (chilli, turmeric, oil, powders).',
      ],
      sources: [_whoRabies],
    ),
    FirstAidGuide(
      kindId: 'burn',
      callNowIf: [
        'The burn is large, deep, or on the face, hands, feet, private parts or joints.',
        'It was caused by electricity or a chemical, or the person breathed in smoke.',
        'The person is a small child or an older person.',
      ],
      dos: [
        'Make sure you are safe first. Switch off electricity or gas before touching the person.',
        'Stop the burning: if clothes are on fire, stop, drop and roll, or cover with a blanket.',
        'Remove clothes and jewellery near the burn, unless they are stuck to the skin.',
        'Cool the burn with cool (not cold) running water as soon as possible.',
        'Cover the burn loosely with a clean cloth or clean plastic wrap.',
        'Keep the person warm and take them to a hospital.',
      ],
      donts: [
        'Do not put paste, oil, haldi (turmeric), toothpaste or raw cotton on the burn.',
        'Do not put ice on the burn. It makes the injury deeper.',
        'Do not keep cooling for too long, especially in children. The body can get too cold.',
        'Do not break blisters.',
        'Do not put any cream or medicine on the burn until a health worker sees it.',
      ],
      sources: [_whoBurns],
    ),
    FirstAidGuide(
      kindId: 'heart',
      signs: [
        'Pain or pressure in the centre of the chest.',
        'Pain in the arms, left shoulder, elbows, jaw or back.',
        'Breathlessness, feeling sick or vomiting, dizziness, cold sweat, looking pale.',
        'Women more often have breathlessness, sickness, and back or jaw pain.',
      ],
      callNowIf: ['Any of these signs. Call 108 now. Every minute counts.'],
      dos: [
        'Stop all activity. Sit down and rest in a comfortable position.',
        'Loosen tight clothes.',
        'If the person has chest-pain medicine prescribed by their doctor, help them take it as prescribed.',
        'If the person collapses and is not breathing normally, start CPR if you know how, and keep going until help arrives.',
      ],
      donts: [
        'Do not let the person drive themselves to hospital.',
        'Do not wait to see if the pain goes away.',
        'Do not give food, drink or any medicine that was not prescribed.',
      ],
      sources: [_whoCvd, _whoBec],
    ),
    FirstAidGuide(
      kindId: 'stroke',
      signs: [
        'Sudden weakness or numbness of the face, arm or leg, most often on one side.',
        'Face drooping, trouble speaking or understanding.',
        'Sudden trouble seeing, walking, dizziness or loss of balance.',
        'Sudden very bad headache, fainting.',
      ],
      callNowIf: ['Any of these signs, even if they go away. Call 108 now. Treatment works best in the first hours.'],
      dos: [
        'Note the exact time the signs started, and tell the doctor.',
        'Go to a hospital that can do a brain scan, as fast as possible.',
        'If the person is drowsy or vomiting, lay them on their side.',
      ],
      donts: [
        'Do not give food, water or medicine. Swallowing may not be safe.',
        'Do not wait for the signs to pass or let the person "sleep it off".',
      ],
      sources: [_whoCvd],
    ),
    FirstAidGuide(
      kindId: 'fits',
      callNowIf: [
        'The fit lasts more than 5 minutes, or another fit starts before the person wakes up.',
        'It is the person\'s first fit, they are pregnant, injured, in water, or have trouble breathing afterwards.',
      ],
      dos: [
        'Stay calm and note the time the fit started.',
        'Move hard or sharp things away. Put something soft under the head.',
        'Loosen tight clothes around the neck.',
        'When the jerking stops, turn the person onto their side so they can breathe.',
        'Stay with them until they are fully awake.',
      ],
      donts: [
        'Do not put anything in the mouth: no spoon, cloth, fingers or water.',
        'Do not hold the person down or try to stop the movements.',
        'Do not give food, drink or medicine until the person is fully awake.',
      ],
      sources: [_whoMhgap, _whoEpilepsy],
    ),
    FirstAidGuide(
      kindId: 'breathing',
      callNowIf: [
        'The person cannot speak in full sentences, or is fighting for breath.',
        'Lips or fingernails turn blue or grey.',
        'The reliever inhaler does not help, or the person is very drowsy or confused.',
      ],
      dos: [
        'Help the person sit upright and stay calm.',
        'If they have a reliever inhaler, help them use it as their doctor prescribed (with a spacer if they have one).',
        'Move them away from smoke, dust or whatever set it off.',
        'Loosen tight clothes.',
      ],
      donts: [
        'Do not make the person lie flat.',
        'Do not give medicines that were not prescribed for them.',
      ],
      sources: [_whoAsthma],
      sourceToConfirm: true,
    ),
    FirstAidGuide(
      kindId: 'accident',
      callNowIf: [
        'Heavy bleeding, a head injury, or the person is not fully awake.',
        'Possible broken bones, or neck or back pain after a fall or road accident.',
      ],
      dos: [
        'Make the place safe first: watch for traffic, fire or falling objects.',
        'Call 108.',
        'Press firmly on a bleeding wound with a clean cloth, and keep pressing.',
        'If the neck or back may be hurt, keep the head and body still.',
        'Keep the person warm and talk to them calmly.',
        'If the person is not awake but breathing, and there is no neck or back injury, turn them onto their side.',
      ],
      donts: [
        'Do not move the person unless they are in danger where they are.',
        'Do not pull out objects stuck in a wound. Press around them instead.',
        'Do not give food or drink.',
      ],
      sources: [_whoBec],
    ),
    FirstAidGuide(
      kindId: 'child',
      intro: 'These are danger signs in a child. A child with any one of them needs a hospital now.',
      callNowIf: [
        'Not able to drink or breastfeed.',
        'Vomits everything.',
        'Has had fits.',
        'Very sleepy or hard to wake.',
        'Breathing fast or with difficulty, or the chest pulls in with each breath.',
        'A baby under 2 months with fever, or a body that feels cold.',
      ],
      dos: [
        'Go to the nearest hospital now.',
        'On the way, keep breastfeeding or giving small sips of fluid, if the child can drink.',
        'Keep a small baby warm, skin to skin with the mother if possible.',
        'Take the child\'s vaccine card and any medicines they are taking.',
      ],
      donts: [
        'Do not wait until morning or to see if it gets better.',
        'Do not give medicines on your own.',
        'Do not lose time with home remedies.',
      ],
      sources: [_whoImci],
    ),
    FirstAidGuide(
      kindId: 'pregnancy',
      intro: 'These are danger signs in pregnancy. Any one of them needs a hospital now.',
      callNowIf: [
        'Any bleeding from the vagina.',
        'Fits.',
        'Very bad headache with blurred vision.',
        'Fever, and too weak to get out of bed.',
        'Very bad pain in the stomach.',
        'Fast or difficult breathing.',
      ],
      dos: [
        'Go to the hospital now. Take someone with you.',
        'Take your pregnancy card or reports.',
        'While waiting for transport, lie on your left side.',
      ],
      donts: [
        'Do not wait until morning.',
        'Do not take any medicine or home remedy on your own.',
      ],
      sources: [_whoPcpnc],
    ),
    FirstAidGuide(
      kindId: 'heat',
      signs: ['Very hot body, confusion, fainting, fits, or very hot and dry or very sweaty skin, after time in the heat.'],
      callNowIf: ['The person is confused, faints, has fits, or their body stays very hot. This is heat stroke: call 108.'],
      dos: [
        'Move the person to a cool, shaded place.',
        'Remove extra clothes.',
        'Cool the body: wet the skin with cool water, use wet cloths and fan them.',
        'If they are awake and can swallow, give small sips of water.',
      ],
      donts: [
        'Do not give drinks to a person who is not fully awake.',
        'Do not leave the person alone.',
      ],
      sources: [_whoHeat],
    ),
    FirstAidGuide(
      kindId: 'poison',
      callNowIf: [
        'Always, for anything swallowed that could be poison, including pesticides, kerosene, cleaning liquids or too many tablets.',
        'Faster if the person is drowsy, has fits, or has trouble breathing.',
      ],
      dos: [
        'Call 108 or go to the nearest hospital now.',
        'Take the container, bottle, packet or tablet strip with you.',
        'If poison is on the skin, remove the clothes and wash the skin with plenty of water.',
        'If it is a gas or fumes, move the person to fresh air.',
      ],
      donts: [
        'Do not make the person vomit.',
        'Do not give salt water, milk, oil or anything by mouth unless a doctor says so.',
        'Do not wait for signs to appear.',
      ],
      sources: [_whoBec],
      sourceToConfirm: true,
    ),
    FirstAidGuide(
      kindId: 'eye',
      callNowIf: [
        'A chemical went into the eye, something is stuck in the eye, or sight suddenly gets worse.',
      ],
      dos: [
        'For a chemical: rinse the eye straight away with plenty of clean running water for at least 15 minutes, holding the eye open.',
        'Remove contact lenses if the person wears them.',
        'For something stuck in the eye: cover it lightly with a clean cup or pad, without pressing.',
        'Go to an eye hospital or emergency now.',
      ],
      donts: [
        'Do not rub the eye.',
        'Do not try to pull out anything stuck in the eye.',
        'Do not put drops, ghee, milk or any home remedy in the eye.',
      ],
      sources: [_whoBec],
      sourceToConfirm: true,
    ),
  ];
}
