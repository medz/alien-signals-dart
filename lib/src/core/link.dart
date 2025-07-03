import 'dependency.dart';
import 'subscriber.dart';

class Link {
  Link(this.dep, this.sub, {this.nextDep, this.nextSub, this.prevSub});

  final Dependency dep;
  final Subscriber sub;
  Link? nextDep;
  Link? nextSub;
  Link? prevSub;
}
