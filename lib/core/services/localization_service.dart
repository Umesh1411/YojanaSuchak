import 'package:flutter/material.dart';
import 'language_service.dart';

/// Localization Service - Provides translated strings for the app
class LocalizationService {
  static LocalizationService? _instance;
  static Locale _currentLocale = LanguageService.defaultLocale;

  LocalizationService._internal();

  factory LocalizationService() {
    _instance ??= LocalizationService._internal();
    return _instance!;
  }

  static Locale get currentLocale => _currentLocale;

  static Future<void> initialize() async {
    _currentLocale = await LanguageService.getCurrentLanguage();
  }

  static void setLocale(Locale locale) {
    _currentLocale = locale;
  }

  // Translations map
  static Map<String, Map<String, String>> _translations = {
    'en': {
      // App
      'appName': 'YojanaSuchak',
      'appTagline': 'Your Voice-Powered Scheme Assistant',
      
      // Common
      'continue': 'Continue',
      'skip': 'Skip',
      'next': 'Next',
      'back': 'Back',
      'done': 'Done',
      'cancel': 'Cancel',
      'save': 'Save',
      'edit': 'Edit',
      'delete': 'Delete',
      'logout': 'Logout',
      
      // Chatbot
      'chatbotGreeting': 'Hello! I am YojanaSuchak Assistant. I can help you find the best government schemes. Let\'s start by getting to know you.',
      'askAge': 'What is your age?',
      'askGender': 'What is your gender? (Male/Female/Other)',
      'askState': 'Which state do you belong to?',
      'askDistrict': 'Which district do you live in?',
      'askIncome': 'What is your approximate annual income in rupees?',
      'askOccupation': 'What is your occupation? (e.g., Teacher, Engineer, Farmer, Student, Business, Government Employee, etc.)',
      'askCategory': 'What is your category? (Student, Farmer, Woman, Senior Citizen, Unemployed, General)',
      'analyzingSchemes': 'Thank you! I am analyzing the best schemes for you. Please wait...',
      'schemesRecommended': 'Here are the top {count} schemes recommended for you:',
      'schemesRecommendedReplace': '{count}',
      'whichSchemeDetails': 'Which scheme would you like to know more about?',
      'sendEmailQuestion': 'Would you like to receive these details via email?',
      'errorOccurred': 'Sorry, I encountered an error. Please try again.',
      'noSchemesFound': 'I apologize, but I couldn\'t find any schemes that match your criteria at this time.',
      
      // Home
      'findScheme': 'Find Scheme',
      'welcome': 'Welcome',
      'discoverSchemes': 'Discover the best government schemes for you',
      
      // Menu
      'profile': 'Profile',
      'mySchemes': 'My Schemes',
      'contactUs': 'Contact Us',
      'settings': 'Settings',
      'rateUs': 'Rate Us',
      'about': 'About',
      'selectLanguage': 'Select Language',
    },
    'hi': {
      // App
      'appName': 'योजनासूचक',
      'appTagline': 'आपका स्वर-संचालित योजना सहायक',
      
      // Common
      'continue': 'जारी रखें',
      'skip': 'छोड़ें',
      'next': 'अगला',
      'back': 'वापस',
      'done': 'पूर्ण',
      'cancel': 'रद्द करें',
      'save': 'सहेजें',
      'edit': 'संपादित करें',
      'delete': 'हटाएं',
      'logout': 'लॉगआउट',
      
      // Chatbot
      'chatbotGreeting': 'नमस्ते! मैं योजनासूचक सहायक हूं। मैं आपको सर्वोत्तम सरकारी योजनाएं खोजने में मदद कर सकता हूं। आइए आपको जानने से शुरू करें।',
      'askAge': 'आपकी उम्र क्या है?',
      'askGender': 'आपका लिंग क्या है? (पुरुष/महिला/अन्य)',
      'askState': 'आप किस राज्य से हैं?',
      'askDistrict': 'आप किस जिले में रहते हैं?',
      'askIncome': 'आपकी अनुमानित वार्षिक आय रुपये में क्या है?',
      'askOccupation': 'आपका व्यवसाय क्या है? (जैसे, शिक्षक, इंजीनियर, किसान, छात्र, व्यवसाय, सरकारी कर्मचारी, आदि)',
      'askCategory': 'आपकी श्रेणी क्या है? (छात्र, किसान, महिला, वरिष्ठ नागरिक, बेरोजगार, सामान्य)',
      'analyzingSchemes': 'धन्यवाद! मैं आपके लिए सर्वोत्तम योजनाओं का विश्लेषण कर रहा हूं। कृपया प्रतीक्षा करें...',
      'schemesRecommended': 'यहां आपके लिए शीर्ष {count} योजनाएं अनुशंसित हैं:',
      'schemesRecommendedReplace': '{count}',
      'whichSchemeDetails': 'आप किस योजना के बारे में अधिक जानना चाहेंगे?',
      'sendEmailQuestion': 'क्या आप इन विवरणों को ईमेल के माध्यम से प्राप्त करना चाहेंगे?',
      'errorOccurred': 'क्षमा करें, मुझे एक त्रुटि का सामना करना पड़ा। कृपया पुनः प्रयास करें।',
      'noSchemesFound': 'मैं क्षमा चाहता हूं, लेकिन मुझे आपकी कसौटी से मेल खाने वाली कोई योजना नहीं मिली।',
      
      // Home
      'findScheme': 'योजना खोजें',
      'welcome': 'स्वागत है',
      'discoverSchemes': 'अपने लिए सर्वोत्तम सरकारी योजनाएं खोजें',
      
      // Menu
      'profile': 'प्रोफ़ाइल',
      'mySchemes': 'मेरी योजनाएं',
      'contactUs': 'संपर्क करें',
      'settings': 'सेटिंग्स',
      'rateUs': 'हमें रेट करें',
      'about': 'के बारे में',
      'selectLanguage': 'भाषा चुनें',
    },
    'mr': {
      // App
      'appName': 'योजनासूचक',
      'appTagline': 'तुमचा व्हॉइस-पॉवर केलेला योजना सहाय्यक',
      
      // Common
      'continue': 'सुरू ठेवा',
      'skip': 'वगळा',
      'next': 'पुढे',
      'back': 'मागे',
      'done': 'पूर्ण',
      'cancel': 'रद्द करा',
      'save': 'जतन करा',
      'edit': 'संपादन करा',
      'delete': 'हटवा',
      'logout': 'लॉगआउट',
      
      // Chatbot
      'chatbotGreeting': 'नमस्कार! मी योजनासूचक सहाय्यक आहे. मी तुम्हाला सर्वोत्तम सरकारी योजना शोधण्यात मदत करू शकतो. चला तुम्हाला ओळखून सुरुवात करूया.',
      'askAge': 'तुमचे वय किती आहे?',
      'askGender': 'तुमचे लिंग काय आहे? (पुरुष/स्त्री/इतर)',
      'askState': 'तुम्ही कोणत्या राज्यातील आहात?',
      'askDistrict': 'तुम्ही कोणत्या जिल्ह्यात राहतात?',
      'askIncome': 'तुमचे अंदाजे वार्षिक उत्पन्न रुपयांमध्ये किती आहे?',
      'askOccupation': 'तुमचे व्यवसाय काय आहे? (उदा., शिक्षक, अभियंता, शेतकरी, विद्यार्थी, व्यवसाय, सरकारी कर्मचारी, इ.)',
      'askCategory': 'तुमची श्रेणी काय आहे? (विद्यार्थी, शेतकरी, स्त्री, वरिष्ठ नागरिक, बेरोजगार, सामान्य)',
      'analyzingSchemes': 'धन्यवाद! मी तुमच्यासाठी सर्वोत्तम योजनांचे विश्लेषण करत आहे. कृपया प्रतीक्षा करा...',
      'schemesRecommended': 'येथे तुमच्यासाठी शीर्ष {count} योजना शिफारस केल्या आहेत:',
      'schemesRecommendedReplace': '{count}',
      'whichSchemeDetails': 'तुम्ही कोणत्या योजनेबद्दल अधिक जाणून घ्यायचे?',
      'sendEmailQuestion': 'तुम्हाला ही तपशील ईमेलद्वारे प्राप्त करायचे आहेत का?',
      'errorOccurred': 'माफ करा, मला एक त्रुटी आली. कृपया पुन्हा प्रयत्न करा.',
      'noSchemesFound': 'मला माफी मागायची आहे, पण मला तुमच्या निकषांशी जुळणारी कोणतीही योजना सध्या सापडली नाही.',
      
      // Home
      'findScheme': 'योजना शोधा',
      'welcome': 'स्वागत आहे',
      'discoverSchemes': 'तुमच्यासाठी सर्वोत्तम सरकारी योजना शोधा',
      
      // Menu
      'profile': 'प्रोफाइल',
      'mySchemes': 'माझ्या योजना',
      'contactUs': 'संपर्क साधा',
      'settings': 'सेटिंग्ज',
      'rateUs': 'आम्हाला रेट करा',
      'about': 'बद्दल',
      'selectLanguage': 'भाषा निवडा',
    },
  };

  String translate(String key, {Map<String, String>? params}) {
    String languageCode = _currentLocale.languageCode;
    String translation = _translations[languageCode]?[key] ?? 
                         _translations['en']?[key] ?? 
                         key;
    
    // Replace parameters
    if (params != null) {
      params.forEach((paramKey, value) {
        translation = translation.replaceAll('{$paramKey}', value);
      });
    }
    
    return translation;
  }

  // Shortcut methods for common translations
  static String get(String key, {Map<String, String>? params}) {
    return LocalizationService().translate(key, params: params);
  }
}

