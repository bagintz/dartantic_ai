import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';

class SqlGenerator {
  final Agent agent;

  SqlGenerator(this.agent);

  Future<String> generate(String naturalLanguageQuery, DatabaseSchema schema, {String? context}) async {
    final prompt = '''
You are an expert SQL generator.
Given the following database schema:
${schema.rawSchema}

And the user's request: "$naturalLanguageQuery"

${context != null ? 'Additional context: $context\n' : ''}
Generate a valid SQL query to answer the request.
Return ONLY the SQL query, no markdown formatting, no explanations.
''';

    final response = await agent.send(prompt);
    // Clean up response if it contains markdown code blocks
    var sql = response.output.trim();
    if (sql.startsWith('```sql')) {
      sql = sql.substring(6);
    } else if (sql.startsWith('```')) {
      sql = sql.substring(3);
    }
    if (sql.endsWith('```')) {
      sql = sql.substring(0, sql.length - 3);
    }
    return sql.trim();
  }
}
