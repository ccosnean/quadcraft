part of 'l10n.dart';

/// Chrome for the generated part of the ladder.
///
/// Generated levels have no authored name or brief to translate, so the UI
/// renders them from structure instead: a depth number, the band it belongs
/// to, and a line chosen by [LevelTheme]. That keeps an endless mode fully
/// localized without an endless string table.
class DiveCopy {
  const DiveCopy({
    required this.depthLabel,
    required this.deepest,
    required this.collection,
    required this.seedLabel,
    required this.seedHint,
    required this.seedRandom,
    required this.seedDefault,
    required this.seedBody,
    required this.diveLocked,
    required this.nextDepth,
    required this.deepestYet,
    required this.newFind,
    required this.freeExplorer,
    required this.freeExplorerNote,
    required this.builtCount,
    required this.clearedThisRun,
    required this.sharedLevel,
    required this.playShared,
    required this.shareCodeHint,
    required this.shareCodeBad,
    required this.scanToPlay,
    required this.movesToBeat,
    required this.goDeeperHint,
    required this.useKey,
    required this.outOfKeys,
    required this.openedWithKey,
    required this.keyWon,
    required this.beatenIt,
    required this.sharedNotCounted,
    required this.diveThisSeed,
    required this.diveThisSeedBody,
    required this.strata,
    required this.themes,
  });

  /// Uses `{n}`.
  final String depthLabel;
  final String deepest;
  final String collection;
  final String seedLabel;
  final String seedHint;
  final String seedRandom;
  final String seedDefault;

  /// Warns that changing the seed regrows every generated level.
  final String seedBody;
  final String diveLocked;
  final String nextDepth;
  final String deepestYet;
  final String newFind;

  /// Earned by clearing a hundred depths: the ladder stops deciding
  /// what comes next.
  final String freeExplorer;
  final String freeExplorerNote;

  /// Uses `{n}`.
  final String builtCount;

  /// Uses `{n}`.
  final String clearedThisRun;

  /// A level opened from somebody else's code rather than off your ladder.
  final String sharedLevel;
  final String playShared;
  final String shareCodeHint;
  final String shareCodeBad;
  final String scanToPlay;

  /// The sharer's score, printed on a challenge. Uses `{n}`.
  final String movesToBeat;

  /// Shown when a depth that has not been reached yet is tapped.
  final String goDeeperHint;

  /// The offer on that same message, while there is a key left to spend.
  final String useKey;
  final String outOfKeys;
  final String openedWithKey;

  /// Called out on the win sheet on every tenth clear.
  final String keyWon;

  /// Badge for beating that score.
  final String beatenIt;

  /// Why a cleared challenge left no record.
  final String sharedNotCounted;
  final String diveThisSeed;

  /// Warns that adopting a seed restarts the run.
  final String diveThisSeedBody;

  /// Six band names, cycled with a numeral past the sixth.
  final List<String> strata;

  final Map<LevelTheme, String> themes;
}

const kDiveEn = DiveCopy(
  depthLabel: 'Level {n}',
  deepest: 'Furthest',
  collection: 'Collection',
  seedLabel: 'Seed',
  seedHint: 'Leave empty for a random seed',
  seedRandom: 'Random',
  seedDefault: 'Back to mine',
  seedBody:
      'Every level past the tutorial grows from this seed. Yours was drawn '
      "for this device — take a friend's to climb the ladder they are on. "
      'Changing it regrows the lot: your collection is kept, your scores are '
      'not.',
  diveLocked: 'Finish the tutorial to open the generated levels.',
  nextDepth: 'Next level',
  deepestYet: 'Furthest yet',
  newFind: 'New find',
  freeExplorer: 'Free explorer',
  freeExplorerNote: 'The whole dive is open. Go anywhere.',
  builtCount: '{n} built',
  clearedThisRun: '{n} cleared on this seed',
  sharedLevel: 'Shared level',
  playShared: 'Play a shared level',
  shareCodeHint: 'Paste a code or link',
  shareCodeBad: 'That is not a Quadcraft code.',
  scanToPlay: 'Scan to play this level',
  movesToBeat: 'To beat: {n} moves',
  goDeeperHint: 'Finish the levels above it to go deeper.',
  useKey: 'Use key',
  outOfKeys: 'Out of keys. Three more tomorrow.',
  openedWithKey: 'Opened with a key.',
  keyWon: 'Key won',
  beatenIt: 'Beaten',
  sharedNotCounted: 'Shared levels do not count toward your own progress.',
  diveThisSeed: 'Play this seed',
  diveThisSeedBody:
      'Start a fresh run on this seed. The ladder is regrown from it: your '
      'collection is kept, your scores are not.',
  strata: [
    'The Shallows',
    'Brass Terrace',
    'The Kiln',
    'Verdigris',
    'The Deep Loom',
    'Starfall',
  ],
  themes: {
    LevelTheme.open: 'A bare plate. Everything here starts in the tray.',
    LevelTheme.wash:
        'One weather for all of it. Build it raw, then let the colour fall.',
    LevelTheme.relic:
        'What is already here is already right. Save it before you paint.',
    LevelTheme.shell:
        'The coat is on the plate; the lining is not. Build inward, then '
        'slide the coat under.',
    LevelTheme.nested: 'Deep corners. Dress each one from the inside out.',
    LevelTheme.spectrum:
        'More than one weather. Every colour wants its own trip.',
  },
);

