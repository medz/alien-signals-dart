import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('dart2js can compile a basic alien_signals entrypoint', () async {
    final tempDir = await Directory.systemTemp
        .createTemp('alien_signals_dart2js_compile_');
    final outputPath =
        '${tempDir.path}${Platform.pathSeparator}alien_signals_entry.js';

    try {
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['compile', 'js', 'test/fixtures/dart2js_entry.dart', '-o', outputPath],
        workingDirectory: Directory.current.path,
      );

      if (result.exitCode != 0) {
        fail(
          'dart2js compile failed (exit ${result.exitCode}).\n'
          'stdout: ${result.stdout}\n'
          'stderr: ${result.stderr}',
        );
      }

      expect(await File(outputPath).exists(), isTrue);
    } finally {
      await tempDir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
