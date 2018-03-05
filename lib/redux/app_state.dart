import 'package:meta/meta.dart';

@immutable
class AppState {
  final int counter;

  AppState({
    this.counter = 0,
  });

  AppState copyWith({int counter}) => new AppState(counter: counter ?? this.counter);
}