const kDiveZh = DiveCopy(
  depthLabel: '第 {n} 关',
  deepest: '最远',
  collection: '收藏',
  seedLabel: '种子',
  seedHint: '留空则随机生成种子',
  seedRandom: '随机',
  seedDefault: '回到我的种子',
  seedBody:
      '教学之后的每一关都由这颗种子生成。你的种子是这台设备专属的——换上朋友的，'
      '就能爬同一条阶梯。更换种子会重新生成一切：收藏会保留，成绩不会。',
  diveLocked: '完成教学后开启生成关卡。',
  nextDepth: '下一关',
  deepestYet: '最远纪录',
  newFind: '新发现',
  freeExplorer: '自由探索者',
  freeExplorerNote: '整个深渊已开放，随意探索。',
  builtCount: '已造 {n} 个',
  clearedThisRun: '本种子已通过 {n} 层',
  sharedLevel: '共享关卡',
  playShared: '玩共享关卡',
  shareCodeHint: '粘贴代码或链接',
  shareCodeBad: '这不是 Quadcraft 代码。',
  scanToPlay: '扫码即玩这一关',
  movesToBeat: '需超越：{n} 步',
  goDeeperHint: '先完成上面的关卡，才能继续下潜。',
  useKey: '使用钥匙',
  outOfKeys: '钥匙用完了，明天再拿三把。',
  openedWithKey: '已用钥匙开启。',
  keyWon: '获得钥匙',
  beatenIt: '已超越',
  sharedNotCounted: '共享关卡不计入你自己的进度。',
  diveThisSeed: '玩这颗种子',
  diveThisSeedBody: '用这颗种子开始新的一轮。阶梯会由它重新生成：收藏会保留，成绩不会。',
  strata: ['浅滩', '黄铜台地', '窑火', '铜绿', '深织机', '星落'],
  themes: {
    LevelTheme.open: '空盘一块。这里的一切都从托盘开始。',
    LevelTheme.wash: '整块一种天色。先素坯搭好，再让颜色落下。',
    LevelTheme.relic: '盘上已有的正是对的。上色之前先把它收好。',
    LevelTheme.shell: '外衣已在盘上，内衬还没有。先由内造起，再把外衣塞到底下。',
    LevelTheme.nested: '角落很深。每一个都要从里往外穿。',
    LevelTheme.spectrum: '不止一种天色。每种颜色都得单独跑一趟。',
  },
);

const kDiveHi = DiveCopy(
  depthLabel: 'स्तर {n}',
  deepest: 'सबसे दूर',
  collection: 'संग्रह',
  seedLabel: 'बीज',
  seedHint: 'खाली छोड़ें तो बीज अपने आप चुना जाएगा',
  seedRandom: 'यादृच्छिक',
  seedDefault: 'मेरे बीज पर लौटें',
  seedBody:
      'ट्यूटोरियल के बाद हर स्तर इसी बीज से बनता है। आपका बीज इसी डिवाइस के '
      'लिए चुना गया — दोस्त का बीज डालें और उसी सीढ़ी पर चढ़ें। बदलने पर सब '
      'दोबारा बनता है: संग्रह बचा रहेगा, अंक नहीं।',
  diveLocked: 'बनाए गए स्तर खोलने के लिए ट्यूटोरियल पूरा करें।',
  nextDepth: 'अगला स्तर',
  deepestYet: 'अब तक सबसे दूर',
  newFind: 'नई खोज',
  freeExplorer: 'स्वतंत्र खोजी',
  freeExplorerNote: 'पूरी गहराई खुल गई। कहीं भी जाएँ।',
  builtCount: '{n} बनाए',
  clearedThisRun: 'इस बीज पर {n} पूरे',
  sharedLevel: 'साझा स्तर',
  playShared: 'साझा स्तर खेलें',
  shareCodeHint: 'कोड या लिंक चिपकाएँ',
  shareCodeBad: 'यह Quadcraft कोड नहीं है।',
  scanToPlay: 'यही स्तर खेलने के लिए स्कैन करें',
  movesToBeat: 'लक्ष्य: {n} चाल',
  goDeeperHint: 'और गहरे जाने के लिए ऊपर के स्तर पूरे करें।',
  useKey: 'चाबी उपयोग करें',
  outOfKeys: 'चाबियाँ खत्म। कल तीन और मिलेंगी।',
  openedWithKey: 'चाबी से खोला गया।',
  keyWon: 'चाबी मिली',
  beatenIt: 'पीछे छोड़ा',
  sharedNotCounted: 'साझा स्तर आपकी अपनी प्रगति में नहीं गिने जाते।',
  diveThisSeed: 'इस बीज पर खेलें',
  diveThisSeedBody:
      'इसी बीज से नई शुरुआत करें। सीढ़ी दोबारा बनेगी: संग्रह बचा रहेगा, '
      'अंक नहीं।',
  strata: ['उथला जल', 'पीतल की छत', 'भट्ठी', 'जंगाल', 'गहरा करघा', 'तारापात'],
  themes: {
    LevelTheme.open: 'खाली थाली। यहाँ सब कुछ ट्रे से शुरू होता है।',
    LevelTheme.wash: 'सब पर एक ही मौसम। पहले कच्चा खड़ा करो, फिर रंग गिरने दो।',
    LevelTheme.relic: 'जो पहले से है वह सही है। रंगने से पहले उसे बचा लो।',
    LevelTheme.shell:
        'कोट थाली पर है, अस्तर नहीं। भीतर से बनाओ, फिर कोट नीचे सरकाओ।',
    LevelTheme.nested: 'गहरे कोने। हर एक को भीतर से बाहर की ओर पहनाओ।',
    LevelTheme.spectrum: 'एक से ज़्यादा मौसम। हर रंग को अपनी अलग फेरी चाहिए।',
  },
);

