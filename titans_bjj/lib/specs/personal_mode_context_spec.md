# Personal Mode Context Spec

Task: `PERSONAL-MODE-CONTEXT-CONTRACT-001`

Status: contrato documental, sem implementacao funcional.

Data: 2026-09-06.

## Objetivo
Fechar o contrato tecnico para separar dois mundos antes de qualquer implementacao:

- `Personal Workspace`: espaco privado do usuario autenticado, sem academia e sem membership.
- `Academy Workspace`: espaco de academia, time, grupo ou professor personal, sempre com membership ativa.

Este documento nao altera runtime, schema, rules, repositories, use cases ou dados.

## Baseline auditado
- Git root: `C:/Users/ricar/AndroidStudioProjects`.
- Repo do app: `titans_bjj`.
- Branch: `master`.
- Commit base observado: `d94e36279dd58d98c4b496ecb7af42c447d6d29e`.
- Worktree ja estava suja antes desta tarefa; alteracoes preexistentes nao foram revertidas.
- Nenhum documento previo com `PERSONAL-MODE-CONTEXT-CONTRACT-001`, `Personal Workspace` ou `personalContexts` foi encontrado em busca local.

Arquivos observados para este contrato:

- `lib/auth_gate.dart`
- `lib/config/app_config.dart`
- `lib/model/app_user.dart`
- `lib/model/academy_membership.dart`
- `lib/model/user_scope.dart`
- `lib/repository/students_repository.dart`
- `lib/repository/user_repository.dart`
- `lib/repository/training_repository.dart`
- `lib/repository/user_progress_repository.dart`
- `lib/repository/coach_evaluation_repository.dart`
- `lib/repository/athlete_registration_repository.dart`
- `lib/repository/attendance_repository.dart`
- `lib/screen/login_screen.dart`
- `firestore.rules`
- `functions/index.js`

## Respostas do audit

1. Onde `defaultAcademyId` e usado:
   `lib/config/app_config.dart`, `lib/auth_gate.dart`, `lib/model/app_user.dart`, `lib/repository/students_repository.dart` e `lib/screen/login_screen.dart`.

2. Onde usuario sem membership pode cair hoje:
   `AuthGate` tenta memberships, mas permission denied/unavailable podem virar lista vazia; sem membership legivel, o fluxo ainda pode usar `AppConfig.resolveActiveAcademyId()`. `AppUser.fromMap` tambem aplica fallback quando `academyId` nao vem do dado real.

3. Se existe Personal Mode real:
   Nao foi encontrado Personal Workspace privado. O `type: "personal"` atual em `multi_academy_spec.md` representa coaching/professor personal dentro de `academies/{academyId}`, portanto ainda e Academy Workspace.

4. Telas que dependem de academia:
   Login/AuthGate, dashboard/console, treino, adicionar treino, progresso, Game Map, nutricao, presenca, eventos, painel do mestre e cadastro de atleta usam ou dependem do contexto de academia direta ou indiretamente.

5. Repositories que exigem academia:
   `UserRepository`, `TrainingRepository`, `UserProgressRepository`, `CoachEvaluationRepository`, `GradingRulesRepository`, `StudentsRepository`, `AthleteRegistrationRepository`, `AttendanceRepository`, repositories de eventos/nutricao e fluxo de convite dependem de `academyId` ou de paths sob `academies/{academyId}`. `AcademyMembershipRepository` e excecao conceitual: le memberships por usuario para resolver contexto.

6. Solucao minima viavel:
   Criar contratos explicitos de `WorkspaceContext` e `TargetContext`, introduzir namespace privado para Personal, migrar uma fatia vertical de treino/progresso, e so entao remover fallback silencioso para `defaultAcademyId`.

7. Arquivos a alterar nesta tarefa:
   Apenas docs: este arquivo, `lib/specs/README.md`, `lib/specs/multi_academy_spec.md` e `lib/specs/refactor_migration_plan.md`.

