import 'package:fcd_app/src/app.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionController = SessionController();
  await sessionController.bootstrap();

  runApp(
    ChangeNotifierProvider<SessionController>.value(
      value: sessionController,
      child: const FcdApp(),
    ),
  );
}
