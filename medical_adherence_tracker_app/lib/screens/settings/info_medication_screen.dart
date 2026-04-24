import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class InfoMedicationScreen extends StatelessWidget {
  const InfoMedicationScreen({super.key});

  static const List<_MedicationInfo> _medications = [
    _MedicationInfo(
      name: 'Ibuprofen',
      subtitle: 'Pain and inflammation relief',
      info:
          'Ibuprofen is a painkiller that helps relieve pain and reduce swelling (inflammation).',
      keyFacts: [
        'How you use your medicine and how much to use depends on which type it is and how much ibuprofen it contains. Always check the packet or leaflet that comes with your medicine. Ask a pharmacist or doctor for advice if you are not sure how to use it or have any problems using it.',
        'Common side effects of ibuprofen tablets, capsules, liquid and granules include: indigestion and stomach aches, feeling sick (nausea) and, being sick (vomiting), headaches, a rash, dizziness or diarrhoea or constipation',
        'Do not take ibuprofen at the same time as other non-steroidal anti-inflammatory drugs (NSAIDs), such as naproxen or aspirin. This can increase the risk of serious side effects like stomach ulcers.',
        'If you are breastfeeding, check with a pharmacist or doctor before using ibuprofen. You should avoid using ibuprofen during pregnancy unless you are advised to by a doctor or pharmacist.',
        'You can eat and drink normally while taking ibuprofen, but try to avoid drinking a lot of alcohol because this can increase the risk of side effects.',     
      ],
    ),
    _MedicationInfo(
      name: 'Paracetamol',
      subtitle: 'Pain and fever reduction',
      info:
          'Paracetamol is a common painkiller used to treat aches and pain. It can also be used to reduce a high temperature.',
      keyFacts: [
        'Paracetamol can take up to an hour to work.',
        'The usual dose of paracetamol is one or two 500mg tablets at a time, up to 4 times in 24 hours. The maximum dose is eight 500mg tablets in 24 hours.',
        'Do not take paracetamol with other medicines containing paracetamol because there is a risk of overdose.',
        'Paracetamol is safe to take during pregnancy and while breastfeeding, at recommended doses.',
        'It may not be safe for you to drink alcohol with paracetamol if you have certain health conditions, such as liver problems. Check the leaflet that comes with your medicine.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Medication Info'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Tap a medication card to view a quick summary from the NHS:',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          ..._medications.map((med) => _MedicationInfoCard(medication: med)),
        ],
      ),
    );
  }
}

class _MedicationInfoCard extends StatefulWidget {
  final _MedicationInfo medication;

  const _MedicationInfoCard({required this.medication});

  @override
  State<_MedicationInfoCard> createState() => _MedicationInfoCardState();
}

class _MedicationInfoCardState extends State<_MedicationInfoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.medication_outlined,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.medication.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          widget.medication.subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textLight,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                Text(
                  widget.medication.info,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 12),
                ...widget.medication.keyFacts.map((fact) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(color: AppTheme.primary),
                          ),
                          Expanded(
                            child: Text(
                              fact,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textPrimary,
                                    height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationInfo {
  final String name;
  final String subtitle;
  final String info;
  final List<String> keyFacts;

  const _MedicationInfo({
    required this.name,
    required this.subtitle,
    required this.info,
    required this.keyFacts,
  });
}
