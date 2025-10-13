import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GraphQLService {
  //final String endpoint = 'http://192.168.7.163:8080/graphql';
  final String endpoint = "http://localhost:8080/graphql";

  /// 🔁 Send a GraphQL mutation with optional token
  Future<Map<String, dynamic>> sendMutation(
      String query,
      Map<String, dynamic> variables, {
        String? token,
      }) async {
    final headers = {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    print("📡 Sending mutation to $endpoint");
    print("📄 Query: $query");
    print("📦 Variables: $variables");
    print("🛡️ Headers: $headers");

    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: jsonEncode({
        "query": query,
        "variables": variables,
      }),
    );

    print("✅ Status code: ${response.statusCode}");
    print("🧾 Response body: ${response.body}");

    return jsonDecode(response.body);
  }

  /// 🔁 Send a GraphQL query with optional token
  Future<Map<String, dynamic>> sendQuery(
      String query,
      Map<String, dynamic> variables, {
        String? token,
      }) async {
    final headers = {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    print("📡 Sending query to $endpoint");
    print("📄 Query: $query");
    print("📦 Variables: $variables");
    print("🛡️ Headers: $headers");

    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: jsonEncode({
        "query": query,
        "variables": variables,
      }),
    );

    print("✅ Status code: ${response.statusCode}");
    print("🧾 Response body: ${response.body}");

    return jsonDecode(response.body);
  }

  /// 🔐 Send mutation using token from SharedPreferences
  Future<Map<String, dynamic>> sendAuthenticatedMutation(
      String query,
      Map<String, dynamic> variables,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token");
    return sendMutation(query, variables, token: token);
  }

  /// 🔐 Send query using token from SharedPreferences
  Future<Map<String, dynamic>> sendAuthenticatedQuery(
      String query,
      Map<String, dynamic> variables,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token");
    return sendQuery(query, variables, token: token);
  }
}
//final String endpoint = "http://localhost:8080/graphql";
