import 'package:flutter/material.dart';
import '../models/user_context_model.dart';

class UserContextProvider with ChangeNotifier {
  UserContext _userContext = UserContext.defaultContext();

  UserContext get userContext => _userContext;
  DetectedPersona get currentPersona => _userContext.primaryPersona;

  void setPersona(DetectedPersona persona) {
    _userContext = UserContext(
      userId: _userContext.userId,
      userName: _userContext.userName,
      primaryPersona: persona,
      confidenceScore: 0.95,
      detectedInterests: _userContext.detectedInterests,
      activeContextData: _userContext.activeContextData,
      lastUpdated: DateTime.now(),
    );
    notifyListeners();
  }

  void removeInterest(String interest) {
    final updatedList = List<String>.from(_userContext.detectedInterests)..remove(interest);
    _userContext = UserContext(
      userId: _userContext.userId,
      userName: _userContext.userName,
      primaryPersona: _userContext.primaryPersona,
      confidenceScore: _userContext.confidenceScore,
      detectedInterests: updatedList,
      activeContextData: _userContext.activeContextData,
      lastUpdated: DateTime.now(),
    );
    notifyListeners();
  }

  void addInterest(String interest) {
    if (!_userContext.detectedInterests.contains(interest)) {
      final updatedList = List<String>.from(_userContext.detectedInterests)..add(interest);
      _userContext = UserContext(
        userId: _userContext.userId,
        userName: _userContext.userName,
        primaryPersona: _userContext.primaryPersona,
        confidenceScore: _userContext.confidenceScore,
        detectedInterests: updatedList,
        activeContextData: _userContext.activeContextData,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
    }
  }
}
