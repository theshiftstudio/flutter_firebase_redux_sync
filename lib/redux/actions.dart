class IncrementCounterAction {}

class CounterDataPushedAction {}

class RequestCounterDataEventsAction {}

class CancelCounterDataEventsAction {}

class CounterOnDataEventAction {
  final int counter;

  CounterOnDataEventAction(this.counter);

  @override
  String toString() => 'CounterOnDataEventAction{counter: $counter}';
}

class CounterOnErrorEventAction {
  final dynamic error;

  CounterOnErrorEventAction(this.error);

  @override
  String toString() => 'CounterOnErrorEventAction{error: $error}';
}
