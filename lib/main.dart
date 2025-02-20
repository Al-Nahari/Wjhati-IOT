import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // التطبيق الجذري مع ثيم حديث
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQTT & OpenStreetMap v5',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MqttHome(),
    );
  }
}

class MqttHome extends StatefulWidget {
  @override
  _MqttHomeState createState() => _MqttHomeState();
}

class _MqttHomeState extends State<MqttHome> {
  late MqttService _mqttService;
  // تخزين بيانات الرحلة المستلمة (JSON) في قائمة
  List<Map<String, dynamic>> _trips = [];
  // تخزين نقاط الرحلة لرسم المسار على الخريطة
  List<LatLng> _route = [];
  // متحكم الخريطة
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _mqttService = MqttService(
      onMessageReceived: (String message) {
        // تقسيم الرسالة إلى أسطر وإيجاد السطر الذي يحتوي على JSON
        List<String> lines = message.split('\n');
        for (var line in lines) {
          line = line.trim();
          if (line.startsWith('{') && line.endsWith('}')) {
            try {
              Map<String, dynamic> data = jsonDecode(line);
              double? lat = _parseCoordinate(data['lat']);
              double? lng = _parseCoordinate(data['lng']);
              if (lat != null && lng != null) {
                setState(() {
                  _trips.add(data);
                  _route.add(LatLng(lat, lng));
                });
                // تحديث موقع الكاميرا إلى الموقع الجديد
                _mapController.move(LatLng(lat, lng), 15);
              }
            } catch (e) {
              print("خطأ في فك تشفير JSON: $e");
            }
          }
        }
      },
    );
    _mqttService.connect();
  }

  double? _parseCoordinate(dynamic value) {
    // محاولة تحويل القيمة إلى double سواء كانت رقم أو نص
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        print("خطأ في تحويل الإحداثية: $value");
        return null;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // تحديد مركز الخريطة بناءً على آخر نقطة تم استقبالها، أو مركز افتراضي إذا لم تتوفر بيانات
    LatLng center = _route.isNotEmpty ? _route.last : LatLng(0.0, 0.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('رحلات GPS - MQTT'),
      ),
      body: Column(
        children: [
          // الجزء العلوي: عرض الخريطة باستخدام flutter_map إصدار 5
          Expanded(
            flex: 2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(

              ),
              children: [
                TileLayer(
                  urlTemplate:
                  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                  // الخاصية المطلوبة في الإصدار 5
                  userAgentPackageName: 'com.example.app',

                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: _route.isNotEmpty
                      ? [

                  ]
                      : [],
                ),
              ],
            ),
          ),
          // الجزء السفلي: قائمة بيانات الرحلة المستلمة
          Expanded(
            flex: 1,
            child: _trips.isEmpty
                ? Center(child: Text('في انتظار بيانات الرحلة...'))
                : ListView.builder(
              itemCount: _trips.length,
              itemBuilder: (context, index) {
                final trip = _trips[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.navigation, color: Colors.deepPurple),
                    title: Text(
                      "Lat: ${trip['lat']}\nLng: ${trip['lng']}",
                      style: TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      "Altitude: ${trip['altitude']}\nSpeed: ${trip['speed']}",
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MqttService {
  // بيانات خادم HiveMQ Cloud
  final String server = 'nahari-m1qoxs.a03.euc1.aws.hivemq.cloud';
  final int port = 8883; // المنفذ الآمن
  final String clientId = 'flutter_modern_ui_client';
  // بيانات الاعتماد (استبدلها ببيانات حسابك)
  final String username = 'hivemq.client.1740007217404';
  final String password = 'N@VG3:C7dBh#Qgze0<j5';

  late MqttServerClient client;
  final Function(String message) onMessageReceived;

  MqttService({required this.onMessageReceived}) {
    client = MqttServerClient.withPort(server, clientId, port)
      ..secure = true
      ..keepAlivePeriod = 20
      ..logging(on: true)
      ..onConnected = onConnected
      ..onDisconnected = onDisconnected
      ..onSubscribed = onSubscribed;
  }

  Future<void> connect() async {
    try {
      client.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .authenticateAs(username, password)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      await client.connect();

      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        print('✅ تم الاتصال بـ MQTT Broker');
        subscribeToTopic('flutter/test');
      } else {
        print('❌ فشل الاتصال: ${client.connectionStatus}');
        disconnect();
      }
    } catch (e) {
      print('❌ خطأ أثناء الاتصال: $e');
      disconnect();
    }
  }

  void disconnect() {
    client.disconnect();
    print('❌ تم قطع الاتصال');
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
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('📩 رسالة جديدة من $topic: $pt');
      onMessageReceived(pt);
    });
  }

  void publishMessage(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    print('📤 تم إرسال: $message إلى $topic');
  }
}
