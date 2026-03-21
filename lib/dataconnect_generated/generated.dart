library dataconnect_generated;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'add_new_watch.dart';

part 'get_public_movie_lists.dart';

part 'update_review.dart';

part 'get_user_reviews.dart';







class ExampleConnector {
  
  
  AddNewWatchVariablesBuilder addNewWatch ({required String movieId, required String userId, required DateTime watchDate, }) {
    return AddNewWatchVariablesBuilder(dataConnect, movieId: movieId,userId: userId,watchDate: watchDate,);
  }
  
  
  GetPublicMovieListsVariablesBuilder getPublicMovieLists () {
    return GetPublicMovieListsVariablesBuilder(dataConnect, );
  }
  
  
  UpdateReviewVariablesBuilder updateReview ({required String id, }) {
    return UpdateReviewVariablesBuilder(dataConnect, id: id,);
  }
  
  
  GetUserReviewsVariablesBuilder getUserReviews ({required String userId, }) {
    return GetUserReviewsVariablesBuilder(dataConnect, userId: userId,);
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east4',
    'example',
    'app',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    return ExampleConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