const kDiveEs = DiveCopy(
  depthLabel: 'Nivel {n}',
  deepest: 'Más lejos',
  collection: 'Colección',
  seedLabel: 'Semilla',
  seedHint: 'Déjalo vacío para una semilla al azar',
  seedRandom: 'Aleatoria',
  seedDefault: 'Volver a la mía',
  seedBody:
      'Cada nivel posterior al tutorial nace de esta semilla. La tuya se sorteó '
      'para este dispositivo: usa la de un amigo para subir su misma escalera. '
      'Cambiarla lo regenera todo: la colección se conserva; tus marcas no.',
  diveLocked: 'Termina el tutorial para abrir los niveles generados.',
  nextDepth: 'Siguiente',
  deepestYet: 'Tu récord',
  newFind: 'Hallazgo',
  freeExplorer: 'Explorador libre',
  freeExplorerNote: 'Todo el descenso está abierto. Ve donde quieras.',
  builtCount: '{n} construidas',
  clearedThisRun: '{n} superadas con esta semilla',
  sharedLevel: 'Nivel compartido',
  playShared: 'Jugar un nivel compartido',
  shareCodeHint: 'Pega un código o un enlace',
  shareCodeBad: 'Ese no es un código de Quadcraft.',
  scanToPlay: 'Escanea para jugar este nivel',
  movesToBeat: 'A batir: {n} movimientos',
  goDeeperHint: 'Termina los niveles anteriores para bajar más.',
  useKey: 'Usar llave',
  outOfKeys: 'Sin llaves. Mañana habrá tres más.',
  openedWithKey: 'Abierto con una llave.',
  keyWon: 'Llave ganada',
  beatenIt: 'Superado',
  sharedNotCounted:
      'Los niveles compartidos no cuentan para tu propio progreso.',
  diveThisSeed: 'Jugar esta semilla',
  diveThisSeedBody:
      'Empieza una tirada nueva con esta semilla. La escalera se regenera: '
      'la colección se conserva; tus marcas no.',
  strata: [
    'Los Bajíos',
    'Terraza de Latón',
    'El Horno',
    'Cardenillo',
    'El Telar Hondo',
    'Lluvia de Estrellas',
  ],
  themes: {
    LevelTheme.open: 'Plato desnudo. Aquí todo empieza en la bandeja.',
    LevelTheme.wash:
        'Un solo clima para todo. Levántalo en crudo y deja caer el color.',
    LevelTheme.relic:
        'Lo que ya está aquí ya está bien. Guárdalo antes de pintar.',
    LevelTheme.shell:
        'El abrigo está en el plato; el forro no. Construye hacia dentro y '
        'desliza el abrigo debajo.',
    LevelTheme.nested: 'Esquinas hondas. Viste cada una de dentro afuera.',
    LevelTheme.spectrum: 'Más de un clima. Cada color quiere su propio viaje.',
  },
);

