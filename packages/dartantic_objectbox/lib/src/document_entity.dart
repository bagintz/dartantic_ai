import 'package:objectbox/objectbox.dart';

@Entity()
class DocumentEntity {
  @Id()
  int id = 0;

  @Unique()
  String docId;

  String content;

  /// Metadata stored as JSON string
  String metadataJson;

  /// Vector embedding.
  /// Note: For efficient similarity search, you should add an HNSW index 
  /// with the correct dimensions for your model in your own schema if possible,
  /// or we rely on the store implementation to handle it.
  /// 
  /// Example: @HnswIndex(dimensions: 1536)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  DocumentEntity({
    required this.docId,
    required this.content,
    required this.metadataJson,
    this.embedding,
  });
}
