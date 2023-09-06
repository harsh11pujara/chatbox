import 'dart:async';
import 'package:chatting_app/Helper/themes.dart';
import 'package:chatting_app/Model/userModel.dart';
import 'package:chatting_app/Screens/authentication/loginScreen.dart';
import 'package:chatting_app/Screens/home/home.dart';
import 'package:chatting_app/Screens/welcomeScreen.dart';
import 'package:chatting_app/Screens/splashScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  String? token = await FirebaseMessaging.instance.getToken();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CustomTheme.lightTheme(),
    home: const MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool userLoginFlag = false;
  FirebaseAuth auth = FirebaseAuth.instance;
  UserModel? userData;

  @override
  void initState() {
    // registerNotification();
    Timer(
      const Duration(seconds: 1),
      () {
        checkIfLogin();
      },
    );
    super.initState();
  }

  checkIfLogin() async {
    auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        DocumentSnapshot data = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        var temp = data.data() as Map<String, dynamic>;
        userData = UserModel.fromJson(temp);
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen(userData: userData!)));
        }
        // setState(() {
        //   userLoginFlag = true;
        // });
      } else {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => WelcomeScreen()));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }

  // void registerNotification() async {
  //   FirebaseMessaging messaging = FirebaseMessaging.instance;
  //   FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  //   localNotifications.resolvePlatformSpecificImplementation();
  //   await localNotifications.initialize(const InitializationSettings(android: AndroidInitializationSettings("splash_logo")),onDidReceiveBackgroundNotificationResponse: (details) {
  //     // localNotifications.show(123, "title", "new message",
  //     //     NotificationDetails(android: AndroidNotificationDetails("123", "local", color: Colors.greenAccent)));
  //   },);
  //   localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!.requestPermission();
  //
  //   NotificationSettings setting = await messaging.requestPermission(alert: true, sound: true, badge: true,announcement: true);
  //   if (setting.authorizationStatus == AuthorizationStatus.authorized) {
  //     print("granted");
  //     FirebaseMessaging.onMessage.listen((message) {
  //       print(message.data);
  //       localNotifications.show(123, "title", "new message",
  //           NotificationDetails(android: AndroidNotificationDetails("123", "local", color: Colors.greenAccent,importance: Importance.max,)));
  //       // localNotifications.zonedSchedule(1, "title", "body", , const NotificationDetails(android: AndroidNotificationDetails("123", "local", color: Colors.greenAccent)), uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime, androidAllowWhileIdle: true);
  //     });
  //   } else {
  //     print("not granted");
  //   }
  // }
}
