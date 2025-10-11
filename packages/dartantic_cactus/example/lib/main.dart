import 'package:flutter/material.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:dartantic_cactus/dartantic_cactus.dart';

void main() {
  runApp(const CactusExampleApp());
}

class CactusExampleApp extends StatelessWidget {
  const CactusExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cactus AI Example',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  late final CactusProvider _provider;
  late final ChatModel<CactusChatModelOptions> _chatModel;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  void _initializeModel() {
    try {
      _provider = CactusProvider();
      _chatModel = _provider.createChatModel(
        name: 'phi-3-mini-4k-instruct',
        options: const CactusChatModelOptions(
          modelUrl: 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
          contextSize: 4096,
          gpuLayers: 0, // CPU only for compatibility
          temperature: 0.7,
        ),
      );
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing model: $e');
      setState(() {
        _isInitialized = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (!_isInitialized || _controller.text.trim().isEmpty) return;

    final userMessage = _controller.text.trim();
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage.user(userMessage));
      _messages.add(ChatMessage.model('')); // Placeholder for assistant response
    });

    try {
      // Create conversation history including system message
      final conversationMessages = [
        ChatMessage.system('You are a helpful AI assistant running locally on device.'),
        ..._messages.where((m) => m.text.isNotEmpty),
      ];

      String responseText = '';
      await for (final result in _chatModel.sendStream(conversationMessages)) {
        responseText = result.output.text;
        setState(() {
          _messages[_messages.length - 1] = ChatMessage.model(responseText);
        });
      }
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] = ChatMessage.model(
          'Error: $e\n\nNote: This is a demo with stubbed implementation. '
          'The actual Cactus API integration is pending.'
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cactus AI Example'),
          backgroundColor: Colors.green,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Cactus AI...'),
              SizedBox(height: 8),
              Text(
                'Note: This is a demo implementation.\nActual model loading would happen here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cactus AI Chat'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == ChatMessageRole.user;
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.green[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUser ? 'You' : 'Cactus AI',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(message.text),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}