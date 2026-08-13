# Graduation Spec

## Objetivo do modulo
Definir fonte unica de graduacao por modalidade, regras de progressao e exibicao consistente de faixa/grau para atletas e professores.

## Responsabilidades
- Centralizar faixa, grau e historico de graduacao.
- Suportar regras por modalidade e academia.
- Evitar duplicidade entre perfil do aluno, progresso e regras.
- Permitir evolucao para aprovacao pelo mestre/professor.

## Dados usados
- Perfil do atleta.
- Regras de graduacao.
- Historico de graduacoes.
- Modalidade: BJJ inicialmente, outras futuramente.
- Presenca, tempo de treino e progresso como criterios possiveis.

## Telas envolvidas
- `progress_screen.dart`
- `athlete_dashboard_screen.dart`
- `athlete_console_screen.dart`
- `master_panel_screen.dart`
- `athlete_registration_screen.dart`

## Repositories envolvidas
- `GradingRulesRepository`
- `UserProgressRepository`
- `StudentsRepository`
- `AthleteRegistrationRepository`

## Regras de negocio
- Graduacao exibida deve vir de uma fonte canonica.
- Alteracao de faixa/grau deve gerar historico.
- Regras podem variar por modalidade, idade, academia e policy do mestre.
- Cadastro inicial pode sugerir graduacao, mas nao deve duplicar fonte final.

## Problemas atuais
- Graduacao duplicada e problema conhecido.
- Regras de graduacao podem estar separadas de perfil/progresso.
- Modalidade unica BJJ limita expansao.

## Arquitetura desejada
Feature futura:

```text
features/graduation/
  data/
    repositories/graduation_repository.dart
    repositories/grading_rules_repository.dart
  domain/
    entities/graduation.dart
    entities/graduation_history_entry.dart
    entities/grading_rule_set.dart
    use_cases/evaluate_graduation_eligibility.dart
  presentation/
    widgets/graduation_badge.dart
    view_models/graduation_view_model.dart
```

## Plano de migracao incremental
1. Inventariar campos atuais de faixa/grau.
2. Escolher documento canonico.
3. Criar adapter que calcula exibicao a partir da fonte canonica.
4. Migrar telas para ler adapter.
5. Migrar dados duplicados para historico.
6. Ativar regras por modalidade.

## Riscos de regressao
- Faixa exibida mudar para atleta existente.
- Historico antigo se perder.
- Professor editar campo antigo sem refletir no novo.
- Regras automaticas promoverem atleta indevidamente.

## Criterios de aceite
- Fonte canonica futura esta definida.
- Historico e regras por modalidade estao previstos.
- Duplicidade atual esta registrada.
- Nenhum campo de graduacao foi alterado nesta etapa.
