import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/api_service.dart';
import 'core/services/local_notifier.dart';
import 'core/services/storage_service.dart';
import 'core/services/app_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF09090B),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await initializeDateFormatting('es', null);

  final storage = await StorageService.getInstance();
  final api = ApiService(storage);
  final localNotifier = LocalNotifier();
  await localNotifier.init();

  final appProvider = AppProvider(storage: storage, api: api);
  appProvider.setLocalNotifier(localNotifier);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider(
          create: (_) => appProvider.uploadQueue,
        ),
      ],
      child: const VidalisApp(),
    ),
  );
}
