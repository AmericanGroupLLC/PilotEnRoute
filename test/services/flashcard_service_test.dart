import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/flashcard_service.dart';

void main() {
  group('FlashcardService', () {
    late FlashcardService service;

    setUp(() {
      service = FlashcardService();
    });

    test('initializes with empty cards before loading', () {
      expect(service.cards, isEmpty);
      expect(service.currentIndex, equals(0));
      expect(service.isFlipped, isFalse);
    });

    test('flip toggles isFlipped state', () {
      service.flip();
      expect(service.isFlipped, isTrue);
      service.flip();
      expect(service.isFlipped, isFalse);
    });

    test('categories getter returns a list', () {
      final cats = service.categories;
      expect(cats, isA<List<String>>());
    });

    test('categories always includes All', () {
      final cats = service.categories;
      expect(cats, contains('All'));
    });

    test('currentCard returns null when no cards loaded', () {
      expect(service.currentCard, isNull);
    });

    test('setCategory does not crash', () {
      expect(() => service.setCategory('All'), returnsNormally);
    });

    test('setCategory to unknown category does not crash', () {
      expect(() => service.setCategory('Unknown Category'), returnsNormally);
    });
  });

  group('Flashcard model', () {
    test('creates Flashcard with required fields', () {
      final card = Flashcard(
        id: 'fc-001',
        question: 'What is the standard temperature at sea level?',
        answer: '15°C (59°F)',
        category: 'Meteorology',
      );
      expect(card.id, equals('fc-001'));
      expect(card.question, isNotEmpty);
      expect(card.answer, isNotEmpty);
      expect(card.category, equals('Meteorology'));
    });

    test('Flashcard default values are correct', () {
      final card = Flashcard(
        id: 'fc-002',
        question: 'What is VFR?',
        answer: 'Visual Flight Rules',
        category: 'Regulations',
      );
      expect(card.reviewCount, equals(0));
      expect(card.correctCount, equals(0));
      expect(card.isStarred, isFalse);
      expect(card.lastReviewed, isNull);
    });

    test('Flashcard accuracy is 0 with no reviews', () {
      final card = Flashcard(
        id: 'fc-003',
        question: 'What is IFR?',
        answer: 'Instrument Flight Rules',
        category: 'Regulations',
      );
      expect(card.accuracy, equals(0.0));
    });

    test('Flashcard accuracy calculates correctly', () {
      final card = Flashcard(
        id: 'fc-004',
        question: 'What is METAR?',
        answer: 'Meteorological Terminal Air Report',
        category: 'Weather',
        reviewCount: 10,
        correctCount: 8,
      );
      expect(card.accuracy, equals(0.8));
    });

    test('Flashcard toJson round-trips correctly', () {
      final card = Flashcard(
        id: 'fc-005',
        question: 'What is a TAF?',
        answer: 'Terminal Aerodrome Forecast',
        category: 'Weather',
        detail: 'Valid for 24-30 hours',
        reference: 'AIM 7-1-30',
      );
      final json = card.toJson();
      final restored = Flashcard.fromJson(json);
      expect(restored.id, equals(card.id));
      expect(restored.question, equals(card.question));
      expect(restored.answer, equals(card.answer));
      expect(restored.category, equals(card.category));
      expect(restored.detail, equals(card.detail));
      expect(restored.reference, equals(card.reference));
    });
  });
}