const kDiveAr = DiveCopy(
  depthLabel: 'المستوى {n}',
  deepest: 'الأبعد',
  collection: 'المجموعة',
  seedLabel: 'البذرة',
  seedHint: 'اتركه فارغًا لبذرة عشوائية',
  seedRandom: 'عشوائية',
  seedDefault: 'العودة إلى بذرتي',
  seedBody:
      'كل مستوى بعد الدرس التمهيدي ينبت من هذه البذرة. بذرتك سُحبت لهذا الجهاز '
      'وحده — خذ بذرة صديق لتصعد سلّمه نفسه. تغييرها يعيد بناء كل شيء: '
      'مجموعتك تبقى، أما نتائجك فلا.',
  diveLocked: 'أنهِ الدرس التمهيدي لفتح المستويات المولَّدة.',
  nextDepth: 'المستوى التالي',
  deepestYet: 'أبعد ما وصلت',
  newFind: 'اكتشاف جديد',
  freeExplorer: 'مستكشف حر',
  freeExplorerNote: 'الغوص كله مفتوح. اذهب أينما شئت.',
  builtCount: '{n} مبنية',
  clearedThisRun: '{n} بهذه البذرة',
  sharedLevel: 'مستوى مشترك',
  playShared: 'العب مستوى مشتركًا',
  shareCodeHint: 'الصق رمزًا أو رابطًا',
  shareCodeBad: 'هذا ليس رمز Quadcraft.',
  scanToPlay: 'امسح الرمز للعب هذا المستوى',
  movesToBeat: 'المطلوب تجاوزه: {n} حركة',
  goDeeperHint: 'أكمل المستويات السابقة لتغوص أعمق.',
  useKey: 'استخدم مفتاحًا',
  outOfKeys: 'نفدت المفاتيح. ثلاثة أخرى غدًا.',
  openedWithKey: 'فُتح بمفتاح.',
  keyWon: 'ربحت مفتاحًا',
  beatenIt: 'تم تجاوزه',
  sharedNotCounted: 'المستويات المشتركة لا تُحتسب في تقدّمك.',
  diveThisSeed: 'العب بهذه البذرة',
  diveThisSeedBody:
      'ابدأ جولة جديدة بهذه البذرة. يُعاد بناء السلّم منها: مجموعتك تبقى، '
      'أما نتائجك فلا.',
  strata: [
    'المياه الضحلة',
    'شرفة النحاس',
    'الأتون',
    'الزنجار',
    'النول العميق',
    'سقوط النجوم',
  ],
  themes: {
    LevelTheme.open: 'صحن خالٍ. كل شيء هنا يبدأ من الدرج.',
    LevelTheme.wash: 'طقس واحد للجميع. ابنِه خامًا ثم دع اللون يهبط.',
    LevelTheme.relic: 'ما هو موجود صحيح كما هو. احفظه قبل أن تطلي.',
    LevelTheme.shell:
        'المعطف على الصحن والبطانة ليست. ابنِ من الداخل ثم أدخل المعطف تحته.',
    LevelTheme.nested: 'زوايا عميقة. ألبس كل واحدة من الداخل إلى الخارج.',
    LevelTheme.spectrum: 'أكثر من طقس. كل لون يريد رحلته الخاصة.',
  },
);

const kDivePt = DiveCopy(
  depthLabel: 'Nível {n}',
  deepest: 'Mais longe',
  collection: 'Coleção',
  seedLabel: 'Semente',
  seedHint: 'Deixe vazio para uma semente aleatória',
  seedRandom: 'Aleatória',
  seedDefault: 'Voltar à minha',
  seedBody:
      'Cada nível depois do tutorial nasce desta semente. A sua foi sorteada '
      'para este aparelho — use a de um amigo para subir a mesma escada. '
      'Trocá-la refaz tudo: a coleção fica; suas marcas não.',
  diveLocked: 'Termine o tutorial para abrir os níveis gerados.',
  nextDepth: 'Próximo',
  deepestYet: 'Seu recorde',
  newFind: 'Achado novo',
  freeExplorer: 'Explorador livre',
  freeExplorerNote: 'Todo o mergulho está aberto. Vá aonde quiser.',
  builtCount: '{n} construídas',
  clearedThisRun: '{n} com esta semente',
  sharedLevel: 'Nível compartilhado',
  playShared: 'Jogar um nível compartilhado',
  shareCodeHint: 'Cole um código ou um link',
  shareCodeBad: 'Esse não é um código do Quadcraft.',
  scanToPlay: 'Escaneie para jogar este nível',
  movesToBeat: 'A bater: {n} movimentos',
  goDeeperHint: 'Termine os níveis anteriores para descer mais.',
  useKey: 'Usar chave',
  outOfKeys: 'Sem chaves. Mais três amanhã.',
  openedWithKey: 'Aberto com uma chave.',
  keyWon: 'Chave ganha',
  beatenIt: 'Superado',
  sharedNotCounted: 'Níveis compartilhados não contam para o seu progresso.',
  diveThisSeed: 'Jogar esta semente',
  diveThisSeedBody:
      'Comece uma série nova com esta semente. A escada é refeita a partir '
      'dela: a coleção fica; suas marcas não.',
  strata: [
    'Os Baixios',
    'Terraço de Latão',
    'A Fornalha',
    'Verdete',
    'O Tear Profundo',
    'Chuva de Estrelas',
  ],
  themes: {
    LevelTheme.open: 'Prato vazio. Aqui tudo começa na bandeja.',
    LevelTheme.wash:
        'Um só tempo para tudo. Levante em cru e deixe a cor cair.',
    LevelTheme.relic:
        'O que já está aqui já está certo. Salve antes de pintar.',
    LevelTheme.shell:
        'O casaco está no prato; o forro não. Construa para dentro e deslize '
        'o casaco por baixo.',
    LevelTheme.nested: 'Cantos fundos. Vista cada um de dentro para fora.',
    LevelTheme.spectrum: 'Mais de um tempo. Cada cor quer a própria viagem.',
  },
);

