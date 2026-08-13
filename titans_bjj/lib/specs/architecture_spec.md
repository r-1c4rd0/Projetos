# Architecture Spec

## Objetivo do modulo
Propor a arquitetura alvo do Titans BJJ para uma migracao futura de camadas genericas para modulos por feature, mantendo o legado atual ate cada etapa ser validada.

## Responsabilidades
- Definir estrutura futura.
- Definir fronteiras entre app, core e features.
- Estabelecer separacao entre presentation, domain e data.
- Orientar migracao incremental sem mover arquivos nesta etapa.

## Dados usados
- Estado global de app: auth, sessao, role, academia selecionada, aluno selecionado e tema.
- Dados por feature: usuarios, alunos, treinos, progresso, nutricao, eventos, graduacao, presenca e configuracoes.
- Integracoes: Firebase Auth, Firestore, biometria e recursos de dispositivo futuros como QR/NFC.

## Telas envolvidas
- Todas as telas em `lib/screen`.
- Gates e escopos atuais: `AuthGate`, `UserScope`, `SelectedStudentScope`, `SessionLock`.
- Widgets compartilhados em `lib/widgets`.

## Repositories envolvidas
- Todas as repositories atuais em `lib/repository`.
- Repositories futuras por feature dentro de `features/<feature>/data`.

## Regras de negocio
- Presentation nao acessa Firestore diretamente.
- Domain define entidades, value objects, policies e use cases quando houver regra relevante.
- Data e a fonte unica de verdade operacional e conversa com services externos.
- Core nao deve depender de features.
- Features podem depender de core, mas nao devem depender entre si sem contrato explicito.

## Problemas atuais
- Camadas genericas agrupam arquivos por tipo e nao por dominio.
- Regras podem estar em telas.
- Services podem conter estado de aplicacao.
- Repositories globais tendem a crescer e misturar responsabilidades.
- Streams em `build` podem recriar subscriptions e aumentar risco de comportamento instavel.

## Arquitetura desejada
Estrutura alvo futura:

```text
lib/
  app/
    app.dart
    bootstrap.dart
    routes/
    providers/
    session/
  core/
    config/
    errors/
    firebase/
    theme/
    widgets/
    utils/
  features/
    auth_session/
      data/
      domain/
      presentation/
    academy/
      data/
      domain/
      presentation/
    athletes/
      data/
      domain/
      presentation/
    graduation/
      data/
      domain/
      presentation/
    training/
      data/
      domain/
      presentation/
    progress/
      data/
      domain/
      presentation/
    nutrition/
      data/
      domain/
      presentation/
    attendance/
      data/
      domain/
      presentation/
    events/
      data/
      domain/
      presentation/
    master_panel/
      data/
      domain/
      presentation/
    design_system/
      data/
      domain/
      presentation/
```

Contrato por feature:

```text
features/<feature>/
  data/
    models/
    repositories/
    services/
  domain/
    entities/
    use_cases/
    policies/
  presentation/
    screens/
    widgets/
    view_models/
```

Mapeamento inicial sugerido:
- `auth_gate.dart`, `user_session.dart`, `session_lock_controller.dart`, `session_lifecycle.dart`, `biometric_service.dart` -> `features/auth_session`.
- `academy_screen.dart`, `academy_models.dart`, configuracoes por academia -> `features/academy`.
- `athlete_registration_screen.dart`, `students_repository.dart`, `athlete_registration_repository.dart` -> `features/athletes`.
- `grading_rules.dart`, `grading_rules_repository.dart` -> `features/graduation`.
- `training_screen.dart`, `add_training_session_screen.dart`, `training_repository.dart`, `training_aggregator.dart` -> `features/training`.
- `progress_screen.dart`, `user_progress_repository.dart`, `user_progress_profile.dart` -> `features/progress`.
- `nutrition_screen.dart`, `nutrition_repository.dart`, `nutrition_models.dart` -> `features/nutrition`.
- Eventos atuais -> `features/events`.
- Presenca QR/NFC futura -> `features/attendance`.
- Painel do mestre -> `features/master_panel`.

## Plano de migracao incremental
1. Criar specs e inventario.
2. Introduzir contratos sem mover codigo.
3. Criar wrappers/adapters por feature quando necessario.
4. Migrar uma feature por vez, iniciando por modulo com menor acoplamento.
5. Manter exports temporarios para compatibilidade.
6. Remover estruturas antigas somente apos testes e aceite.

## Riscos de regressao
- Ciclos de dependencia entre features.
- Providers globais ficarem duplicados.
- Mudanca de imports quebrar telas existentes.
- Domain layer virar espelho inutil de DTOs se nao houver regra real.

## Criterios de aceite
- Arquitetura alvo esta documentada.
- Nao houve movimentacao de arquivos nesta etapa.
- Cada feature futura possui `data`, `domain` e `presentation`.
- O plano permite migracao incremental e reversivel.
