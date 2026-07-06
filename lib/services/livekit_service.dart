import 'package:livekit_client/livekit_client.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class LiveKitService {
  static const String _serverUrl = "wss://classforge-mdjuoxm0.livekit.cloud";

  // You can find these in your LiveKit Cloud dashboard
  static const String _apiKey = "APIWdH7cgkBrZZc";
  static const String _apiSecret =
      "AI5vN4BlcOaxyIExz0mlV136UyyrWakMpXVVEef74Ge";

  Future<Room> createOrJoinRoom({
    required String roomName,
    required String identity,
    required String name,
    required bool isHost,
  }) async {
    final room = Room();

    // Generating the token locally to avoid Firebase Cloud Function costs (Blaze Plan)
    final token = await _getToken(roomName, identity, name, isHost);

    await room.connect(_serverUrl, token);

    return room;
  }

  Future<String> _getToken(
    String roomName,
    String identity,
    String name,
    bool isHost,
  ) async {
    // Create the JWT for LiveKit
    final jwt = JWT(
      {
        'video': {
          'room': roomName,
          'roomJoin': true,
          'canPublish':
              true, // Set to true to allow participants to share video/audio
          'canSubscribe':
              true, // Set to true to allow participants to see others
        },
        'name': name,
      },
      issuer: _apiKey,
      subject: identity,
    );

    // Sign the token with HMAC-SHA256 using your API Secret
    // Set expiry to 6 hours as requested
    final token = jwt.sign(
      SecretKey(_apiSecret),
      expiresIn: const Duration(hours: 6),
    );

    return token;
  }
}
