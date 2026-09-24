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

part '../widgets/attendance/attendance_session_list.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceRepository _repository = AttendanceRepository.instance;
  final IStudentRepository _studentRepository = StudentRepository.create();

  AppUser? _user;
  String? _activeAcademyId;
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

    final scope = UserScope.scopeOf(context);
    final user = scope.user;
    final academyId = scope.activeAcademyId.trim();
    if (_user?.uid == user.uid && _activeAcademyId == academyId) return;

    _user = user;
    _activeAcademyId = academyId;
    _sessionsStream =
        academyId.isEmpty
            ? Stream<List<AttendanceSession>>.value(const <AttendanceSession>[])
            : _repository.watchSessions(academyId: academyId);
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
                label: const Text('Abrir chamada'),
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

                  return AttendanceSessionList(
                    sessions: snap.data ?? const <AttendanceSession>[],
                    isStaff: _isStaff,
                    isBusy: _submitting,
                    onOpen: _openSessionDetails,
                    onClose: _closeSession,
                    onCancel: _cancelSession,
                  );
                },
              ),
    );
  }

  Future<void> _openCreateSession() async {
    final user = _user;
    final academyId = _activeAcademyId?.trim() ?? '';
    if (user == null || academyId.isEmpty || !_isStaff) return;

    final draft = await showModalBottomSheet<_AttendanceSessionDraft?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateAttendanceSessionSheet(),
    );

    if (draft == null) return;

    setState(() => _submitting = true);
    try {
      await _repository.createSession(
        academyId: academyId,
        title: draft.title,
        classType: draft.classType,
        instructorUid: user.uid,
        instructorName: user.name.isEmpty ? user.email : user.name,
        startsAt: draft.startsAt,
        endsAt: draft.endsAt,
      );
      if (!mounted) return;
      _showMessage('Chamada aberta.');
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
      successMessage: 'Sessao anulada.',
      errorMessage: 'Nao foi possivel anular a sessao',
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
      appBar: AppBar(title: const Text('Chamada')),
      floatingActionButton:
          _canEdit
              ? FloatingActionButton.extended(
                heroTag: 'attendance_checkin_fab_${session.id}',
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Marcar manualmente'),
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
    final manualCount =
        visibleCheckIns
            .where((item) => item.source == AttendanceCheckInSource.manual)
            .length;
    final qrCount =
        visibleCheckIns
            .where((item) => item.source == AttendanceCheckInSource.qr)
            .length;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: TitansUI.listPadding(context),
          children: [
            _SessionHeader(session: session),
            const SizedBox(height: 12),
            _MetricRail(
              metrics: [
                _MetricData('Marcados', visibleCheckIns.length.toString()),
                _MetricData('Presentes', visibleCheckIns.length.toString()),
                _MetricData('Manual', manualCount.toString()),
                _MetricData('QR', qrCount.toString()),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: _SectionTitle('Lista de presenca')),
                if (session.status == AttendanceSessionStatus.open)
                  _QrCheckInActionCard(
                    isStaff: _isStaff,
                    isBusy: _submitting,
                    onShowQr: _isStaff ? () => _showQrCode(session) : null,
                    onScanQr: !_isStaff ? () => _scanQrCode(session) : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (visibleCheckIns.isEmpty)
              const _InlineEmptyState(message: 'Nenhum aluno marcado ainda.')
            else
              ...visibleCheckIns.map(
                (checkIn) => _CheckInTile(
                  checkIn: checkIn,
                  canRemove: _canEdit && !_submitting,
                  onRemove: () => _removeCheckIn(checkIn),
                ),
              ),
          ],
        ),
      ),
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
                  'QR da chamada',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use este QR para check-in dos alunos presentes.',
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

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});

  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(cs, session.status);
    final instructor =
        session.instructorName.isEmpty
            ? session.instructorUid
            : session.instructorName;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRESENCA',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_relativeDayLabel(session.startsAt)} - ${_formatShortDate(session.startsAt)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${session.classType} - ${_formatTime(session.startsAt)} - $instructor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.66),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _CompactStatusPill(
              label: _statusLabel(session.status),
              color: statusColor,
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
    final action = isStaff ? onShowQr : onScanQr;
    return OutlinedButton.icon(
      icon: Icon(
        isStaff ? Icons.qr_code_2_outlined : Icons.qr_code_scanner_outlined,
      ),
      label: Text(isStaff ? 'Check-in por QR' : 'Escanear QR'),
      onPressed: isBusy ? null : action,
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
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.42)),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: cs.primary.withValues(alpha: 0.12),
          child: Text(
            _initials(checkIn.studentName),
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(
          checkIn.studentName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${_beltName(checkIn.belt)} - Grau ${checkIn.degree} - ${_sourceLabel(checkIn.source)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing:
            canRemove
                ? IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                )
                : _CompactStatusPill(label: 'Presente', color: Colors.green),
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
                  'Marcar aluno',
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

class _MetricData {
  const _MetricData(this.label, this.value);

  final String label;
  final String value;
}

class _MetricRail extends StatelessWidget {
  const _MetricRail({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              Expanded(child: _MetricItem(metric: metrics[i])),
              if (i != metrics.length - 1)
                SizedBox(
                  height: 30,
                  child: VerticalDivider(color: cs.outlineVariant),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          metric.value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.62),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _CompactStatusPill extends StatelessWidget {
  const _CompactStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
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
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.74)),
          ),
        ),
      ],
    );
  }
}

