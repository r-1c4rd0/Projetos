# Personal Mode Context Spec

Task: `PERSONAL-MODE-CONTEXT-CONTRACT-001`

Status: contrato de implementacao revisado, sem implementacao funcional.

Data: 2026-09-20. Auditoria inicial: 2026-09-06.

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
- Na auditoria inicial de 2026-09-06, nenhum documento anterior com
  `PERSONAL-MODE-CONTEXT-CONTRACT-001`, `Personal Workspace` ou
  `personalContexts` havia sido encontrado. Este arquivo passou a ser o
  contrato canonico e deve ser atualizado, sem criar uma spec concorrente.

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
Academy aluno        self/self             membership active   treino institucional proprio
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
- A auditoria inicial nao confirmou provisioning de membership no convite. A
  implementacao posterior `MEMBERSHIP-PROVISIONING-COMPATIBILITY-001` passou a
  criar/vincular `users/{uid}/academyMemberships/{academyId}` no aceite
  server-side validado; o cliente ainda mantem o aceite desabilitado.

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

## Reconciliacao com o codigo em 2026-09-20

O contrato continua valido, mas a implementacao atual avancou parcialmente:

- `MembershipQuerySnapshot` ja distingue `confirmedEmpty`,
  `confirmedActive`, `unavailable`, `permissionDenied` e `error`.
- `MembershipSessionResolver` bloqueia contexto de academia em erro, mas
  `confirmedNoActiveMembership` ainda permite o fallback legado.
- `AuthGate` ainda chama `ensureUserDoc` com uma academia resolvida e nao cria
  sessao pessoal.
- `UserScope` ainda exige `activeAcademyId` nao anulavel.
- `TargetProfile` ainda exige `academyId` e, portanto, nao representa self em
  Personal Workspace.
- `TrainingRepository`, `UserProgressRepository` e as telas Home/Treinos ainda
  leem exclusivamente paths sob `academies/{academyId}`.
- Home e Treinos ja reutilizam streams e caches fora de `build`, mas suas
  chaves sao baseadas em `academyId|uid`; falta incluir o tipo e a identidade
  do workspace.
- `TrainingOperationContext` protege resultados atrasados por
  `actorUid|academyId|targetUid`; ele precisa aceitar uma chave de workspace
  para oferecer a mesma protecao no Personal.
- As rules atuais negam `users/{uid}/personalContexts/**` pelo catch-all. A
  persistencia pessoal so pode ser ativada depois de rules especificas serem
  validadas e publicadas em uma etapa autorizada.

Nenhum desses pontos autoriza tratar erro de membership como ausencia ou usar
`defaultAcademyId` para criar um contexto pessoal.

## Contrato normativo da primeira fatia: treino pessoal BJJ

### Eixos independentes

A resolucao de um treino combina tres eixos, sem inferencia entre eles:

1. `WorkspaceContext`: ownership institucional ou pessoal.
2. `TargetContext`: actor e target autorizados.
3. `SportContext`: modalidade e capacidades do formulario/agregadores.

Consequencias obrigatorias:

- `TrainingPlace.academy`, `home` ou `other` descreve somente o local fisico.
- Um treino pessoal pode ter `place: academy` sem pertencer a essa academia.
- Um treino institucional pode ter `place: home` sem deixar o Academy
  Workspace.
- `classType` nao representa modalidade nem ownership.
- A primeira fatia permanece BJJ-first. Nao deve persistir `sportId` nem criar
  seletor multi-esporte antes do contrato de Sport Pack autorizar isso.
- Quando modalidade for implementada, ela deve compor o contexto e a chave de
  cache; nunca deve ser derivada de `place` ou `academyId`.

### Representacao runtime

Contrato minimo, discriminado por tipo:

```text
WorkspaceContext.personal(ownerUid)
  key = personal:{ownerUid}

WorkspaceContext.academy(academyId, activeMembership)
  key = academy:{academyId}
```

Invariantes:

