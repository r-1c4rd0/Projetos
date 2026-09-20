import 'package:flutter/material.dart';

import '../features/training/application/training_use_cases.dart';
import '../model/training_session.dart';
import 'quick_log_sheet.dart';

enum TrainingSaveConfirmationKind { created, plannedSessionConfirmed }

enum TrainingConfirmationDetail { technique, position, intensity }

Set<TrainingConfirmationDetail> quickLogConfirmationDetails(
  QuickLogSaveResult result,
) {
  final fields = result.explicitlyProvidedFields;
  return <TrainingConfirmationDetail>{
    if (fields.contains(QuickLogInputField.technique))
      TrainingConfirmationDetail.technique,
    if (fields.contains(QuickLogInputField.position))
      TrainingConfirmationDetail.position,
    if (fields.contains(QuickLogInputField.intensity))
      TrainingConfirmationDetail.intensity,
  };
}

void showTrainingSaveConfirmation({
  required BuildContext context,
  required TrainingSession session,
  required TrainingSaveConfirmationKind kind,
  required VoidCallback onViewTraining,
  Set<TrainingConfirmationDetail> visibleDetails =
      const <TrainingConfirmationDetail>{
        TrainingConfirmationDetail.technique,
        TrainingConfirmationDetail.position,
        TrainingConfirmationDetail.intensity,
      },
}) {
  final title = switch (kind) {
    TrainingSaveConfirmationKind.created => 'Treino registrado',
    TrainingSaveConfirmationKind.plannedSessionConfirmed =>
      'Treino planejado confirmado',
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            trainingSaveConfirmationSummary(
              session,
              visibleDetails: visibleDetails,
            ),
          ),
        ],
      ),
      action: SnackBarAction(label: 'Ver treino', onPressed: onViewTraining),
    ),
  );
}

String trainingSaveConfirmationSummary(
  TrainingSession session, {
  Set<TrainingConfirmationDetail> visibleDetails =
      const <TrainingConfirmationDetail>{
        TrainingConfirmationDetail.technique,
        TrainingConfirmationDetail.position,
        TrainingConfirmationDetail.intensity,
      },
}) {
  final details = <String>[smartDateLabel(session.date)];
  final primaryEntry = session.effectiveTechniqueEntries.firstOrNull;
  final technique = cleanTrainingDisplayText(
    primaryEntry?.technique ?? session.technique,
  );
  final position = cleanTrainingDisplayText(
    primaryEntry?.position ?? session.position,
  );

  if (visibleDetails.contains(TrainingConfirmationDetail.technique) &&
      technique != null) {
    details.add(technique);
  } else if (visibleDetails.contains(TrainingConfirmationDetail.position) &&
      position != null) {
    details.add(position);
  }
  if (visibleDetails.contains(TrainingConfirmationDetail.intensity) &&
      session.intensity != null) {
    details.add('Intensidade ${session.intensity}/5');
  }
  if (details.length == 1) details.add('Salvo no histórico');
  return details.join(' • ');
}
