import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/advice.dart';

/// Thrown for any failure while fetching advice — network, timeout,
/// non-200 response, or an unparseable/unexpected JSON body. Callers
/// (future UI code) can catch this single type rather than every
/// individual failure mode.
class AdviceServiceException implements Exception {
  const AdviceServiceException(this.message);

  final String message;

  @override
  String toString() => 'AdviceServiceException: $message';
}

/// Fetches a piece of advice from the public Advice Slip API
/// (https://api.adviceslip.com/advice).
///
/// Static-class service with no instance state, following the same shape
/// as [UserDataService]/[GuardianService] in this directory.
class AdviceService {
  AdviceService._();

  static const _endpoint = 'https://api.adviceslip.com/advice';

  static Future<Advice> fetchAdvice() async {
    final http.Response response;
    try {
      response = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const AdviceServiceException(
        'Advice Slip API timed out after 10 seconds.',
      );
    } catch (e) {
      throw AdviceServiceException(
        'Could not reach the Advice Slip API: $e',
      );
    }

    if (response.statusCode != 200) {
      throw AdviceServiceException(
        'Advice Slip API returned HTTP ${response.statusCode}: '
        '${response.body}',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (e) {
      throw AdviceServiceException(
        'Advice Slip API returned invalid JSON: ${e.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw AdviceServiceException(
        'Advice Slip API returned an unexpected JSON shape (expected an '
        'object): $decoded',
      );
    }

    try {
      return Advice.fromJson(decoded);
    } on FormatException catch (e) {
      throw AdviceServiceException(e.message);
    }
  }
}
