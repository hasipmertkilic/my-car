import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../services/policy_document_parser.dart';

class PolicyDocumentReview extends StatefulWidget {
  const PolicyDocumentReview({super.key, required this.fields});
  final PolicyDocumentFields fields;
  @override
  State<PolicyDocumentReview> createState() => _PolicyDocumentReviewState();
}

class _PolicyDocumentReviewState extends State<PolicyDocumentReview> {
  late final Map<String, String> values;
  late final Set<String> selected;
  @override
  void initState() {
    super.initState();
    final f = widget.fields;
    values = {
      if (f.company != null) 'company': 'Sigorta şirketi: ${f.company}',
      if (f.number != null) 'number': 'Poliçe numarası: ${f.number}',
      if (f.kind != null)
        'kind': 'Tür: ${f.kind == 'casco' ? 'Kasko' : 'Trafik sigortası'}',
      if (f.level != null) 'level': 'Kapsam: ${f.level}',
      if (f.step != null) 'step': 'Hasarsızlık: ${f.step}. basamak',
      if (f.startDate != null)
        'start': 'Başlangıç: ${Formatters.date(f.startDate!)}',
      if (f.endDate != null) 'end': 'Bitiş: ${Formatters.date(f.endDate!)}',
      if (f.premiumKurus != null)
        'premium': 'Tutar: ${Formatters.preciseMoney(f.premiumKurus! / 100)}',
    };
    selected = values.keys.toSet();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Belgeden okunan bilgiler'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bilgileri belgenle karşılaştır. Seçtiğin alanlar formdaki mevcut değerlerin yerine geçecek; diğer alanlar korunacak.',
            ),
            const SizedBox(height: 12),
            for (final entry in values.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(entry.value),
                value: selected.contains(entry.key),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    selected.add(entry.key);
                  } else {
                    selected.remove(entry.key);
                  }
                }),
              ),
            const Text(
              'Okunmayan alanları elle tamamla. Belge doğrulaması veya e-Devlet bağlantısı yapılmaz.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: selected.isEmpty
            ? null
            : () => Navigator.pop(context, selected),
        child: const Text('Seçilenleri forma doldur'),
      ),
    ],
  );
}
