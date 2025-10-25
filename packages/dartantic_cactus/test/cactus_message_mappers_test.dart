import 'package:dartantic_cactus/src/cactus_message_mappers.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CactusMessageMappers', () {
    group('toCactusMessages', () {
      test('converts simple user message', () {
        final messages = [
          ChatMessage.user('Hello, AI!'),
        ];
        
        final cactusMessages = CactusMessageMappers.toCactusMessages(messages);
        
        expect(cactusMessages.length, 1);
        expect(cactusMessages[0].role, 'user');
        expect(cactusMessages[0].content, 'Hello, AI!');
      });

      test('converts simple assistant message', () {
        final messages = [
          ChatMessage.model('Hello, human!'),
        ];
        
        final cactusMessages = CactusMessageMappers.toCactusMessages(messages);
        
        expect(cactusMessages.length, 1);
        expect(cactusMessages[0].role, 'assistant');
        expect(cactusMessages[0].content, 'Hello, human!');
      });

      test('converts simple system message', () {
        final messages = [
          ChatMessage.system('You are a helpful assistant.'),
        ];
        
        final cactusMessages = CactusMessageMappers.toCactusMessages(messages);
        
        expect(cactusMessages.length, 1);
        expect(cactusMessages[0].role, 'system');
        expect(cactusMessages[0].content, 'You are a helpful assistant.');
      });

      test('converts conversation with multiple messages', () {
        final messages = [
          ChatMessage.system('You are helpful.'),
          ChatMessage.user('What is 2+2?'),
          ChatMessage.model('2+2 equals 4.'),
          ChatMessage.user('Thanks!'),
        ];
        
        final cactusMessages = CactusMessageMappers.toCactusMessages(messages);
        
        expect(cactusMessages.length, 4);
        expect(cactusMessages[0].role, 'system');
        expect(cactusMessages[1].role, 'user');
        expect(cactusMessages[2].role, 'assistant');
        expect(cactusMessages[3].role, 'user');
      });

      test('handles empty message list', () {
        final messages = <ChatMessage>[];
        
        final cactusMessages = CactusMessageMappers.toCactusMessages(messages);
        
        expect(cactusMessages, isEmpty);
      });

      test('extracts text from multi-part messages', () {
        final messages = [
          ChatMessage.user('Hello'),
        ];
        
        final cactusMessages = CactusMessageMappers.toCactusMessages(messages);
        
        expect(cactusMessages[0].content, 'Hello');
      });

      test('concatenates multiple text parts', () {
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: [
            TextPart('First part. '),
            TextPart('Second part.'),
          ],
        );
        
        final cactusMessages = CactusMessageMappers.toCactusMessages([message]);
        
        expect(cactusMessages[0].content, 'First part. Second part.');
      });
    });

    group('fromCactusResponse', () {
      test('creates ChatMessage from response text', () {
        final message = CactusMessageMappers.fromCactusResponse('Hello from AI!');
        
        expect(message.role, ChatMessageRole.model);
        expect(message.text, 'Hello from AI!');
      });

      test('handles empty response', () {
        final message = CactusMessageMappers.fromCactusResponse('');
        
        expect(message.role, ChatMessageRole.model);
        expect(message.text, isEmpty);
      });
    });

    group('extractImagePaths', () {
      test('returns empty list for text-only messages', () async {
        final messages = [
          ChatMessage.user('Hello'),
          ChatMessage.model('Hi there'),
        ];
        
        final imagePaths = await CactusMessageMappers.extractImagePaths(messages);
        
        expect(imagePaths, isEmpty);
      });

      test('returns empty list for empty messages', () async {
        final messages = <ChatMessage>[];
        
        final imagePaths = await CactusMessageMappers.extractImagePaths(messages);
        
        expect(imagePaths, isEmpty);
      });

      // Note: Testing with actual images would require mock file system
      // which is complex for this unit test. Image path extraction is
      // covered in integration tests.
    });
  });
}
