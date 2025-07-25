/// Performance monitoring utilities for alien-signals optimizations.
///
/// This module provides tools to measure and track the performance benefits
/// of the implemented optimizations like memory pooling, batching, and
/// priority scheduling.
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._();

  // Counters for tracking optimization usage
  int _linkPoolHits = 0;
  int _linkPoolMisses = 0;
  int _batchedUpdates = 0;
  int _immediateUpdates = 0;
  int _highPriorityEffects = 0;
  int _normalPriorityEffects = 0;
  
  // Timing measurements
  final List<int> _flushTimes = <int>[];
  final List<int> _propagationTimes = <int>[];
  
  /// Records a successful hit from the Link memory pool.
  void recordLinkPoolHit() => _linkPoolHits++;
  
  /// Records a miss from the Link memory pool (new allocation).
  void recordLinkPoolMiss() => _linkPoolMisses++;
  
  /// Records a batched signal update.
  void recordBatchedUpdate() => _batchedUpdates++;
  
  /// Records an immediate signal update.
  void recordImmediateUpdate() => _immediateUpdates++;
  
  /// Records execution of a high priority effect.
  void recordHighPriorityEffect() => _highPriorityEffects++;
  
  /// Records execution of a normal priority effect.
  void recordNormalPriorityEffect() => _normalPriorityEffects++;
  
  /// Records the time taken for a flush operation.
  void recordFlushTime(int microseconds) {
    _flushTimes.add(microseconds);
    // Keep only recent measurements to avoid unbounded growth
    if (_flushTimes.length > 1000) {
      _flushTimes.removeAt(0);
    }
  }
  
  /// Records the time taken for a propagation operation.
  void recordPropagationTime(int microseconds) {
    _propagationTimes.add(microseconds);
    // Keep only recent measurements to avoid unbounded growth
    if (_propagationTimes.length > 1000) {
      _propagationTimes.removeAt(0);
    }
  }
  
  /// Gets the memory pool hit rate as a percentage.
  double get poolHitRate {
    final total = _linkPoolHits + _linkPoolMisses;
    return total > 0 ? (_linkPoolHits / total) * 100 : 0.0;
  }
  
  /// Gets the batch utilization rate as a percentage.
  double get batchUtilizationRate {
    final total = _batchedUpdates + _immediateUpdates;
    return total > 0 ? (_batchedUpdates / total) * 100 : 0.0;
  }
  
  /// Gets the priority effect usage rate as a percentage.
  double get highPriorityUsageRate {
    final total = _highPriorityEffects + _normalPriorityEffects;
    return total > 0 ? (_highPriorityEffects / total) * 100 : 0.0;
  }
  
  /// Gets the average flush time in microseconds.
  double get averageFlushTime {
    return _flushTimes.isEmpty 
        ? 0.0 
        : _flushTimes.reduce((a, b) => a + b) / _flushTimes.length;
  }
  
  /// Gets the average propagation time in microseconds.
  double get averagePropagationTime {
    return _propagationTimes.isEmpty 
        ? 0.0 
        : _propagationTimes.reduce((a, b) => a + b) / _propagationTimes.length;
  }
  
  /// Resets all performance counters and measurements.
  void reset() {
    _linkPoolHits = 0;
    _linkPoolMisses = 0;
    _batchedUpdates = 0;
    _immediateUpdates = 0;
    _highPriorityEffects = 0;
    _normalPriorityEffects = 0;
    _flushTimes.clear();
    _propagationTimes.clear();
  }
  
  /// Returns a formatted performance summary.
  String summary() {
    return '''
Performance Monitor Summary:
  Memory Pool Hit Rate: ${poolHitRate.toStringAsFixed(1)}%
  Batch Utilization Rate: ${batchUtilizationRate.toStringAsFixed(1)}%
  High Priority Effect Usage: ${highPriorityUsageRate.toStringAsFixed(1)}%
  Average Flush Time: ${averageFlushTime.toStringAsFixed(2)}μs
  Average Propagation Time: ${averagePropagationTime.toStringAsFixed(2)}μs
  
  Counters:
    Link Pool Hits: $_linkPoolHits
    Link Pool Misses: $_linkPoolMisses
    Batched Updates: $_batchedUpdates
    Immediate Updates: $_immediateUpdates
    High Priority Effects: $_highPriorityEffects
    Normal Priority Effects: $_normalPriorityEffects
''';
  }
}

/// Global performance monitor instance.
final performanceMonitor = PerformanceMonitor();