abstract class StructurallyMutable {
  /// Add a component to the configuration
  void addComponent();
  
  /// Remove a component from the configuration
  void removeComponent();
  
  /// Check if components can be added
  bool get canAddComponent;
  
  /// Check if components can be removed
  bool get canRemoveComponent;
}
