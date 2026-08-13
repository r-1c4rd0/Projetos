# Events Spec

## Objetivo do modulo
Definir eventos como agenda e comunicacao de atividades da academia, incluindo aulas especiais, campeonatos, seminarios e compromissos.

## Responsabilidades
- Criar, listar e atualizar eventos.
- Filtrar eventos por academia, role, modalidade e publico.
- Suportar recorrencia quando aplicavel.
- Integrar com presenca ou treino quando o evento representar aula.

## Dados usados
- `EventModel` e modelos em `event_models.dart`.
- Academia ativa.
- Publico alvo.
- Data, horario, recorrencia, local, descricao, status e modalidade.

## Telas envolvidas
- `event_screen.dart`
- `athlete_console_screen.dart`
- `athlete_dashboard_screen.dart`
- `master_panel_screen.dart`

## Repositories envolvidas
- `EventRepository`
- `FirebaseEventRepository`
- `StudentsRepository`
- Futuro `AttendanceRepository` para eventos com check-in.

## Regras de negocio
- Evento pertence a academia.
- Admin/professor pode criar eventos conforme role.
- Athlete ve eventos liberados para seu perfil/academia.
- Eventos recorrentes devem ser gerados de forma previsivel e rastreavel.

## Problemas atuais
- Existem `event_model.dart` e `event_models.dart`, indicando possivel sobreposicao.
- Recorrencia precisa de contrato claro.
- Multi-academia impacta visibilidade.

## Arquitetura desejada
Feature futura:

```text
features/events/
  data/
    repositories/events_repository.dart
    services/events_firestore_service.dart
  domain/
    entities/event.dart
    entities/event_recurrence.dart
    use_cases/create_event.dart
    use_cases/watch_visible_events.dart
  presentation/
    screens/events_screen.dart
    view_models/events_view_model.dart
```

## Plano de migracao incremental
1. Inventariar modelos de evento duplicados.
2. Escolher entidade canonica.
3. Centralizar recorrencia em domain/service especifico.
4. Garantir filtros por academia e publico.
5. Migrar tela para view model.
6. Integrar presenca quando aplicavel.

## Riscos de regressao
- Eventos antigos desaparecerem por mudanca de modelo.
- Recorrencias duplicarem.
- Athlete ver evento privado.
- Professor nao conseguir editar evento autorizado.

## Criterios de aceite
- Modelo futuro de eventos esta documentado.
- Duplicidade de modelos atuais esta registrada.
- Recorrencia tem plano de centralizacao.
- Nenhum evento foi alterado nesta etapa.