const kDiveFr = DiveCopy(
  depthLabel: 'Niveau {n}',
  deepest: 'Le plus loin',
  collection: 'Collection',
  seedLabel: 'Graine',
  seedHint: 'Laissez vide pour une graine au hasard',
  seedRandom: 'Aléatoire',
  seedDefault: 'Revenir à la mienne',
  seedBody:
      'Chaque niveau après le tutoriel pousse de cette graine. La vôtre a été '
      "tirée pour cet appareil — prenez celle d'un ami pour gravir son échelle. "
      'La changer fait tout repousser : la collection reste, vos scores non.',
  diveLocked: 'Terminez le tutoriel pour ouvrir les niveaux générés.',
  nextDepth: 'Suivant',
  deepestYet: 'Record',
  newFind: 'Trouvaille',
  freeExplorer: 'Explorateur libre',
  freeExplorerNote: 'Toute la plongée est ouverte. Allez où vous voulez.',
  builtCount: '{n} construites',
  clearedThisRun: '{n} avec cette graine',
  sharedLevel: 'Niveau partagé',
  playShared: 'Jouer un niveau partagé',
  shareCodeHint: 'Collez un code ou un lien',
  shareCodeBad: "Ce n'est pas un code Quadcraft.",
  scanToPlay: 'Scannez pour jouer ce niveau',
  movesToBeat: 'À battre : {n} coups',
  goDeeperHint: 'Terminez les niveaux précédents pour descendre plus bas.',
  useKey: 'Utiliser une clé',
  outOfKeys: 'Plus de clés. Trois autres demain.',
  openedWithKey: 'Ouvert avec une clé.',
  keyWon: 'Clé gagnée',
  beatenIt: 'Battu',
  sharedNotCounted:
      'Les niveaux partagés ne comptent pas dans votre progression.',
  diveThisSeed: 'Jouer cette graine',
  diveThisSeedBody:
      'Commencez une nouvelle partie avec cette graine. '
      "L'échelle repousse : la collection reste, vos scores non.",
  strata: [
    'Les Bas-Fonds',
    'Terrasse de Laiton',
    'Le Four',
    'Vert-de-gris',
    'Le Métier Profond',
    'Pluie d\'Étoiles',
  ],
  themes: {
    LevelTheme.open: 'Plateau nu. Ici, tout commence dans le plateau à plans.',
    LevelTheme.wash:
        'Un seul temps pour le tout. Montez-le brut, puis laissez tomber la '
        'couleur.',
    LevelTheme.relic:
        'Ce qui est déjà là est déjà juste. Mettez-le à l\'abri avant de '
        'peindre.',
    LevelTheme.shell:
        'Le manteau est sur le plateau, la doublure non. Bâtissez vers '
        'l\'intérieur, puis glissez le manteau dessous.',
    LevelTheme.nested: 'Coins profonds. Habillez chacun de l\'intérieur.',
    LevelTheme.spectrum: 'Plus d\'un temps. Chaque couleur veut son voyage.',
  },
);

const kDiveId = DiveCopy(
  depthLabel: 'Level {n}',
  deepest: 'Terjauh',
  collection: 'Koleksi',
  seedLabel: 'Benih',
  seedHint: 'Kosongkan untuk benih acak',
  seedRandom: 'Acak',
  seedDefault: 'Kembali ke milikku',
  seedBody:
      'Setiap level setelah tutorial tumbuh dari benih ini. Benih Anda diundi '
      'untuk perangkat ini — pakai benih teman untuk menaiki tangga yang sama. '
      'Menggantinya menumbuhkan ulang semuanya: koleksi tetap, skor tidak.',
  diveLocked: 'Selesaikan tutorial untuk membuka level yang dibuat.',
  nextDepth: 'Level berikutnya',
  deepestYet: 'Rekor terjauh',
  newFind: 'Temuan baru',
  freeExplorer: 'Penjelajah bebas',
  freeExplorerNote: 'Seluruh penyelaman terbuka. Pergilah ke mana saja.',
  builtCount: '{n} dibuat',
  clearedThisRun: '{n} selesai dengan benih ini',
  sharedLevel: 'Level bagikan',
  playShared: 'Mainkan level yang dibagikan',
  shareCodeHint: 'Tempel kode atau tautan',
  shareCodeBad: 'Itu bukan kode Quadcraft.',
  scanToPlay: 'Pindai untuk memainkan level ini',
  movesToBeat: 'Target: {n} langkah',
  goDeeperHint: 'Selesaikan level sebelumnya untuk menyelam lebih dalam.',
  useKey: 'Pakai kunci',
  outOfKeys: 'Kunci habis. Tiga lagi besok.',
  openedWithKey: 'Dibuka dengan kunci.',
  keyWon: 'Dapat kunci',
  beatenIt: 'Terlampaui',
  sharedNotCounted: 'Level yang dibagikan tidak dihitung dalam kemajuan Anda.',
  diveThisSeed: 'Mainkan benih ini',
  diveThisSeedBody:
      'Mulai putaran baru dengan benih ini. Tangga tumbuh ulang darinya: '
      'koleksi tetap, skor tidak.',
  strata: [
    'Perairan Dangkal',
    'Teras Kuningan',
    'Tungku',
    'Karat Hijau',
    'Alat Tenun Dalam',
    'Hujan Bintang',
  ],
  themes: {
    LevelTheme.open: 'Piring kosong. Semua di sini bermula dari baki.',
    LevelTheme.wash:
        'Satu cuaca untuk semuanya. Susun mentah, lalu biarkan warna turun.',
    LevelTheme.relic:
        'Yang sudah ada memang sudah benar. Simpan sebelum Anda mengecat.',
    LevelTheme.shell:
        'Mantelnya sudah di piring, lapisannya belum. Bangun ke dalam, lalu '
        'selipkan mantel di bawahnya.',
    LevelTheme.nested: 'Sudut yang dalam. Pakaikan dari dalam ke luar.',
    LevelTheme.spectrum:
        'Lebih dari satu cuaca. Tiap warna minta perjalanannya sendiri.',
  },
);

