import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_push_notification/controller/auth_service.dart';
import 'package:firebase_push_notification/controller/curd_service.dart';
import 'package:firebase_push_notification/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';

class PushNotifications {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // request notification permission
  static Future init() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );
    final token= await _firebaseMessaging.getToken();
    print('Device token: $token');
  }

  // get the fcm device token
  static Future getDeviceToken({int maxRetires = 3}) async {
    try {
      String? token;
      if (kIsWeb) {
        // get the device fcm token
        token = await _firebaseMessaging.getToken(
            vapidKey:
            "BPA9r_00LYvGIV9GPqkpCwfIl3Es4IfbGqE9CSrm6oeYJslJNmicXYHyWOZQMPlORgfhG8RNGe7hIxmbLXuJ92k");
        print("for web device token: $token");
      } else {
        // get the device fcm token
        token = await _firebaseMessaging.getToken();
        print("for android device token: $token");
      }
      saveTokentoFirestore(token: token!);
      return token;
    } catch (e) {
      print("failed to get device token");
      if (maxRetires > 0) {
        print("try after 10 sec");
        await Future.delayed(Duration(seconds: 10));
        return getDeviceToken(maxRetires: maxRetires - 1);
      } else {
        return null;
      }
    }
  }

  static saveTokentoFirestore({required String token}) async {
    bool isUserLoggedin = await AuthService.isLoggedIn();
    print("User is logged in $isUserLoggedin");
    if (isUserLoggedin) {
      await CRUDService.saveUserToken(token!);
      print("save to firestore");
    }
    // also save if token changes
    _firebaseMessaging.onTokenRefresh.listen((event) async {
      if (isUserLoggedin) {
        await CRUDService.saveUserToken(token!);
        print("save to firestore");
      }
    });
  }

  // initalize local notifications
  static Future localNotiInit() async {
    // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      onDidReceiveLocalNotification: (id, title, body, payload) => null,
    );
    final LinuxInitializationSettings initializationSettingsLinux =
    LinuxInitializationSettings(defaultActionName: 'Open notification');
    final InitializationSettings initializationSettings =
    InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        linux: initializationSettingsLinux);

    // request notification permissions for android 13 or above
    _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()!
        .requestNotificationsPermission();

    _flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: onNotificationTap);
  }

  // on tap local notification in foreground
  static void onNotificationTap(NotificationResponse notificationResponse) {
    navigatorKey.currentState!
        .pushNamed("/message", arguments: notificationResponse);
  }

  //Get server key

  // static Future<String> getServerKeyToken() async{
  //   final scopes=[
  //     "https://www.googleapis.com/auth/userinfo.email",
  //     "https://www.googleapis.com/auth/firebase.database",
  //     "https://www.googleapis.com/auth/firebase.messaging",
  //   ];
  //   final client =  await clientViaServiceAccount(
  //   ServiceAccountCredentials.fromJson(
  //     {
  //         "type": "service_account",
  //         "project_id": "fir-pushnotification-f9031",
  //         "private_key_id": "c6fd1e1887934b7fa9df933fc7eeeff4c74898f8",
  //         "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDdQS+anbo7Ksbt\nLGVKOdFpj34fTEAujTx/3JFttza4y6siHibD3q6hV/0G+SVJpJrmxY/KvivJV3Gl\nj5x5QUojrWlp+PHgmXYhiey5Iz2w5PYK5IImcGZjTScEIdboq8Fs951a0T5GVGZG\npuw5wZF7qeYxpbWhqj+/SfhZreR6ydQdabmEaOPPali6Tk4v8c3U9BAa2rnAgnBU\nr6iWnxvwuGXnExiNSjah14Fw6Eciol7INtiqq3tyGZSeK/rUMIiyGYFya0PBG2R4\nDCDmx+C0EAP4oxBAgXp46DV9XU4Tyn7mBOBbvhm26+Oakl9JDc84srNQ2c/PZ5nb\nN2Ul3F3RAgMBAAECggEAGbuEu/arc8lvOqMa0jHMhlqNHHp/rfJY9pV6eABSndY5\nLHYFg+sMlCEBwXt9T9X0OpIAXd/1g3yXL/5WgF88rk7TN2MfzYOHotGx3Zvoxz+v\n0nc+YFZbACJXXvKJFkUwkTnwvADhPWiAPygXigWWZCOvzTcku11LvfWOS+7Op42F\njdDv5VQUmiOtLpgEyidl91b1p2dHd8oCjT70NBYplTgGs3kBxrFBZTdd837/LwA8\nYC6Xd5Ndogh9sHOzW2oQj1e+JlQ78YaKcg6oGHykAfViLrJ6JD7kp4TP+iPRaWct\nBEOsveRMq8RR0nCMv4hgdB7siUbjw4dABLr87Y7f6QKBgQDzJAlsOFRKUUwerQm7\nWSmDzgVsFUI+lg4OYMxEL/kSFUCckC34TuOxj9l3i594IePu4mDeW939FBNK5ESW\nwz1Pn6SkNwRp9xKTPqjeidfaurl/ncI7aNucLfHREd9s5WUEmCRA1tDLw2ghyobU\nn9Z6ByWdVQ88uFE+MDO7p1oZOQKBgQDo9NNVIojrjcBouDDd0J39zZX6GIyMtmOY\nQe8901n0kUapHhOa/LEWTq/SpGSZe6XTmyhSjxe/CHAeqXIuPom0IKQLhBQL/O1D\nyMGi3EXKadstvta15LUqhj5fUPx+mhE+5E39HkKf4QAe1qDNRdEtCFyJHYTOR9d+\ny7+OWtNhWQKBgQDYz6G3ZuODAcum7xZmgbOLXQNoxew0cwpFt/tuMnkfruPWuJrF\neVOA2o1JFLA3J8FhG2zV24WwT16EwdiHt8HMZschyA2fkDp4Ir/i8XgSC7+uFLdG\n0tJCCpY/oHhjWosh9akeSHAXwz/wIfDpWT6fwg/ApEDaHGIV2lXHWAv3wQKBgQCf\n43GtLB/XtJoMBeecRtQ5X8KBPhoxdfmThiWjRI2oO5HI/1irdqZAzk8E/0oAwgoF\n26doSsgcmLkDgn9Y2BmBZSnSsZtkwvtCG+czVYYdMFx74FDT1R63Ch6DIz250xrl\nFKOmh/9oZnDDucHyQeoYw3Vnsrf1MP/qCgP2u8X7OQKBgQDfCCAjrpMHnywf6fMY\nKWwHzzDazGQXYC7HxqYYxM4e+RVJuExocYE+gjHi0yxsLkkaMDsNg8hf1RNKVeNv\nCqNNpsV26TS4mMSrzTBPitjs/QKbFX8j6aRJBTcIt8i6/wXkaK+5ZBAY/ouy124Y\nTqzclrtjBydpY0l8Uv4HVrtePg==\n-----END PRIVATE KEY-----\n",
  //         "client_email": "firebase-adminsdk-m246c@fir-pushnotification-f9031.iam.gserviceaccount.com",
  //         "client_id": "103020400064192638038",
  //         "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  //         "token_uri": "https://oauth2.googleapis.com/token",
  //         "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  //         "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-m246c%40fir-pushnotification-f9031.iam.gserviceaccount.com",
  //         "universe_domain": "googleapis.com"
  //     }, ),
  //   scopes,
  //   );
  //   final accessServerKey= client.credentials.accessToken.data;
  //   return accessServerKey;
  // }

  // show a simple notification

  static Future<String> getServerKeyToken() async {
    try {
      print('Starting getServerKeyToken');
      final scopes = [
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/firebase.database",
        "https://www.googleapis.com/auth/firebase.messaging",
      ];

      final client = await clientViaServiceAccount(
        ServiceAccountCredentials.fromJson({
          "type": "service_account",
          "project_id": "fir-pushnotification-f9031",
          "private_key_id": "c6fd1e1887934b7fa9df933fc7eeeff4c74898f8",
          "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDdQS+anbo7Ksbt\nLGVKOdFpj34fTEAujTx/3JFttza4y6siHibD3q6hV/0G+SVJpJrmxY/KvivJV3Gl\nj5x5QUojrWlp+PHgmXYhiey5Iz2w5PYK5IImcGZjTScEIdboq8Fs951a0T5GVGZG\npuw5wZF7qeYxpbWhqj+/SfhZreR6ydQdabmEaOPPali6Tk4v8c3U9BAa2rnAgnBU\nr6iWnxvwuGXnExiNSjah14Fw6Eciol7INtiqq3tyGZSeK/rUMIiyGYFya0PBG2R4\nDCDmx+C0EAP4oxBAgXp46DV9XU4Tyn7mBOBbvhm26+Oakl9JDc84srNQ2c/PZ5nb\nN2Ul3F3RAgMBAAECggEAGbuEu/arc8lvOqMa0jHMhlqNHHp/rfJY9pV6eABSndY5\nLHYFg+sMlCEBwXt9T9X0OpIAXd/1g3yXL/5WgF88rk7TN2MfzYOHotGx3Zvoxz+v\n0nc+YFZbACJXXvKJFkUwkTnwvADhPWiAPygXigWWZCOvzTcku11LvfWOS+7Op42F\njdDv5VQUmiOtLpgEyidl91b1p2dHd8oCjT70NBYplTgGs3kBxrFBZTdd837/LwA8\nYC6Xd5Ndogh9sHOzW2oQj1e+JlQ78YaKcg6oGHykAfViLrJ6JD7kp4TP+iPRaWct\nBEOsveRMq8RR0nCMv4hgdB7siUbjw4dABLr87Y7f6QKBgQDzJAlsOFRKUUwerQm7\nWSmDzgVsFUI+lg4OYMxEL/kSFUCckC34TuOxj9l3i594IePu4mDeW939FBNK5ESW\nwz1Pn6SkNwRp9xKTPqjeidfaurl/ncI7aNucLfHREd9s5WUEmCRA1tDLw2ghyobU\nn9Z6ByWdVQ88uFE+MDO7p1oZOQKBgQDo9NNVIojrjcBouDDd0J39zZX6GIyMtmOY\nQe8901n0kUapHhOa/LEWTq/SpGSZe6XTmyhSjxe/CHAeqXIuPom0IKQLhBQL/O1D\nyMGi3EXKadstvta15LUqhj5fUPx+mhE+5E39HkKf4QAe1qDNRdEtCFyJHYTOR9d+\ny7+OWtNhWQKBgQDYz6G3ZuODAcum7xZmgbOLXQNoxew0cwpFt/tuMnkfruPWuJrF\neVOA2o1JFLA3J8FhG2zV24WwT16EwdiHt8HMZschyA2fkDp4Ir/i8XgSC7+uFLdG\n0tJCCpY/oHhjWosh9akeSHAXwz/wIfDpWT6fwg/ApEDaHGIV2lXHWAv3wQKBgQCf\n43GtLB/XtJoMBeecRtQ5X8KBPhoxdfmThiWjRI2oO5HI/1irdqZAzk8E/0oAwgoF\n26doSsgcmLkDgn9Y2BmBZSnSsZtkwvtCG+czVYYdMFx74FDT1R63Ch6DIz250xrl\nFKOmh/9oZnDDucHyQeoYw3Vnsrf1MP/qCgP2u8X7OQKBgQDfCCAjrpMHnywf6fMY\nKWwHzzDazGQXYC7HxqYYxM4e+RVJuExocYE+gjHi0yxsLkkaMDsNg8hf1RNKVeNv\nCqNNpsV26TS4mMSrzTBPitjs/QKbFX8j6aRJBTcIt8i6/wXkaK+5ZBAY/ouy124Y\nTqzclrtjBydpY0l8Uv4HVrtePg==\n-----END PRIVATE KEY-----\n",
          "client_email": "firebase-adminsdk-m246c@fir-pushnotification-f9031.iam.gserviceaccount.com",
          "client_id": "103020400064192638038",
          "auth_uri": "https://accounts.google.com/o/oauth2/auth",
          "token_uri": "https://oauth2.googleapis.com/token",
          "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
          "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-m246c%40fir-pushnotification-f9031.iam.gserviceaccount.com",
          "universe_domain": "googleapis.com"
        }),
        scopes,
      );
      // print('Client created: ${client.credentials.accessToken}');
      final accessServerKey = client.credentials.accessToken.data;
      // print("??????????????????? Access Token ?????????????????????????");
      // print('Access Server Key: $accessServerKey');
      // print("??????????????????? Access Token ?????????????????????????");
      return accessServerKey;
    } catch (e) {
      print("????????????????????????????????????????????");
      print('Error in getting server key: $e');
      return 'Error';
    }
  }

  static Future showSimpleNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails('your channel id', 'your channel name',
        channelDescription: 'your channel description',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker');
    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidNotificationDetails);
    await _flutterLocalNotificationsPlugin
        .show(0, title, body, notificationDetails, payload: payload);
  }
}
