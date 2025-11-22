abstract class Tunable {
  /// Get a map of tunable numeric parameters
  Map<String, num> get numericParameters;
  
  /// Update a numeric parameter
  void setNumericParameter(String key, num value);
  
  /// Get ranges for parameters (min, max)
  Map<String, (num, num)> get parameterRanges;
  
  /// Get a map of discrete parameters
  Map<String, dynamic> get discreteParameters;
  
  /// Update a discrete parameter
  void setDiscreteParameter(String key, dynamic value);
  
  /// Get options for discrete parameters
  Map<String, List<dynamic>> get discreteOptions;
}
