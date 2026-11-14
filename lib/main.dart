import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/utils/formatters.dart';

Future<void> main() async {

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      if (kDebugMode) FlutterError.presentError(details);
    };

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    Formatters.init();
    runApp(const LabConnectApp());
  }, (error, stack) {
    // Intentionally silent in release builds.
    if (kDebugMode) debugPrint('Unhandled error: ${error.runtimeType}');
  });
}
