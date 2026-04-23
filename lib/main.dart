import 'package:fcd_app/src/app.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionController = SessionController();
  await sessionController.bootstrap();

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SessionController>.value(value: sessionController),
        ChangeNotifierProvider<DownloadTaskController>(
          create: (_) => DownloadTaskController(
            downloadRepository: DownloadRepository(
              apiClient: sessionController.apiClient,
            ),
          ),
        ),
      ],
      child: const FcdApp(),
    ),
  );
}
