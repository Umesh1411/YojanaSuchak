import 'package:cloud_functions/cloud_functions.dart';

class NotificationService {
  final FirebaseFunctions _functions;

  NotificationService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Call the HTTPS function to send scheme details to given emails.
  Future<void> sendSchemeDetailsToEmails(
      {required String schemeId,
      required List<String> emails,
      String lang = 'en'}) async {
    final callable = _functions.httpsCallable('sendSchemeDetailsCallable');
    await callable.call({'schemeId': schemeId, 'emails': emails, 'lang': lang});
    // resp.data can be checked for success
    return;
  }
}
