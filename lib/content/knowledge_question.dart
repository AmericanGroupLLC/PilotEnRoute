/// One knowledge-test practice question.
///
/// The stems and choices are the FAA's own Private Pilot-Airplane (PAR)
/// sample questions, word for word. The FAA publishes no answer key, so each
/// answer is decided by the quoted FAA text in [quote] / [cite]; a question
/// whose answer could not be proved that way is not in the bank.
class KnowledgeQuestion {
  /// "PAR-04": the FAA sample number.
  final String id;
  final String stem;

  /// A, B and C in the FAA's order.
  final List<String> choices;

  /// Index into [choices].
  final int answer;
  final String explanation;

  /// The FAA sentence that decides the answer, verbatim.
  final String quote;

  /// Where [quote] is: "14 CFR 91.155(a)", "AIM 4-1-20(a)".
  final String cite;

  /// The ACS code the FAA printed with the question.
  final String acsCode;

  /// One of [KnowledgeQuestion.topics] keys.
  final String topic;

  const KnowledgeQuestion({
    required this.id,
    required this.stem,
    required this.choices,
    required this.answer,
    required this.explanation,
    required this.quote,
    required this.cite,
    required this.acsCode,
    required this.topic,
  });

  static const letters = ['A', 'B', 'C'];

  /// Display names for the topics.
  static const topics = <String, String>{
    'regulations': 'Regulations',
    'airspace': 'Airspace',
    'weather': 'Weather',
    'weather-services': 'Weather services',
    'performance': 'Performance',
    'weight-balance': 'Weight & balance',
    'aerodynamics': 'Aerodynamics',
    'systems': 'Systems',
    'instruments': 'Instruments',
    'navigation': 'Navigation',
    'airport-ops': 'Airport operations',
    'human-factors': 'Human factors',
    'adm': 'Decision making',
    'other': 'Other',
  };

  static String topicName(String key) => topics[key] ?? key;
}
