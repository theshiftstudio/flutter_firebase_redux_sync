import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_redux_sync/redux/actions.dart';
import 'package:firebase_redux_sync/redux/app_state.dart';
import 'package:redux_epics/redux_epics.dart';
import 'package:rxdart/rxdart.dart';

final allEpics = combineEpics<AppState>([counterEpic, incrementEpic]);

Stream<dynamic> incrementEpic(Stream<dynamic> actions, EpicStore<AppState> store) {
  return new Observable(actions)
      .ofType(new TypeToken<IncrementCounterAction>())
      .flatMap((_) {
    return new Observable.fromFuture(Firestore.instance.document("users/tudor")
        .updateData({'counter': store.state.counter + 1})
        .then((_) => new CounterDataPushedAction())
        .catchError((error) => new CounterOnErrorEventAction(error)));
  });
}

Stream<dynamic> counterEpic(Stream<dynamic> actions, EpicStore<AppState> store) {
  return new Observable(actions)
      .ofType(new TypeToken<RequestCounterDataEventsAction>())
      .flatMapLatest((RequestCounterDataEventsAction requestAction) {
    return getUserClicks()
        .map((counter) => new CounterOnDataEventAction(counter))
        .takeUntil(actions.where((action) => action is CancelCounterDataEventsAction));
  });
}

Observable<int> getUserClicks() {
  return new Observable(Firestore.instance.document("users/tudor").snapshots)
      .map((doc) => doc['counter'] as int);
}
