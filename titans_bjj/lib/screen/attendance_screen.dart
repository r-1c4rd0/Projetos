import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
import '../model/attendance_models.dart';
import '../model/grading_rules.dart';
import '../repository/attendance_repository.dart';
import '../repository/students_repository.dart';
import '../service/user_session.dart';
import '../widgets/titans_scaffold.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceRepository _repository = AttendanceRepository.instance;
  final IStudentRepository _studentRepository = StudentRepository.create();

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
      appBar: AppBar(title: const Text('Presenca')),
      floatingActionButton:
          _isStaff
              ? FloatingActionButton.extended(
                heroTag: 'attendance_fab',
                icon: const Icon(Icons.add),
                label: const Text('Nova aula'),
                onPressed: _submitting ? null : _openCreateSession,
              )
              : null,
      body:
          sessionsStream == null
              ? const TitansStateView.loading()
              : StreamBuilder<List<AttendanceSession>>(
                stream: sessionsStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const TitansStateView.loading();
                  }

                  if (snap.hasError) {
                    return _ErrorState(message: snap.error.toString());
                  }

                  final sessions = snap.data ?? const <AttendanceSession>[];
                  if (sessions.isEmpty) return _EmptyState(isStaff: _isStaff);

                  return ListView.separated(
                    padding: TitansUI.listPadding(context),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _AttendanceSessionCard(
                        session: session,
                        isStaff: _isStaff,
                        isBusy: _submitting,
                        onTap: () => _openSessionDetails(session),
                        onClose:
                            session.status == AttendanceSessionStatus.open
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
      _showMessage('Sessao criada.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Nao foi possivel criar a sessao: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openSessionDetails(AttendanceSession session) {
    final user = _user;
    if (user == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _AttendanceSessionDetailsScreen(
              session: session,
              currentUser: user,
              attendanceRepository: _repository,
              studentRepository: _studentRepository,
            ),
      ),
    );
  }

  Future<void> _closeSession(AttendanceSession session) async {
    await _updateStatus(
      action:
          () => _repository.closeSession(
            academyId: session.academyId,
            sessionId: session.id,
          ),
      successMessage: 'Sessao fechada.',
      errorMessage: 'Nao foi possivel fechar a sessao',
    );
  }

  Future<void> _cancelSession(AttendanceSession session) async {
    await _updateStatus(
      action:
          () => _repository.cancelSession(
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
      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) return;
      _showMessage('$errorMessage: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AttendanceSessionDetailsScreen extends StatefulWidget {
  const _AttendanceSessionDetailsScreen({
    required this.session,
    required this.currentUser,
    required this.attendanceRepository,
    required this.studentRepository,
  });

  final AttendanceSession session;
  final AppUser currentUser;
  final AttendanceRepository attendanceRepository;
  final IStudentRepository studentRepository;

  @override
  State<_AttendanceSessionDetailsScreen> createState() =>
      _AttendanceSessionDetailsScreenState();
}

class _AttendanceSessionDetailsScreenState
    extends State<_AttendanceSessionDetailsScreen> {
  StreamSubscription<List<AttendanceCheckIn>>? _checkInsSubscription;
  List<AttendanceCheckIn> _checkIns = const <AttendanceCheckIn>[];
  Object? _checkInsError;
  bool _loadingCheckIns = true;
  bool _submitting = false;

  bool get _isStaff {
    return widget.currentUser.role == UserRole.admin ||
        widget.currentUser.role == UserRole.professor;
  }

  bool get _canEdit {
    return _isStaff && widget.session.status == AttendanceSessionStatus.open;
  }

  @override
  void initState() {
    super.initState();

    if (!_isStaff) {
      _loadingCheckIns = false;
      return;
    }

    _checkInsSubscription = widget.attendanceRepository
        .watchSessionCheckIns(
          academyId: widget.session.academyId,
          sessionId: widget.session.id,
        )
        .listen(
          (checkIns) {
            if (!mounted) return;
            setState(() {
              _checkIns = checkIns;
              _loadingCheckIns = false;
              _checkInsError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _checkInsError = error;
              _loadingCheckIns = false;
            });
          },
        );
  }

  @override
  void dispose() {
    _checkInsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return TitansScaffold(
      scroll: false,
      appBar: AppBar(title: const Text('Presenca da aula')),
      floatingActionButton:
          _canEdit
              ? FloatingActionButton.extended(
                heroTag: 'attendance_checkin_fab_${session.id}',
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Adicionar aluno'),
                onPressed: _submitting ? null : _openAddStudentSheet,
              )
              : null,
      body: _buildBody(session),
    );
  }

  Widget _buildBody(AttendanceSession session) {
    if (_loadingCheckIns) {
      return const TitansStateView.loading();
    }

    final error = _checkInsError;
    if (error != null) return _ErrorState(message: error.toString());

    final visibleCheckIns =
        _isStaff
            ? _checkIns
            : _checkIns
                .where((item) => item.uid == widget.currentUser.uid)
                .toList();

    return ListView(
      padding: TitansUI.listPadding(context),
      children: [
        _SessionHeader(session: session),
        if (session.status == AttendanceSessionStatus.open) ...[
          const SizedBox(height: 12),
          _QrCheckInActionCard(
            isStaff: _isStaff,
            isBusy: _submitting,
            onShowQr: _isStaff ? () => _showQrCode(session) : null,
            onScanQr: !_isStaff ? () => _scanQrCode(session) : null,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Alunos presentes',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (visibleCheckIns.isEmpty)
          const _InlineEmptyState(
            message: 'Nenhum aluno presente nesta sessao.',
          )
        else
          ...visibleCheckIns.map(
            (checkIn) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CheckInTile(
                checkIn: checkIn,
                canRemove: _canEdit && !_submitting,
                onRemove: () => _removeCheckIn(checkIn),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showQrCode(AttendanceSession session) async {
    if (!_canEdit) return;

    final payload =
        _AttendanceQrPayload(
          academyId: session.academyId,
          sessionId: session.id,
          generatedAt: DateTime.now().toUtc(),
        ).encode();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'QR Code da aula',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aluno escaneia para registrar presenca',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 18),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _scanQrCode(AttendanceSession session) async {
    if (_isStaff ||
        session.status != AttendanceSessionStatus.open ||
        _submitting) {
      return;
    }

    final rawPayload = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _QrScannerScreen()));
    if (rawPayload == null || rawPayload.trim().isEmpty) return;

    late final _AttendanceQrPayload payload;
    try {
      payload = _AttendanceQrPayload.decode(rawPayload);
    } catch (_) {
      _showMessage('QR Code invalido para presenca.');
      return;
    }

    if (payload.academyId != widget.currentUser.academyId) {
      _showMessage('QR Code pertence a outra academia.');
      return;
    }
    if (payload.sessionId != session.id) {
      _showMessage('QR Code pertence a outra sessao.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.attendanceRepository.addQrCheckIn(
        academyId: payload.academyId,
        sessionId: payload.sessionId,
        student: widget.currentUser,
      );
      if (!mounted) return;
      _showMessage('Presenca registrada por QR Code.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Nao foi possivel registrar QR Code: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openAddStudentSheet() async {
    if (!_canEdit) return;

    final checkedUids = _checkIns.map((item) => item.uid).toSet();
    final student = await showModalBottomSheet<StudentVm?>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _AddStudentSheet(
            academyId: widget.session.academyId,
            studentRepository: widget.studentRepository,
            checkedUids: checkedUids,
          ),
    );

    if (student == null) return;

    final latestCheckedUids = _checkIns.map((item) => item.uid).toSet();
    if (latestCheckedUids.contains(student.uid)) {
      _showMessage('Aluno ja esta presente nesta sessao.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.attendanceRepository.addManualCheckIn(
        academyId: widget.session.academyId,
        sessionId: widget.session.id,
        uid: student.uid,
        studentName: student.name,
        belt: student.belt,
        degree: student.degree,
        createdByUid: widget.currentUser.uid,
      );
      if (!mounted) return;
      _showMessage('Aluno adicionado.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Nao foi possivel adicionar aluno: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _removeCheckIn(AttendanceCheckIn checkIn) async {
    if (!_canEdit || _submitting) return;

    setState(() => _submitting = true);
    try {
      await widget.attendanceRepository.removeCheckIn(
        academyId: widget.session.academyId,
        sessionId: widget.session.id,
        uid: checkIn.uid,
      );
      if (!mounted) return;
      _showMessage('Check-in removido.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Nao foi possivel remover check-in: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AttendanceSessionCard extends StatelessWidget {
  const _AttendanceSessionCard({
    required this.session,
    required this.isStaff,
    required this.isBusy,
    required this.onTap,
    required this.onClose,
    required this.onCancel,
  });

  final AttendanceSession session;
  final bool isStaff;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback? onClose;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _statusLabel(session.status);
    final statusColor = _statusColor(cs, session.status);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
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
                    label:
                        '${_formatDateTime(session.startsAt)} - ${_formatTime(session.endsAt)}',
                  ),
                  _InfoItem(
                    icon: Icons.person_outline,
                    label:
                        session.instructorName.isEmpty
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
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});

  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(cs, session.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_statusLabel(session.status)),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.5)),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _InfoItem(
                  icon: Icons.school_outlined,
                  label: session.classType,
                ),
                _InfoItem(
                  icon: Icons.schedule,
                  label:
                      '${_formatDateTime(session.startsAt)} - ${_formatTime(session.endsAt)}',
                ),
                _InfoItem(
                  icon: Icons.person_outline,
                  label:
                      session.instructorName.isEmpty
                          ? session.instructorUid
                          : session.instructorName,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QrCheckInActionCard extends StatelessWidget {
  const _QrCheckInActionCard({
    required this.isStaff,
    required this.isBusy,
    required this.onShowQr,
    required this.onScanQr,
  });

  final bool isStaff;
  final bool isBusy;
  final VoidCallback? onShowQr;
  final VoidCallback? onScanQr;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = isStaff ? 'Check-in por QR Code' : 'Registrar presenca';
    final message =
        isStaff
            ? 'Exiba o QR Code para os alunos presentes nesta aula.'
            : 'Escaneie o QR Code da aula aberta para registrar sua presenca.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.qr_code_2_outlined, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: Icon(
                  isStaff
                      ? Icons.qr_code_2_outlined
                      : Icons.qr_code_scanner_outlined,
                ),
                label: Text(isStaff ? 'Exibir QR Code' : 'Escanear QR Code'),
                onPressed: isBusy ? null : (isStaff ? onShowQr : onScanQr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TitansScaffold(
      scroll: false,
      appBar: AppBar(title: const Text('Escanear QR Code')),
      body: ClipRRect(
        borderRadius: BorderRadius.circular(TitansUI.radius),
        child: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_handled) return;
                String? rawValue;
                for (final barcode in capture.barcodes) {
                  final value = barcode.rawValue?.trim();
                  if (value == null || value.isEmpty) continue;
                  rawValue = value;
                  break;
                }
                if (rawValue == null) return;

                _handled = true;
                Navigator.of(context).pop(rawValue);
              },
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.black.withValues(alpha: 0.62),
                child: const Text(
                  'Aponte a camera para o QR Code da aula aberta.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceQrPayload {
  static const type = 'attendance_checkin';

  final String academyId;
  final String sessionId;
  final DateTime generatedAt;

  const _AttendanceQrPayload({
    required this.academyId,
    required this.sessionId,
    required this.generatedAt,
  });

  String encode() {
    return jsonEncode({
      'type': type,
      'academyId': academyId,
      'sessionId': sessionId,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
    });
  }

  static _AttendanceQrPayload decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Payload QR invalido.');
    }

    final payloadType = decoded['type']?.toString();
    final academyId = decoded['academyId']?.toString().trim() ?? '';
    final sessionId = decoded['sessionId']?.toString().trim() ?? '';
    final generatedAtRaw = decoded['generatedAt']?.toString() ?? '';
    final generatedAt = DateTime.tryParse(generatedAtRaw);

    if (payloadType != type ||
        academyId.isEmpty ||
        sessionId.isEmpty ||
        generatedAt == null) {
      throw const FormatException('Payload QR invalido.');
    }

    return _AttendanceQrPayload(
      academyId: academyId,
      sessionId: sessionId,
      generatedAt: generatedAt,
    );
  }
}

class _CheckInTile extends StatelessWidget {
  const _CheckInTile({
    required this.checkIn,
    required this.canRemove,
    required this.onRemove,
  });

  final AttendanceCheckIn checkIn;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(_initials(checkIn.studentName))),
        title: Text(
          checkIn.studentName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_beltName(checkIn.belt)} - G${checkIn.degree} - ${_sourceLabel(checkIn.source)}',
        ),
        trailing:
            canRemove
                ? IconButton(
                  tooltip: 'Remover check-in',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                )
                : null,
      ),
    );
  }
}

class _AddStudentSheet extends StatefulWidget {
  const _AddStudentSheet({
    required this.academyId,
    required this.studentRepository,
    required this.checkedUids,
  });

  final String academyId;
  final IStudentRepository studentRepository;
  final Set<String> checkedUids;

  @override
  State<_AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends State<_AddStudentSheet> {
  late final Stream<List<StudentVm>> _studentsStream;

  @override
  void initState() {
    super.initState();
    _studentsStream = widget.studentRepository.watchStudents(
      academyId: widget.academyId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Adicionar aluno',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<StudentVm>>(
                  stream: _studentsStream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const TitansStateView.loading();
                    }

                    if (snap.hasError) {
                      return _ErrorState(message: snap.error.toString());
                    }

                    final students = snap.data ?? const <StudentVm>[];
                    if (students.isEmpty) {
                      return const _InlineEmptyState(
                        message: 'Nenhum aluno encontrado.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final student = students[index];
                        final checked = widget.checkedUids.contains(
                          student.uid,
                        );
                        return Card(
                          child: ListTile(
                            enabled: !checked,
                            leading: CircleAvatar(
                              child: Text(_initials(student.name)),
                            ),
                            title: Text(
                              student.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_beltName(student.belt)} - G${student.degree}',
                            ),
                            trailing:
                                checked
                                    ? const Icon(Icons.check_circle_outline)
                                    : const Icon(Icons.add_circle_outline),
                            onTap:
                                checked
                                    ? null
                                    : () => Navigator.of(context).pop(student),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Titulo'),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Informe o titulo'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _classTypeController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Tipo de aula'),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
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
    final endsAt =
        _endsAt.isAfter(startsAt)
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

        onPick(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
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
  final bool isStaff;

  const _EmptyState({required this.isStaff});

  @override
  Widget build(BuildContext context) {
    return TitansStateView.empty(
      title: 'Nenhuma sessao de presenca',
      message:
          isStaff
              ? 'Crie uma nova aula para registrar presencas.'
              : 'Nenhuma aula de presenca esta aberta no momento.',
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return TitansStateView.error(
      title: 'Erro ao carregar presenca',
      message: message,
    );
  }
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

String _sourceLabel(AttendanceCheckInSource source) {
  if (source == AttendanceCheckInSource.manual) return 'Manual';
  if (source == AttendanceCheckInSource.qr) return 'QR Code';
  return source.name.toUpperCase();
}

String _beltName(BeltColor belt) {
  return TitansUI.beltLabel(belt.name);
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'A';
  final first = parts.first.characters.first;
  final second =
      parts.length > 1 && parts.last.isNotEmpty
          ? parts.last.characters.first
          : '';
  return '$first$second'.toUpperCase();
}

String _formatDateTime(DateTime value) {
  return '${_two(value.day)}/${_two(value.month)} ${_two(value.hour)}:${_two(value.minute)}';
}

String _formatTime(DateTime value) {
  return '${_two(value.hour)}:${_two(value.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
