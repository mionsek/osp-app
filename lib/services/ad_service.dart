/// Ads-free unit email — hardcoded, not configurable by users.
const adsFreeEmail = 'ospkielno@gmail.com';

/// Test banner ad unit ID (Google's official test ID).
/// TODO: Replace with real AdMob banner ad unit ID before publishing to Play Store.
/// Real ID format: ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
const bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

/// Returns true if ads should be shown for the given signed-in user email.
bool shouldShowAds(String? userEmail) {
  return userEmail != adsFreeEmail;
}