enum _ClassMode { single, recurring }

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

  _ClassMode _mode = _ClassMode.single;
  DateTime _startsAt = _nextHour();
  DateTime _endsAt = _nextHour().add(const Duration(hours: 1));
  DateTime? _recurrenceEndsAt;
  final Set<int> _recurrenceWeekdays = <int>{};

  @override
  void dispose() {
    _titleController.dispose();
    _classTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isSingle = _mode == _ClassMode.single;
    final recurrenceMessage = _recurrenceValidationMessage();

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
                'Abrir chamada',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                isSingle
                    ? 'Aula unica por padrao.'
                    : 'Repeticao aberta para revisao; a persistencia ainda e manual.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.70),
                ),
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
              const SizedBox(height: 16),
              const _SheetSectionTitle('Data'),
              const SizedBox(height: 8),
              _DateQuickSelector(
                selectedDate: _startsAt,
                onToday: () => _setDate(DateTime.now()),
                onTomorrow:
                    () => _setDate(DateTime.now().add(const Duration(days: 1))),
                onOtherDate: _pickStartDate,
              ),
              const SizedBox(height: 10),
              Text(
                _formatFullDate(_startsAt),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Inicio',
                      value: _startsAt,
                      onPick: _setStartTime,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TimeField(
                      label: 'Fim',
                      value: _endsAt,
                      onPick: _setEndTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SheetSectionTitle('Modo'),
              const SizedBox(height: 8),
              SegmentedButton<_ClassMode>(
                segments: const [
                  ButtonSegment(
                    value: _ClassMode.single,
                    icon: Icon(Icons.event_available_outlined),
                    label: Text('Aula unica'),
                  ),
                  ButtonSegment(
                    value: _ClassMode.recurring,
                    icon: Icon(Icons.event_repeat_outlined),
                    label: Text('Repetir aula'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged:
                    (value) => setState(() => _mode = value.first),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child:
                    isSingle
                        ? Column(
                          key: const ValueKey('single'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ScheduleSummary(
                              title: 'Resumo da agenda',
                              text:
                                  'Aula unica - ${_formatFullDate(_startsAt)} as ${_formatTime(_startsAt)}',
                            ),
                          ],
                        )
                        : Column(
                          key: const ValueKey('recurring'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _RecurrenceControls(
                              startsAt: _startsAt,
                              endsAt: _recurrenceEndsAt,
                              selectedWeekdays: _recurrenceWeekdays,
                              onWeekdayToggle: _toggleRecurrenceWeekday,
                              onPickEnd: _pickRecurrenceEndDate,
                            ),
                            const SizedBox(height: 12),
                            _ScheduleSummary(
                              title: 'Resumo da agenda',
                              text: _recurrenceSummary(),
                              warning: recurrenceMessage,
                            ),
                          ],
                        ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  isSingle ? 'Abrir chamada' : 'Criar aulas recorrentes',
                ),
                onPressed: isSingle ? _submit : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final date = await _showTitansDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    _setDate(date);
  }

  Future<void> _pickRecurrenceEndDate() async {
    final date = await _showTitansDatePicker(
      context: context,
      initialDate: _recurrenceEndsAt ?? _startsAt.add(const Duration(days: 28)),
      firstDate: _dateOnly(_startsAt),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() => _recurrenceEndsAt = date);
  }

  void _setDate(DateTime date) {
    final currentDuration = _endsAt.difference(_startsAt);
    final duration =
        currentDuration.isNegative || currentDuration.inMinutes == 0
            ? const Duration(hours: 1)
            : currentDuration;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        _startsAt.hour,
        _startsAt.minute,
      );
      _endsAt = _startsAt.add(duration);
      if (_recurrenceEndsAt != null &&
          _recurrenceEndsAt!.isBefore(_dateOnly(_startsAt))) {
        _recurrenceEndsAt = null;
      }
    });
  }

  void _setStartTime(TimeOfDay value) {
    setState(() {
      _startsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        value.hour,
        value.minute,
      );
      if (!_endsAt.isAfter(_startsAt)) {
        _endsAt = _startsAt.add(const Duration(hours: 1));
      }
    });
  }

  void _setEndTime(TimeOfDay value) {
    setState(() {
      _endsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        value.hour,
        value.minute,
      );
      if (!_endsAt.isAfter(_startsAt)) {
        _endsAt = _startsAt.add(const Duration(hours: 1));
      }
    });
  }

  void _toggleRecurrenceWeekday(int weekday) {
    setState(() {
      if (_recurrenceWeekdays.contains(weekday)) {
        _recurrenceWeekdays.remove(weekday);
      } else {
        _recurrenceWeekdays.add(weekday);
      }
    });
  }

  String? _recurrenceValidationMessage() {
    if (_mode == _ClassMode.single) return null;
    final endsAt = _recurrenceEndsAt;
    if (_recurrenceWeekdays.isEmpty) {
      return 'Escolha pelo menos um dia da semana.';
    }
    if (endsAt == null) {
      return 'Informe o termino da repeticao.';
    }
    if (endsAt.isBefore(_dateOnly(_startsAt))) {
      return 'O termino precisa ser igual ou posterior ao inicio.';
    }
    if (!_hasRecurrenceOccurrence(_dateOnly(_startsAt), endsAt)) {
      return 'A configuracao nao gera nenhuma aula.';
    }
    return 'Agenda recorrente ainda nao possui contrato de persistencia nesta tela.';
  }

  bool _hasRecurrenceOccurrence(DateTime start, DateTime end) {
    var cursor = start;
    final limit = _dateOnly(end);
    while (!cursor.isAfter(limit)) {
      if (_recurrenceWeekdays.contains(cursor.weekday)) return true;
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  String _recurrenceSummary() {
    final weekdays = _formatWeekdayList(_recurrenceWeekdays);
    final end = _recurrenceEndsAt;
    if (_recurrenceWeekdays.isEmpty || end == null) {
      return 'Complete dias e termino para revisar.';
    }
    return 'Repete toda $weekdays\nDe ${_formatShortDate(_startsAt)} ate ${_formatShortDate(end)}';
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

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.text, this.title, this.warning});

  final String text;
  final String? title;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              text,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Text(
                warning!,
                style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _DateQuickSelector extends StatelessWidget {
  const _DateQuickSelector({
    required this.selectedDate,
    required this.onToday,
    required this.onTomorrow,
    required this.onOtherDate,
  });

  final DateTime selectedDate;
  final VoidCallback onToday;
  final VoidCallback onTomorrow;
  final VoidCallback onOtherDate;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final selected = _dateOnly(selectedDate);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          avatar: const Icon(Icons.today_outlined, size: 18),
          label: const Text('Hoje'),
          selected: selected == today,
          onSelected: (_) => onToday(),
        ),
        ChoiceChip(
          avatar: const Icon(Icons.next_plan_outlined, size: 18),
          label: const Text('Amanha'),
          selected: selected == today.add(const Duration(days: 1)),
          onSelected: (_) => onTomorrow(),
        ),
        ActionChip(
          avatar: const Icon(Icons.calendar_month_outlined, size: 18),
          label: const Text('Outra data'),
          onPressed: onOtherDate,
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime value;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
          helpText: 'Escolher horario',

          confirmText: 'Confirmar',
        );
        if (time == null) return;
        onPick(time);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(_formatTime(value)),
      ),
    );
  }
}

