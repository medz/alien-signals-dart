import 'package:alien_signals/src/system/node.dart';

class Link {
  Link({
    required this.dep,
    required this.sub,
    this.prevDep,
    this.nextDep,
    this.prevSub,
    this.nextSub,
  });

  Node dep;
  Node sub;
  Link? prevSub;
  Link? nextSub;
  Link? prevDep;
  Link? nextDep;
}
