/// What the pilot tells the app about themselves. Stored on the device only.
///
/// No date of birth is stored: 61.23(d) only needs to know whether the pilot
/// was under 40 or 40 or older on the date of the medical examination, so that
/// is the one question asked.
library;

/// The medical qualification the pilot flies under.
enum MedicalKind {
  none('No medical on record'),
  first('First-class medical'),
  second('Second-class medical'),
  third('Third-class medical'),
  basicMed('BasicMed (14 CFR 61.113(i))');

  const MedicalKind(this.label);
  final String label;

  static MedicalKind fromName(String? name) => MedicalKind.values
      .firstWhere((m) => m.name == name, orElse: () => MedicalKind.none);
}

/// The privileges the pilot exercises, which decides which row of the
/// 61.23(d) table applies.
enum MedicalPrivilege {
  /// Private, recreational, student, sport, or flight instructor acting as
  /// PIC: needs third-class privileges.
  third('Private, recreational, student or CFI'),

  /// Commercial pilot privileges: needs second-class privileges.
  second('Commercial pilot'),

  /// ATP pilot-in-command: needs first-class privileges.
  first('Airline transport pilot (PIC)');

  const MedicalPrivilege(this.label);
  final String label;

  static MedicalPrivilege fromName(String? name) =>
      MedicalPrivilege.values.firstWhere((m) => m.name == name,
          orElse: () => MedicalPrivilege.third);
}

class PilotProfile {
  /// Printed on the PDF export. Optional.
  final String name;

  final MedicalKind medicalKind;

  /// Date of the examination shown on the medical certificate.
  final DateTime? medicalExamDate;

  /// "Were you 40 or older on the date of that examination?" Null = not
  /// answered, in which case the engine assumes the shorter (40+) duration and
  /// says so.
  final bool? age40OrOlderAtExam;

  final MedicalPrivilege privilege;

  /// BasicMed comprehensive medical examination (CMEC) date.
  final DateTime? basicMedExamDate;

  /// BasicMed online medical education course completion date.
  final DateTime? basicMedCourseDate;

  /// Most recent flight review typed in during onboarding/settings. Logbook
  /// entries flagged "flight review" or "practical test" also count.
  final DateTime? flightReviewDate;

  final bool instrumentRated;

  final bool studentPilot;

  /// Student solo endorsement date (61.87(n)).
  final DateTime? soloEndorsementDate;

  /// Category/class the pilot normally flies; the Go Card defaults to it.
  final String homeCategoryClass;
  final bool homeTailwheel;

  const PilotProfile({
    this.name = '',
    this.medicalKind = MedicalKind.none,
    this.medicalExamDate,
    this.age40OrOlderAtExam,
    this.privilege = MedicalPrivilege.third,
    this.basicMedExamDate,
    this.basicMedCourseDate,
    this.flightReviewDate,
    this.instrumentRated = false,
    this.studentPilot = false,
    this.soloEndorsementDate,
    this.homeCategoryClass = '',
    this.homeTailwheel = false,
  });

  static const empty = PilotProfile();

  Map<String, Object?> toJson() => {
        'name': name,
        'medicalKind': medicalKind.name,
        'medicalExamDate': medicalExamDate?.toIso8601String(),
        'age40OrOlderAtExam': age40OrOlderAtExam,
        'privilege': privilege.name,
        'basicMedExamDate': basicMedExamDate?.toIso8601String(),
        'basicMedCourseDate': basicMedCourseDate?.toIso8601String(),
        'flightReviewDate': flightReviewDate?.toIso8601String(),
        'instrumentRated': instrumentRated,
        'studentPilot': studentPilot,
        'soloEndorsementDate': soloEndorsementDate?.toIso8601String(),
        'homeCategoryClass': homeCategoryClass,
        'homeTailwheel': homeTailwheel,
      };

  factory PilotProfile.fromJson(Map<String, Object?> j) {
    DateTime? date(String k) =>
        j[k] == null ? null : DateTime.tryParse(j[k].toString());
    return PilotProfile(
      name: (j['name'] ?? '').toString(),
      medicalKind: MedicalKind.fromName(j['medicalKind']?.toString()),
      medicalExamDate: date('medicalExamDate'),
      age40OrOlderAtExam: j['age40OrOlderAtExam'] as bool?,
      privilege: MedicalPrivilege.fromName(j['privilege']?.toString()),
      basicMedExamDate: date('basicMedExamDate'),
      basicMedCourseDate: date('basicMedCourseDate'),
      flightReviewDate: date('flightReviewDate'),
      instrumentRated: j['instrumentRated'] == true,
      studentPilot: j['studentPilot'] == true,
      soloEndorsementDate: date('soloEndorsementDate'),
      homeCategoryClass: (j['homeCategoryClass'] ?? '').toString(),
      homeTailwheel: j['homeTailwheel'] == true,
    );
  }

  PilotProfile copyWith({
    String? name,
    MedicalKind? medicalKind,
    DateTime? medicalExamDate,
    bool clearMedicalExamDate = false,
    bool? age40OrOlderAtExam,
    bool clearAge = false,
    MedicalPrivilege? privilege,
    DateTime? basicMedExamDate,
    bool clearBasicMedExamDate = false,
    DateTime? basicMedCourseDate,
    bool clearBasicMedCourseDate = false,
    DateTime? flightReviewDate,
    bool clearFlightReviewDate = false,
    bool? instrumentRated,
    bool? studentPilot,
    DateTime? soloEndorsementDate,
    bool clearSoloEndorsementDate = false,
    String? homeCategoryClass,
    bool? homeTailwheel,
  }) {
    return PilotProfile(
      name: name ?? this.name,
      medicalKind: medicalKind ?? this.medicalKind,
      medicalExamDate: clearMedicalExamDate
          ? null
          : (medicalExamDate ?? this.medicalExamDate),
      age40OrOlderAtExam:
          clearAge ? null : (age40OrOlderAtExam ?? this.age40OrOlderAtExam),
      privilege: privilege ?? this.privilege,
      basicMedExamDate: clearBasicMedExamDate
          ? null
          : (basicMedExamDate ?? this.basicMedExamDate),
      basicMedCourseDate: clearBasicMedCourseDate
          ? null
          : (basicMedCourseDate ?? this.basicMedCourseDate),
      flightReviewDate: clearFlightReviewDate
          ? null
          : (flightReviewDate ?? this.flightReviewDate),
      instrumentRated: instrumentRated ?? this.instrumentRated,
      studentPilot: studentPilot ?? this.studentPilot,
      soloEndorsementDate: clearSoloEndorsementDate
          ? null
          : (soloEndorsementDate ?? this.soloEndorsementDate),
      homeCategoryClass: homeCategoryClass ?? this.homeCategoryClass,
      homeTailwheel: homeTailwheel ?? this.homeTailwheel,
    );
  }
}
