import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/care_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/care_provider.dart';
import '../../widgets/app_ui.dart';

class CarePortalScreen extends ConsumerWidget {
  const CarePortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(accessibleChildrenProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Care portal')),
      body: children.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load children.')),
        data: (items) => items.isEmpty
            ? const Center(
                child: Text('No children are available to this account.'),
              )
            : _CareChildPortal(children: items),
      ),
    );
  }
}

class _CareChildPortal extends ConsumerStatefulWidget {
  const _CareChildPortal({required this.children});

  final List<CareChild> children;

  @override
  ConsumerState<_CareChildPortal> createState() => _CareChildPortalState();
}

class _CareChildPortalState extends ConsumerState<_CareChildPortal> {
  late CareChild _child = widget.children.first;
  var _refreshKey = 0;

  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(careRepositoryProvider);
    final auth = ref.watch(appAuthProvider);
    if (repository == null) {
      return const Center(child: Text('Care portal is unavailable.'));
    }
    final canWriteNotes = auth.canSyncScreenings;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownButtonFormField<CareChild>(
          initialValue: _child,
          decoration: const InputDecoration(labelText: 'Child'),
          items: widget.children
              .map(
                (child) => DropdownMenuItem(
                  value: child,
                  child: Text(child.displayName),
                ),
              )
              .toList(),
          onChanged: (child) {
            if (child != null) setState(() => _child = child);
          },
        ),
        const SizedBox(height: 20),
        _Section<CareScreeningSession>(
          title: 'Screening history',
          future: repository.getScreenings(_child.id),
          refreshKey: _refreshKey,
          empty: 'No screenings recorded.',
          item: (screening) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${screening.analysisStatus} screening'),
            subtitle: Text(
              DateFormat.yMMMd().add_jm().format(screening.createdAt.toLocal()),
            ),
            trailing: screening.riskLevel == null
                ? null
                : Text(screening.riskLevel!),
          ),
        ),
        const SizedBox(height: 16),
        _Section<CareAppointment>(
          title: 'Appointments',
          future: repository.getAppointments(_child.id),
          refreshKey: _refreshKey,
          empty: 'No appointments yet.',
          action: auth.role == AppUserRole.parent
              ? IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Request appointment',
                  onPressed: () => _requestAppointment(repository),
                )
              : null,
          item: (appointment) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(appointment.status),
            subtitle: Text(
              appointment.reason ??
                  (appointment.requestedFor == null
                      ? 'No preferred time supplied'
                      : DateFormat.yMMMd().add_jm().format(
                          appointment.requestedFor!.toLocal(),
                        )),
            ),
            trailing:
                auth.canSyncScreenings && appointment.status == 'requested'
                ? Wrap(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        tooltip: 'Confirm',
                        onPressed: () async {
                          await repository.updateAppointmentStatus(
                            appointment.id,
                            'confirmed',
                          );
                          _refresh();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        tooltip: 'Decline',
                        onPressed: () async {
                          await repository.updateAppointmentStatus(
                            appointment.id,
                            'declined',
                          );
                          _refresh();
                        },
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        _Section<CareConversation>(
          title: 'Conversations',
          future: repository.getConversations(_child.id),
          refreshKey: _refreshKey,
          empty: 'No conversations yet.',
          item: (conversation) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Care conversation'),
            subtitle: Text(
              'Updated ${DateFormat.yMMMd().add_jm().format(conversation.updatedAt.toLocal())}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/care/conversations/${conversation.id}'),
          ),
        ),
        if (canWriteNotes) ...[
          const SizedBox(height: 16),
          _Section<CareClinicalNote>(
            title: 'Clinical notes',
            future: repository.getClinicalNotes(_child.id),
            refreshKey: _refreshKey,
            empty: 'No clinical notes yet.',
            action: IconButton(
              icon: const Icon(Icons.note_add_outlined),
              tooltip: 'Add clinical note',
              onPressed: () => _addNote(repository),
            ),
            item: (note) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(note.body),
              subtitle: Text(
                DateFormat.yMMMd().add_jm().format(note.createdAt.toLocal()),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _requestAppointment(CareRepository repository) async {
    final clinicianIds = await repository.getClinicianIds(_child.id);
    if (!mounted || clinicianIds.isEmpty) return;
    final reasonController = TextEditingController();
    var clinicianId = clinicianIds.first;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: clinicianId,
                items: clinicianIds
                    .map(
                      (id) => DropdownMenuItem(
                        value: id,
                        child: Text('Clinician ${id.substring(0, 8)}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => clinicianId = value!),
              ),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Request'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true) {
      await repository.requestAppointment(
        childId: _child.id,
        clinicianId: clinicianId,
        requestedFor: DateTime.now().add(const Duration(days: 7)),
        reason: reasonController.text,
      );
      _refresh();
    }
    reasonController.dispose();
  }

  Future<void> _addNote(CareRepository repository) async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clinical note'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (submitted == true && controller.text.trim().isNotEmpty) {
      await repository.createClinicalNote(_child.id, controller.text);
      _refresh();
    }
    controller.dispose();
  }
}

class CareMessageThreadScreen extends ConsumerStatefulWidget {
  const CareMessageThreadScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<CareMessageThreadScreen> createState() =>
      _CareMessageThreadScreenState();
}

class _CareMessageThreadScreenState
    extends ConsumerState<CareMessageThreadScreen> {
  final _controller = TextEditingController();
  var _refreshKey = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(careRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: repository == null
          ? const Center(child: Text('Care portal is unavailable.'))
          : Column(
              children: [
                Expanded(
                  child: _Section<CareMessage>(
                    title: '',
                    future: repository.getMessages(widget.conversationId),
                    refreshKey: _refreshKey,
                    empty: 'No messages yet.',
                    item: (message) => ListTile(
                      title: Text(message.body),
                      subtitle: Text(
                        DateFormat.yMMMd().add_jm().format(
                          message.createdAt.toLocal(),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLength: 2000,
                            decoration: const InputDecoration(
                              hintText: 'Message',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          tooltip: 'Send message',
                          onPressed: () async {
                            if (_controller.text.trim().isEmpty) return;
                            await repository.sendMessage(
                              widget.conversationId,
                              _controller.text,
                            );
                            _controller.clear();
                            setState(() => _refreshKey++);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Section<T> extends StatelessWidget {
  const _Section({
    required this.title,
    required this.future,
    required this.refreshKey,
    required this.empty,
    required this.item,
    this.action,
  });

  final String title;
  final Future<List<T>> future;
  final int refreshKey;
  final String empty;
  final Widget Function(T value) item;
  final Widget? action;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<T>>(
    key: ValueKey('$title-$refreshKey'),
    future: future,
    builder: (context, snapshot) => AppSurface(
      padding: const EdgeInsets.all(16),
      child: snapshot.connectionState != ConnectionState.done
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          : snapshot.hasError
          ? const Text('Could not load this care record.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ?action,
                    ],
                  ),
                if ((snapshot.data ?? []).isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(empty),
                  )
                else ...[
                  if (title.isNotEmpty) const SizedBox(height: 8),
                  ...snapshot.data!.map(item),
                ],
              ],
            ),
    ),
  );
}