class _RecurrenceControls extends StatelessWidget {
  const _RecurrenceControls({
    required this.startsAt,
    required this.endsAt,
    required this.selectedWeekdays,
    required this.onWeekdayToggle,
    required this.onPickEnd,
  });

  final DateTime startsAt;
  final DateTime? endsAt;
  final Set<int> selectedWeekdays;
  final ValueChanged<int> onWeekdayToggle;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    const weekdays = <MapEntry<int, String>>[
      MapEntry(DateTime.monday, 'S'),
      MapEntry(DateTime.tuesday, 'T'),
      MapEntry(DateTime.wednesday, 'Q'),
      MapEntry(DateTime.thursday, 'Q'),
      MapEntry(DateTime.friday, 'S'),
      MapEntry(DateTime.saturday, 'S'),
      MapEntry(DateTime.sunday, 'D'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _FieldLabel('Repetir')),
            _CompactStatusPill(
              label: 'Semanalmente',
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _FieldLabel('Dias'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final item in weekdays)
              FilterChip(
                label: Text(item.value),
                selected: selectedWeekdays.contains(item.key),
                onSelected: (_) => onWeekdayToggle(item.key),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(child: _FieldLabel('Ate')),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_busy_outlined),
              label: Text(
                endsAt == null ? 'Definir termino' : _formatDate(endsAt!),
              ),
              onPressed: onPickEnd,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Outros formatos ficam para um contrato futuro.',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _TitansCalendarSheet extends StatefulWidget {
  const _TitansCalendarSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_TitansCalendarSheet> createState() => _TitansCalendarSheetState();
}

class _TitansCalendarSheetState extends State<_TitansCalendarSheet> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.initialDate);
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final days = _monthCells(_visibleMonth);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Escolher data',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _canGoToPreviousMonth() ? _previousMonth : null,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _canGoToNextMonth() ? _nextMonth : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: const [
                _WeekdayCell('SEG'),
                _WeekdayCell('TER'),
                _WeekdayCell('QUA'),
                _WeekdayCell('QUI'),
                _WeekdayCell('SEX'),
                _WeekdayCell('SAB'),
                _WeekdayCell('DOM'),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: days.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final day = days[index];
                if (day == null) return const SizedBox.shrink();
                final disabled =
                    day.isBefore(_dateOnly(widget.firstDate)) ||
                    day.isAfter(_dateOnly(widget.lastDate));
                final selected = day == _selectedDate;
                final isToday = day == today;
                return _CalendarDayButton(
                  day: day,
                  selected: selected,
                  today: isToday,
                  disabled: disabled,
                  onPressed:
                      disabled
                          ? null
                          : () => setState(() => _selectedDate = day),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed:
                      today.isBefore(_dateOnly(widget.firstDate)) ||
                              today.isAfter(_dateOnly(widget.lastDate))
                          ? null
                          : () => setState(() {
                            _selectedDate = today;
                            _visibleMonth = DateTime(today.year, today.month);
                          }),
                  child: const Text('Hoje'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDate),
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<DateTime?> _monthCells(DateTime month) {
    final firstDay = DateTime(month.year, month.month);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final leadingEmptyCells = firstDay.weekday - DateTime.monday;
    return <DateTime?>[
      for (var i = 0; i < leadingEmptyCells; i++) null,
      for (var day = 1; day <= lastDay.day; day++)
        DateTime(month.year, month.month, day),
    ];
  }

  bool _canGoToPreviousMonth() {
    final previous = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    return !previous.isBefore(firstMonth);
  }

  bool _canGoToNextMonth() {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    return !next.isAfter(lastMonth);
  }

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.62),
        ),
      ),
    );
  }
}

