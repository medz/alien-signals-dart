import 'package:alien_signals/alien_signals.dart';
import 'package:alien_signals/preset.dart';
import 'package:alien_signals/system.dart';
import 'package:test/test.dart';

void main() {
  test('preset nodes are the public handles', () {
    final WritableSignal<int> source = SignalNode(
      flags: .mutable,
      currentValue: 1,
      pendingValue: 1,
    );
    final Computed<int> doubled = ComputedNode(
      flags: .none,
      getter: (_) => source() * 2,
    );

    expect(doubled(), 2);
    source.set(2);
    expect(doubled(), 4);

    expect(signal(0), isA<SignalNode<int>>());
    expect(computed((_) => 0), isA<ComputedNode<int>>());
    expect(effect(() {}), isA<EffectNode>());
    expect(effectScope(() {}), isA<EffectScopeNode>());
  });

  test('first computed run keeps repeated reads deduplicated', () {
    final source = signal(1);
    final unrelated = computed((_) => 0);
    ReactiveNode? node;
    final stop = effect(() {
      node = getActiveSub();
      source();
      unrelated();
      source();
    });

    var links = 0;
    for (var link = node!.deps; link != null; link = link.nextDep) {
      links++;
    }
    expect(links, 2);
    stop();
  });

  test('stopping a computed disposes child effects in reverse order', () {
    final disposed = <String>[];
    final value = computed((_) {
      effect(
        () =>
            () => disposed.add('first'),
      );
      effect(
        () =>
            () => disposed.add('second'),
      );
      return 0;
    });

    value();
    stop(value as ComputedNode<int>);
    expect(disposed, ['second', 'first']);
  });

  group('a node stopped during its own rerun keeps consistent links', () {
    void expectLinks(ReactiveNode node, List<Object> expected) {
      final forward = <Object>[], backward = <Object>[];
      for (var link = node.deps; link != null; link = link.nextDep) {
        forward.add(link.dep);
      }
      for (var link = node.depsTail; link != null; link = link.prevDep) {
        backward.insert(0, link.dep);
      }
      expect(forward, expected);
      expect(backward, expected);
    }

    final nodes = <String, void Function(void Function(void Function()))>{
      'effect': (body) {
        late Effect handle;
        handle = effect(() => body(() => handle()));
      },
      'computed': (body) {
        late Computed<int> value;
        value = computed((_) {
          body(() => stop(value as ReactiveNode));
          return 0;
        });
        effect(() {
          value();
        });
      },
    };

    for (final MapEntry(key: name, value: create) in nodes.entries) {
      test(name, () {
        final a = signal(0), b = signal(0), c = signal(0), other = signal(0);
        ReactiveNode? node;
        var runs = 0;
        create((stopSelf) {
          node ??= getActiveSub();
          a();
          if (++runs == 2) {
            stopSelf();
            other();
            return;
          }
          b();
          c();
        });

        a.set(1);
        expect(runs, 2);
        expectLinks(node!, [other]);
        expect((b as ReactiveNode).subs, isNull);
        expect((c as ReactiveNode).subs, isNull);
      });
    }
  });

  test('nullable computed values survive cached reads', () {
    final source = signal<int?>(null);
    final value = computed<int?>((_) => source());

    expect(value(), isNull);
    expect(value(), isNull);
    source.set(1);
    expect(value(), 1);
    source.set(null);
    expect(value(), isNull);
  });

  test('effects ignore callback results that are not cleanups', () {
    final source = signal(0);
    var runs = 0;
    final stop = effect(() {
      source();
      runs++;
      // Not an EffectCleanup: it requires an argument.
      return (int _) => fail('must not be called');
    });

    source.set(1);
    stop();
    expect(runs, 2);
  });
}
