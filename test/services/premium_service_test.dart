import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilot_enroute/services/premium_service.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PremiumService', () {
    // PremiumService is a singleton — get the shared instance
    final service = PremiumService();

    test('initializes with free tier by default', () {
      expect(service.isPremium, isFalse);
      expect(service.tier, equals(PremiumTier.free));
    });

    test('isLoading is false initially', () {
      expect(service.isLoading, isFalse);
    });

    test('errorMessage is null initially', () {
      expect(service.errorMessage, isNull);
    });

    test('products list is empty before loading', () {
      expect(service.products, isEmpty);
    });

    test('free user does not have premium features', () {
      expect(service.hasFeature(PremiumFeature.adFree), isFalse);
      expect(service.hasFeature(PremiumFeature.unlimitedExams), isFalse);
      expect(service.hasFeature(PremiumFeature.logbookExport), isFalse);
    });
  });

  group('PremiumFeature constants', () {
    test('adFree constant is defined', () {
      expect(PremiumFeature.adFree, equals('ad_free'));
    });

    test('unlimitedExams constant is defined', () {
      expect(PremiumFeature.unlimitedExams, equals('unlimited_exams'));
    });

    test('logbookExport constant is defined', () {
      expect(PremiumFeature.logbookExport, equals('logbook_export'));
    });

    test('advancedWeather constant is defined', () {
      expect(PremiumFeature.advancedWeather, equals('advanced_weather'));
    });

    test('flightPlanner constant is defined', () {
      expect(PremiumFeature.flightPlanner, equals('flight_planner'));
    });

    test('offlineMode constant is defined', () {
      expect(PremiumFeature.offlineMode, equals('offline_mode'));
    });

    test('aiInstructor constant is defined', () {
      expect(PremiumFeature.aiInstructor, equals('ai_instructor'));
    });

    test('allAircraft constant is defined', () {
      expect(PremiumFeature.allAircraft, equals('all_aircraft'));
    });
  });

  group('PremiumTier enum', () {
    test('has four tiers', () {
      expect(PremiumTier.values.length, equals(4));
    });

    test('free tier is first', () {
      expect(PremiumTier.free.index, equals(0));
    });

    test('all tier values exist', () {
      expect(PremiumTier.values, contains(PremiumTier.free));
      expect(PremiumTier.values, contains(PremiumTier.monthly));
      expect(PremiumTier.values, contains(PremiumTier.yearly));
      expect(PremiumTier.values, contains(PremiumTier.lifetime));
    });
  });
}
