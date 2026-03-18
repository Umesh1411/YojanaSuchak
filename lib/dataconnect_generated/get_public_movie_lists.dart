part of 'generated.dart';

class GetPublicMovieListsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  GetPublicMovieListsVariablesBuilder(this._dataConnect, );
  Deserializer<GetPublicMovieListsData> dataDeserializer = (dynamic json)  => GetPublicMovieListsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<GetPublicMovieListsData, void>> execute() {
    return ref().execute();
  }

  QueryRef<GetPublicMovieListsData, void> ref() {
    
    return _dataConnect.query("GetPublicMovieLists", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class GetPublicMovieListsMovieLists {
  final String id;
  final String name;
  final String? description;
  GetPublicMovieListsMovieLists.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  name = nativeFromJson<String>(json['name']),
  description = json['description'] == null ? null : nativeFromJson<String>(json['description']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetPublicMovieListsMovieLists otherTyped = other as GetPublicMovieListsMovieLists;
    return id == otherTyped.id && 
    name == otherTyped.name && 
    description == otherTyped.description;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, name.hashCode, description.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['name'] = nativeToJson<String>(name);
    if (description != null) {
      json['description'] = nativeToJson<String?>(description);
    }
    return json;
  }

  GetPublicMovieListsMovieLists({
    required this.id,
    required this.name,
    this.description,
  });
}

@immutable
class GetPublicMovieListsData {
  final List<GetPublicMovieListsMovieLists> movieLists;
  GetPublicMovieListsData.fromJson(dynamic json):
  
  movieLists = (json['movieLists'] as List<dynamic>)
        .map((e) => GetPublicMovieListsMovieLists.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetPublicMovieListsData otherTyped = other as GetPublicMovieListsData;
    return movieLists == otherTyped.movieLists;
    
  }
  @override
  int get hashCode => movieLists.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['movieLists'] = movieLists.map((e) => e.toJson()).toList();
    return json;
  }

  GetPublicMovieListsData({
    required this.movieLists,
  });
}

