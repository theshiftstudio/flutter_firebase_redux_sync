import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_redux_sync/redux/actions.dart';
import 'package:firebase_redux_sync/redux/app_state.dart';
import 'package:redux/redux.dart';
import 'package:redux_epics/redux_epics.dart';
import 'package:rxdart/rxdart.dart';


AppState appStateReducer(AppState state, dynamic action) {
  return new AppState(
    counter: counterReducer(state.counter, action),
  );
}

final counterReducer = combineTypedReducers<int>([
  new ReducerBinding<int, CounterOnDataEventAction>(_setCounter),
]);

int _setCounter(int oldCounter, CounterOnDataEventAction action) {
  return action.counter;
}

