import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

Future<String?> getUserRoleFromToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString("jwt_token");

  if (token == null || JwtDecoder.isExpired(token)) return null;

  final decoded = JwtDecoder.decode(token);
  return decoded['role'] as String?;
}
