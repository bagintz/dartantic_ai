/// Customizable templates for LLM analysis.
class DiagnosisPromptTemplate {
  final String systemPrompt;
  final String userPromptTemplate;

  const DiagnosisPromptTemplate({
    required this.systemPrompt,
    required this.userPromptTemplate,
  });

  /// The default template for general performance diagnosis.
  static const DiagnosisPromptTemplate defaultTemplate = DiagnosisPromptTemplate(
    systemPrompt: '''
You are an expert AI system performance diagnostician. Your goal is to analyze performance metrics, identify weaknesses, determine root causes, and provide actionable recommendations.

You must output your diagnosis in a structured JSON format matching the following schema:
{
  "weaknessAnalysis": "string",
  "rootCauses": ["string"],
  "recommendations": [
    {
      "target": "string (parameter or component)",
      "suggestion": "string (value or action)",
      "reasoning": "string",
      "difficulty": "low|medium|high",
      "expectedImpact": "low|medium|high",
      "confidence": number (0.0-1.0)
    }
  ],
  "overallConfidence": number (0.0-1.0)
}
''',
    userPromptTemplate: '''
Please analyze the following performance history and context for an AI system.

Context:
{{CONTEXT}}

Performance History Summary:
{{HISTORY_SUMMARY}}

Statistical Analysis:
{{STATISTICAL_ANALYSIS}}

Identify the key weaknesses, their likely root causes, and suggest specific improvements.
''',
  );

  /// Fills the user prompt template with data.
  String fill(Map<String, String> values) {
    String result = userPromptTemplate;
    values.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });
    return result;
  }
}
