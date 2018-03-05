import 'package:firebase_redux_sync/redux/actions.dart';
import 'package:firebase_redux_sync/redux/app_state.dart';
import 'package:firebase_redux_sync/redux/app_state_reducer.dart';
import 'package:firebase_redux_sync/redux/middleware.dart';
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux_epics/redux_epics.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  final store = new Store<AppState>(
    appStateReducer,
    initialState: new AppState(),
    middleware: [new EpicMiddleware(allEpics)]
  );

  @override
  Widget build(BuildContext context) {
    return new StoreProvider(
      store: store,
      child: new MaterialApp(
        title: 'Flutter: Firebase & Redux in sync',
        theme: new ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: new MyHomePage(title: 'Flutter: Firebase & Redux in sync'),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final String title;

  MyHomePage({Key key, this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new StoreBuilder(
      onInit: (store) => store.dispatch(new RequestCounterDataEventsAction()),
      onDispose: (store) => store.dispatch(new CancelCounterDataEventsAction()),
      builder: (context, Store<AppState> store) {
        return new Scaffold(
          appBar: new AppBar(
            title: new Text(title),
          ),
          body: new Center(
            child: new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Text('You have pushed the button this many times:'),
                new Text(
                  '${store.state.counter}',
                  style: Theme.of(context).textTheme.display1,
                ),
              ],
            ),
          ),
          floatingActionButton: new FloatingActionButton(
            onPressed: () {
              store.dispatch(new IncrementCounterAction());
            },
            tooltip: 'Increment',
            child: new Icon(Icons.add),
          ),
        );
      },
    );
  }
}