8. Faixa/grau no Personal:
   Risco aceito nesta fase. Personal pode exibir graduacao autodeclarada/rascunho, mas nao altera graduacao oficial. Graduacao oficial continua sendo decisao de professor/admin em Academy Workspace.

## Vocabulario
- `AuthIdentity`: usuario autenticado pelo Firebase Auth, identificado por `uid` e email.
- `Personal Workspace`: contexto privado em que `actor == target == auth.uid` e nao ha academia ativa.
- `Academy Workspace`: contexto operacional vinculado a `academyId` e membership ativa.
- `Coaching Workspace`: academia conceitual com `type: "personal"` em `academies/{academyId}`; e Academy Workspace, nao Personal privado.
- `Membership`: vinculo entre usuario e academia com role e estado.
- `Staff`: usuario com role `admin`, `master` ou `professor` dentro de uma academia ativa.
- `Actor`: usuario logado que executa a acao.
- `Target`: usuario visualizado/editado.

## WorkspaceContext
Contrato futuro:

```text
WorkspaceContext.personal(ownerUid)
WorkspaceContext.academy(academyId, membership)
```

Regras:
- Toda leitura/escrita operacional deve receber contexto explicito.
- Personal nao usa `academyId`.
- Academy nao existe sem membership ativa, exceto telas de convite/onboarding que tenham estado proprio.
- `defaultAcademyId` nao pode representar autorizacao real.
- Cache offline nao pode promover contexto pendente para autorizado.

## TargetContext
Contrato futuro:

```text
TargetContext(
  actorUid,
  targetUid,
  mode,
  workspaceContext,
  capabilities,
)
```

Modos:
- `self`: `actorUid == targetUid`.
- `student`: `actorUid != targetUid` e actor e staff no Academy Workspace.

Regras:
- Aluno comum em Personal usa sempre `actor == target`.
- Aluno comum em Academy usa seus proprios dados, salvo telas de convite/onboarding.
- Professor/admin vendo aluno usa `actor != target`.
- Professor/admin em Meu Perfil usa `actor == target`.
- Nunca reaproveitar `selectedStudent` em `TargetMode.self`.

## Membership
Contrato futuro:

```text
Membership(
  uid,
  academyId,
  role,
  state,
  createdAt,
  acceptedAt,
  revokedAt,
)
```

Estados:
- `pending`: convite criado, Auth/perfil ainda nao confirmado.
- `active`: usuario autorizado para o Academy Workspace.
- `revoked`: acesso encerrado.
- `expired`: convite vencido.
- `disabled`: vinculo bloqueado administrativamente.

Somente `active` autoriza leitura/escrita operacional em academia.

## Storage escolhido
Escolha proposta para Personal privado:

```text
users/{uid}/personalContexts/main
users/{uid}/personalContexts/main/training_sessions/{sessionId}
users/{uid}/personalContexts/main/progress/profile
users/{uid}/personalContexts/main/technical_evidence/{evidenceId}
```

Motivos:
- Ownership simples: o usuario dono e o proprio path.
- Nao mistura dados privados com `academies/{academyId}`.
- Evita criar academias artificiais como `personal_<uid>`.
- Permite rules `isSelf(uid)` sem membership.

Alternativas rejeitadas nesta fase:
- `academies/personal_<uid>`: confunde Personal privado com Academy Workspace.
- `workspaces/{workspaceId}` global: pode ser melhor no futuro, mas exige migracao maior de rules, repositories e indexes.

## Matriz de acesso

```text
Contexto             Actor/target          Leitura             Escrita
Personal privado     self/self             self                treino/progresso pessoal
Personal privado     staff/student         proibido            proibido
Academy aluno        self/self             membership active   treino pessoal permitido
Academy staff        staff/student         membership active   avaliacoes oficiais permitidas
Academy staff        staff/staff           limitado            sem avaliacao de staff
Sem membership       qualquer              sem dados academy   sem escrita academy
Offline incerto      qualquer              cache rotulado      sem promocao de acesso
```

