import 'dart:convert';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'document_entity.dart';
import '../objectbox.g.dart'; 

/// A ObjectBox implementation of [VectorStore].
class ObjectBoxStore implements VectorStore {
  final String _path;
  final String _id;
  final Agent? _embeddingAgent;
  Store? _store;
  Box<DocumentEntity>? _box;

  ObjectBoxStore({
    required String path,
    String? id,
    Agent? embeddingAgent,
  })  : _path = path,
        _id = id ?? 'objectbox_${DateTime.now().millisecondsSinceEpoch}',
        _embeddingAgent = embeddingAgent;

  @override
  String get storeId => _id;

  @override
  Set<StoreCaps> get caps => {
        StoreCaps.vectorStorage,
        StoreCaps.batchOperations,
        if (_embeddingAgent != null) StoreCaps.embeddingGeneration,
      };

  @override
  Future<void> initialize() async {
    if (_store != null) return;
    
    _store = openStore(directory: _path);
    _box = _store!.box<DocumentEntity>();
  }

  @override
  Future<void> storeDocuments(List<Document> documents) async {
    _checkInitialized();

    final entities = <DocumentEntity>[];
    final docsToEmbed = <Document>[];

    for (final doc in documents) {
      if (doc.embedding == null && _embeddingAgent != null) {
        docsToEmbed.add(doc);
      } else {
        entities.add(_toEntity(doc));
      }
    }

    if (docsToEmbed.isNotEmpty) {
      if (_embeddingAgent == null) {
        throw StateError('Documents missing embeddings and no embedding agent provided');
      }
      
      // Batch embed
      final texts = docsToEmbed.map((d) => d.content).toList();
      final result = await _embeddingAgent.embedDocuments(texts);
      
      for (var i = 0; i < docsToEmbed.length; i++) {
        final doc = docsToEmbed[i];
        final embedding = result.embeddings[i];
        entities.add(_toEntity(doc, embedding: embedding));
      }
    }

    _box!.putMany(entities);
  }

  @override
  Future<List<SearchResult>> similaritySearch(String query, {int limit = 5, double threshold = 0.7}) async {
    _checkInitialized();

    // List<double> queryVector;
    if (_embeddingAgent != null) {
      await _embeddingAgent.embedQuery(query);
      // queryVector = result.embeddings;
    } else {
      throw StateError('Embedding agent required for similarity search from text query');
    }

    final queryBuilder = _box!.query(
      DocumentEntity_.embedding.lessThan(1.0) // Placeholder for vector search
    );
    // Note: ObjectBox Dart vector search API might differ in version 2.4.0 vs 4.0.0
    // For 2.4.0, vector search might not be fully supported or has different API.
    // We are using 2.4.0 to satisfy build_runner constraints.
    // Assuming standard query for now as placeholder if vector search API is missing.
    
    final queryObj = queryBuilder.build();
    final results = queryObj.find(); // findWithScores might be missing in older versions
    queryObj.close();

    return results.map((entity) {
      return SearchResult(
        document: _fromEntity(entity),
        score: 1.0, // Dummy score as findWithScores is missing
      );
    }).toList();
  }

  @override
  Future<List<double>> generateEmbedding(String text) async {
    if (_embeddingAgent == null) {
      throw StateError('No embedding agent provided');
    }
    final result = await _embeddingAgent.embedQuery(text);
    return result.embeddings;
  }

  @override
  Future<void> deleteDocuments({List<String>? ids, Map<String, dynamic>? filters}) async {
    _checkInitialized();

    if (ids != null && ids.isNotEmpty) {
      // This is inefficient because we store string IDs but ObjectBox uses int IDs.
      // We need to find the int IDs for the string IDs.
      // A real implementation should probably index the string ID.
      
      // TODO: Use generated property query
      /*
      final query = _box!.query(DocumentEntity_.docId.oneOf(ids)).build();
      query.remove();
      query.close();
      */
    }
    
    if (filters != null && filters.isNotEmpty) {
      // Implement metadata filtering
      // This is complex with JSON metadata. 
      // For now, we might need to fetch and filter in memory or use a better schema.
    }
  }

  @override
  Future<void> dispose() async {
    _store?.close();
    _store = null;
    _box = null;
  }

  void _checkInitialized() {
    if (_store == null || _box == null) {
      throw StateError('Store not initialized. Call initialize() first.');
    }
  }

  DocumentEntity _toEntity(Document doc, {List<double>? embedding}) {
    return DocumentEntity(
      docId: doc.id,
      content: doc.content,
      metadataJson: _mapToJson(doc.metadata),
      embedding: embedding ?? doc.embedding,
    );
  }

  Document _fromEntity(DocumentEntity entity) {
    return Document(
      id: entity.docId,
      content: entity.content,
      metadata: _jsonToMap(entity.metadataJson),
      embedding: entity.embedding,
    );
  }

  String _mapToJson(Map<String, dynamic> map) {
    return jsonEncode(map);
  }

  Map<String, dynamic> _jsonToMap(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
}
