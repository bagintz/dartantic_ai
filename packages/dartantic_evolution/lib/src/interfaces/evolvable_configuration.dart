abstract class EvolvableConfiguration<T extends EvolvableConfiguration<T>> {
  /// Creates a deep copy of this configuration
  T clone();

  /// Unique identifier for this configuration instance
  String get id;
  
  /// Metadata about this configuration's lineage
  Map<String, dynamic> get metadata;
}
