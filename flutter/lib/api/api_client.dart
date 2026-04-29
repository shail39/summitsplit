import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiClient {
  static const String baseUrl = 'https://app.summitsplit.com/api';

  // Trips
  static Future<Trip> createTrip(String name, String description, String currency, {String emoji = ''}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/trips'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'description': description, 'currency': currency, 'emoji': emoji}),
    );
    _check(res);
    return Trip.fromJson(jsonDecode(res.body));
  }

  static Future<Trip> getTrip(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/trips/$id'));
    _check(res);
    return Trip.fromJson(jsonDecode(res.body));
  }

  static Future<Trip> updateTrip(String id, String name, String description, String currency, String emoji) async {
    final res = await http.put(
      Uri.parse('$baseUrl/trips/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'description': description, 'currency': currency, 'emoji': emoji}),
    );
    _check(res);
    return Trip.fromJson(jsonDecode(res.body));
  }

  // Members
  static Future<List<Member>> getMembers(String tripId) async {
    final res = await http.get(Uri.parse('$baseUrl/trips/$tripId/members'));
    _check(res);
    final list = jsonDecode(res.body) as List? ?? [];
    return list.map((e) => Member.fromJson(e)).toList();
  }

  static Future<Member> addMember(String tripId, String name, String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/trips/$tripId/members'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email}),
    );
    _check(res);
    return Member.fromJson(jsonDecode(res.body));
  }

  // Expenses
  static Future<List<Expense>> getExpenses(String tripId) async {
    final res = await http.get(Uri.parse('$baseUrl/trips/$tripId/expenses'));
    _check(res);
    final list = jsonDecode(res.body) as List? ?? [];
    return list.map((e) => Expense.fromJson(e)).toList();
  }

  static Future<void> addExpense(String tripId, String paidById, String description,
      String category, double amount, DateTime date, List<Map<String, dynamic>> splits, {String notes = ''}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/trips/$tripId/expenses'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'paid_by_id': paidById,
        'description': description,
        'category': category,
        'notes': notes,
        'amount': amount,
        'date': date.toIso8601String().substring(0, 10),
        'splits': splits,
      }),
    );
    _check(res);
  }

  static Future<void> updateExpense(String tripId, String expenseId, String paidById, String description,
      String category, double amount, DateTime date, List<Map<String, dynamic>> splits, {String notes = ''}) async {
    final res = await http.put(
      Uri.parse('$baseUrl/trips/$tripId/expenses/$expenseId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'paid_by_id': paidById,
        'description': description,
        'category': category,
        'notes': notes,
        'amount': amount,
        'date': date.toIso8601String().substring(0, 10),
        'splits': splits,
      }),
    );
    _check(res);
  }

  static Future<void> deleteExpense(String tripId, String expenseId) async {
    final res = await http.delete(Uri.parse('$baseUrl/trips/$tripId/expenses/$expenseId'));
    _check(res);
  }

  static Future<void> deleteMember(String tripId, String memberId) async {
    final res = await http.delete(Uri.parse('$baseUrl/trips/$tripId/members/$memberId'));
    _check(res);
  }

  // Balances & Settlements
  static Future<List<Balance>> getBalances(String tripId) async {
    final res = await http.get(Uri.parse('$baseUrl/trips/$tripId/balances'));
    _check(res);
    final list = jsonDecode(res.body) as List? ?? [];
    return list.map((e) => Balance.fromJson(e)).toList();
  }

  static Future<List<Settlement>> getSettlements(String tripId) async {
    final res = await http.get(Uri.parse('$baseUrl/trips/$tripId/settlements'));
    _check(res);
    final list = jsonDecode(res.body) as List? ?? [];
    return list.map((e) => Settlement.fromJson(e)).toList();
  }

  // Payments (mark as paid)
  static Future<void> recordPayment(String tripId, String fromId, String toId, double amount) async {
    final res = await http.post(
      Uri.parse('$baseUrl/trips/$tripId/payments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'from_id': fromId, 'to_id': toId, 'amount': amount}),
    );
    _check(res);
  }

  // Export CSV URL (for download)
  static String exportCsvUrl(String tripId) => '$baseUrl/trips/$tripId/export.csv';

  static void _check(http.Response res) {
    if (res.statusCode >= 400) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }
  }
}
