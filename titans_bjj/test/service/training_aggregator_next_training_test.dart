import 'package:flutter_test/flutter_test.dart';
import 'package:titans_bjj/model/training_session.dart';
import 'package:titans_bjj/service/training_aggregator.dart';

void main() {
  group('TrainingAggregator.buildNextTrainingRecommendation', () {
    test('gera revisao para falha ou defesa em aplicacao real', () {
      final recommendation = TrainingAggregator.buildNextTrainingRecommendation([
        session(
          date: DateTime(2026, 8, 20),
          position: 'Montada',
          technique: 'Americana',
          intensity: 4,
          applicationContext: TrainingSession.applicationContextSparring,
          techniqueOutcome: TrainingSession.techniqueOutcomeDefended,
        ),
      ]);

      expect(recommendation.hasRecommendation, isTrue);
      expect(recommendation.focusTechnique, 'Americana');
      expect(recommendation.priority, RecommendedTrainingFocusPriority.high);
      expect(recommendation.title, contains('revisar'));
      expect(recommendation.objective, contains('controle'));
      expect(recommendation.applicationSuggestion, contains('treino posicional'));
      expectNoRawLabels(recommendation);
    });

    test('gera consolidacao quando quase funcionou', () {
      final recommendation = TrainingAggregator.buildNextTrainingRecommendation([
        session(
          date: DateTime(2026, 8, 20),
          position: 'Meia Guarda',
          technique: 'Raspagem Coyote',
          applicationContext:
              TrainingSession.applicationContextPositionalSparring,
          techniqueOutcome: TrainingSession.techniqueOutcomeAlmost,
        ),
      ]);

      expect(recommendation.focusTechnique, 'Raspagem Coyote');
      expect(recommendation.title, contains('consolidar'));
      expect(recommendation.objective, contains('detalhe'));
      expect(recommendation.tags, contains('Quase funcionou'));
      expectNoRawLabels(recommendation);
    });

    test('repete tecnica que funcionou com pouca repeticao', () {
      final recommendation = TrainingAggregator.buildNextTrainingRecommendation([
        session(
          date: DateTime(2026, 8, 20),
          position: 'Guarda Fechada',
          technique: 'Vi\u00fava Negra',
          applicationContext: TrainingSession.applicationContextCompetition,
          techniqueOutcome: TrainingSession.techniqueOutcomeWorked,
        ),
      ]);

      expect(recommendation.title, contains('repetir'));
      expect(recommendation.applicationSuggestion, contains('resist\u00eancia progressiva'));
      expect(recommendation.tags, contains('Funcionou'));
      expectNoRawLabels(recommendation);
    });

    test('leva drill para aplicacao controlada', () {
      final recommendation = TrainingAggregator.buildNextTrainingRecommendation([
        session(
          date: DateTime(2026, 8, 20),
          position: 'Guarda',
          technique: 'Lapela',
          applicationContext: TrainingSession.applicationContextDrill,
          techniqueOutcome: TrainingSession.techniqueOutcomeWorked,
        ),
      ]);

      expect(recommendation.title, contains('testar'));
      expect(recommendation.objective, contains('situa\u00e7\u00e3o controlada'));
      expect(recommendation.applicationSuggestion, contains('registrar'));
      expect(recommendation.tags, contains('Drill'));
      expectNoRawLabels(recommendation);
    });

    test('retorna mensagem vazia sem tecnica registrada', () {
      final recommendation = TrainingAggregator.buildNextTrainingRecommendation([
        session(
          date: DateTime(2026, 8, 20),
          position: 'Guarda',
          difficulties: 'sem detalhe',
        ),
      ]);

      expect(recommendation.hasRecommendation, isFalse);
      expect(recommendation.emptyMessage, contains('posi\u00e7\u00e3o'));
      expect(recommendation.emptyMessage, contains('t\u00e9cnica'));
      expectNoRawLabels(recommendation);
    });

    test('nao vaza labels brutos em cenario de dificuldade', () {
      final recommendation = TrainingAggregator.buildNextTrainingRecommendation([
        session(
          date: DateTime(2026, 8, 19),
          position: 'Costas',
          technique: 'Mata-le\u00e3o',
          difficulties: 'perdi o controle',
          applicationContext: TrainingSession.applicationContextNotApplied,
          techniqueOutcome: TrainingSession.techniqueOutcomeNotTested,
        ),
      ]);

      expect(recommendation.hasRecommendation, isTrue);
      expect(recommendation.title, contains('revisar'));
      expectNoRawLabels(recommendation);
    });
  });
}

TrainingSession session({
  required DateTime date,
  String? position,
  String? technique,
  String? difficulties,
  String? successes,
  int? intensity,
  String? applicationContext,
  String? techniqueOutcome,
}) {
  return TrainingSession(
    id: date.microsecondsSinceEpoch.toString(),
    date: date,
    place: TrainingPlace.academy,
    position: position,
    technique: technique,
    difficulties: difficulties,
    successes: successes,
    intensity: intensity,
    applicationContext: applicationContext,
    techniqueOutcome: techniqueOutcome,
  );
}

String displayText(NextTrainingRecommendation recommendation) {
  return [
    recommendation.title,
    recommendation.subtitle,
    recommendation.focusPosition,
    recommendation.focusTechnique,
    recommendation.objective,
    recommendation.warmupSuggestion,
    recommendation.technicalDrill,
    recommendation.applicationSuggestion,
    recommendation.reflectionQuestion,
    recommendation.intensityGuidance,
    recommendation.emptyMessage,
    ...recommendation.tags,
  ].whereType<String>().join(' | ');
}

void expectNoRawLabels(NextTrainingRecommendation recommendation) {
  final text = displayText(recommendation);
  const forbidden = [
    'sparring',
    'positionalSparring',
    'competition',
    'worked',
    'almost',
    'failed',
    'defended',
    'notTested',
    'Other',
    'Aplicacao',
    'N\u00ef\u00bf\u00bdo',
    'T\u00ef\u00bf\u00bdcnica',
  ];

  for (final value in forbidden) {
    expect(text, isNot(contains(value)), reason: 'raw label leaked: $value');
  }
}