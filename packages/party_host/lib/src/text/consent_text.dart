/// The crash reports consent prompt's words (design sentry-consent.md): the
/// adult's question, what a report holds, and what to press. They match the
/// privacy page's crash reports section in `site/privacy.html`, in plain words
/// for the adult in charge of the device.
abstract final class ConsentText {
  /// The crash reports question, over the prompt.
  static const crashQuestion = 'Send crash reports?';

  /// What a crash report holds and what happens to it.
  static const crashBody =
      'For the adult in charge of this device.\n\n'
      'Thumb Party can send crash reports to its developer through Sentry, so bugs get fixed. Nothing is '
      'sent until someone says yes.\n\n'
      'A report holds the error, where in the app it happened, the app version, the platform and operating '
      'system version, and the device model. No names, email addresses or account IDs are sent.\n\n'
      'Sentry stores the reports for the developer in the United States. You can change this at any time in '
      'settings. The privacy policy explains it in full.';

  /// The crash prompt's "no" button.
  static const dontSend = 'Don\'t send';

  /// The crash prompt's "yes" button.
  static const sendCrashReports = 'Send crash reports';

  /// The Stats screen's crash reports button, while reports are sent.
  static const crashOn = 'Crash reports: on';

  /// The Stats screen's crash reports button, while nothing is sent.
  static const crashOff = 'Crash reports: off';
}
