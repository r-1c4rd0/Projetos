# Nutrition Spec

## Objetivo do modulo
Definir o modulo de nutricao como area de planos, orientacoes e acompanhamento nutricional associado ao atleta e a academia.

## Responsabilidades
- Exibir planos e registros nutricionais.
- Permitir conteudo orientado por professor/admin quando aplicavel.
- Conectar nutricao ao progresso sem acoplamento forte.
- Preservar dados pessoais e sensiveis com controle de acesso.

## Dados usados
- Modelos em `nutrition_models.dart`.
- Usuario/aluno alvo.
- Academia ativa.
- Planos, metas, observacoes, restricoes e periodo.

## Telas envolvidas
- `nutrition_screen.dart`
- `athlete_console_screen.dart`
- `athlete_dashboard_screen.dart`
- `master_panel_screen.dart`

## Repositories envolvidas
- `NutritionRepository`
- `StudentsRepository`
- `UserRepository`

## Regras de negocio
- Athlete acessa seus proprios dados nutricionais.
- Professor/admin acessa dados conforme permissao da academia.
- Dados sensiveis devem ter leitura e escrita restritas.
- Nutricao nao deve depender diretamente da UI de progresso.

## Problemas atuais
- Fronteira de privacidade precisa ser explicitada.
- Multi-academia pode afetar ownership de planos.
- Regras por role precisam ser refletidas em Firestore Rules.

## Arquitetura desejada
Feature futura:

```text
features/nutrition/
  data/
    repositories/nutrition_repository.dart
  domain/
    entities/nutrition_plan.dart
    entities/nutrition_entry.dart
    policies/nutrition_access_policy.dart
  presentation/
    screens/nutrition_screen.dart
    view_models/nutrition_view_model.dart
```

## Plano de migracao incremental
1. Inventariar campos e permissao atual.
2. Definir acesso por role.
3. Garantir escopo por academia e aluno.
4. Migrar repository para contrato por feature.
5. Separar widgets de visualizacao e edicao.
6. Integrar indicadores opcionais ao progresso.

## Riscos de regressao
- Expor dado sensivel para usuario indevido.
- Perder plano ao trocar academia ativa.
- Professor nao conseguir editar plano autorizado.
- Tela quebrar com plano incompleto.

## Criterios de aceite
- Privacidade e role access estao documentados.
- Escopo por academia/aluno esta definido.
- Integracao com progresso e fraca e explicita.
- Nenhum dado nutricional foi alterado nesta etapa.
