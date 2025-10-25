import 'package:dartantic_cactus/src/cactus_embeddings_model.dart';
import 'package:dartantic_cactus/src/cactus_chat_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CactusEmbeddingsModel Unit Tests', () {
    group('Constructor and Properties', () {
      test('creates model with default options', () {
        final model = CactusEmbeddingsModel(name: 'test-embeddings');
        expect(model.name, 'test-embeddings');
        expect(model.defaultOptions, isA<CactusEmbeddingsModelOptions>());
      });

      test('creates model with custom options', () {
        final model = CactusEmbeddingsModel(
          name: 'custom-embeddings',
          options: const CactusEmbeddingsModelOptions(
            modelUrl: 'custom-url',
            contextSize: 8192,
          ),
        );
        expect(model.name, 'custom-embeddings');
        expect(model.defaultOptions.modelUrl, 'custom-url');
        expect(model.defaultOptions.contextSize, 8192);
      });
    });

    group('Input Validation', () {
      test('embedQuery rejects empty query', () {
        final model = CactusEmbeddingsModel(name: 'test');
        expect(
          () => model.embedQuery(''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('embedQuery rejects too long query', () {
        final model = CactusEmbeddingsModel(name: 'test');
        final longQuery = 'A' * 9000;
        expect(
          () => model.embedQuery(longQuery),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('embedDocuments rejects empty list', () {
        final model = CactusEmbeddingsModel(name: 'test');
        expect(
          () => model.embedDocuments([]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('embedDocuments rejects too many documents', () {
        final model = CactusEmbeddingsModel(name: 'test');
        final manyDocs = List.generate(101, (i) => 'Doc $i');
        expect(
          () => model.embedDocuments(manyDocs),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('embedDocuments rejects empty document', () {
        final model = CactusEmbeddingsModel(name: 'test');
        expect(
          () => model.embedDocuments(['valid', '', 'also valid']),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Dispose', () {
      test('dispose completes without error', () {
        final model = CactusEmbeddingsModel(name: 'test');
        expect(() => model.dispose(), returnsNormally);
      });

      test('can dispose multiple times', () {
        final model = CactusEmbeddingsModel(name: 'test');
        model.dispose();
        expect(() => model.dispose(), returnsNormally);
      });
    });
  });
}
