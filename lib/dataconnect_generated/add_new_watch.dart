part of 'generated.dart';

class AddNewWatchVariablesBuilder {
  String movieId;
  String userId;
  DateTime watchDate;

  final FirebaseDataConnect _dataConnect;
  AddNewWatchVariablesBuilder(this._dataConnect, {required  this.movieId,required  this.userId,required  this.watchDate,});
  Deserializer<AddNewWatchData> dataDeserializer = (dynamic json)  => AddNewWatchData.fromJson(jsonDecode(json));
  Serializer<AddNewWatchVariables> varsSerializer = (AddNewWatchVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<AddNewWatchData, AddNewWatchVariables>> execute() {
    return ref().execute();
  }

  MutationRef<AddNewWatchData, AddNewWatchVariables> ref() {
    AddNewWatchVariables vars= AddNewWatchVariables(movieId: movieId,userId: userId,watchDate: watchDate,);
    return _dataConnect.mutation("AddNewWatch", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class AddNewWatchWatchInsert {
  final String id;
  AddNewWatchWatchInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AddNewWatchWatchInsert otherTyped = other as AddNewWatchWatchInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  AddNewWatchWatchInsert({
    required this.id,
  });
}

@immutable
class AddNewWatchData {
  final AddNewWatchWatchInsert watch_insert;
  AddNewWatchData.fromJson(dynamic json):
  
  watch_insert = AddNewWatchWatchInsert.fromJson(json['watch_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AddNewWatchData otherTyped = other as AddNewWatchData;
    return watch_insert == otherTyped.watch_insert;
    
  }
  @override
  int get hashCode => watch_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['watch_insert'] = watch_insert.toJson();
    return json;
  }

  AddNewWatchData({
    required this.watch_insert,
  });
}

@immutable
class AddNewWatchVariables {
  final String movieId;
  final String userId;
  final DateTime watchDate;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  AddNewWatchVariables.fromJson(Map<String, dynamic> json):
  
  movieId = nativeFromJson<String>(json['movieId']),
  userId = nativeFromJson<String>(json['userId']),
  watchDate = nativeFromJson<DateTime>(json['watchDate']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AddNewWatchVariables otherTyped = other as AddNewWatchVariables;
    return movieId == otherTyped.movieId && 
    userId == otherTyped.userId && 
    watchDate == otherTyped.watchDate;
    
  }
  @override
  int get hashCode => Object.hashAll([movieId.hashCode, userId.hashCode, watchDate.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['movieId'] = nativeToJson<String>(movieId);
    json['userId'] = nativeToJson<String>(userId);
    json['watchDate'] = nativeToJson<DateTime>(watchDate);
    return json;
  }

  AddNewWatchVariables({
    required this.movieId,
    required this.userId,
    required this.watchDate,
  });
}

