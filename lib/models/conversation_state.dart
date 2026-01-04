import '../core/services/localization_service.dart';

/// Enum representing different states in the conversation flow
enum ConversationState {
  greeting,
  askAge,
  askGender,
  askState,
  askDistrict,
  askIncome,
  askOccupation,
  askCategory,
  askSpecialCondition,
  sendToGemini,
  result,
  askSchemeDetails,
  sendEmail,
  error,
}

/// Extension to get user-friendly messages for each state
extension ConversationStateExtension on ConversationState {
  String getMessage() {
    switch (this) {
      case ConversationState.greeting:
        return LocalizationService.get('chatbotGreeting');
      case ConversationState.askAge:
        return LocalizationService.get('askAge');
      case ConversationState.askGender:
        return LocalizationService.get('askGender');
      case ConversationState.askState:
        return LocalizationService.get('askState');
      case ConversationState.askDistrict:
        return LocalizationService.get('askDistrict');
      case ConversationState.askIncome:
        return LocalizationService.get('askIncome');
      case ConversationState.askOccupation:
        return LocalizationService.get('askOccupation');
      case ConversationState.askCategory:
        return LocalizationService.get('askCategory');
      case ConversationState.askSpecialCondition:
        return LocalizationService.get('askCategory'); // Reuse category question
      case ConversationState.askSchemeDetails:
        return LocalizationService.get('whichSchemeDetails');
      case ConversationState.sendEmail:
        return LocalizationService.get('sendEmailQuestion');
      case ConversationState.sendToGemini:
        return LocalizationService.get('analyzingSchemes');
      case ConversationState.result:
        return LocalizationService.get('schemesRecommended', params: {'count': '3'});
      case ConversationState.error:
        return LocalizationService.get('errorOccurred');
    }
  }
}



