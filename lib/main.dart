import 'package:flutter/material.dart';

import '/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: "NFC Passport Reader",
        debugShowCheckedModeBanner: false,
        home: SplashScreen());
  }
}
