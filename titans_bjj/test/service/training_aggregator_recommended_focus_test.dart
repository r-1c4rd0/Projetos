import 'package:flutter_test/flutter_test.dart';
import 'package:titans_bjj/model/training_session.dart';
import 'package:titans_bjj/service/training_aggregator.dart';

void main() {
  group('TrainingAggregator.buildRecommendedFocus v2', () {
    test('prioriza falha ou defesa em aplicacao real', () {
      final focus = TrainingAggregator.buildRecommendedFocus([
        session(
          date: DateTime(2026, 8, 20),
          position: 'Montada',
          technique: 'Americana',
          applicationContext: TrainingSession.applicationContextSparring,
          techniqueOutcome: TrainingSession.techniqueOutcomeDefended,
        ),
        session(
          date: DateTime(2026, 8, 21),
          position: 'Guarda',
          technique: 'Raspagem',
          difficulties: 'base instavel',
        ),
      ]);

      expect(focus.technique, 'Americana');
      expect(focus.position, 'Montada');
      expect(focus.priority, RecommendedTrainingFocusPriority.high);
      expect(
        focus.recommendationType,
        RecommendedTrainingFocusType.applicationAdjustment,
      );
      expect(focus.tags, contains('Aplica\u00e7\u00e3o real'));
      expect(focus.tags, contains('Precisa ajuste'));
      expect(_displayText(focus), contains('Rola'));
      expect(_displayText(focus), contains('Parceiro defendeu'));
      expectNoRawEnums(focus);
    });

    test('sugere consolidar quando quase funcionou em aplicacao real', () {
      final focus = TrainingAggregator.buildRecommendedFocus([
        session(
          date: DateTime(2026, 8, 20),
          position: 'Meia Guarda',
          technique: 'Raspagem Coyote',
          applicationContext:
              TrainingSession.applicationContextPositionalSparring,
          techniqueOutcome: TrainingSession.techniqueOutcomeAlmost,
        ),
      ]);

      expect(focus.technique, 'Raspagem Coyote');
      expect(focus.title, contains('Consolidar'));
      expect(focus.priority, isIn([
        RecommendedTrainingFocusPriority.high,
        RecommendedTrainingFocusPriority.medium,
      ]));
      expect(focus.recommendationType, RecommendedTrainingFocusType.nearSuccess);
      expect(_displayText(focus), contains('Quase funcionou'));
      expect(_displayText(focus), contains('Treino posicional'));
      expectNoRawEnums(focus);
    });

    test('sugere repetir quando funcionou com pouca repeticao', () {
      final focus = TrainingAggregator.buildRecommendedFocus([
        session(
          date: DateTime(2026, 8, 20),
          position: 'Guarda Fechada',
          technique: 'Vi\u00fava Negra',
          applicationContext: TrainingSession.applicationContextCompetition,
          techniqueOutcome: TrainingSession.techniqueOutcomeWorked,
        ),
      ]);

      expect(focus.technique, 'Vi\u00fava Negra');
      expect(focus.title, contains('Repetir'));
      expect(focus.priority, RecommendedTrainingFocusPriority.medium);
      expect(focus.recommendationType, RecommendedTrainingFocusType.recentSuccess);
      expect(_displayText(focus), contains('Funcionou'));
      expect(_displayText(focus), contains('Competi\u00e7\u00e3o'));
      expectNoRawEnums(focus);
    });

    test('sugere testar tecnica treinada apenas em drill', () {
      final focus = TrainingAggregator.buildRecommendedFocus([
        session(
          date: DateTime(2026, 8, 20),
          position: 'Guarda',
          technique: 'Lapela',
          applicationContext: TrainingSession.applicationContextDrill,
          techniqueOutcome: TrainingSession.techniqueOutcomeWorked,
        ),
      ]);

      expect(focus.technique, 'Lapela');
      expect(focus.title, contains('Testar'));
      expect(focus.priority, RecommendedTrainingFocusPriority.medium);
      expect(
        focus.recommendationType,
        RecommendedTrainingFocusType.drillToApplication,
      );
      expect(_displayText(focus), contains('Drill'));
      expect(_displayText(focus), contains('Testar aplica\u00e7\u00e3o'));
      expect(_displayText(focus), isNot(contains('Aplica\u00e7\u00e3o real')));
      expectNoRawEnums(focus);
    });

    test('preserva fallback v1 por dificuldade recente', () {
      final focus = TrainingAggregator.buildRecommendedFocus([
        session(
          date: DateTime(2026, 8, 19),
          position: 'Costas',
          technique: 'Mata-le\u00e3o',
          difficulties: 'perdi o controle',
        ),
      ]);

      expect(focus.hasRecommendation, isTrue);
      expect(focus.technique, 'Mata-le\u00e3o');
      expect(focus.title, contains('Revisar'));
      expect(focus.recommendationType, RecommendedTrainingFocusType.difficulty);
      expect(focus.tags, contains('Dificuldade recente'));
      expect(focus.confidenceLabel, 'Fallback v1');
      expectNoRawEnums(focus);
    });

    test('retorna estado vazio para lista vazia ou sem tecnica', () {
      final empty = TrainingAggregator.buildRecommendedFocus(const []);
      final withoutTechnique = TrainingAggregator.buildRecommendedFocus([
        session(
          date: DateTime(2026, 8, 20),
          position: 'Guarda',
          difficulties: 'sem detalhe',
        ),
      ]);

      for (final focus in [empty, withoutTechnique]) {
        expect(focus.hasRecommendation, isFalse);
        expect(focus.recommendationType, RecommendedTrainingFocusType.none);
        expect(focus.summary, contains('t\u00e9cnica'));
        expect(focus.reason, contains('posi\u00e7\u00e3o'));
        expectNoRawEnums(focus);
      }
    });

    test('usa evidencia mais recente quando prioridades equivalem', () {
      final focus = TrainingAggregator.buildRecommendedFocus([
        session(
          date: DateTime(2026, 8, 18),
          position: 'Montada',
          technique: 'Americana',
          applicationContext: TrainingSession.applicationContextSparring,
          techniqueOutcome: TrainingSession.techniqueOutcomeFailed,
        ),
        session(
          date: DateTime(2026, 8, 22),
          position: 'Guarda',
          technique: 'Triangulo',
          applicationContext:
              TrainingSession.applicationContextPositionalSparring,
          techniqueOutcome: TrainingSession.techniqueOutcomeDefended,
        ),
      ]);

      expect(focus.technique, 'Triangulo');
      expect(focus.position, 'Guarda');
      expect(
        focus.recommendationType,
        RecommendedTrainingFocusType.applicationAdjustment,
      );
      expect(_displayText(focus), contains('Treino posicional'));
      expectNoRawEnums(focus);
    });

    test('mantem labels de apresentacao sem enum bruto', () {
      final focus = TrainingAggregator.buildRecommendedFocus([
        session(
          date: DateTime(2026, 8, 20),
          position: 'Guarda',
          technique: 'Armbar',
          applicationContext: TrainingSession.applicationContextSparring,
          techniqueOutcome: TrainingSession.techniqueOutcomeFailed,
        ),
      ]);

      final text = _displayText(focus);
      expect(text, contains('Rola'));
      expect(text, contains('Falhou'));
      expectNoRawEnums(focus);
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

String _displayText(RecommendedTrainingFocus focus) {
  return [
    focus.title,
    focus.summary,
    focus.reason,
    focus.suggestedAction,
    focus.evidenceLabel,
    focus.applicationLabel,
    focus.outcomeLabel,
    focus.confidenceLabel,
    focus.nextStepLabel,
    ...focus.tags,
    ...focus.evidenceTags,
  ].whereType<String>().join(' | ');
}

void expectNoRawEnums(RecommendedTrainingFocus focus) {
  final text = _displayText(focus);
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