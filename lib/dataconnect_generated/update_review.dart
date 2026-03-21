part of 'generated.dart';

class UpdateReviewVariablesBuilder {
  String id;
  Optional<String> _text = Optional.optional(nativeFromJson, nativeToJson);
  Optional<int> _rating = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  UpdateReviewVariablesBuilder text(String? t) {
   _text.value = t;
   return this;
  }
  UpdateReviewVariablesBuilder rating(int? t) {
   _rating.value = t;
   return this;
  }

  UpdateReviewVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<UpdateReviewData> dataDeserializer = (dynamic json)  => UpdateReviewData.fromJson(jsonDecode(json));
  Serializer<UpdateReviewVariables> varsSerializer = (UpdateReviewVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateReviewData, UpdateReviewVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateReviewData, UpdateReviewVariables> ref() {
    UpdateReviewVariables vars= UpdateReviewVariables(id: id,text: _text,rating: _rating,);
    return _dataConnect.mutation("UpdateReview", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateReviewReviewUpdate {
  final String id;
  UpdateReviewReviewUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateReviewReviewUpdate otherTyped = other as UpdateReviewReviewUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateReviewReviewUpdate({
    required this.id,
  });
}

@immutable
class UpdateReviewData {
  final UpdateReviewReviewUpdate? review_update;
  UpdateReviewData.fromJson(dynamic json):
  
  review_update = json['review_update'] == null ? null : UpdateReviewReviewUpdate.fromJson(json['review_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateReviewData otherTyped = other as UpdateReviewData;
    return review_update == otherTyped.review_update;
    
  }
  @override
  int get hashCode => review_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (review_update != null) {
      json['review_update'] = review_update!.toJson();
    }
    return json;
  }

  UpdateReviewData({
    this.review_update,
  });
}

@immutable
class UpdateReviewVariables {
  final String id;
  late final Optional<String>text;
  late final Optional<int>rating;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateReviewVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']) {
  
  
  
    text = Optional.optional(nativeFromJson, nativeToJson);
    text.value = json['text'] == null ? null : nativeFromJson<String>(json['text']);
  
  
    rating = Optional.optional(nativeFromJson, nativeToJson);
    rating.value = json['rating'] == null ? null : nativeFromJson<int>(json['rating']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateReviewVariables otherTyped = other as UpdateReviewVariables;
    return id == otherTyped.id && 
    text == otherTyped.text && 
    rating == otherTyped.rating;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, text.hashCode, rating.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    if(text.state == OptionalState.set) {
      json['text'] = text.toJson();
    }
    if(rating.state == OptionalState.set) {
      json['rating'] = rating.toJson();
    }
    return json;
  }

  UpdateReviewVariables({
    required this.id,
    required this.text,
    required this.rating,
  });
}

