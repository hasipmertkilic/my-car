const expertiseParts = <String, String>{
  'front_bumper': 'Ön tampon',
  'hood': 'Kaput',
  'roof': 'Tavan',
  'trunk': 'Bagaj kapağı',
  'rear_bumper': 'Arka tampon',
  'left_front_wing': 'Sol ön çamurluk',
  'right_front_wing': 'Sağ ön çamurluk',
  'left_front_door': 'Sol ön kapı',
  'right_front_door': 'Sağ ön kapı',
  'left_rear_door': 'Sol arka kapı',
  'right_rear_door': 'Sağ arka kapı',
  'left_rear_wing': 'Sol arka çamurluk',
  'right_rear_wing': 'Sağ arka çamurluk',
};
const expertiseStatuses = <String, String>{
  'unknown': 'Belirtilmedi',
  'original': 'Orijinal',
  'painted': 'Boyalı',
  'local_paint': 'Lokal boyalı',
  'replaced': 'Değişen',
  'damaged': 'Hasarlı',
};
const maxExpertisePdfBytes = 10 * 1024 * 1024;

class ExpertiseRecord {
  ExpertiseRecord({
    Map<String, String> parts = const {},
    this.notes = '',
    this.reportId = '',
    this.reportName = '',
  }) : parts = {
         for (final key in expertiseParts.keys) key: parts[key] ?? 'unknown',
       };
  final Map<String, String> parts;
  final String notes, reportId, reportName;
  bool get valid =>
      parts.length == expertiseParts.length &&
      parts.keys.every(expertiseParts.containsKey) &&
      parts.values.every(expertiseStatuses.containsKey) &&
      notes.length <= 2000 &&
      reportName.length <= 200 &&
      ((reportId.isEmpty && reportName.isEmpty) ||
          (RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(reportId) &&
              reportName.isNotEmpty));
  Map<String, dynamic> toMap() => {
    'parts': parts,
    'notes': notes,
    'reportId': reportId,
    'reportName': reportName,
  };
  factory ExpertiseRecord.fromMap(Map<String, dynamic> data) => ExpertiseRecord(
    parts: Map<String, String>.from(data['parts'] as Map? ?? {}),
    notes: data['notes'] as String? ?? '',
    reportId: data['reportId'] as String? ?? '',
    reportName: data['reportName'] as String? ?? '',
  );
}

bool isExpertisePdf(List<int> bytes) =>
    bytes.length >= 5 &&
    bytes.length <= maxExpertisePdfBytes &&
    String.fromCharCodes(bytes.take(5)) == '%PDF-';