const kDiveJa = DiveCopy(
  depthLabel: 'レベル {n}',
  deepest: '最高到達',
  collection: 'コレクション',
  seedLabel: 'シード',
  seedHint: '空欄ならシードはおまかせ',
  seedRandom: 'ランダム',
  seedDefault: '自分の種に戻す',
  seedBody:
      'チュートリアル以降のレベルはすべてこのシードから育ちます。あなたのシードは'
      'この端末のために引かれたもの。友達のシードを入れれば同じ梯子を登れます。'
      '変更するとすべて作り直しになり、コレクションは残りますが記録は残りません。',
  diveLocked: 'チュートリアルを終えると生成レベルが開きます。',
  nextDepth: '次のレベル',
  deepestYet: '自己最高',
  newFind: '新発見',
  freeExplorer: '自由な探検者',
  freeExplorerNote: '潜行のすべてが開かれました。どこへでも。',
  builtCount: '{n} 個',
  clearedThisRun: 'このシードで {n} 層',
  sharedLevel: '共有レベル',
  playShared: '共有レベルで遊ぶ',
  shareCodeHint: 'コードかリンクを貼り付け',
  shareCodeBad: 'Quadcraft のコードではありません。',
  scanToPlay: 'スキャンしてこのレベルで遊ぶ',
  movesToBeat: '目標: {n} 手',
  goDeeperHint: 'さらに深く潜るには、上のレベルをクリアしてください。',
  useKey: '鍵を使う',
  outOfKeys: '鍵がありません。明日また3つ。',
  openedWithKey: '鍵で開きました。',
  keyWon: '鍵を獲得',
  beatenIt: '更新',
  sharedNotCounted: '共有レベルは自分の進行には加算されません。',
  diveThisSeed: 'この種で遊ぶ',
  diveThisSeedBody:
      'このシードで新しく始めます。梯子は作り直しになり、コレクションは'
      '残りますが記録は残りません。',
  strata: ['浅瀬', '真鍮の段', '窯', '緑青', '深き機', '星降り'],
  themes: {
    LevelTheme.open: '素の皿。ここではすべてトレイから始まります。',
    LevelTheme.wash: '全部に同じ天気を。素のまま組んで、あとから色を落とす。',
    LevelTheme.relic: 'すでにあるものは、すでに正しい。塗る前に取り分けて。',
    LevelTheme.shell: '外套は皿の上、裏地はまだ。内から組んで、外套を下に滑り込ませる。',
    LevelTheme.nested: '深い角。どれも内から外へ着せていく。',
    LevelTheme.spectrum: '天気はひとつではない。色ごとに一往復。',
  },
);

const kDiveDe = DiveCopy(
  depthLabel: 'Level {n}',
  deepest: 'Am weitesten',
  collection: 'Sammlung',
  seedLabel: 'Saatwert',
  seedHint: 'Leer lassen für einen zufälligen Saatwert',
  seedRandom: 'Zufällig',
  seedDefault: 'Zurück zu meinem',
  seedBody:
      'Jedes Level nach dem Tutorial wächst aus diesem Saatwert. Deiner wurde '
      'für dieses Gerät gezogen — nimm den eines Freundes, um dieselbe Leiter '
      'zu steigen. Änderst du ihn, wächst alles neu: die Sammlung bleibt, '
      'deine Werte nicht.',
  diveLocked: 'Beende das Tutorial, um die erzeugten Level zu öffnen.',
  nextDepth: 'Nächstes Level',
  deepestYet: 'Neuer Rekord',
  newFind: 'Neuer Fund',
  freeExplorer: 'Freier Entdecker',
  freeExplorerNote: 'Der ganze Tauchgang ist offen. Geh, wohin du willst.',
  builtCount: '{n} gebaut',
  clearedThisRun: '{n} mit diesem Saatwert',
  sharedLevel: 'Geteiltes Level',
  playShared: 'Geteiltes Level spielen',
  shareCodeHint: 'Code oder Link einfügen',
  shareCodeBad: 'Das ist kein Quadcraft-Code.',
  scanToPlay: 'Scannen und dieses Level spielen',
  movesToBeat: 'Zu schlagen: {n} Züge',
  goDeeperHint: 'Schließe die Ebenen darüber ab, um tiefer zu gehen.',
  useKey: 'Schlüssel nutzen',
  outOfKeys: 'Keine Schlüssel mehr. Morgen gibt es drei.',
  openedWithKey: 'Mit einem Schlüssel geöffnet.',
  keyWon: 'Schlüssel erhalten',
  beatenIt: 'Geschlagen',
  sharedNotCounted:
      'Geteilte Level zählen nicht für deinen eigenen Fortschritt.',
  diveThisSeed: 'Diesen Saatwert spielen',
  diveThisSeedBody:
      'Starte einen neuen Lauf mit diesem Saatwert. Die Leiter wächst '
      'daraus neu: die Sammlung bleibt, deine Werte nicht.',
  strata: [
    'Die Untiefen',
    'Messingterrasse',
    'Der Brennofen',
    'Grünspan',
    'Der Tiefe Webstuhl',
    'Sternenfall',
  ],
  themes: {
    LevelTheme.open: 'Blanke Platte. Hier beginnt alles im Tablett.',
    LevelTheme.wash:
        'Ein Wetter für alles. Roh aufbauen, dann die Farbe fallen lassen.',
    LevelTheme.relic:
        'Was schon da ist, ist schon richtig. Rette es, bevor du streichst.',
    LevelTheme.shell:
        'Der Mantel liegt auf der Platte, das Futter nicht. Bau nach innen, '
        'dann schieb den Mantel darunter.',
    LevelTheme.nested: 'Tiefe Ecken. Kleide jede von innen nach außen.',
    LevelTheme.spectrum:
        'Mehr als ein Wetter. Jede Farbe will ihre eigene Fahrt.',
  },
);

