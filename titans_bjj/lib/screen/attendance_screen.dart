import 'package:flutter/material.dart';

import '../model/app_user.dart';
import '../model/attendance_models.dart';
import '../repository/attendance_repository.dart';
import '../service/user_session.dart';
import '../widgets/titans_scaffold.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceRepository _repository = AttendanceRepository.instance;

  AppUser? _user;
  Stream<List<AttendanceSession>>? _sessionsStream;
  bool _submitting = false;

  bool get _isStaff {
    final user = _user;
    return user != null &&
        (user.role == UserRole.admin || user.role == UserRole.professor);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final user = UserScope.of(context);
    if (_user?.uid == user.uid && _user?.academyId == user.academyId) return;

    _user = user;
    _sessionsStream = _repository.watchSessions(academyId: user.academyId);
  }

  @override
  Widget build(BuildContext context) {
    final sessionsStream = _sessionsStream;

    return TitansScaffold(
      scroll: false,
      appBar: AppBar(
        title: const Text('Presenca'),
      ),
      floatingActionButton: _isStaff
          ? FloatingActionButton.extended(
              heroTag: 'attendance_fab',
              icon: const Icon(Icons.add),
              label: const Text('Nova aula'),
              onPressed: _submitting ? null : _openCreateSession,
            )
          : null,
      body: sessionsStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<AttendanceSession>>(
              stream: sessionsStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return _ErrorState(message: snap.error.toString());
                }

                final sessions = snap.data ?? const <AttendanceSession>[];
                if (sessions.isEmpty) {
                  return const _EmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return _AttendanceSessionCard(
                      session: session,
                      isStaff: _isStaff,
                      isBusy: _submitting,
                      onClose: session.status == AttendanceSessionStatus.open
                          ? () => _closeSession(session)
                          : null,
                      onCancel:
                          session.status == AttendanceSessionStatus.cancelled
                              ? null
                              : () => _cancelSession(session),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _openCreateSession() async {
    final user = _user;
    if (user == null || !_isStaff) return;

    final draft = await showModalBottomSheet<_AttendanceSessionDraft?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateAttendanceSessionSheet(),
    );

    if (draft == null) return;

    setState(() => _submitting = true);
    try {
      await _repository.createSession(
        academyId: user.academyId,
        title: draft.title,
        classType: draft.classType,
        instructorUid: user.uid,
        instructorName: user.name.isEmpty ? user.email : user.name,
        startsAt: draft.startsAt,
        endsAt: draft.endsAt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessao criada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel criar a sessao: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _closeSession(AttendanceSession session) async {
    await _updateStatus(
      action: () => _repository.closeSession(
        academyId: session.academyId,
        sessionId: session.id,
      ),
      successMessage: 'Sessao fechada.',
      errorMessage: 'Nao foi possivel fechar a sessao',
    );
  }

  Future<void> _cancelSession(AttendanceSession session) async {
    await _updateStatus(
      action: () => _repository.cancelSession(
        academyId: session.academyId,
        sessionId: session.id,
      ),
      successMessage: 'Sessao cancelada.',
      errorMessage: 'Nao foi possivel cancelar a sessao',
    );
  }

  Future<void> _updateStatus({
    required Future<void> Function() action,
    required String successMessage,
    required String errorMessage,
  }) async {
    if (!_isStaff || _submitting) return;

    setState(() => _submitting = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorMessage: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _AttendanceSessionCard extends StatelessWidget {
  const _AttendanceSessionCard({
    required this.session,
    required this.isStaff,
    required this.isBusy,
    required this.onClose,
    required this.onCancel,
  });

  final AttendanceSession session;
  final bool isStaff;
  final bool isBusy;
  final VoidCallback? onClose;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _statusLabel(session.status);
    final statusColor = _statusColor(cs, session.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.classType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(status),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.5)),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _InfoItem(
                  icon: Icons.schedule,
                  label: '${_formatDateTime(session.startsAt)} - ${_formatTime(session.endsAt)}',
                ),
                _InfoItem(
                  icon: Icons.person_outline,
                  label: session.instructorName.isEmpty
                      ? session.instructorUid
                      : session.instructorName,
                ),
              ],
            ),
            if (isStaff) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar'),
                    onPressed: isBusy ? null : onCancel,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Fechar'),
                    onPressed: isBusy ? null : onClose,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(AttendanceSessionStatus status) {
    switch (status) {
      case AttendanceSessionStatus.open:
        return 'Aberta';
      case AttendanceSessionStatus.closed:
        return 'Fechada';
      case AttendanceSessionStatus.cancelled:
        return 'Cancelada';
    }
  }

  Color _statusColor(ColorScheme cs, AttendanceSessionStatus status) {
    switch (status) {
      case AttendanceSessionStatus.open:
        return cs.primary;
      case AttendanceSessionStatus.closed:
        return Colors.green;
      case AttendanceSessionStatus.cancelled:
        return cs.error;
    }
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.62)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.74)),
        ),
      ],
    );
  }
}

class _CreateAttendanceSessionSheet extends StatefulWidget {
  const _CreateAttendanceSessionSheet();

  @override
  State<_CreateAttendanceSessionSheet> createState() =>
      _CreateAttendanceSessionSheetState();
}

class _CreateAttendanceSessionSheetState
    extends State<_CreateAttendanceSessionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _classTypeController = TextEditingController(text: 'BJJ');

  DateTime _startsAt = _nextHour();
  DateTime _endsAt = _nextHour().add(const Duration(hours: 1));

  @override
  void dispose() {
    _titleController.dispose();
    _classTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nova aula',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Titulo'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o titulo'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _classTypeController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Tipo de aula'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o tipo de aula'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateTimeField(
                      label: 'Inicio',
                      value: _startsAt,
                      onPick: (value) {
                        setState(() {
                          _startsAt = value;
                          if (!_endsAt.isAfter(_startsAt)) {
                            _endsAt = _startsAt.add(const Duration(hours: 1));
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateTimeField(
                      label: 'Fim',
                      value: _endsAt,
                      onPick: (value) => setState(() => _endsAt = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Criar sessao'),
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final startsAt = _startsAt;
    final endsAt = _endsAt.isAfter(startsAt)
        ? _endsAt
        : startsAt.add(const Duration(hours: 1));

    Navigator.of(context).pop(
      _AttendanceSessionDraft(
        title: _titleController.text.trim(),
        classType: _classTypeController.text.trim(),
        startsAt: startsAt,
        endsAt: endsAt,
      ),
    );
  }

  static DateTime _nextHour() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1);
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date == null || !context.mounted) return;

        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        if (time == null) return;

        onPick(DateTime(date.year, date.month, date.day, time.hour, time.minute));
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(_formatDateTime(value)),
      ),
    );
  }
}

class _AttendanceSessionDraft {
  const _AttendanceSessionDraft({
    required this.title,
    required this.classType,
    required this.startsAt,
    required this.endsAt,
  });

  final String title;
  final String classType;
  final DateTime startsAt;
  final DateTime endsAt;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nenhuma sessao de presenca encontrada.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  return '${_two(value.day)}/${_two(value.month)} ${_two(value.hour)}:${_two(value.minute)}';
}

String _formatTime(DateTime value) {
  return '${_two(value.hour)}:${_two(value.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');