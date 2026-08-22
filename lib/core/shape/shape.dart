import 'package:flutter/foundation.dart';

/// The four quadrants of a Quadcraft shape, in canonical order.
enum Corner { tl, tr, bl, br }

/// Geometry that can occupy a single quadrant.
enum QuadForm {
  circle('C'),
  square('S'),
  star('T'),
  windmill('W');

  const QuadForm(this.code);

  final String code;

  static QuadForm fromCode(String code) =>
      values.firstWhere((f) => f.code == code, orElse: () => throw FormatException('unknown form "$code"'));
}

/// Paint applied to a piece. [uncolored] is the raw, unpainted material.
enum QuadColor {
  uncolored('u'),
  red('r'),
  green('g'),
  blue('b'),
  yellow('y'),
  purple('p'),
  cyan('c');

  const QuadColor(this.code);

  final String code;

  static QuadColor fromCode(String code) =>
      values.firstWhere((c) => c.code == code, orElse: () => throw FormatException('unknown color "$code"'));
}

/// A single stacked piece inside a quadrant.
@immutable
class LayerPiece {
  const LayerPiece(this.form, [this.color = QuadColor.uncolored]);

  final QuadForm form;
  final QuadColor color;

  String get code => '${form.code}${color.code}';

  LayerPiece painted(QuadColor color) => LayerPiece(form, color);

  static LayerPiece parse(String code) {
    if (code.length != 2) {
      throw FormatException('layer code must be 2 chars, got "$code"');
    }
    return LayerPiece(QuadForm.fromCode(code[0]), QuadColor.fromCode(code[1]));
  }

  @override
  bool operator ==(Object other) => other is LayerPiece && other.form == form && other.color == color;

  @override
  int get hashCode => Object.hash(form, color);

  @override
  String toString() => code;
}

/// One quadrant: an ordered stack of pieces from bottom (outermost, drawn
/// largest) to top (innermost, drawn smallest).
@immutable
class Quadrant {
  Quadrant(List<LayerPiece> layers) : layers = List.unmodifiable(layers);

  const Quadrant._empty() : layers = const [];

  static const Quadrant empty = Quadrant._empty();

  final List<LayerPiece> layers;

  bool get isEmpty => layers.isEmpty;
  bool get isNotEmpty => layers.isNotEmpty;
  int get depth => layers.length;

  Quadrant painted(QuadColor color) =>
      isEmpty ? this : Quadrant([for (final l in layers) l.painted(color)]);

  String get code => isEmpty ? '-' : layers.map((l) => l.code).join('+');

  static Quadrant parse(String code) {
    if (code == '-' || code.isEmpty) return empty;
    return Quadrant([for (final part in code.split('+')) LayerPiece.parse(part)]);
  }

  @override
  bool operator ==(Object other) => other is Quadrant && listEquals(other.layers, layers);

  @override
  int get hashCode => Object.hashAll(layers);

  @override
  String toString() => code;
}

/// An immutable 2x2 shape.
///
/// Serialises to a compact, human-readable DSL used for level authoring, tray
/// de-duplication and goal comparison:
///
/// ```text
/// tl/tr/bl/br            corners in [Corner] order, "-" when empty
/// Sr+Cb                  one quadrant: square-red at the bottom, circle-blue on top
/// "Cu/Cu/-/-"            two uncoloured circles across the top
/// ```
@immutable
class Shape {
  Shape(Map<Corner, Quadrant> corners)
      : corners = Map.unmodifiable({
          for (final corner in Corner.values) corner: corners[corner] ?? Quadrant.empty,
        });

  const Shape._empty() : corners = const {};

  /// A board with nothing on it.
  static const Shape empty = Shape._empty();

  /// Highest number of pieces a single quadrant can hold.
  static const int maxLayers = 4;

  final Map<Corner, Quadrant> corners;

  Quadrant operator [](Corner corner) => corners[corner] ?? Quadrant.empty;

  bool get isEmpty => Corner.values.every((c) => this[c].isEmpty);
  bool get isNotEmpty => !isEmpty;

  Iterable<Corner> get filledCorners => Corner.values.where((c) => this[c].isNotEmpty);

  int get pieceCount => Corner.values.fold(0, (sum, c) => sum + this[c].depth);

  /// Deepest quadrant stack, used for layout and layer-cap checks.
  int get depth => Corner.values.fold(0, (max, c) => this[c].depth > max ? this[c].depth : max);

  /// Canonical identity. Two shapes look identical if and only if their ids match.
  String get id => Corner.values.map((c) => this[c].code).join('/');

  Shape withCorner(Corner corner, Quadrant quadrant) =>
      Shape({...corners, corner: quadrant});

  static Shape parse(String dsl) {
    final parts = dsl.split('/');
    if (parts.length != Corner.values.length) {
      throw FormatException('shape needs ${Corner.values.length} quadrants, got "$dsl"');
    }
    return Shape({
      for (var i = 0; i < parts.length; i++)
        Corner.values[i]: Quadrant.parse(parts[i].trim()),
    });
  }

  /// Convenience for authoring: the same form and colour in every quadrant.
  static Shape uniform(QuadForm form, [QuadColor color = QuadColor.uncolored]) => Shape({
        for (final corner in Corner.values) corner: Quadrant([LayerPiece(form, color)]),
      });

  /// Convenience for authoring: a single piece in one quadrant.
  static Shape single(Corner corner, QuadForm form, [QuadColor color = QuadColor.uncolored]) =>
      Shape({corner: Quadrant([LayerPiece(form, color)])});

  @override
  bool operator ==(Object other) => other is Shape && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}
