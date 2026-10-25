// lib/Config/legal.dart
//
// One place for the legal facts the app points at. Change a value here and
// every screen follows.

/// The organisation's website. The legal pages below are expected to live here.
const String kWebsite = 'https://canopycircle.org';

/// These pages must exist on the website before release (Google Play requires
/// a public privacy policy URL and a web path to request account deletion).
const String kPrivacyUrl = '$kWebsite/privacy';
const String kTermsUrl = '$kWebsite/terms';
const String kDeleteAccountUrl = '$kWebsite/delete-account';

/// The youngest a person may be to use Canopy on their own. Anyone younger
/// needs a parent or guardian's permission. Confirm this with counsel.
const int kMinimumAge = 18;
