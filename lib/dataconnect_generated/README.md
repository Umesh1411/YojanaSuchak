# dataconnect_generated SDK

## Installation
```sh
flutter pub get firebase_data_connect
flutterfire configure
```
For more information, see [Flutter for Firebase installation documentation](https://firebase.google.com/docs/data-connect/flutter-sdk#use-core).

## Data Connect instance
Each connector creates a static class, with an instance of the `DataConnect` class that can be used to connect to your Data Connect backend and call operations.

### Connecting to the emulator

```dart
String host = 'localhost'; // or your host name
int port = 9399; // or your port number
ExampleConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### GetPublicMovieLists
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.getPublicMovieLists().execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetPublicMovieListsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getPublicMovieLists();
GetPublicMovieListsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.getPublicMovieLists().ref();
ref.execute();

ref.subscribe(...);
```


### GetUserReviews
#### Required Arguments
```dart
String userId = ...;
ExampleConnector.instance.getUserReviews(
  userId: userId,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetUserReviewsData, GetUserReviewsVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getUserReviews(
  userId: userId,
);
GetUserReviewsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String userId = ...;

final ref = ExampleConnector.instance.getUserReviews(
  userId: userId,
).ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### AddNewWatch
#### Required Arguments
```dart
String movieId = ...;
String userId = ...;
DateTime watchDate = ...;
ExampleConnector.instance.addNewWatch(
  movieId: movieId,
  userId: userId,
  watchDate: watchDate,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<AddNewWatchData, AddNewWatchVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.addNewWatch(
  movieId: movieId,
  userId: userId,
  watchDate: watchDate,
);
AddNewWatchData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String movieId = ...;
String userId = ...;
DateTime watchDate = ...;

final ref = ExampleConnector.instance.addNewWatch(
  movieId: movieId,
  userId: userId,
  watchDate: watchDate,
).ref();
ref.execute();
```


### UpdateReview
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.updateReview(
  id: id,
).execute();
```

#### Optional Arguments
We return a builder for each query. For UpdateReview, we created `UpdateReviewBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class UpdateReviewVariablesBuilder {
  ...
   UpdateReviewVariablesBuilder text(String? t) {
   _text.value = t;
   return this;
  }
  UpdateReviewVariablesBuilder rating(int? t) {
   _rating.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.updateReview(
  id: id,
)
.text(text)
.rating(rating)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<UpdateReviewData, UpdateReviewVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateReview(
  id: id,
);
UpdateReviewData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.updateReview(
  id: id,
).ref();
ref.execute();
```

