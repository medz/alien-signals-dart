import 'package:alien_signals/alien_signals.dart';

void main() {
  print('🚀 Alien Signals Performance Optimization Demo\n');
  
  // Reset performance monitor for clean measurements
  performanceMonitor.reset();
  
  print('1. Testing Memory Pool Optimization...');
  _testMemoryPool();
  
  print('\n2. Testing Batch Update Optimization...');
  _testBatchUpdates();
  
  print('\n3. Testing Priority Effect Scheduling...');
  _testPriorityScheduling();
  
  print('\n📊 Performance Summary:');
  print(performanceMonitor.summary());
}

void _testMemoryPool() {
  // Create and dispose many effects to test memory pool
  final signals = List.generate(50, (i) => signal(i));
  final cleanupFunctions = <void Function()>[];
  
  // Create effects that will create many Link objects
  for (int i = 0; i < 50; i++) {
    cleanupFunctions.add(effect(() {
      for (final sig in signals) {
        sig(); // Read each signal to create links
      }
    }));
  }
  
  // Cleanup to return Links to pool
  for (final cleanup in cleanupFunctions) {
    cleanup();
  }
  
  print('   ✓ Created and disposed 50 effects with 2500 dependencies');
  print('   Memory pool hit rate: ${performanceMonitor.poolHitRate.toStringAsFixed(1)}%');
}

void _testBatchUpdates() {
  final count = signal(0);
  final doubled = computed((_) => count() * 2);
  final tripled = computed((_) => count() * 3);
  
  var effectRuns = 0;
  effect(() {
    doubled();
    tripled();
    effectRuns++;
  });
  
  // Without batching - multiple effect runs
  print('   Testing without batching:');
  final initialRuns = effectRuns;
  for (int i = 1; i <= 10; i++) {
    count(i);
  }
  print('   Effect ran ${effectRuns - initialRuns} times for 10 updates');
  
  // With batching - single effect run
  print('   Testing with batching:');
  final batchedStartRuns = effectRuns;
  startBatch();
  for (int i = 11; i <= 20; i++) {
    count(i);
  }
  endBatch();
  print('   Effect ran ${effectRuns - batchedStartRuns} times for 10 batched updates');
  print('   Batch utilization rate: ${performanceMonitor.batchUtilizationRate.toStringAsFixed(1)}%');
}

void _testPriorityScheduling() {
  final trigger = signal(0);
  final results = <String>[];
  
  // Create effects with different priorities
  effect(() {
    trigger();
    results.add('Normal Priority Effect');
  }); // Default priority = 0
  
  effect(() {
    trigger();
    results.add('High Priority Effect');
  }, priority: 10);
  
  effect(() {
    trigger();
    results.add('Higher Priority Effect');
  }, priority: 20);
  
  // Trigger all effects
  results.clear();
  trigger(1);
  
  print('   Execution order:');
  for (int i = 0; i < results.length; i++) {
    print('   ${i + 1}. ${results[i]}');
  }
  
  print('   High priority effect usage: ${performanceMonitor.highPriorityUsageRate.toStringAsFixed(1)}%');
  print('   Average flush time: ${performanceMonitor.averageFlushTime.toStringAsFixed(2)}μs');
}