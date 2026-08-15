import 'package:http/http.dart' as http;
import 'dart:convert';

class IAAnalisisFinanciero {
  final String apiKey = "TU_API_KEY_AQUI"; // <- pon aquí tu API key

  Future<String> analizar({
    required double ingresos,
    required List<Map<String, dynamic>> gastos,
    required List<Map<String, dynamic>> metas,
  }) async {
    final url = Uri.parse("https://api.openai.com/v1/chat/completions");

    final body = {
      "model": "gpt-4o-mini",
      "messages": [
        {
          "role": "system",
          "content":
              "Eres un asesor experto en finanzas personales. Analiza ingresos, gastos y metas. Identifica gastos innecesarios, da sugerencias de ahorro y pasos concretos para cumplir metas."
        },
        {
          "role": "user",
          "content": jsonEncode({
            "ingresos": ingresos,
            "gastos": gastos,
            "metas": metas,
          })
        }
      ],
      "max_tokens": 600
    };

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey"
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);
    return data["choices"][0]["message"]["content"] ?? "No hubo respuesta.";
  }
}
