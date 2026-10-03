// Which store updates the app (StoreAppUpdater): Google Play on Android,
// the App Store on iOS, and none on the web or a desktop, where nothing is
// checked.

import 'package:elang/shared/services/app_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each platform updates from its own store', () {
    expect(
      StoreAppUpdater(platform: TargetPlatform.android, isWeb: false).store,
      UpdateStore.googlePlay,
    );
    expect(
      StoreAppUpdater(platform: TargetPlatform.iOS, isWeb: false).store,
      UpdateStore.appStore,
    );
    expect(
      StoreAppUpdater(platform: TargetPlatform.windows, isWeb: false).store,
      isNull,
    );
    expect(
      StoreAppUpdater(platform: TargetPlatform.android, isWeb: true).store,
      isNull,
    );
  });

  test('away from Google Play, Play is never asked', () async {
    final updater = StoreAppUpdater(platform: TargetPlatform.iOS, isWeb: false);
    expect(await updater.checkPlay(), PlayUpdate.none);
    expect(await updater.updateNow(), isFalse);
  });

  test('with no store page to open, nothing opens', () async {
    final updater = StoreAppUpdater(platform: TargetPlatform.iOS, isWeb: false);
    expect(await updater.openStore(), isFalse);
  });
}
