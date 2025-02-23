import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQTT Control App',
      theme: ThemeData.dark(), // استخدام الثيم الداكن
      home: MQTTControlPage(),
    );
  }
}

class MQTTControlPage extends StatefulWidget {
  @override
  _MQTTControlPageState createState() => _MQTTControlPageState();
}

class _MQTTControlPageState extends State<MQTTControlPage> {
  late MqttServerClient client;
  final String server = 'nahari-m1qoxs.a03.euc1.aws.hivemq.cloud';
  final int port = 8883; // المنفذ الآمن
  // استخدام معرف عميل فريد
  final String clientId =
      'FlutterClient_${DateTime.now().millisecondsSinceEpoch}';
  final String username = 'hivemq.client.1740007217404';
  final String password = 'N@VG3:C7dBh#Qgze0<j5';
  final String controlTopic = 'flutter/control';

  bool isConnected = false;
  String connectionStatus = "غير متصل";

  @override
  void initState() {
    super.initState();
    connect();
  }

  Future<void> connect() async {
    // إنشاء العميل باستخدام withPort مع إعدادات الاتصال
    client = MqttServerClient.withPort(server, clientId, port)
      ..secure = true
      ..keepAlivePeriod = 20
      ..logging(on: true)
      ..onConnected = onConnected
      ..onDisconnected = onDisconnected
      ..onSubscribed = onSubscribed
    // لتجاوز التحقق من الشهادة أثناء الاختبار (استخدمه فقط في بيئة الاختبار)
      ..onBadCertificate = (Object cert) => true;

    // إعداد رسالة الاتصال مع بيانات الاعتماد
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    try {
      await client.connect();
    } catch (e) {
      print('❌ خطأ أثناء الاتصال: $e');
      setState(() {
        connectionStatus = "خطأ أثناء الاتصال: $e";
      });
      disconnect();
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      setState(() {
        isConnected = true;
        connectionStatus = "متصل";
      });
      print('✅ تم الاتصال بـ MQTT Broker');
      subscribeToTopic(controlTopic);
    } else {
      print('❌ فشل الاتصال: ${client.connectionStatus}');
      setState(() {
        connectionStatus = "فشل الاتصال: ${client.connectionStatus}";
      });
      disconnect();
    }
  }

  void disconnect() {
    client.disconnect();
    setState(() {
      isConnected = false;
      connectionStatus = "تم قطع الاتصال";
    });
  }

  void onConnected() {
    print('✅ تم الاتصال بنجاح');
  }

  void onDisconnected() {
    print('❌ تم قطع الاتصال');
  }

  void onSubscribed(String topic) {
    print('✅ تم الاشتراك في الموضوع: $topic');
  }

  void subscribeToTopic(String topic) {
    client.subscribe(topic, MqttQos.atMostOnce);
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      final recMess = events[0].payload as MqttPublishMessage;
      final payload =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('📩 رسالة جديدة من $topic: $payload');
      // يمكنك معالجة الرسالة الواردة هنا حسب الحاجة
    });
  }

  void publishCommand(String command) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(command);
    client.publishMessage(controlTopic, MqttQos.atLeastOnce, builder.payload!);
    print('📤 تم إرسال الأمر: $command إلى $controlTopic');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('التحكم عبر MQTT'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // عرض حالة الاتصال في بطاقة
            Card(
              elevation: 4,
              child: ListTile(
                leading: Icon(
                  isConnected ? Icons.check_circle : Icons.error,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                title: Text('حالة الاتصال'),
                subtitle: Text(connectionStatus),
              ),
            ),
            SizedBox(height: 20),
            // أزرار التحكم لإرسال الأوامر
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isConnected ? () => publishCommand('start') : null,
                  child: Text('ابدأ'),
                ),
                ElevatedButton(
                  onPressed: isConnected ? () => publishCommand('stop') : null,
                  child: Text('أوقف'),
                ),
              ],
            ),
            SizedBox(height: 20),
            // بطاقة عرض معلومات العميل
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("معلومات العميل:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text("الخادم: $server"),
                    Text("المنفذ: $port"),
                    Text("معرف العميل: $clientId"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
