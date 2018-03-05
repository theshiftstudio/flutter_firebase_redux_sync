# Flutter, Redux and Firebase Cloud Firestore - in sync

Cloud Firestore is a great persistence option to keep your data in sync
across mobile and web clients. Redux is a great solution to manage your
application's state in a way that's easier to reason about.

Things get a bit hairy when you try to integrate an external event
driven service, like Firestore or Firebase Realtime Database, into the
synchronous world of redux. You need to figure out:
- how to maintain the connection between Redux and Firestore
- where to START listening for data change events
- where to STOP listening for those events

In this article I'll showcase one way of solving this problem. I'm using
Flutter as the context, but the ideas I'm presenting could be used in
other environments as well, like react/react-native.

## Getting started

### What are we doing today?

We'll make a simple counter app with redux, add Cloud Firestore to it
and keep the redux store in sync with data from Firestore.

### How are going to do that?

Using [redux.dart](https://pub.dartlang.org/packages/redux),
[flutter_redux](https://pub.dartlang.org/packages/flutter_redux) and
[redux_epics](https://pub.dartlang.org/packages/redux_epics).

How exactly? Keep reading... :)

### Do you need to know some stuff & things?

- basic understanding of
  [Firebase Cloud Firestore](https://firebase.google.com/docs/firestore/)
  for Android/iOS/web
- be able to make a simple [Flutter](https://flutter.io/) app
- basic concepts of
  [Redux](https://github.com/johnpryan/redux.dart/blob/master/doc/basics.md)
- basic
  [Rx* concepts / Dart Streams](https://pub.dartlang.org/packages/rxdart)


## Project setup

We're going to keep it simple and use the default counter app that gets
created when you make a new project in Flutter.

So make a new project using either Android Studio, Intellij Idea or the
command line with `flutter create`.

Right now, the app uses a `StatefulWidget` to save the counter. Let's
switch it to redux!

## Reduxing our counter

I'll assume you already know how redux works so I won't go too much into
detail how to implement it for the counter app.

Add redux dependencies to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  redux: "^2.1.1"
  flutter_redux: "^0.3.5"
```

The [redux](https://pub.dartlang.org/packages/redux) package is a great
Dart port by [Brian Egan](https://twitter.com/brianegan) and
[John Ryan](https://twitter.com/jryanio). It's a plain Dart package, so
you can use it for a command line application as well, not only Flutter.

The [flutter_redux](https://pub.dartlang.org/packages/flutter_redux)
package (say thanks to Brian!) gives us the glue we need to marry
together redux and Flutter.

### Implement redux, already!

First, we need to define the `AppState` that will be saved in the redux
store.

```dart
class AppState {
  final int counter;

  AppState({
    this.counter = 0,
  });

  AppState copyWith({int counter}) => new AppState(counter: counter ?? this.counter);
}
```

We have one action that can change the state: a simple
`IncrementCounterAction`.

```dart
class IncrementCounterAction {}
```

The reducer is pretty straightforward.

```dart
AppState appStateReducer(AppState state, dynamic action) {
  return new AppState(
    counter: counterReducer(state.counter, action),
  );
}

final counterReducer = combineTypedReducers<int>([
  new ReducerBinding<int, IncrementCounterAction>(_incrementCounter),
]);

int _incrementCounter(int oldCounter, action) {
  return oldCounter + 1;
}
```

We can put everything together in `main.dart`.

```dart
void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  final store = new Store<AppState>(
    appStateReducer,
    initialState: new AppState(),
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
```

The redux implementation is pretty straightforward:
- the store is just a final field of `MyApp` widget;
- we use a
  [`StoreProvider`](https://github.com/brianegan/flutter_redux/blob/master/lib/flutter_redux.dart#L12)
  from the flutter_redux package to expose the store to the widget tree;
- down in the widget tree,
  [`StoreBuilder`](https://github.com/brianegan/flutter_redux/blob/master/lib/flutter_redux.dart#L174)
  gets the `AppState` and renders the counter;
- when pressed, the **+** action button dispatches an
  `IncrementCounterAction` to the store.

## Adding Firebase into the mix

If you need help with Firebase integration, there is a great
[codelab](https://codelabs.developers.google.com/codelabs/flutter-firebase/#4)
that does just that. The only difference is that we'll be using only
`cloud_firestore` for this demo.

Add firestore dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  ...
  cloud_firestore: "^0.2.10"
```

### Again, what do we want to accomplish?

- persist our application state to Firestore;
- each time Firestore emits a data change event we want the redux store
  to get updated with the latest value.

If we do this right, we'll be able to count clicks from multiple devices
and see changes happening in real time.

### "Firestore is our real truth!" Amen!

`MyHomePage` is the widget that gets the counter from the store and
renders it. As long as this widget is being displayed to the user we
want the redux store to be in sync with Firestore.

Flutter offers a very easy way to **init** subscriptions when a widget
is displayed for the first time and **dispose** them when the widget is
gone: we override `initState()` and `dispose()` methods from the `State`
class.

But "we no longer have a `State<MyHomePage>`", you might say...

No worries, both `StoreBuilder` and `StoreConnector` have 2 callbacks,
`onInit` and `onDispose`, that we can use.

From **flutter_redux**:

```dart
  /// A function that will be run when the StoreConnector is initially created.
  /// It is run in the [State.initState] method.
  ///
  /// This can be useful for dispatching actions that fetch data for your Widget
  /// when it is first displayed.
  final OnInitCallback onInit;

  /// A function that will be run when the StoreBuilder is removed from the
  /// Widget Tree.
  ///
  /// It is run in the [State.dispose] method.
  ///
  /// This can be useful for dispatching actions that remove stale data from
  /// your State tree.
  final OnDisposeCallback onDispose;
```

Perfect! Now we know when to **start** and **stop** the Firestore
connection.

Let's add the actions and dispatch them.

```dart
class RequestCounterDataEventsAction {}

class CancelCounterDataEventsAction {}
```

```dart
class MyHomePage extends StatelessWidget {
  ...

  @override
  Widget build(BuildContext context) {
    return new StoreBuilder(
      onInit: (store) => store.dispatch(new RequestCounterDataEventsAction()),
      onDispose: (store) => store.dispatch(new CancelCounterDataEventsAction()),
      ...
}
```

We need another action, let's call it `CounterOnDataEventAction`, that
will be dispatched each time Firestore fires a data change event for our
counter value. This will come in handy in the next section.

```dart
class CounterOnDataEventAction {
  final int counter;

  CounterOnDataEventAction(this.counter);
}
```

Next we need to create a middleware that will watch for our **request**
and **cancel** actions and **manage** the connection to Firestore.

### Middleware madness with redux_epics & RxDart

#### redux_epics intro

With **redux.dart**, a middleware is just a function that receives the
store, the dispatched action and a dispatcher (should you choose to let
the action flow through).

```dart
void boringMiddleware(Store<SomeState> store, dynamic action, NextDispatcher next) {
  print('action $action dispatched at ${new DateTime.now()}');
  next(action);
}
```

What **redux_epics** brings to the table are Dart `Streams`. And Streams
are awesome for event driven systems like Firestore & Firebase Realtime
DB.

An
[Epic](https://github.com/brianegan/dart_redux_epics/blob/master/lib/src/epic.dart#L54)
is a function that receives a Stream of actions, handles some of those
actions and returns a new Stream of actions. <br/> That's it. Actions go
in, actions come out.

```dart
Stream<dynamic> exampleEpic(Stream<dynamic> actions, EpicStore<State> store) {
  return actions
    .where((action) => action is PerformSearchAction)
    .asyncMap((action) =>
      // Pseudo api that returns a Future of SearchResults
      api.search((action as PerformSearch).searchTerm)
        .then((results) => new SearchResultsAction(results))
        .catchError((error) => new SearchErrorAction(error)));
}
```

The actions you emit from your Epics are dispatched to your store, so
writing an Epic that simply returns the original actions Stream will
result in an infinite loop.

```dart
Stream<dynamic> infiniteLoopEpic(Stream<dynamic> actions, EpicStore<State> store) {
  return actions;
}
```

**Do not do this!**

#### epic dependencies!

Ok, now let's add the redux_epics dependency to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  ...
  redux_epics: "^0.8.0"
```

redux_epics comes packed with
[RxDart](https://pub.dartlang.org/packages/rxdart).

RxDart gives us a Stream on steroids, called
[Observable](https://www.dartdocs.org/documentation/rxdart/0.15.1/rx/Observable-class.html).
Observable is a subclass of Stream, so we can use it whenever we need a
Stream.

#### sync. what you came for.

Now everything comes together nicely!

```dart
Stream<dynamic> counterEpic(Stream<dynamic> actions, EpicStore<AppState> store) {
  return new Observable(actions) // 1
      .ofType(new TypeToken<RequestCounterDataEventsAction>()) // 2
      .flatMapLatest((RequestCounterDataEventsAction requestAction) { // 3
        return getUserClicks() // 4
            .map((counter) => new CounterOnDataEventAction(counter)) // 5
            .takeUntil(actions.where((action) => action is CancelCounterDataEventsAction)); // 6
  });
}

Observable<int> getUserClicks() {
  return new Observable(Firestore.instance.document("users/tudor").snapshots) // 4.1
      .map((DocumentSnapshot doc) => doc['counter'] as int); // 4.2
}
```

Let's see what's happening in `counterEpic`, step by step:
1. we create a new Observable from the actions Stream, so we'll get
   operators like `map()`, `ofType()` and `flatMapLatest()`;
2. [`ofType()`](https://www.dartdocs.org/documentation/rxdart/0.15.1/rx/Observable/ofType.html)
   operator filters the Observable, letting pass only actions of type
   `RequestCounterDataEventsAction` and casts those actions from
   `dynamic` to `RequestCounterDataEventsAction`;
3. [`flatMapLatest()`](https://www.dartdocs.org/documentation/rxdart/0.15.1/rx/Observable/flatMapLatest.html)
   (in RxJava2 it's called `switchMap`) takes our request action and
   returns a new Observable that will emit `CounterOnDataEventAction`s
   and dispose the previously created Observable; <br>(for more details
   about
   [flatMap, switchMap & co](https://medium.com/appunite-edu-collection/rxjava-flatmap-switchmap-and-concatmap-differences-examples-6d1f3ff88ee0))
4. each time a document changes on Firestore, `document.snapshots`
   Stream emits a new `DocumentSnapshot` with those changes
   1. make a new Observable out of the `snapshots` Stream;
   2. extract the **counter** value from the document snapshot;
5. wrap each counter value into a `CounterOnDataEventAction` that will
   be dispatched to our store;
6. [`takeUntil()`](https://www.dartdocs.org/documentation/rxdart/0.15.1/rx/Observable/takeUntil.html)
   is where we close the connection to Firestore (remember the snapshots
   Stream?) when the input actions stream emits a
   `CancelCounterDataEventsAction`.

Now we need to update our `counterReducer` to handle
`CounterOnDataEventAction`.

```dart
final counterReducer = combineTypedReducers<int>([
  new ReducerBinding<int, CounterOnDataEventAction>(_setCounter),
]);

int _setCounter(int oldCounter, CounterOnDataEventAction action) {
  return action.counter;
}
```

That's it! We have an Epic that will keep our redux store in sync with
Firestore.

There's only one thing missing: we can no longer increment our counter!

Let's fix that with another Epic.

```dart
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
```

Each time `IncrementCounterAction` is dispatched, we increment the
counter value by 1 and return a new Observable that will emit
`CounterDataPushedAction` if Firestore updated our counter successfully,
or `CounterOnErrorEventAction` if something went wrong.

We don't really need `CounterDataPushedAction` for anything, but we
should fulfill the Epics contract: actions go in, actions come out, not
nulls. :)

I'll leave it up to you to handle the error action (maybe display a
Toast).

#### wiring up

The only thing left is wiring our middleware to the store.

```dart
final allEpics = combineEpics<AppState>([counterEpic, incrementEpic]);

...

final store = new Store<AppState>(
  appStateReducer,
  initialState: new AppState(),
  middleware: [new EpicMiddleware(allEpics)]
);

```

Both `EpicMiddleware` and `combineEpics` are provided by
**redux_epics**.

## Wrap-up

This pattern allows us to keep the widgets simple and testable and
offers an efficient way to hook-up into an external event driven system
like Cloud Firestore, or Firebase Realtime Database.

This was a long read, I know. Thanks for hanging in there!

You can find the entire project on
[github](https://github.com/theshiftstudio/flutter_firebase_redux_sync).
Also, please give some love to the awesome packages we used in this
article.

Note: If want to use Cloud Firestore in your projects please vote for
[this](https://github.com/flutter/plugins/pull/343) pull request and the
covered issues. I need those timestamps.

## About Shift STUDIO

[Shift STUDIO](https://shiftstudio.com/) is a development studio that
works with great companies to create amazing apps. We have been building
native apps for Android and iOS ever since mobile became a thing... but
Flutter got as all wet and excited like never before!


If you wanna see more articles like this, follow us on twitter
[@shiftstudiodevs](https://twitter.com/shiftstudiodevs) .

[Contact us](mailto:hello@shiftstudio.com) about your digital project.
