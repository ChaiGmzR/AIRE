import 'package:flutter/material.dart';
import 'screens/boxing_screen.dart';
import 'services/api_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initialize(args: args);
  runApp(const PCBBoxingApp());
}

class PCBBoxingApp extends StatelessWidget {
  const PCBBoxingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PCB Boxing System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Segoe UI',
        scaffoldBackgroundColor: const Color(0xFFC0C0C0),
      ),
      home: const BoxingScreen(),
    );
  }
}
