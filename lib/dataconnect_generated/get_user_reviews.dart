part of 'generated.dart';

class GetUserReviewsVariablesBuilder {
  String userId;

  final FirebaseDataConnect _dataConnect;
  GetUserReviewsVariablesBuilder(this._dataConnect, {required  this.userId,});
  Deserializer<GetUserReviewsData> dataDeserializer = (dynamic json)  => GetUserReviewsData.fromJson(jsonDecode(json));
  Serializer<GetUserReviewsVariables> varsSerializer = (GetUserReviewsVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetUserReviewsData, GetUserReviewsVariables>> execute() {
    return ref().execute();
  }

  QueryRef<GetUserReviewsData, GetUserReviewsVariables> ref() {
    GetUserReviewsVariables vars= GetUserReviewsVariables(userId: userId,);
    return _dataConnect.query("GetUserReviews", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetUserReviewsReviews {
  final String id;
  final String movieId;
  final int rating;
  final String? text;
  GetUserReviewsReviews.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  movieId = nativeFromJson<String>(json['movieId']),
  rating = nativeFromJson<int>(json['rating']),
  text = json['text'] == null ? null : nativeFromJson<String>(json['text']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetUserReviewsReviews otherTyped = other as GetUserReviewsReviews;
    return id == otherTyped.id && 
    movieId == otherTyped.movieId && 
    rating == otherTyped.rating && 
    text == otherTyped.text;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, movieId.hashCode, rating.hashCode, text.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['movieId'] = nativeToJson<String>(movieId);
    json['rating'] = nativeToJson<int>(rating);
    if (text != null) {
      json['text'] = nativeToJson<String?>(text);
    }
    return json;
  }

  GetUserReviewsReviews({
    required this.id,
    required this.movieId,
    required this.rating,
    this.text,
  });
}

@immutable
class GetUserReviewsData {
  final List<GetUserReviewsReviews> reviews;
  GetUserReviewsData.fromJson(dynamic json):
  
  reviews = (json['reviews'] as List<dynamic>)
        .map((e) => GetUserReviewsReviews.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetUserReviewsData otherTyped = other as GetUserReviewsData;
    return reviews == otherTyped.reviews;
    
  }
  @override
  int get hashCode => reviews.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['reviews'] = reviews.map((e) => e.toJson()).toList();
    return json;
  }

  GetUserReviewsData({
    required this.reviews,
  });
}

@immutable
class GetUserReviewsVariables {
  final String userId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetUserReviewsVariables.fromJson(Map<String, dynamic> json):
  
  userId = nativeFromJson<String>(json['userId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetUserReviewsVariables otherTyped = other as GetUserReviewsVariables;
    return userId == otherTyped.userId;
    
  }
  @override
  int get hashCode => userId.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['userId'] = nativeToJson<String>(userId);
    return json;
  }

  GetUserReviewsVariables({
    required this.userId,
  });
}

