# Titans BJJ Specs Index

Este arquivo e o indice oficial das specs do Titans BJJ. Qualquer agente deve le-lo antes de alterar arquivos e, em seguida, abrir a spec especifica do modulo afetado.

## Specs oficiais
- `product_spec.md` - Produto, personas, modulos atuais e roadmap.
- `architecture_spec.md` - Arquitetura alvo em `lib/app`, `lib/core` e `lib/features`.
- `firebase_schema_spec.md` - Schema Firebase/Firestore, ownership e rules futuras.
- `design_system_spec.md` - Design system base e personalizacao por academia.
- `auth_session_spec.md` - Auth, sessao, roles, biometria, session lock e escopos.
- `multi_academy_spec.md` - Multi-academia, memberships e academia ativa.
- `graduation_spec.md` - Fonte unica de graduacao por modalidade.
- `training_spec.md` - Treinos, sessoes e agregacoes.
- `progress_spec.md` - Progresso, indicadores e status futuro.
- `nutrition_spec.md` - Nutricao, planos e privacidade.
- `attendance_spec.md` - Presenca futura por manual, QR e NFC.
- `events_spec.md` - Eventos, agenda, recorrencia e visibilidade.
- `refactor_migration_plan.md` - Fases oficiais de migracao incremental.

## Ordem recomendada de leitura
1. `README.md`
2. `product_spec.md`
3. `architecture_spec.md`
4. Spec especifica do modulo alterado
5. `refactor_migration_plan.md` quando a tarefa envolver refatoracao ou mudanca estrutural

## Objetivo do modulo
Centralizar as especificacoes de produto, arquitetura, dados, design system e migracao incremental do Titans BJJ antes de qualquer refatoracao funcional.

## Responsabilidades
- Servir como contrato de evolucao do app.
- Registrar decisoes desejadas sem mover codigo legado.
- Mapear riscos conhecidos: `academyId` default, graduacao duplicada, multi-academia pendente, rules por papel, streams em `build` e inconsistencia visual.
- Orientar fases futuras de refatoracao em `lib/app`, `lib/core` e `lib/features`.

## Dados usados
- Usuarios, perfis, roles e sessoes.
- Academias, configuracoes, alunos e professores.
- Treinos, progresso, nutricao, eventos, presenca e graduacao.
- Temas, branding e preferencias por academia.

## Telas envolvidas
- `auth_gate.dart`
- `screen/login_screen.dart`
- `screen/signup_screen.dart`
- `screen/signup_gate_screen.dart`
- `screen/athlete_registration_screen.dart`
- `screen/master_panel_screen.dart`
- `screen/athlete_console_screen.dart`
- `screen/athlete_dashboard_screen.dart`
- `screen/training_screen.dart`
- `screen/add_training_session_screen.dart`
- `screen/progress_screen.dart`
- `screen/nutrition_screen.dart`
- `screen/event_screen.dart`
- `screen/academy_screen.dart`

## Repositories envolvidas
- `user_repository.dart`
- `students_repository.dart`
- `athlete_registration_repository.dart`
- `training_repository.dart`
- `user_progress_repository.dart`
- `nutrition_repository.dart`
- `event_repository.dart`
- `firebase_event_repository.dart`
- `grading_rules_repository.dart`

## Regras de negocio
- Nenhuma mudanca funcional deve ser feita nesta etapa.
- Specs devem ser versionadas junto com o codigo.
- Migracoes futuras devem preservar comportamento legado ate cada feature possuir aceite validado.
- Cada feature futura deve ter fonte unica de verdade para dados e regras.

## Problemas atuais
- Estrutura por camadas genericas dificulta ownership por dominio.
- Algumas regras de negocio parecem distribuídas entre telas, services e repositories.
- Multi-academia ainda nao esta consolidada como fronteira de dados.
- Graduacao pode existir em mais de uma fonte.
- Visual nao possui contrato unico personalizavel por academia.

## Arquitetura desejada
- `lib/app` para bootstrap, rotas, providers globais e composicao.
- `lib/core` para utilitarios compartilhados, tema base, erros, Firebase wrappers e contratos comuns.
- `lib/features/<feature>/{data,domain,presentation}` para modulos de produto.

## Plano de migracao incremental
1. Criar specs.
2. Estabilizar auth, sessao e resolucao de `academyId`.
3. Consolidar graduacao.
4. Consolidar schema e repositories.
5. Migrar features uma por vez.
6. Introduzir design system por academia.
7. Evoluir presenca, multi-modalidade e analytics.

## Riscos de regressao
- Alterar fronteiras de dados sem rules compatíveis.
- Quebrar roles existentes.
- Mudar fluxo de login/cadastro sem preservar usuarios atuais.
- Duplicar dados durante migracao.

## Criterios de aceite
- Todos os arquivos de spec existem em `lib/specs`.
- Nenhum arquivo funcional foi alterado.
- Cada spec contem objetivo, responsabilidades, dados, telas, repositories, regras, problemas, arquitetura, plano, riscos e aceite.
- `refactor_migration_plan.md` descreve as oito fases pedidas.

## Spec de evolucao visual

- `visual_evolution_spec.md` - Governanca para evolucao visual, QA economico, graficos, widgets visuais e actor/target.

Use esta spec em fases VISUAL EVOLUTION e em qualquer mudanca visual que precise preservar metricas reais, evitar dependencia nova, manter actor/target correto e validar em modo economico.
