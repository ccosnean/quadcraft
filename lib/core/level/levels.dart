import '../shape/shape.dart';
import 'level.dart';

/// Shorthand for authoring: parse a shape from the DSL in [Shape].
Shape _s(String dsl) => Shape.parse(dsl);

const _rotate = RotateMove();
const _cut = CutMove();
StackMove _place(String dsl) => StackMove(dsl);
PaintMove _paint(QuadColor color) => PaintMove(color);

/// The hand-authored tutorial: the only fixed levels in the game.
///
/// Each section teaches exactly one verb — turn, place, stack, paint, cut —
/// and the last one puts them together. Everything after this is generated
/// from the run seed, which is why the tutorial has to leave the player
/// holding the whole vocabulary: a generated target asks questions in every
/// verb at once and cannot stop to explain itself.
final List<Level> kLevels = [
  // ── Tutorial · Turn ──
  Level(
    number: 1,
    name: 'First Turn',
    section: 'Tutorial · Turn',
    brief: 'A quarter-turn clockwise — like a key in a lock.',
    start: _s('Cu/-/-/-'),
    goal: _s('-/Cu/-/-'),
    canRotate: true,
    solution: const [_rotate],
  ),
  Level(
    number: 2,
    name: 'In Step',
    section: 'Tutorial · Turn',
    brief: 'What sits together, spins together.',
    start: _s('Cu/Su/-/-'),
    goal: _s('-/-/Su/Cu'),
    canRotate: true,
    solution: const [_rotate, _rotate],
  ),
  Level(
    number: 3,
    name: 'The Long Way',
    section: 'Tutorial · Turn',
    brief: 'Three clicks walk a piece the long way home.',
    start: _s('Su/-/-/-'),
    goal: _s('-/-/Su/-'),
    canRotate: true,
    solution: const [_rotate, _rotate, _rotate],
  ),
  // ── Tutorial · Place ──
  Level(
    number: 4,
    name: 'First Drop',
    section: 'Tutorial · Place',
    brief: 'A plan in the tray is a piece on the plate.',
    goal: _s('Cu/-/-/-'),
    tray: [_s('Cu/-/-/-')],
    solution: [_place('Cu/-/-/-')],
  ),
  Level(
    number: 5,
    name: 'Two Parts',
    section: 'Tutorial · Place',
    brief: 'Two plans, two corners. Both belong.',
    goal: _s('Cu/Su/-/-'),
    tray: [_s('Cu/-/-/-'), _s('-/Su/-/-')],
    solution: [_place('Cu/-/-/-'), _place('-/Su/-/-')],
  ),
  Level(
    number: 6,
    name: 'Across',
    section: 'Tutorial · Place',
    brief: 'Some plans stretch across a pair of corners.',
    goal: _s('Su/Su/-/-'),
    tray: [_s('Su/Su/-/-')],
    solution: [_place('Su/Su/-/-')],
  ),
  // ── Tutorial · Turn + Place ──
  Level(
    number: 7,
    name: 'Park It',
    section: 'Tutorial · Turn + Place',
    brief: 'Drop it, then stroll it into the empty stall.',
    goal: _s('-/Su/-/-'),
    tray: [_s('Su/-/-/-')],
    canRotate: true,
    solution: [_place('Su/-/-/-'), _rotate],
  ),
  Level(
    number: 8,
    name: 'Three Corners',
    section: 'Tutorial · Turn + Place',
    brief: 'Place, turn, place — a little waltz around the plate.',
    goal: _s('Cu/Cu/-/Cu'),
    tray: [_s('Cu/-/-/-')],
    canRotate: true,
    solution: [
      _place('Cu/-/-/-'),
      _rotate,
      _place('Cu/-/-/-'),
      _rotate,
      _place('Cu/-/-/-'),
    ],
  ),
  Level(
    number: 9,
    name: 'Chequer',
    section: 'Tutorial · Turn + Place',
    brief: 'Dark, light, dark, light. Turn between the notes.',
    goal: _s('Su/Cu/Su/Cu'),
    tray: [_s('Cu/-/-/-'), _s('Su/-/-/-')],
    canRotate: true,
    solution: [
      _place('Su/-/-/-'),
      _rotate,
      _place('Cu/-/-/-'),
      _rotate,
      _place('Cu/-/-/-'),
      _rotate,
      _place('Su/-/-/-'),
    ],
  ),
  // ── Tutorial · Stack ──
  Level(
    number: 10,
    name: 'Underneath',
    section: 'Tutorial · Stack',
    brief: 'Newcomers slip under the ones already seated.',
    goal: _s('Su+Cu/-/-/-'),
    tray: [_s('Cu/-/-/-'), _s('Su/-/-/-')],
    solution: [_place('Cu/-/-/-'), _place('Su/-/-/-')],
  ),
  Level(
    number: 11,
    name: 'Three Deep',
    section: 'Tutorial · Stack',
    brief: 'Biggest at the bottom. Dress from the inside out.',
    goal: _s('Tu+Su+Cu/-/-/-'),
    tray: [_s('Cu/-/-/-'), _s('Su/-/-/-'), _s('Tu/-/-/-')],
    solution: [_place('Cu/-/-/-'), _place('Su/-/-/-'), _place('Tu/-/-/-')],
  ),
  Level(
    number: 12,
    name: 'The Limit',
    section: 'Tutorial · Stack',
    brief: 'Four deep. A corner\'s closet is not endless.',
    goal: _s('Wu+Tu+Su+Cu/-/-/-'),
    tray: [_s('Cu/-/-/-'), _s('Su/-/-/-'), _s('Tu/-/-/-'), _s('Wu/-/-/-')],
    solution: [
      _place('Cu/-/-/-'),
      _place('Su/-/-/-'),
      _place('Tu/-/-/-'),
      _place('Wu/-/-/-'),
    ],
  ),
  // ── Tutorial · Paint ──
  Level(
    number: 13,
    name: 'Fresh Coat',
    section: 'Tutorial · Paint',
    brief: 'One tap of colour floods the whole plate.',
    goal: _s('Sr/Sr/Sr/Sr'),
    tray: [_s('Su/Su/Su/Su')],
    colors: const [QuadColor.red],
    solution: [_place('Su/Su/Su/Su'), _paint(QuadColor.red)],
  ),
  Level(
    number: 14,
    name: 'Blue Bar',
    section: 'Tutorial · Paint',
    brief: 'Shape first. Colour after.',
    goal: _s('Cb/Cb/-/-'),
    tray: [_s('Cu/Cu/-/-')],
    colors: const [QuadColor.blue],
    solution: [_place('Cu/Cu/-/-'), _paint(QuadColor.blue)],
  ),
  Level(
    number: 15,
    name: 'Dyed Stack',
    section: 'Tutorial · Paint',
    brief: 'Paint is no respecter of layers.',
    goal: _s('Sr+Cr/-/-/-'),
    tray: [_s('Cu/-/-/-'), _s('Su/-/-/-')],
    colors: const [QuadColor.red],
    solution: [_place('Cu/-/-/-'), _place('Su/-/-/-'), _paint(QuadColor.red)],
  ),
  // ── Tutorial · Cut ──
  Level(
    number: 16,
    name: 'Slice',
    section: 'Tutorial · Cut',
    brief: 'A cut makes two keepable halves. Nothing is lost.',
    goal: _s('Cu/Cu/-/-'),
    tray: [_s('Cu/Cu/Cu/Cu')],
    canCut: true,
    solution: [_place('Cu/Cu/Cu/Cu'), _cut, _place('Cu/Cu/-/-')],
  ),
  Level(
    number: 17,
    name: 'Stand Up',
    section: 'Tutorial · Cut',
    brief: 'A row, stood on end, becomes a column.',
    goal: _s('-/Su/-/Su'),
    tray: [_s('Su/Su/Su/Su')],
    canRotate: true,
    canCut: true,
    solution: [_place('Su/Su/Su/Su'), _cut, _place('Su/Su/-/-'), _rotate],
  ),
  Level(
    number: 18,
    name: 'Other Half',
    section: 'Tutorial · Cut',
    brief: 'The other half waits. Bring it home on its own.',
    goal: _s('-/-/Cu/Cu'),
    tray: [_s('Cu/Cu/Cu/Cu')],
    canCut: true,
    solution: [_place('Cu/Cu/Cu/Cu'), _cut, _place('-/-/Cu/Cu')],
  ),
  // ── Tutorial · Colour Bank ──
  Level(
    number: 19,
    name: 'Two Tones',
    section: 'Tutorial · Colour Bank',
    brief: 'The brush is greedy. Hide a colour before it drinks.',
    goal: _s('Cr/Cr/Cb/Cb'),
    tray: [_s('Cu/Cu/Cu/Cu')],
    colors: const [QuadColor.red, QuadColor.blue],
    canCut: true,
    solution: [
      _place('Cu/Cu/Cu/Cu'),
      _paint(QuadColor.red),
      _cut,
      _place('Cu/Cu/Cu/Cu'),
      _paint(QuadColor.blue),
      _cut,
      _place('Cr/Cr/-/-'),
      _place('-/-/Cb/Cb'),
    ],
  ),
  Level(
    number: 20,
    name: 'Coloured Core',
    section: 'Tutorial · Colour Bank',
    brief: 'Dye them apart, then let one wear the other.',
    goal: _s('Cb+Cr/Cb+Cr/-/-'),
    tray: [_s('Cu/Cu/-/-')],
    colors: const [QuadColor.red, QuadColor.blue],
    canCut: true,
    solution: [
      _place('Cu/Cu/-/-'),
      _paint(QuadColor.red),
      _cut,
      _place('Cu/Cu/-/-'),
      _paint(QuadColor.blue),
      _cut,
      _place('Cr/Cr/-/-'),
      _place('Cb/Cb/-/-'),
    ],
  ),
  Level(
    number: 21,
    name: 'Corner Dyes',
    section: 'Tutorial · Colour Bank',
    brief: 'One corner at a time. Park the first before the next.',
    goal: _s('Cr/Cy/-/-'),
    tray: [_s('Cu/-/-/-')],
    colors: const [QuadColor.red, QuadColor.yellow],
    canRotate: true,
    canCut: true,
    solution: [
      _place('Cu/-/-/-'),
      _paint(QuadColor.yellow),
      _cut,
      _place('Cu/-/-/-'),
      _paint(QuadColor.red),
      _cut,
      _place('Cy/-/-/-'),
      _rotate,
      _place('Cr/-/-/-'),
    ],
  ),
];

Level levelByNumber(int number) =>
    kLevels.firstWhere((l) => l.number == number, orElse: () => kLevels.first);

/// Levels grouped by [Level.section], preserving authored order.
List<MapEntry<String, List<Level>>> get kLevelSections {
  final groups = <String, List<Level>>{};
  for (final level in kLevels) {
    groups.putIfAbsent(level.section, () => <Level>[]).add(level);
  }
  return groups.entries.toList(growable: false);
}
