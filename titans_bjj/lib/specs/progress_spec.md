# Progress Spec

## Objetivo do modulo
Definir progresso do atleta como leitura consolidada de treinos, presenca, graduacao, metas e indicadores de evolucao.

## Responsabilidades
- Exibir progresso individual.
- Agregar historico por periodo.
- Alimentar painel do mestre.
- Apoiar status automatico e elegibilidade de graduacao.

## Dados usados
- `UserProgressProfile`
- `ProgressPeriod`
- Treinos e presencas.
- Graduacao atual e historico.
- Metas, frequencia, consistencia e indicadores futuros.

## Telas envolvidas
- `progress_screen.dart`
- `athlete_dashboard_screen.dart`
- `athlete_console_screen.dart`
- `master_panel_screen.dart`

## Repositories envolvidas
- `UserProgressRepository`
- `TrainingRepository`
- `StudentsRepository`
- Futuro `AttendanceRepository`
- Futuro `GraduationRepository`

## Regras de negocio
- Progresso deve ser derivado de fontes canonicas sempre que possivel.
- Indicadores devem ser calculados por academia, aluno, modalidade e periodo.
- Athlete ve seu progresso.
- Professor/admin ve progresso dos alunos autorizados.

## Problemas atuais
- Progresso pode duplicar graduacao.
- Agregacoes podem estar espalhadas.
- Status automatico ainda nao existe como engine.
- Periodos e filtros precisam de contrato consistente.

## Arquitetura desejada
Feature futura:

```text
features/progress/
  data/
    repositories/progress_repository.dart
  domain/
    entities/progress_snapshot.dart
    entities/progress_period.dart
    use_cases/build_progress_snapshot.dart
    use_cases/evaluate_athlete_status.dart
  presentation/
    screens/progress_screen.dart
    widgets/progress_summary.dart
    view_models/progress_view_model.dart
```

## Plano de migracao incremental
1. Definir indicadores oficiais.
2. Separar dado armazenado de dado calculado.
3. Remover dependencia de campos duplicados.
4. Migrar tela para snapshot unico.
5. Integrar presenca e graduacao.
6. Alimentar analytics/status engine.

## Riscos de regressao
- Numeros historicos mudarem sem explicacao.
- Dashboard e tela de progresso divergirem.
- Calculos pesados afetarem performance.
- Dados incompletos gerarem status incorreto.

## Criterios de aceite
- Fontes de progresso estao definidas.
- Status automatico esta previsto.
- Graduacao duplicada nao deve ser fonte futura.
- Nenhum calculo atual foi alterado nesta etapa.