const kDiveKo = DiveCopy(
  depthLabel: '레벨 {n}',
  deepest: '최고 도달',
  collection: '수집',
  seedLabel: '시드',
  seedHint: '비워 두면 시드를 무작위로 뽑습니다',
  seedRandom: '무작위',
  seedDefault: '내 시드로',
  seedBody:
      '튜토리얼 이후의 모든 레벨은 이 시드에서 자랍니다. 당신의 시드는 이 기기를 '
      '위해 뽑힌 것 — 친구의 시드를 넣으면 같은 사다리를 오릅니다. 바꾸면 전부 '
      '다시 자라며, 수집은 남지만 기록은 남지 않습니다.',
  diveLocked: '튜토리얼을 끝내면 생성 레벨이 열립니다.',
  nextDepth: '다음 레벨',
  deepestYet: '최고 기록',
  newFind: '새 발견',
  freeExplorer: '자유 탐험가',
  freeExplorerNote: '잠수 전체가 열렸습니다. 어디든 가세요.',
  builtCount: '{n}개 제작',
  clearedThisRun: '이 시드로 {n}층',
  sharedLevel: '공유된 레벨',
  playShared: '공유된 레벨 플레이',
  shareCodeHint: '코드나 링크를 붙여넣기',
  shareCodeBad: 'Quadcraft 코드가 아닙니다.',
  scanToPlay: '스캔해서 이 레벨 플레이',
  movesToBeat: '목표: {n}수',
  goDeeperHint: '더 깊이 내려가려면 위의 단계를 완료하세요.',
  useKey: '열쇠 사용',
  outOfKeys: '열쇠가 없습니다. 내일 세 개 더.',
  openedWithKey: '열쇠로 열었습니다.',
  keyWon: '열쇠 획득',
  beatenIt: '경신',
  sharedNotCounted: '공유된 레벨은 내 진행에 포함되지 않습니다.',
  diveThisSeed: '이 시드로 플레이',
  diveThisSeedBody:
      '이 시드로 새로 시작합니다. 사다리가 다시 자라며, 수집은 남지만 기록은 '
      '남지 않습니다.',
  strata: ['얕은 여울', '황동 단구', '가마', '녹청', '깊은 베틀', '별비'],
  themes: {
    LevelTheme.open: '빈 판. 여기서는 모든 것이 트레이에서 시작합니다.',
    LevelTheme.wash: '전부 한 가지 날씨로. 민무늬로 쌓고 마지막에 색을 내립니다.',
    LevelTheme.relic: '이미 있는 것은 이미 옳습니다. 칠하기 전에 챙기세요.',
    LevelTheme.shell:
        '외투는 판 위에, 안감은 아직입니다. 안쪽부터 짓고 외투를 아래로 밀어 '
        '넣으세요.',
    LevelTheme.nested: '깊은 모서리. 하나하나 안에서 밖으로 입히세요.',
    LevelTheme.spectrum: '날씨가 하나가 아닙니다. 색마다 한 번씩 다녀와야 합니다.',
  },
);

