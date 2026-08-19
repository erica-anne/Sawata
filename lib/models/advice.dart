/// Immutable model for a single Advice Slip API response.
///
/// Source: https://api.adviceslip.com/advice
///
/// Sample response:
/// ```json
/// {
///   "slip": {
///     "id": 214,
///     "advice": "Things are just things. Don’t get too attached to them."
///   }
/// }
/// ```
class Advice {
  const Advice({required this.id, required this.advice});

  final int id;
  final String advice;

  /// Parses the raw decoded JSON body of an Advice Slip API response.
  ///
  /// Throws a [FormatException] with a descriptive message if `slip`, `id`,
  /// or `advice` is missing or not of the expected type — callers should
  /// never receive a partially-populated [Advice].
  factory Advice.fromJson(Map<String, dynamic> json) {
    final slip = json['slip'];
    if (slip is! Map<String, dynamic>) {
      throw FormatException(
        'Invalid Advice Slip response: expected a "slip" object, got: '
        '${json['slip']}',
      );
    }

    final id = slip['id'];
    if (id is! int) {
      throw FormatException(
        'Invalid Advice Slip response: expected "slip.id" to be an int, '
        'got: ${slip['id']}',
      );
    }

    final advice = slip['advice'];
    if (advice is! String || advice.trim().isEmpty) {
      throw FormatException(
        'Invalid Advice Slip response: expected a non-empty "slip.advice" '
        'string, got: ${slip['advice']}',
      );
    }

    return Advice(id: id, advice: advice);
  }
}
