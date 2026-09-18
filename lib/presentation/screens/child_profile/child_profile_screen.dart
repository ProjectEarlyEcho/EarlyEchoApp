import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../data/models/child_profile.dart';
import '../../providers/locale_provider.dart';
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
    final l10n = ref.read(appLocaleProvider);
    final text = value?.trim() ?? '';
    if (text.isEmpty) return AppStrings.tr('cp_age_required', l10n);
    final months = int.tryParse(text);
    if (months == null) return AppStrings.tr('cp_age_number', l10n);
    final profile = ChildProfile(
      childAgeMonths: months,
      anganwadiId: '',
      stateCode: '',
      districtCode: '',
    );
    if (!profile.isAgeValid) {
      return AppStrings.trf('cp_age_range', l10n, {
        'min': '${EarlyEchoConstants.minChildAgeMonths}',
        'max': '${EarlyEchoConstants.maxChildAgeMonths}',
      });
    }
    return null;
  }

  String? _required(String? value, String messageKey) {
    if (value != null && value.trim().isNotEmpty) return null;
    return AppStrings.tr(messageKey, ref.read(appLocaleProvider));
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
            cloudChildId: ref.read(sessionProvider).selectedCareChild?.id,
          ),
        );
    context.push('/developmental-goals');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocaleProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('title_child_profile', l10n))),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              AppStepIndicator(
                current: 1,
                total: 7,
                label: AppStrings.stepLabel(
                  1,
                  7,
                  AppStrings.tr('step1_name', l10n),
                  l10n,
                ),
              ),
              const SizedBox(height: 20),
              AppSectionHeader(
                title: AppStrings.tr('cp_header', l10n),
                subtitle: AppStrings.tr('cp_header_sub', l10n),
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
                            AppStrings.tr('cp_section_child', l10n),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('cp_child_name', l10n),
                        hintText: AppStrings.tr('cp_child_name_hint', l10n),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('cp_age', l10n),
                        hintText: AppStrings.tr('cp_age_hint', l10n),
                        prefixIcon: const Icon(Icons.cake_outlined),
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
                      AppStrings.tr('cp_section_location', l10n),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _anganwadiController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('cp_anganwadi', l10n),
                        hintText: AppStrings.tr('cp_anganwadi_hint', l10n),
                        prefixIcon: const Icon(Icons.location_city_outlined),
                      ),
                      validator: (value) =>
                          _required(value, 'cp_anganwadi_required'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _stateCode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('cp_state', l10n),
                        hintText: AppStrings.tr('cp_state_hint', l10n),
                        prefixIcon: const Icon(Icons.map_outlined),
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
                      validator: (value) => value == null
                          ? AppStrings.tr('cp_state_required', l10n)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _districtController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('cp_district', l10n),
                        hintText: AppStrings.tr('cp_district_hint', l10n),
                        prefixIcon: const Icon(Icons.place_outlined),
                      ),
                      validator: (value) =>
                          _required(value, 'cp_district_required'),
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
                      AppStrings.tr('cp_section_worker', l10n),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _workerController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('cp_worker', l10n),
                        hintText: AppStrings.tr('cp_worker_hint', l10n),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      validator: (value) =>
                          _required(value, 'cp_worker_required'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(AppStrings.tr('cp_next', l10n)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
