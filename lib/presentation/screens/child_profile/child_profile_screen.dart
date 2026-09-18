import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../data/models/child_profile.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_ui.dart';

/// Step 1 of the screening flow — enrollment form for the child and worker.
///
/// Collects the ChildProfile contract: optional name, required age in
/// months (validated through [ChildProfile.isAgeValid]), Anganwadi ID,
/// state, district and worker name. On a valid form the profile is written
/// to [sessionProvider] and the flow continues to the questionnaire.
class ChildProfileScreen extends ConsumerStatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  ConsumerState<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends ConsumerState<ChildProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _anganwadiController = TextEditingController();
  final _districtController = TextEditingController();
  final _workerController = TextEditingController();
  String? _stateCode;

  /// Indian states and union territories, stored as the display name so it
  /// can be matched against the DEIC directory by state later.
  static const _states = <String>[
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Andaman and Nicobar Islands',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Jammu and Kashmir',
    'Ladakh',
    'Lakshadweep',
    'Puducherry',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _anganwadiController.dispose();
    _districtController.dispose();
    _workerController.dispose();
    super.dispose();
  }

  String? _validateAge(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'बच्चे की उम्र दर्ज करें';
    final months = int.tryParse(text);
    if (months == null) return 'उम्र पूरे महीनों में संख्या लिखें';
    final profile = ChildProfile(
      childAgeMonths: months,
      anganwadiId: '',
      stateCode: '',
      districtCode: '',
    );
    if (!profile.isAgeValid) {
      return 'उम्र ${EarlyEchoConstants.minChildAgeMonths}–'
          '${EarlyEchoConstants.maxChildAgeMonths} महीनों के बीच होनी चाहिए';
    }
    return null;
  }

  String? _required(String? value, String message) {
    return (value == null || value.trim().isEmpty) ? message : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(sessionProvider.notifier)
        .setChildProfile(
          ChildProfile(
            childName: _nameController.text.trim().isEmpty
                ? null
                : _nameController.text.trim(),
            childAgeMonths: int.parse(_ageController.text.trim()),
            anganwadiId: _anganwadiController.text.trim(),
            stateCode: _stateCode!,
            districtCode: _districtController.text.trim(),
            workerName: _workerController.text.trim(),
          ),
        );
    context.push('/questionnaire');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('बच्चे की जानकारी')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const AppStepIndicator(
                current: 1,
                total: 7,
                label: 'चरण 1/7 • बच्चे की जानकारी',
              ),
              const SizedBox(height: 20),
              const AppSectionHeader(
                title: 'बच्चे का विवरण भरें',
                subtitle:
                    'Fill in the child and worker details. The name is optional.',
              ),
              const SizedBox(height: 22),
              AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIconBadge(
                          icon: Icons.child_care_outlined,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'बच्चे का विवरण',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'बच्चे का नाम (वैकल्पिक)',
                        hintText: 'Child name — optional',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'उम्र (महीनों में)',
                        hintText: 'Age in months, 12–60',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      validator: _validateAge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'स्क्रीनिंग स्थान',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _anganwadiController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'आंगनबाड़ी आईडी',
                        hintText: 'Anganwadi ID, e.g. IN-MP-042',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      validator: (value) =>
                          _required(value, 'आंगनबाड़ी आईडी आवश्यक है'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _stateCode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'राज्य',
                        hintText: 'State',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      items: _states
                          .map(
                            (state) => DropdownMenuItem(
                              value: state,
                              child: Text(state),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _stateCode = value),
                      validator: (value) =>
                          value == null ? 'राज्य चुनें' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _districtController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'जिला',
                        hintText: 'District',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      validator: (value) => _required(value, 'जिला दर्ज करें'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'कार्यकर्ता',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _workerController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'कार्यकर्ता का नाम',
                        hintText: 'Worker name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) =>
                          _required(value, 'कार्यकर्ता का नाम दर्ज करें'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('प्रश्नावली की ओर बढ़ें'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
