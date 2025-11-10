import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/station.dart';

class ApiService {
  static const String _baseUrl = 'http://radio.rajnikantmahato.me';

  static Future<List<Station>> getStations() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/stations'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Station.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      throw Exception('Failed to load data');
    }
  }
}
