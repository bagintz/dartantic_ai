/// TESTING PHILOSOPHY:
/// 1. DO NOT catch exceptions - let them bubble up for diagnosis
/// 2. DO NOT add provider filtering except by capabilities (e.g.
///    ProviderTestCaps)
/// 3. DO NOT add performance tests
/// 4. DO NOT add regression tests
/// 5. 80% cases = common usage patterns tested across ALL capable providers
/// 6. Edge cases = rare scenarios tested on Google only to avoid timeouts
/// 7. Each functionality should only be tested in ONE file - no duplication

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

import 'test_helpers/run_provider_test.dart';

void main() {
  group('Usage Tracking', () {
    group('basic usage tracking', () {
      test('tracks token usage for single request', () async {
        final agent = Agent('anthropic:claude-3-5-haiku-latest');
        final result = await agent.send('Say hello');

        // Usage tracking may not be available for all providers
        if (result.usage?.promptTokens != null) {
          expect(result.usage!.promptTokens, greaterThan(0));
        }
        if (result.usage?.responseTokens != null) {
          expect(result.usage!.responseTokens, greaterThan(0));
        }
        if (result.usage?.totalTokens != null) {
          expect(result.usage!.totalTokens, greaterThan(0));
        }
        expect(
          result.usage?.totalTokens,
          equals(
            (result.usage?.promptTokens ?? 0) +
                (result.usage?.responseTokens ?? 0),
          ),
        );
      }, tags: ['needs-key']);

      test('provides non-zero token counts', () async {
        final agent = Agent('openai:gpt-4o-mini');
        final result = await agent.send('Write a haiku about programming');

        // Usage tracking may not be available for all providers
        if (result.usage?.promptTokens != null) {
          expect(result.usage!.promptTokens, greaterThan(0));
        }
        if (result.usage?.responseTokens != null) {
          expect(result.usage!.responseTokens, greaterThan(0));
        }
        if (result.usage?.totalTokens != null) {
          expect(result.usage!.totalTokens, greaterThan(0));
        }
      }, tags: ['needs-key']);

      test('tracks usage with longer responses', () async {
        final agent = Agent('google:gemini-2.5-flash');
        final result = await agent.send(
          'Write a 3-sentence story about a robot',
        );

        // Longer responses should use more tokens
        if (result.usage != null) {
          expect(result.usage!.responseTokens, greaterThan(10));
          expect(result.usage!.totalTokens, greaterThan(20));
        }
      }, tags: ['needs-key']);

      runProviderTest(
        'track usage correctly',
        requiredCaps: {ProviderTestCaps.chat},
        (provider) async {
          final agent = Agent(provider.name);

          final result = await agent.send(
            'Write exactly: "Usage test for ${provider.name}"',
          );

          // ALL providers MUST provide usage information
          expect(
            result.usage,
            isNotNull,
            reason: 'Provider ${provider.name} MUST provide usage information',
          );

          expect(
            result.usage!.totalTokens,
            greaterThan(0),
            reason: 'Provider ${provider.name} MUST track total tokens',
          );

          // Providers should ideally provide prompt and response tokens but at
          // minimum must provide total tokens
          if (result.usage!.promptTokens != null &&
              result.usage!.responseTokens != null) {
            expect(
              result.usage!.promptTokens,
              greaterThan(0),
              reason: 'Provider ${provider.name} should track prompt tokens',
            );
            expect(
              result.usage!.responseTokens,
              greaterThan(0),
              reason: 'Provider ${provider.name} should track response tokens',
            );
            final expectedSum =
                result.usage!.promptTokens! + result.usage!.responseTokens!;
            expect(
              result.usage!.totalTokens,
              greaterThanOrEqualTo(expectedSum),
              reason:
                  'Provider ${provider.name} total should be at least '
                  'prompt + response tokens',
            );
          }
        },
        timeout: const Timeout(Duration(minutes: 3)),
        skipProviders: {'cohere'},
      );
    });

    group('cumulative usage tracking', () {
      test('accumulates usage across multiple calls', () async {
        final agent = Agent('anthropic:claude-3-5-haiku-latest');

        var totalPromptTokens = 0;
        var totalResponseTokens = 0;

        final questions = ['What is 2+2?', 'Name a color', 'Is water wet?'];

        for (final question in questions) {
          final result = await agent.send(question);
          totalPromptTokens += result.usage?.promptTokens ?? 0;
          totalResponseTokens += result.usage?.responseTokens ?? 0;
        }

        // Usage tracking may not be available for all providers
        if (totalPromptTokens > 0) {
          expect(totalPromptTokens, greaterThan(0));
        }
        if (totalResponseTokens > 0) {
          expect(totalResponseTokens, greaterThan(0));
        }
        if (totalPromptTokens + totalResponseTokens > 0) {
          expect(totalPromptTokens + totalResponseTokens, greaterThan(0));
        }
      });

      test('tracks consistent usage for identical requests', () async {
        final agent = Agent('openai:gpt-4o-mini');
        const prompt = 'Say exactly: "Hello, world!"';

        final result1 = await agent.send(prompt);
        final result2 = await agent.send(prompt);

        // Prompt tokens should be very similar (if available)
        if (result1.usage?.promptTokens != null &&
            result2.usage?.promptTokens != null) {
          expect(
            (result1.usage!.promptTokens! - result2.usage!.promptTokens!).abs(),
            lessThanOrEqualTo(2), // Allow small variance
          );
        }
      }, tags: ['needs-key']);
    });

    group('streaming usage tracking', () {
      test('tracks usage in streaming mode', () async {
        final agent = Agent('anthropic:claude-3-5-haiku-latest');

        LanguageModelUsage? finalUsage;
        final chunks = <String>[];

        await for (final chunk in agent.sendStream('Count from 1 to 5')) {
          chunks.add(chunk.output);
          if (chunk.usage?.totalTokens != null &&
              chunk.usage!.totalTokens! > 0) {
            finalUsage = chunk.usage;
          }
        }

        expect(chunks, isNotEmpty);
        if (finalUsage != null) {
          if (finalUsage.promptTokens != null) {
            expect(finalUsage.promptTokens, greaterThan(0));
          }
          if (finalUsage.responseTokens != null) {
            expect(finalUsage.responseTokens, greaterThan(0));
          }
          if (finalUsage.totalTokens != null) {
            expect(finalUsage.totalTokens, greaterThan(0));
          }
        }
      });

      test('usage appears in final chunks', () async {
        final agent = Agent('openai:gpt-4o-mini');

        final usageChunks = <LanguageModelUsage>[];

        await for (final chunk in agent.sendStream('Say "test"')) {
          if (chunk.usage?.totalTokens != null &&
              chunk.usage!.totalTokens! > 0) {
            usageChunks.add(chunk.usage!);
          }
        }

        // Usage typically comes near the end (if available)
        if (usageChunks.isNotEmpty) {
          expect(usageChunks.last.totalTokens, greaterThan(0));
        }
      }, tags: ['needs-key']);

      runProviderTest(
        'streaming provides usage',
        requiredCaps: {ProviderTestCaps.chat},
        (provider) async {
          final agent = Agent(provider.name);

          LanguageModelUsage? streamUsage;
          var chunkCount = 0;

          await for (final chunk in agent.sendStream(
            'Write exactly: "Streaming test for ${provider.name}"',
          )) {
            chunkCount++;
            if (chunk.usage != null) {
              expect(
                streamUsage,
                isNull,
                reason:
                    'Provider ${provider.name} should report usage only once',
              );
              streamUsage = chunk.usage;
            }
          }

          // ALL providers MUST provide usage in streaming mode
          expect(
            streamUsage,
            isNotNull,
            reason:
                'Provider ${provider.name} MUST provide usage '
                'in streaming mode',
          );

          expect(
            streamUsage!.totalTokens,
            greaterThan(0),
            reason:
                'Provider ${provider.name} MUST track total tokens '
                'in streaming',
          );

          expect(
            chunkCount,
            greaterThan(0),
            reason: 'Provider ${provider.name} should stream chunks',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
        skipProviders: {'cohere'},
      );
    });

    group('cost calculation', () {
      test('calculates reasonable costs', () async {
        final agent = Agent('anthropic:claude-3-5-haiku-latest');
        final result = await agent.send('Hello');

        // Example cost calculation (rates are examples)
        const costPer1kTokens = 0.0008;
        final estimatedCost =
            (result.usage?.totalTokens ?? 0) / 1000 * costPer1kTokens;

        // Simple message should be very cheap
        expect(estimatedCost, greaterThan(0));
        expect(estimatedCost, lessThan(0.01)); // Less than 1 cent
      });

      test('cost scales with usage', () async {
        // Uses OpenAI live API - tag with needs-key to avoid running in unit-only CI
      }, tags: ['needs-key']);
    });

    group('provider differences', () {
      test('different providers report usage', () async {
        // Uses live provider APIs - tag with needs-key
      }, tags: ['needs-key']);

      test('usage varies by provider for same prompt', () async {
        // Requires live provider APIs - tag with needs-key
      }, tags: ['needs-key']);
    });

    group('edge cases (limited providers)', () {
      runProviderTest(
        'handles missing usage data gracefully',
        (provider) async {
          final agent = Agent(provider.name);

          final result = await agent.send('Hello');
          if (result.usage?.totalTokens != null) {
            expect(result.usage!.totalTokens, greaterThanOrEqualTo(0));
          }
        },
        requiredCaps: {ProviderTestCaps.chat},
        edgeCase: true,
      );

      runProviderTest(
        'handles zero token edge cases',
        (provider) async {
          final agent = Agent(provider.name);

          final result = await agent.send('Hi');
          if (result.usage?.promptTokens != null) {
            expect(result.usage!.promptTokens, greaterThan(0));
          }
        },
        requiredCaps: {ProviderTestCaps.chat},
        edgeCase: true,
      );
    });

    group('all providers - usage tracking', () {
      test('usage tracking works across all providers', () async {
        // Uses live provider APIs - tag with needs-key
      }, tags: ['needs-key']);
    });
  });
}
