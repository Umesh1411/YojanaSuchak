enum ConversationState {
  greeting,
  askAge,
  askDistrict,
  askIncome,
  askCategory,
  sendToGemini,
  result,
  error
}

extension ConversationStateExtension on ConversationState {
  String getMessage() {
    switch (this) {
      case ConversationState.greeting:
        return "Hello! I can help you find suitable schemes. Let's get started.";
      case ConversationState.askAge:
        return "Please tell me your age in years.";
      case ConversationState.askDistrict:
        return "Which district in Maharashtra do you live in?";
      case ConversationState.askIncome:
        return "What is your annual family income?";
      case ConversationState.askCategory:
        return "What is your category? For example, SC, ST, OBC, or General.";
      case ConversationState.sendToGemini:
        return "Thank you. Give me a moment while I find the best schemes for you.";
      case ConversationState.result:
        return "Here are the schemes I found based on your profile.";
      case ConversationState.error:
        return "I'm sorry, an error occurred while finding schemes.";
    }
  }
}
