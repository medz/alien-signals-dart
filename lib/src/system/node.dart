import 'package:alien_signals/src/system/flags.dart';
import 'package:alien_signals/src/system/link.dart';

abstract class Node {
  Node({
    this.deps,
    this.depsTail,
    this.subs,
    this.subsTail,
    required this.flags,
  });

  Link? deps;
  Link? depsTail;
  Link? subs;
  Link? subsTail;
  Flags flags;
}