## Rules de transicao
Levantamento atual:

- `firestore.rules` ja possui helpers `isSelf(uid)` e `isAcademyStaff(academyId)`.
- `training_sessions` e `progress` permitem self ou staff em paths de academia.
- `coach_evaluations` concentra escrita em staff.
- `academyMemberships` sob `users/{uid}` permite leitura mas bloqueia escrita direta.
- `acceptAcademyInvite` em `functions/index.js` cria/vincula perfil em academia e copia dados, mas o audit nao confirmou criacao do documento `users/{uid}/academyMemberships/{academyId}`.

Transicao esperada:
- Personal privado ganha branch propria baseada em `isSelf(uid)`.
- Academy Workspace exige membership ativa, nao apenas perfil em `academies/{academyId}/users/{uid}`.
- Staff continua autorizado por role ativa na academia.
- Convite deve fechar o triplo vinculo: Auth, membership ativa e perfil de academia.

## Backfill
Estrategia proposta:

1. Congelar contrato antes de migrar dados.
2. Identificar usuarios com perfil em `academies/{academyId}/users/{uid}` sem membership correspondente.
3. Criar memberships ativas apenas quando houver evidencia de vinculo real.
4. Migrar dados pessoais privados somente para usuarios que optarem ou que forem inequivocamente pessoais.
5. Registrar origem, data e ferramenta de migracao.
6. Nunca sobrescrever dado real com bootstrap/default.

## Faixa e grau
- Oficial: somente Academy Workspace, controlado por professor/admin autorizado.
- Personal: pode armazenar leitura local, meta, autodeclaracao ou snapshot, sempre rotulado como nao oficial.
- Treino e evidencia tecnica nao sao nota nem graduacao.
- Game Map mostra leitura tecnica derivada de evidencias, nao desempenho absoluto.

## Dependencias de implementacao
Ordem recomendada:

1. Fechar este contrato documental.
2. Auditar AuthGate, memberships, invite e rules para membership ativa.
3. Corrigir bootstrap para nao sobrescrever dado real.
4. Corrigir convite para criar/vincular Auth, membership ativa e perfil.
5. Criar `WorkspaceContext` e `TargetContext` sem mudar telas amplamente.
6. Migrar fatia vertical: treino pessoal + progresso pessoal.
7. Introduzir rules do Personal privado.
8. Remover fallback silencioso de `defaultAcademyId`.

## QA matrix

```text
Cenario                                      Esperado
Usuario novo sem academia                    entra em Personal privado ou estado sem academy, nunca em default autorizado
Usuario com 1 membership ativa               entra na academy correta
Usuario com varias memberships ativas        exige selecao ou usa selecao persistida revalidada
Membership revogada                          perde acesso academy no proximo refresh
Professor vendo aluno                        actor != target
Professor em Meu Perfil                      actor == target
Aluno registrando treino                     nao altera graduacao oficial
Game Map                                     exibe leitura tecnica, nao ranking absoluto
Offline com cache antigo                     nao concede acesso novo
Convite aceito                               Auth + membership + perfil ficam vinculados
Bootstrap                                    nao sobrescreve campos reais
```

## Non-goals
- Nao implementar Personal Mode nesta tarefa.
- Nao alterar `firestore.rules`.
- Nao alterar schema ou dados.
- Nao alterar repositories, use cases, widgets ou screens.
- Nao executar migracao.
- Nao resolver a fonte canonica de faixa/grau nesta fase.

## Criterios de aceite
- Personal privado e Academy Workspace estao conceitualmente separados.
- Membership ativa e requisito documental para dados de academia.
- `actor` e `target` estao definidos para self e staff/student.
- Riscos de `defaultAcademyId`, invite, bootstrap, offline e graduacao estao registrados.
- Proxima implementacao pode seguir uma fatia vertical sem refatoracao ampla.