- Personal: `actorUid == targetUid == ownerUid == auth.uid`.
- Academy self: `actorUid == targetUid` e membership ativa na academia.
- Academy student: `actorUid != targetUid`, actor staff e target atleta na
  mesma academia.
- Personal nunca recebe `selectedStudent`, role da academia ou capabilities de
  staff.
- `WorkspaceContext` deve ser imutavel e a chave deve participar de streams,
  caches, operacoes pendentes, foco de historico e deduplicacao de UI.
- O contexto selecionado pode ser persistido localmente, mas deve ser
  revalidado em cada sessao. Uma academia revogada nao pode ser restaurada.

Estados de resolucao:

```text
membership loading              -> nao iniciar stream institucional
confirmedEmpty                  -> Personal disponivel e selecionado
confirmedActive                 -> Personal e academias ativas selecionaveis
unavailable                     -> Personal disponivel; Academy indisponivel
permissionDenied                -> Personal disponivel; Academy negado
error                           -> Personal disponivel; Academy com erro
```

O acesso ao Personal depende de Auth e ownership, nao da consulta de
membership. A UI deve preservar a diferenca entre indisponibilidade, acesso
negado e ausencia confirmada, sem apresentar qualquer um deles como academia
vazia ou default.

### Destino de armazenamento

Mantem-se a escolha ja feita neste contrato:

```text
users/{ownerUid}/personalContexts/main/training_sessions/{sessionId}
```

Regras do documento na primeira fatia:

- Reutilizar o formato atual de `TrainingSession` e seu adapter de leitura.
- `uid` deve ser igual a `{ownerUid}` para compatibilidade com o target legado.
- `academyId` deve estar ausente.
- `attendanceSessionId` e `attendanceCheckInUid` devem estar ausentes.
- `source` pessoal nao pode declarar origem oficial de presenca/aula.
- `place` continua obrigatorio pelo modelo atual, mas nao escolhe o path.
- O path e o `WorkspaceContext`, nao um campo de local, definem ownership.
- A primeira fatia nao cria documento de academia artificial nem copia o
  treino para uma academia.

O documento `personalContexts/main` pode receber metadados em etapa futura,
mas nao e pre-requisito para consultar a subcolecao de treinos.

### Autorizacao futura

As rules a validar em etapa propria devem garantir:

- somente `request.auth.uid == ownerUid` le, cria, altera ou remove treino
  pessoal;
- staff de qualquer academia nao recebe acesso implicito;
- create/update validam `uid == ownerUid` e ausencia de `academyId`;
- campos de presenca oficial nao podem ser introduzidos no path pessoal;
- listagem ocorre somente dentro do path do proprio owner;
- membership e entitlement comercial nao ampliam ownership pessoal.

Academy Workspace continua sujeito a membership ativa e suas rules proprias.
Nenhuma rule deve usar existencia de treino pessoal como presenca, credito de
graduacao ou vinculo institucional.

### Repository e operacoes

`TrainingRepository` permanece a fonte unica do dominio, mas deve receber um
contexto de armazenamento explicito em novos metodos. Os metodos atuais com
`academyId` permanecem como wrappers de compatibilidade durante a migracao.

Contrato esperado:

```text
watchSessions(workspace, targetUid)
getSession(workspace, targetUid, sessionId)
createSession(workspace, targetUid, session)
replaceSession(workspace, targetUid, session)
updateSessionLifecycle(workspace, targetUid, sessionId, patch)
```

O resolver interno escolhe um dos dois paths permitidos; a screen nao acessa
Firestore nem monta path. `createSession`, substituicao completa e patch
parcial devem continuar semanticamente separados.

`TrainingOperationContext` deve passar a guardar `workspaceKey` em vez de
assumir `academyId`. Todo retorno async deve ser descartado quando actor,
target, workspace ou geracao nao corresponderem mais ao contexto atual.

### Home, Treinos e resumos

- Home e Treinos devem assinar somente o stream do workspace selecionado.
- Alternar workspace deve trocar a key do subtree/stream, limpar caches de
  resumo, filtros, foco de sessao e conjuntos de operacoes pendentes.
