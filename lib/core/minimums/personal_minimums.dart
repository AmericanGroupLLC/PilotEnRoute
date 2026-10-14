/// The pilot's own limits, one set for day and one for night.
///
/// Every field starts empty and stays empty until the pilot types a number.
/// The app never suggests a value: personal minimums are the pilot's to set.
library;

class MinimumsSet {
  final int? ceilingFt;
  final double? visibilitySm;
  final int? maxWindKt;
  final int? maxGustKt;
  final int? maxCrosswindKt;

  const MinimumsSet({
    this.ceilingFt,
    this.visibilitySm,
    this.maxWindKt,
    this.maxGustKt,
    this.maxCrosswindKt,
  });

  static const blank = MinimumsSet();

  bool get isEmpty =>
      ceilingFt == null &&
      visibilitySm == null &&
      maxWindKt == null &&
      maxGustKt == null &&
      maxCrosswindKt == null;

  Map<String, Object?> toJson() => {
        'ceilingFt': ceilingFt,
        'visibilitySm': visibilitySm,
        'maxWindKt': maxWindKt,
        'maxGustKt': maxGustKt,
        'maxCrosswindKt': maxCrosswindKt,
      };

  factory MinimumsSet.fromJson(Map<String, Object?>? j) {
    if (j == null) return blank;
    return MinimumsSet(
      ceilingFt: (j['ceilingFt'] as num?)?.toInt(),
      visibilitySm: (j['visibilitySm'] as num?)?.toDouble(),
      maxWindKt: (j['maxWindKt'] as num?)?.toInt(),
      maxGustKt: (j['maxGustKt'] as num?)?.toInt(),
      maxCrosswindKt: (j['maxCrosswindKt'] as num?)?.toInt(),
    );
  }
}

class PersonalMinimums {
  final MinimumsSet day;
  final MinimumsSet night;

  const PersonalMinimums({this.day = MinimumsSet.blank, this.night = MinimumsSet.blank});

  static const blank = PersonalMinimums();

  bool get isEmpty => day.isEmpty && night.isEmpty;

  MinimumsSet forFlight({required bool night}) => night ? this.night : day;

  Map<String, Object?> toJson() =>
      {'day': day.toJson(), 'night': night.toJson()};

  factory PersonalMinimums.fromJson(Map<String, Object?>? j) {
    if (j == null) return blank;
    return PersonalMinimums(
      day: MinimumsSet.fromJson((j['day'] as Map?)?.cast<String, Object?>()),
      night:
          MinimumsSet.fromJson((j['night'] as Map?)?.cast<String, Object?>()),
    );
  }
}
