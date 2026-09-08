import 'package:firebase_auth/firebase_auth.dart';

/// iOS bundle id — must match Xcode `PRODUCT_BUNDLE_IDENTIFIER`.
const trackitIosBundleId = 'com.trackit.trackitMobile';

/// Android application id — must match `applicationId` in Gradle.
const trackitAndroidPackageName = 'com.trackit.trackit_mobile';

const trackitFirebaseAuthDomain = 'trackit-fac8a.firebaseapp.com';

/// Production web app — Firebase password-reset continue URL (authorized domain).
const trackitWebAppOrigin = 'https://trackitv1beta.netlify.app';

/// From `REVERSED_CLIENT_ID` in ios/Runner/GoogleService-Info.plist.
const trackitFirebaseIosUrlScheme =
    'com.googleusercontent.apps.323396504255-q0i0kqrrqhrgndei9202e5f673688ssr';

/// Gmail verification during registration — opens in the TrackIT app when installed.
ActionCodeSettings trackitFirebaseActionCodeSettings({String continuePath = '/register'}) {
  final path = continuePath.startsWith('/') ? continuePath : '/$continuePath';
  return ActionCodeSettings(
    url: 'https://$trackitFirebaseAuthDomain$path',
    handleCodeInApp: true,
    androidPackageName: trackitAndroidPackageName,
    androidInstallApp: true,
    androidMinimumVersion: '1',
    iOSBundleId: trackitIosBundleId,
  );
}

/// Password reset — opens TrackIT on iOS/Android when installed, otherwise the web app.
ActionCodeSettings trackitFirebasePasswordResetSettings() {
  return ActionCodeSettings(
    url: '$trackitWebAppOrigin/',
    handleCodeInApp: true,
    androidPackageName: trackitAndroidPackageName,
    androidInstallApp: false,
    androidMinimumVersion: '1',
    iOSBundleId: trackitIosBundleId,
  );
}

Uri trackitPasswordResetWebUri(String oobCode) {
  return Uri.parse(trackitWebAppOrigin).replace(
    queryParameters: {
      'mode': 'resetPassword',
      'oobCode': oobCode,
    },
  );
}

String? parseFirebaseOobCode(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  try {
    final uri = Uri.parse(trimmed.contains('://') ? trimmed : 'https://local?$trimmed');
    final fromQuery = uri.queryParameters['oobCode'];
    if (fromQuery != null && fromQuery.isNotEmpty) {
      return fromQuery;
    }
    if (uri.fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      final fromFragment = fragmentParams['oobCode'];
      if (fromFragment != null && fromFragment.isNotEmpty) {
        return fromFragment;
      }
    }
  } catch (_) {}

  if (trimmed.contains('oobCode=')) {
    final match = RegExp(r'[?&#]oobCode=([^&#\s]+)').firstMatch(trimmed);
    if (match != null) {
      final code = Uri.decodeComponent(match.group(1)!);
      if (code.isNotEmpty) return code;
    }

    final queryStart = trimmed.indexOf('?');
    final query = queryStart >= 0 ? trimmed.substring(queryStart + 1) : trimmed;
    final params = Uri.splitQueryString(query);
    final fromParams = params['oobCode'];
    if (fromParams != null && fromParams.isNotEmpty) {
      return fromParams;
    }
  }

  if (trimmed.length >= 20 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trimmed)) {
    return trimmed;
  }

  return null;
}

String? readEmailVerificationCodeFromUri(Uri uri) {
  final mode = uri.queryParameters['mode'];
  final oobCode = uri.queryParameters['oobCode'];
  if (mode == 'verifyEmail' && oobCode != null && oobCode.isNotEmpty) {
    return oobCode;
  }
  if (uri.fragment.isNotEmpty) {
    final fragmentParams = Uri.splitQueryString(uri.fragment);
    if (fragmentParams['mode'] == 'verifyEmail') {
      final code = fragmentParams['oobCode'];
      if (code != null && code.isNotEmpty) return code;
    }
  }
  return parseFirebaseOobCode(uri.toString());
}

String? readPasswordResetCodeFromUri(Uri uri) {
  final mode = uri.queryParameters['mode'];
  final oobCode = uri.queryParameters['oobCode'];
  if (mode == 'resetPassword' && oobCode != null && oobCode.isNotEmpty) {
    return oobCode;
  }
  if (uri.fragment.isNotEmpty) {
    final fragmentParams = Uri.splitQueryString(uri.fragment);
    if (fragmentParams['mode'] == 'resetPassword') {
      final code = fragmentParams['oobCode'];
      if (code != null && code.isNotEmpty) return code;
    }
  }

  for (final key in const ['link', 'deep_link_id', 'continueUrl']) {
    final nested = uri.queryParameters[key];
    if (nested == null || nested.isEmpty) continue;
    try {
      final nestedUri = Uri.parse(nested);
      final fromNested = readPasswordResetCodeFromUri(nestedUri);
      if (fromNested != null && fromNested.isNotEmpty) return fromNested;
    } catch (_) {}
    final parsed = parseFirebaseOobCode(nested);
    if (parsed != null && parsed.isNotEmpty) return parsed;
  }

  return parseFirebaseOobCode(uri.toString());
}