- Callback atrasado do workspace anterior nao pode abrir, confirmar ou focar
  uma sessao no workspace novo.
- Cache e IDs de operacao devem usar ao menos
  `workspaceKey|targetUid|sessionId`; `sessionId` isolado nao e global.
- `GetHomeDashboardSummary` e `GetTrainingDashboardSummary` continuam sendo
  reutilizados com a lista ja isolada pelo repository.
- A primeira fatia nao concatena listas Personal e Academy. Assim, frequencia,
  historico e evidencias nao duplicam contagens.
- Uma eventual visao Todos exige use case proprio e dedupe por
  `(workspaceKey, sessionId)`; nao faz parte da primeira implementacao.
- Home pessoal nao consulta regras de graduacao, presenca, avaliacao oficial ou
  perfil de progresso da academia. Deve mostrar somente identidade propria e
  resumos derivados dos treinos pessoais disponiveis.
- Game Map/Skills pessoais podem consumir apenas evidencias BJJ pessoais, sem
  incorporar avaliacoes oficiais do professor. Sua ativacao visual pode ficar
  para uma fatia posterior.

### Registros antigos

- Nenhum documento sob `academies/{academyId}` sera movido, copiado ou
  reinterpretado automaticamente.
- Registros antigos permanecem institucionais por localizacao, inclusive os
  criados pelo proprio atleta ou com `place: home`.
- Ausencia de `academyId` dentro de um documento antigo de academia nao o torna
  pessoal; o path continua sendo a origem.
- Registros pessoais novos nao aparecem no historico da academia e nao geram
  presenca, graduacao ou avaliacao oficial.
- Uma futura acao de copiar/mover exigira consentimento, idempotencia,
  auditoria de origem e uma task de migracao separada.

## Auditoria da serializacao de TrainingSession

Consumidores verificados antes deste contrato:

- Criacao e edicao completa: `TrainingRepository.addSession` delega hoje para
  `upsertSession`, que usa `toMap(includeTechnicalDeletes: true)` com merge.
  Em documento novo, os deletes mantem opcionais ausentes; em documento
  existente, um opcional limpo e removido.
- Batch completo: `upsertSessionsBatch` usa a mesma semantica de substituicao
  dos campos editaveis.
- Atualizacao parcial de lifecycle: `updateSessionLifecycle` escreve somente
  status, datas e auditoria; observacao e campos tecnicos sao preservados.
- Sessao derivada de presenca: `setAttendanceDerivedSessionInBatch` usa
  `toMap()` com merge; campos ausentes sao omitidos, preservando complementos
  pessoais ja existentes no documento derivado.

Para `notes`, `toMap()` omite `null`, enquanto
`toMap(includeTechnicalDeletes: true)` envia `FieldValue.delete()`. Portanto,
limpar uma observacao no formulario completo remove o valor persistido; uma
atualizacao parcial nao o apaga. O teste direcionado
`full upsert explicitly removes a cleared observation` fixa esse contrato.

Divida tecnica conhecida: o nome `addSession` tambem cobre edicao completa.
Na fatia pessoal, separar `createSession` de `replaceSession` deve tornar a
intencao explicita sem mudar a leitura de registros antigos.

## Arquivos previstos e sequencia de implementacao

### Etapa 1 - contexto de sessao

- `lib/model/workspace_context.dart`: value object discriminado e chave.
- `lib/service/membership_session_resolver.dart`: resolver Personal/Academy sem
  fallback autorizado.
- `lib/service/user_session.dart`: expor `WorkspaceContext` selecionado.
- `lib/auth_gate.dart`: permitir Personal e selecao explicita de workspace.
- testes de resolver e troca de usuario/contexto.

### Etapa 2 - fatia vertical de treino

- `lib/features/training/domain/training_operation_context.dart`: usar
  `workspaceKey`.
- `lib/repository/training_repository.dart`: rotear paths e separar create,
  replace e patch.
- `lib/service/target_resolver.dart`: self pessoal sem `academyId`; aluno
  selecionado somente em Academy.