class _CalendarDayButton extends StatelessWidget {
  const _CalendarDayButton({
    required this.day,
    required this.selected,
    required this.today,
    required this.disabled,
    required this.onPressed,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final bool disabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg =
        selected
            ? cs.primary
            : today
            ? cs.primary.withValues(alpha: 0.10)
            : Colors.transparent;
    final fg =
        selected
            ? cs.onPrimary
            : disabled
            ? cs.onSurface.withValues(alpha: 0.32)
            : cs.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  today && !selected
                      ? cs.primary.withValues(alpha: 0.32)
                      : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(color: fg, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

Future<DateTime?> _showTitansDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: _TitansCalendarSheet(
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
      );
    },
  );
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
      return 'Anulada';
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

String _relativeDayLabel(DateTime value) {
  final day = _dateOnly(value);
  final today = _dateOnly(DateTime.now());
  if (day == today) return 'Hoje';
  if (day == today.add(const Duration(days: 1))) return 'Amanha';
  return _weekdayName(value.weekday);
}

String _formatDateTime(DateTime value) {
  return '${_two(value.day)}/${_two(value.month)} ${_two(value.hour)}:${_two(value.minute)}';
}

String _formatDate(DateTime value) {
  return '${_two(value.day)}/${_two(value.month)}/${value.year}';
}

String _formatFullDate(DateTime value) {
  return '${_weekdayName(value.weekday)}-feira, ${value.day} de ${_monthName(value.month)} de ${value.year}';
}

String _formatShortDate(DateTime value) {
  return '${value.day} de ${_monthName(value.month)}';
}

String _formatWeekdayList(Set<int> weekdays) {
  final ordered = weekdays.toList()..sort();
  final labels = ordered.map(_weekdayName).toList();
  if (labels.isEmpty) return 'dia escolhido';
  if (labels.length == 1) return labels.single;
  return '${labels.take(labels.length - 1).join(', ')} e ${labels.last}';
}

String _weekdayName(int weekday) {
  const names = <int, String>{
    DateTime.monday: 'segunda',
    DateTime.tuesday: 'terca',
    DateTime.wednesday: 'quarta',
    DateTime.thursday: 'quinta',
    DateTime.friday: 'sexta',
    DateTime.saturday: 'sabado',
    DateTime.sunday: 'domingo',
  };
  return names[weekday] ?? 'dia escolhido';
}

String _monthName(int month) {
  const names = <int, String>{
    1: 'janeiro',
    2: 'fevereiro',
    3: 'marco',
    4: 'abril',
    5: 'maio',
    6: 'junho',
    7: 'julho',
    8: 'agosto',
    9: 'setembro',
    10: 'outubro',
    11: 'novembro',
    12: 'dezembro',
  };
  return names[month] ?? 'mes';
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _formatTime(DateTime value) {
  return '${_two(value.hour)}:${_two(value.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