const kDiveRu = DiveCopy(
  depthLabel: 'Уровень {n}',
  deepest: 'Дальше всего',
  collection: 'Коллекция',
  seedLabel: 'Зерно',
  seedHint: 'Оставьте пустым — зерно выберется само',
  seedRandom: 'Случайное',
  seedDefault: 'Вернуться к своему',
  seedBody:
      'Каждый уровень после обучения вырастает из этого зерна. Ваше выпало '
      'именно этому устройству — возьмите зерно друга, чтобы идти по той же '
      'лестнице. Смена зерна выращивает всё заново: коллекция сохранится, '
      'результаты нет.',
  diveLocked: 'Пройдите обучение, чтобы открыть сгенерированные уровни.',
  nextDepth: 'Следующий',
  deepestYet: 'Личный рекорд',
  newFind: 'Новая находка',
  freeExplorer: 'Вольный исследователь',
  freeExplorerNote: 'Всё погружение открыто. Идите куда угодно.',
  builtCount: 'Собрано: {n}',
  clearedThisRun: 'С этим зерном: {n}',
  sharedLevel: 'Присланный уровень',
  playShared: 'Сыграть присланный уровень',
  shareCodeHint: 'Вставьте код или ссылку',
  shareCodeBad: 'Это не код Quadcraft.',
  scanToPlay: 'Отсканируйте, чтобы сыграть',
  movesToBeat: 'Побить: {n} ходов',
  goDeeperHint: 'Пройдите уровни выше, чтобы спуститься глубже.',
  useKey: 'Ключ',
  outOfKeys: 'Ключи кончились. Завтра будет ещё три.',
  openedWithKey: 'Открыто ключом.',
  keyWon: 'Получен ключ',
  beatenIt: 'Побит',
  sharedNotCounted: 'Присланные уровни не идут в зачёт вашего прогресса.',
  diveThisSeed: 'Играть с этим зерном',
  diveThisSeedBody:
      'Начать новый заход с этим зерном. Лестница вырастет заново: '
      'коллекция сохранится, результаты нет.',
  strata: [
    'Отмели',
    'Латунная терраса',
    'Горнило',
    'Патина',
    'Глубокий станок',
    'Звездопад',
  ],
  themes: {
    LevelTheme.open: 'Пустая плита. Здесь всё начинается с лотка.',
    LevelTheme.wash:
        'Одна погода на всё. Соберите вчерне, а цвет пусть выпадет после.',
    LevelTheme.relic:
        'То, что уже здесь, уже верно. Спрячьте это, прежде чем красить.',
    LevelTheme.shell:
        'Пальто на плите, подкладки нет. Стройте внутрь, потом подсуньте '
        'пальто снизу.',
    LevelTheme.nested: 'Глубокие углы. Одевайте каждый изнутри наружу.',
    LevelTheme.spectrum: 'Погода не одна. Каждому цвету — своя ходка.',
  },
);

const kDiveRo = DiveCopy(
  depthLabel: 'Nivelul {n}',
  deepest: 'Cel mai departe',
  collection: 'Colecție',
  seedLabel: 'Sămânță',
  seedHint: 'Lasă gol pentru o sămânță la întâmplare',
  seedRandom: 'Aleatorie',
  seedDefault: 'Înapoi la a mea',
  seedBody:
      'Fiecare nivel de după tutorial crește din această sămânță. A ta a fost '
      'trasă pentru acest dispozitiv — ia-o pe a unui prieten ca să urci pe '
      'aceeași scară. Dacă o schimbi, totul crește din nou: colecția rămâne, '
      'scorurile nu.',
  diveLocked: 'Termină tutorialul ca să deschizi nivelurile generate.',
  nextDepth: 'Nivelul următor',
  deepestYet: 'Record personal',
  newFind: 'Descoperire',
  freeExplorer: 'Explorator liber',
  freeExplorerNote: 'Toată scufundarea e deschisă. Mergi oriunde.',
  builtCount: '{n} construite',
  clearedThisRun: '{n} cu sămânța asta',
  sharedLevel: 'Nivel primit',
  playShared: 'Joacă un nivel primit',
  shareCodeHint: 'Lipește un cod sau un link',
  shareCodeBad: 'Acesta nu este un cod Quadcraft.',
  scanToPlay: 'Scanează ca să joci nivelul',
  movesToBeat: 'De învins: {n} mutări',
  goDeeperHint: 'Termină nivelurile de deasupra pentru a coborî mai adânc.',
  useKey: 'Folosește o cheie',
  outOfKeys: 'Nu mai ai chei. Mâine primești trei.',
  openedWithKey: 'Deschis cu o cheie.',
  keyWon: 'Cheie câștigată',
  beatenIt: 'Depășit',
  sharedNotCounted: 'Nivelurile primite nu contează pentru progresul tău.',
  diveThisSeed: 'Joacă această sămânță',
  diveThisSeedBody:
      'Începe o rundă nouă cu această sămânță. Scara crește din nou: '
      'colecția rămâne, scorurile nu.',
  strata: [
    'Vadurile',
    'Terasa de Alamă',
    'Cuptorul',
    'Cocleală',
    'Războiul Adânc',
    'Ploaie de Stele',
  ],
  themes: {
    LevelTheme.open: 'Placă goală. Aici totul începe din tavă.',
    LevelTheme.wash:
        'O singură vreme pentru tot. Ridică-l crud, apoi lasă culoarea să '
        'cadă.',
    LevelTheme.relic:
        'Ce e deja aici e deja bun. Pune-l la adăpost înainte să vopsești.',
    LevelTheme.shell:
        'Haina e pe placă, căptușeala nu. Construiește spre înăuntru, apoi '
        'strecoară haina dedesubt.',
    LevelTheme.nested:
        'Colțuri adânci. Îmbracă-le pe fiecare dinăuntru în afară.',
    LevelTheme.spectrum: 'Mai multe vremuri. Fiecare culoare vrea drumul ei.',
  },
);