- `lib/widgets/quick_log_sheet.dart` e
  `lib/screen/add_training_session_screen.dart`: receber contexto explicito.
- testes de repository/path, ownership, serializacao e operacao atrasada.

### Etapa 3 - Home e Treinos

- `lib/screen/training_screen.dart`: stream/cache/foco por workspace.
- `lib/screen/athlete_dashboard_screen.dart`: composicao pessoal sem
  repositories institucionais obrigatorios.
- manter `GetHomeDashboardSummary` e `GetTrainingDashboardSummary` como
  agregadores da lista isolada.
- testes de alternancia, streams, cache, IDs iguais em workspaces diferentes e
  falhas distintas de membership/rede/permissao.

### Etapa 4 - seguranca coordenada

- `firestore.rules`: adicionar branch pessoal owner-only e validacoes de
  payload.
- testes de rules/emulator para self, outro usuario e staff.
- publicar rules somente em entrega autorizada, antes de habilitar escrita na
  UI de producao.

## Decisoes ainda pendentes

- UX exata do seletor quando houver varias academias e Personal; o contrato
  exige selecao explicita e revalidada, mas nao define layout.
- Persistencia local da ultima escolha e politica de expiracao.
- Se perfil/progresso pessoal tera documento proprio na primeira fatia seguinte
  ou se Home pessoal exibira apenas resumo de treinos.
- Momento de ativar Game Map e Skills no Personal sem misturar avaliacao
  oficial.
- Contrato de `sportId`/Sport Pack. A primeira fatia e BJJ e nao deve resolver
  multi-modalidade por conta propria.
- Deploy, rollout e rollback das rules pessoais.

Essas pendencias nao bloqueiam implementar repository + Treinos pessoais,
desde que Home pessoal nao dependa de progresso/graduacao institucional e que
as rules owner-only sejam validadas antes da ativacao.

## Criterios de aceite da proxima etapa

- Usuario autenticado com `confirmedEmpty` entra em Personal sem academia
  sintetica.
- Usuario com membership ativa pode alternar para Personal explicitamente.
- `unavailable`, `permissionDenied` e `confirmedEmpty` continuam estados
  observavelmente distintos.
- Treino pessoal e gravado e relido apenas no path do owner, sem `academyId`.
- Outro usuario, professor ou admin nao le nem altera esse treino.
- `place` nao muda workspace; Personal em academia continua pessoal.
- Treino pessoal nao cria presenca nem conta para graduacao oficial.
- Troca de workspace substitui streams/caches e descarta callbacks atrasados.
- Home/Treinos contam somente a lista do workspace atual.
- Registros antigos permanecem no path original e continuam legiveis.
- Criacao, substituicao completa, patch parcial e remocao explicita de campo
  possuem testes separados.

## Dependencias de implementacao
Ordem recomendada:

1. Contrato documental: concluido e reconciliado neste arquivo.
2. Snapshot de membership, provisionamento de convite e inventario de
   backfill: bases ja documentadas/implementadas; manter revisao operacional.
3. Criar `WorkspaceContext` e adaptar `UserScope`/`TargetContext`, removendo o
   fallback como autorizacao para ausencia confirmada.
4. Implementar repository de treino por workspace e rules pessoais owner-only
   com testes locais, sem habilitar UI antes da seguranca estar disponivel.
5. Migrar Treinos e a parte de treino da Home para a fonte selecionada.
6. Validar alternancia de contexto, callbacks atrasados, cache e isolamento.
7. Planejar progresso pessoal em fatia propria; nao reutilizar graduacao da
   academia.
8. Remover os usos residuais de `defaultAcademyId` somente depois que todos os
   destinos de sessao estiverem explicitos.

## QA matrix

```text
Cenario                                      Esperado
Usuario novo sem academia                    entra em Personal privado ou estado sem academy, nunca em default autorizado
Usuario com 1 membership ativa               oferece Personal e academy valida sem mistura
Usuario com varias memberships ativas        exige escolha ou usa selecao persistida revalidada
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
