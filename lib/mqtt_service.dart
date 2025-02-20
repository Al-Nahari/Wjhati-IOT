import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  final String server = 'broker.hivemq.com'; // استخدم سيرفر MQTT الخاص بك
  final int port = 1883;
  final String clientId = 'flutter_client';

  late MqttServerClient client;

  MqttService() {
    client = MqttServerClient(server, clientId);
    client.port = port;
    client.keepAlivePeriod = 20;
    client.logging(on: true);
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;
  }

  Future<void> connect() async {
    try {
      client.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      await client.connect();

      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        print('✅ متصل بـ MQTT Broker!');
      } else {
        print('❌ فشل الاتصال');
        client.disconnect();
      }
    } catch (e) {
      print('❌ خطأ في الاتصال: $e');
      client.disconnect();
    }
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
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
      final String payload =
      MqttPublishPayload.bytesToStringAsString(message.payload.message);
      print('📩 رسالة جديدة على [$topic]: $payload');
    });
  }

  void publishMessage(String topic, String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    print('📤 تم إرسال: $message إلى $topic');
  }
}
