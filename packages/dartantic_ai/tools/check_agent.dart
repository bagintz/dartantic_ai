import 'package:dartantic_ai/dartantic_ai.dart';

void main() {
  try {
    final providers = Agent.allProviders;
    print('Providers: ${providers.map((p) => p.name).join(', ')}');
  } catch (e, st) {
    print('ERROR: $e');
    print(st);
  }
}
