enum JiguMood { loved, joyful, missing, peaceful, needingHug, angry, misunderstood, sad }

extension JiguMoodDetails on JiguMood {
  String get title => switch (this) {
    JiguMood.loved => 'Loved',
    JiguMood.joyful => 'Happy',
    JiguMood.missing => 'Missing you',
    JiguMood.peaceful => 'Calm',
    JiguMood.needingHug => 'Need a hug',
    JiguMood.angry => 'Angry',
    JiguMood.misunderstood => 'Misunderstood',
    JiguMood.sad => 'Sad',
  };
}

// Original Jigu lines. Each mood has 13 subjects and 4 endings: 260 unique lines.
const _subjects = <JiguMood, List<String>>{
  JiguMood.loved: [
    'Your smile', 'The way you listen', 'Our quiet mornings',
    'Your hand in mine', 'The little things you remember',
    'Our familiar hello', 'The kindness in your voice',
    'The home we make', 'Your sleepy laughter',
    'Every ordinary day with you', 'Our shared secrets',
    'The warmth of your hello', 'The way we find each other',
  ],
  JiguMood.joyful: [
    'Our silly jokes', 'That grin across the room', 'A walk with you',
    'Our dancing in the kitchen', 'A new little adventure',
    'The sound of us laughing', 'A surprise from you',
    'Our favorite song', 'A sunny afternoon together',
    'The smallest good news', 'A spontaneous detour',
    'Our midnight conversations', 'The next thing we dream up',
  ],
  JiguMood.missing: [
    'The thought of your hand', 'The memory of your smile',
    'A message from you', 'Our next hello', 'The space beside me',
    'The sound of your voice', 'A photo of us', 'Our favorite corner',
    'The road back to you', 'The countdown to our hug',
    'A familiar song', 'The little things you say', 'A place we have been',
  ],
  JiguMood.peaceful: [
    'A slow morning with you', 'The calm in your voice',
    'Our comfortable silence', 'A gentle walk together',
    'The way we sit close', 'Our unhurried evenings',
    'The rain outside our window', 'A quiet cup of tea',
    'The sky above us', 'A simple goodnight',
    'Our little routines', 'The soft light at home', 'A deep breath beside you',
  ],
  JiguMood.needingHug: [
    'Your gentle hug', 'A little reassurance from you',
    'The thought of us', 'Your steady presence',
    'A kind word from you', 'A moment to rest together',
    'Your hand on my shoulder', 'The promise of our next hug',
    'A soft hello from you', 'The feeling of being understood',
    'Our safe little world', 'A quiet moment in your arms',
    'The way you stay close',
  ],
  JiguMood.angry: [
    'A little room to breathe', 'An honest pause', 'A softer conversation',
    'The chance to start again', 'A moment without pressure',
    'The courage to say what hurts', 'A walk to clear my head',
    'A quiet reset', 'A kind response', 'The time to find my words',
    'A patient heart', 'A calmer tomorrow', 'The space to be heard',
  ],
  JiguMood.misunderstood: [
    'A chance to explain', 'Being heard all the way through',
    'A gentle question', 'The words I am still finding',
    'A little patience', 'The feeling behind my silence',
    'A conversation without rushing', 'The part I could not say',
    'A safe place to be honest', 'A moment of real listening',
    'The courage to try again', 'A softer way to meet',
    'The hope of being understood',
  ],
  JiguMood.sad: [
    'A gentle day', 'A small bit of comfort', 'The promise of a new morning',
    'A quiet place to rest', 'One soft breath', 'A little kindness',
    'The warmth of a familiar voice', 'A moment to feel it all',
    'A tender memory', 'A hand to hold', 'The room to be myself',
    'A slower pace', 'The thought of being close',
  ],
};

const _endings = <JiguMood, List<String>>{
  JiguMood.loved: [
    'makes today feel a little more like home.',
    'is a small reminder of how lucky we are.',
    'turns an ordinary moment into ours.',
    'is one of my favorite parts of loving you.',
  ],
  JiguMood.joyful: [
    'makes this day worth keeping.',
    'is my favorite kind of sunshine.',
    'gives us another story to smile about.',
    'reminds me how fun being us can be.',
  ],
  JiguMood.missing: [
    'makes the distance feel a little softer.',
    'keeps me close to you from here.',
    'is a promise that we will meet again.',
    'holds a little piece of you beside me.',
  ],
  JiguMood.peaceful: [
    'is enough for this moment.',
    'lets the whole day exhale.',
    'feels like a place where we can just be.',
    'makes our little world feel gentle.',
  ],
  JiguMood.needingHug: [
    'would make this day feel easier.',
    'reminds me I do not have to carry everything alone.',
    'feels like a soft place to land.',
    'is exactly the comfort my heart remembers.',
  ],
  JiguMood.angry: [
    'can help us find our way back to each other.',
    'is okay to need right now.',
    'might make the next words kinder.',
    'gives this feeling somewhere gentle to go.',
  ],
  JiguMood.misunderstood: [
    'could bring us a little closer.',
    'is worth making space for.',
    'might help my heart feel seen.',
    'can turn a hard moment into understanding.',
  ],
  JiguMood.sad: [
    'is enough to ask for today.',
    'makes this heavy moment a little lighter.',
    'can meet me exactly where I am.',
    'reminds me that feelings can move and change.',
  ],
};

List<String> quotesForMood(JiguMood mood) => [
  for (final subject in _subjects[mood]!)
    for (final ending in _endings[mood]!) '$subject $ending',
];

String quoteForDay(JiguMood mood, DateTime day, {int variation = 0}) {
  final quotes = quotesForMood(mood);
  final dayNumber = day.year * 372 + day.month * 31 + day.day;
  return quotes[(dayNumber * 17 + mood.index * 29 + variation * 13) % quotes.length];
}
