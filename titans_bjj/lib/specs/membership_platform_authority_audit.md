# Membership and Platform Authority Audit

Task: `MEMBERSHIP-AND-PLATFORM-AUTHORITY-AUDIT-001`

Status: auditoria documental. Nao altera codigo de producao, schema, rules,
repositories, telas, billing, paywall, painel administrativo ou migracao.

Data: 2026-09-06.

## Objetivo
Separar, no contrato de autorizacao, quatro conceitos que hoje aparecem
parcialmente misturados:

- usuario independente;
- membro ativo de academia;
- professor/mestre da academia;
- administrador autorizado da plataforma para conceder cortesia.

Entitlements comerciais continuam independentes da autorizacao de dados. Plus
por assinatura ou cortesia nao concede acesso a dados pessoais privados nem a
dados de academia sem permissao propria.

## Estado do workspace auditado
- A worktree ja estava suja antes desta auditoria.
- Alteracoes locais preexistentes foram preservadas.
- `firestore.rules` local foi analisado no estado atual, incluindo diff ainda
  nao commitado.
- O codigo versionado foi usado como comparacao apenas para diferenciar regras
  locais de regras em `HEAD`.

### Diferenca local de `firestore.rules` versus versionado
O estado local adiciona `isAcademyAthlete(academyId, uid)` e troca a criacao e
atualizacao de `coach_evaluations` para exigir target atleta. Essa mudanca
endurece avaliacoes oficiais de professor, mas nao resolve:

- membership ativa como fonte de autorizacao;
- fallback default de academia;
- autoridade administrativa de plataforma;
- concessao ou revogacao de cortesia.

No codigo versionado, `coach_evaluations` aceitava `isAcademyUser(academyId,
uid)` como target. No estado local, aceita apenas `isAcademyAthlete(academyId,
uid)`.

## Achados comprovados

### 1. Resolucao de `academyId` e fallback default
- `lib/config/app_config.dart`: `defaultAcademyId` cai em `default` quando
  `TITANS_ACADEMY_ID` nao e informado; `resolveActiveAcademyId()` apenas
  rejeita string vazia.
- `lib/auth_gate.dart`: `_lastResolvedAcademyId` inicia com
  `AppConfig.resolveActiveAcademyId()`.
- `lib/auth_gate.dart`: `_loadSession()` filtra memberships ativas, mas usa
  `_fallbackAcademyId()` quando nao encontra membership ativa.
- `lib/auth_gate.dart`: `_loadMemberships()` converte `permission-denied` e
  `unavailable` em lista vazia.
- `lib/model/app_user.dart`: `AppUser.fromMap()` aplica fallback para
  `AppConfig.resolveActiveAcademyId()` quando o documento nao possui
  `academyId`.
- `lib/repository/students_repository.dart`: mocks ainda usam
  `AppConfig.resolveActiveAcademyId()`.

Risco: usuario sem membership ativa, ou com consulta indisponivel, pode ser
promovido para contexto de academia legado. Isso viola o contrato de Personal
Mode e impede distinguir "sem vinculo" de "nao foi possivel confirmar".

Severidade: P0 para piloto com dados reais de academias; P0 para lancamento
publico.

### 2. Ausencia de membership versus erro de consulta
- `lib/repository/academy_membership_repository.dart`: lista documentos em
  `users/{uid}/academyMemberships`.
- `lib/auth_gate.dart`: o resultado da leitura e reduzido a uma lista; erro
  `permission-denied` ou `unavailable` retorna lista vazia.
- `lib/service/user_session.dart`: `UserScope` carrega `memberships` e
  `activeMembership`, mas nao carrega um estado como `loading`, `confirmedNone`
  ou `error`.

Risco: falha de rede/permissao vira semanticamente igual a ausencia confirmada
de vinculo. Endurecer rules antes de separar estados pode bloquear usuarios
legitimos ou acionar fallback indevido.

Severidade: P0 para piloto; P0 para lancamento publico.

### 3. Criacao, ativacao, revogacao e consulta de memberships
- Consulta existe em `AcademyMembershipRepository.listMemberships()`.
- `firestore.rules`: `users/{uid}/academyMemberships/{academyId}` permite
  leitura pelo proprio usuario e bloqueia escrita direta.
- Nao foi encontrado repository de escrita de membership no cliente.
- `functions/index.js`: `acceptAcademyInvite` cria/vincula perfil em
  `academies/{academyId}/users/{authUid}` e marca convite como aceito, mas nao
  cria `users/{uid}/academyMemberships/{academyId}`.
- `lib/repository/athlete_registration_repository.dart`: cadastro de atleta
  cria perfil de academia com UUID legado e bootstrap de progresso/nutricao, sem
  membership do usuario Auth.
- `lib/repository/invite_repository.dart`: cria, reenvia, revoga e aceita
  convite; aceite manual esta desabilitado por `inviteAcceptanceEnabled = false`.

Risco: a fonte preferida pelo app para academia ativa pode nao ser provisionada
no fluxo de convite. O sistema fica dividido entre perfil de academia, convite
aceito e membership inexistente.

Severidade: P0 para piloto; P0 para lancamento publico.

### 4. Membership ativa versus existencia de perfil de academia
- `firestore.rules`: `isAcademyMember(academyId)` valida apenas existencia de
  `academies/{academyId}/users/{request.auth.uid}` com `academyId` igual.
- `firestore.rules`: `isAcademyAdmin`, `isAcademyProfessor` e
  `isAcademyStaff` derivam autoridade do role no perfil da academia.
- `firestore.rules`: nao consulta `users/{uid}/academyMemberships/{academyId}`
  nem `isActive` da membership para autorizar dados operacionais.
- `lib/repository/students_repository.dart`: filtra alunos por `isActive !=
  false` no documento de perfil, nao por membership ativa.

Risco: documento de usuario em academia funciona como autorizacao real, mesmo
quando o contrato esperado exige membership ativa. Isso tambem permite que
arquivo de perfil legado mantenha acesso sem vinculo administrativo confirmado.

Severidade: P0 para piloto; P0 para lancamento publico.

### 5. Caminhos que contornam membership ativa
- `firestore.rules`: `academies/{academyId}` permite `get` por
  `isAcademyMember()`, baseado em perfil.
- `firestore.rules`: `academies/{academyId}/users/{uid}` permite self criar e
  atualizar perfil proprio com payload permitido.
- `firestore.rules`: `training_sessions`, `progress` e `nutrition` permitem
  `read, write` quando `isSelf(uid)` ou `isAcademyStaff(academyId)`.
- `firestore.rules`: eventos, graduacao tecnica, presenca e checkins usam
  `isAcademyMember()` ou `isAcademyStaff()`, ambos derivados de perfil.
- `firestore.rules`: `coach_evaluations` no estado local ja exige target
  atleta, mas staff ainda vem do perfil de academia.

Risco: para varios paths, possuir ou criar perfil sob a academia e suficiente
para operar. Membership ativa nao e a barreira de dados.

Severidade: P0 para dados privados/academia; P1 para avaliacoes oficiais apos
o endurecimento local de target atleta.

### 6. Autoridade de professor/mestre da academia
- `lib/model/app_user.dart`: roles atuais sao `admin`, `professor` e
  `athlete`; nao ha role separado `master`.
- `firestore.rules`: `isStaffRole(role)` inclui `admin` e `professor`.
- `firestore.rules`: `isAcademyAdmin()` e `isAcademyProfessor()` leem role no
  perfil da academia do usuario logado.
- `lib/screen/master_panel_screen.dart`: `_TargetCapabilities.resolve()` permite
  edicao de perfil/graduacao/acoes administrativas quando actor e staff, mesma
  academia, `TargetMode.selectedStudent` e target diferente.
- `lib/service/target_resolver.dart`: `TargetMode.self` usa o proprio usuario;
  `TargetMode.selectedStudent` usa aluno selecionado.

Risco: o alcance de professor/admin esta razoavelmente separado por actor/target
na UI, mas a autoridade base ainda depende de perfil de academia e nao de
membership ativa. Professor/mestre de academia nao deve herdar poder de
administrador de plataforma.

Severidade: P1 para piloto; P0 para lancamento publico se usado para operacoes
administrativas sensiveis.

### 7. Autoridade administrativa de plataforma
- `functions/index.js`: usa Firebase Admin SDK, mas contem somente
  `acceptAcademyInvite`.
- Buscas por custom claims, platform admin, super admin ou cortesia nao
  encontraram autoridade confiavel de plataforma no servidor.
- `lib/features/entitlements/domain/*`: policy comercial pura existe, mas nao
  consulta servidor, Auth, Firestore ou claims.
- `lib/specs/freemium_entitlements_spec.md`: registra que cortesia deve ser
  concedida/revogada apenas por administrador autorizado da plataforma.

Risco: nao ha caminho seguro atual para conceder/revogar cortesia por UID. Fazer
isso no cliente permitiria autoelevacao ou escrita comercial indevida.

Severidade: P1 para piloto sem cortesia operacional; P0 para lancamento publico
com Plus/cortesia.

### 8. Impacto de endurecer permissao
Dados e fluxos possivelmente afetados:

- usuarios com perfil em `academies/{academyId}/users/{uid}` sem membership em
  `users/{uid}/academyMemberships/{academyId}`;
- alunos criados pelo painel do mestre com UUID legado e sem Auth proprio;
- convites aceitos que migraram perfil mas nao criaram membership;
- usuarios staff cujo role existe apenas no perfil de academia;
- app web/offline que hoje depende de fallback quando Firestore esta
  indisponivel;
- mocks e dados de desenvolvimento que dependem de `default`.

Risco: endurecer rules sem transicao coordenada pode bloquear usuarios reais,
professores e dados historicos.

Severidade: P0 para implantacao coordenada; P1 para piloto fechado com dados
controlados.

## Riscos ja reduzidos
- `users/{uid}/academyMemberships/{academyId}` ja bloqueia escrita direta pelo
  cliente.
- `AuthGate` ja tenta ler memberships antes de escolher academia.
- `UserScope` ja transporta `memberships` e `activeMembership`.
- `TargetResolver` ja separa `self` de `selectedStudent`.
- Estado local de `firestore.rules` ja impede professor/admin de criar ou
  atualizar `coach_evaluations` para target que nao seja atleta.
- Policy comercial de entitlements ja existe isolada e nao bloqueia telas nem
  substitui autorizacao.

## Riscos ainda existentes
- `defaultAcademyId` ainda pode representar contexto autorizado.
- Erro de membership ainda pode virar ausencia vazia.
- Rules ainda autorizam por perfil de academia, nao por membership ativa.
- Convite ainda nao fecha o triplo vinculo Auth + membership + perfil.
- Professor/admin de academia ainda e diferente de administrador da plataforma,
  mas isso nao esta representado no servidor.
- Nao ha funcao de cortesia server-only.
- Nao ha estado runtime para usuario independente sem academia ativa.

## Distincao de autoridades
Administrador de academia:
- escopo limitado a uma `academyId`;
- pode gerir alunos, convites, eventos, presenca, graduacao/avaliacoes dentro da
  academia, conforme rules;
- nao concede cortesia comercial por padrao;
- nao acessa dados pessoais privados por ser staff ou Plus.

Professor/mestre de academia:
- escopo limitado a alunos da academia em que possui role ativa;
- pode avaliar tecnicamente atletas e ver dados de aluno no workspace de
  academia;
- nao administra plataforma;
- nao concede ou revoga Plus/cortesia.

Administrador da plataforma:
- autoridade fora do escopo de academia;
- deve ser validado no servidor por custom claim, allowlist server-side ou outro
  mecanismo confiavel;
- pode conceder/revogar cortesia por UID;
- deve gerar auditoria administrativa;
- nao deve ser inferido de role `admin` em `academies/{academyId}/users`.

## Proposta minima para cortesia no servidor
Menor contrato de implementacao futura:

1. Definir fonte confiavel de platform admin no servidor:
   - preferivel: custom claim como `platformAdmin == true`;
   - alternativa inicial: allowlist server-side em config/colecao server-only,
     nunca editavel pelo cliente.
2. Criar callable server-only para conceder cortesia por `ownerUid`, plano,
   escopo, motivo administrativo e vencimento opcional.
3. Criar callable server-only para revogar cortesia por `grantId` ou
   `ownerUid + plan + origin`.
4. Gravar grants em path privado do titular, com escrita bloqueada para o
   titular e materializacao de snapshot legivel.
5. Registrar auditoria com `actorUid`, autoridade verificada, timestamps,
   operacao, target UID e motivo.
6. Atualizar a policy comercial apenas consumindo snapshot confiavel; a policy
   nao valida compra, papel de professor ou permissao de dados.

Essa implementacao e independente do endurecimento de membership, desde que o
codigo mantenha entitlements e autorizacao separados.

## Dependencias de Personal Mode e membership
- Personal Mode precisa de estado `WorkspaceContext.personal(ownerUid)` para
  usuario sem academia ativa.
- Academy Workspace precisa de `WorkspaceContext.academy(academyId,
  activeMembership)`.
- AuthGate deve distinguir `loading`, `confirmedNoMembership`,
  `permissionError`, `unavailable` e `confirmedActiveMembership`.
- Convite deve criar/vincular Auth + membership ativa + perfil de academia.
- Firestore Rules devem passar a consultar membership ativa antes de dados de
  academia, com transicao planejada.

## Estrategia de transicao
1. Inventariar usuarios com perfil de academia sem membership.
2. Classificar origem: aluno legado sem Auth, convite pendente, convite aceito,
   staff real, dado de desenvolvimento, dado invalido.
3. Criar membership ativa apenas quando houver evidencia legitima.
4. Manter modo de observabilidade antes de bloquear, registrando casos que
   seriam negados pela nova regra.
5. Ajustar convite para criar membership no mesmo fluxo de aceite.
6. Ajustar AuthGate para nao usar fallback como autorizacao; usuario sem
   membership confirmada deve ir para Personal/Onboarding.
7. Alterar rules em implantacao coordenada com backfill e fallback removido.
8. Preservar dados esportivos existentes mesmo quando acesso Plus ou membership
   forem revogados; revogacao remove acesso, nao apaga historico.

## Trabalhos independentes
- Implementar autoridade de plataforma para cortesia server-only.
- Criar estados explicitos de leitura de membership no cliente.
- Criar policy de autorizacao pura em modo observabilidade, sem bloquear telas.
- Documentar/backfill de perfis sem membership.

## Trabalhos coordenados
- Endurecer `firestore.rules` para membership ativa.
- Remover fallback silencioso de `defaultAcademyId`.
- Migrar convite para criar membership e perfil de academia atomicamente.
- Ativar Personal Mode runtime para usuario independente.

## Proxima task recomendada
Task: `MEMBERSHIP-AUTHORITY-SNAPSHOT-001`.

Objetivo: implementar o menor contrato de runtime para representar o estado de
membership sem bloquear telas nem alterar rules.

Arquivos previstos:
- `lib/model/academy_membership.dart`
- `lib/repository/academy_membership_repository.dart`
- `lib/auth_gate.dart`
- `lib/service/user_session.dart`
- testes unitarios direcionados para resolucao de estado quando possivel.

Escopo:
- adicionar estado explicito de consulta de membership;
- diferenciar loading, erro, indisponivel, nenhuma membership confirmada e
  membership ativa;
- manter fallback legado apenas rotulado como compatibilidade, nao como
  autorizacao confirmada;
- nao mudar paywall, cortesia, rules ou telas operacionais.

Criterios de aceite:
- `permission-denied` e `unavailable` nao retornam lista vazia como ausencia
  confirmada;
- usuario sem membership ativa nao e indistinguivel de usuario em erro;
- `UserScope` expoe o estado suficiente para policy futura;
- nenhum dado esportivo existente e apagado;
- nenhuma funcionalidade passa a ser bloqueada nesta etapa.

Testes necessarios:
- repository/policy de resolucao com retorno vazio confirmado;
- erro `permission-denied`;
- erro `unavailable`;
- uma membership ativa;
- multiplas memberships ativas;
- memberships revogadas/inativas.

## Validacao desta auditoria
- Validacao documental apenas.
- Nao foi executado QA runtime.
- Nao foi validada seguranca por deploy ou emulator.
- `firestore.rules` nao foi alterado nesta task.
- Codigo de producao nao foi alterado nesta task.
## MEMBERSHIP-AUTHORITY-SNAPSHOT-001 - Implementacao minima realizada
- `MembershipQuerySnapshot` e `MembershipQueryStatus` foram adicionados a `lib/model/academy_membership.dart` para diferenciar consulta confirmada, ativa, vazia, indisponivel, negada e erro.
- `AcademyMembershipRepository.loadMembershipSnapshot()` passou a retornar snapshot explicito; `permission-denied` e `unavailable` nao sao mais convertidos em lista vazia.
- `MembershipSessionResolver` foi criado em `lib/service/membership_session_resolver.dart` como resolver puro e testavel para active membership, selecao multipla, ausencia confirmada e estados bloqueantes.
- `AuthGate` passou a bloquear criacao de contexto de academia quando a consulta de membership esta indisponivel, negada ou em erro, oferecendo tentativa novamente.
- A resposta atrasada de uma tentativa de sessao e descartada quando uid, email ou geracao nao correspondem mais ao usuario atual.
- Ausencia confirmada de membership ativa ainda preserva fallback legado para `AppConfig.resolveActiveAcademyId()`; isso permanece risco conhecido ate Personal Mode runtime.
- Esta etapa nao altera `firestore.rules`, convite, schema, billing, entitlements ou telas operacionais.
## MEMBERSHIP-PROVISIONING-COMPATIBILITY-001 - Implementacao minima realizada
- `functions/index.js` passou a provisionar `users/{uid}/academyMemberships/{academyId}` no fluxo server-side de `acceptAcademyInvite`, apos validar usuario autenticado, email destinatario, estado do convite, validade, role permitida e autoridade staff registrada no convite.
- O UID da membership vem de `context.auth.uid`; o `academyId` enviado pelo cliente e usado apenas para localizar o convite e precisa bater com `invite.academyId`.
- O payload gravado segue o formato lido pelo cliente: `academyId`, `academyName`/`name`, `role`, `isActive: true` e `status: "active"`.
- Repeticao de aceite preserva membership ativa existente e nao sobrescreve role ja valida.
- Membership revogada, inativa, disabled ou expired nao e reativada por convite antigo.
- Convite ja aceito sem membership e tratado apenas quando `acceptedAuthUid` bate com o usuario autenticado e o perfil Auth correspondente existe; perfil de academia isolado nao basta para conceder vinculo.
- A conclusao do aceite e o provisionamento da membership ficam coordenados na transacao final. Se essa conclusao falhar, nova tentativa pode completar sem criar membership parcial.
- O fluxo de aceite continua desabilitado no cliente por `InviteRepository.inviteAcceptanceEnabled = false`; esta implementacao local nao torna a funcionalidade disponivel ao usuario final por si so.
- `firestore.rules`, schema, treinos, graduacao, avaliacoes, nutricao, Personal Mode, entitlements e billing nao foram alterados nesta etapa.

Evidencias necessarias para backfill seguro:
- convite com `status: "accepted"`, `acceptedAuthUid` e `acceptedAt`;
- `emailNormalized` do convite compativel com o email autenticado historico quando disponivel;
- `pendingProfileId` apontando para o perfil legado de origem;
- perfil Auth em `academies/{academyId}/users/{acceptedAuthUid}` com `migratedFromPendingProfileId` igual ao `pendingProfileId`;
- role do convite limitada a `athlete` ou `professor`;
- evidencia de que o convidador era staff legitimo da academia no momento do convite;
- ausencia de membership revogada/inativa para o mesmo UID e academia.

Proxima dependencia:
- Criar uma rotina auditavel de inventario/backfill assistido para usuarios existentes, sem criar membership automaticamente para todos os perfis e antes de endurecer `firestore.rules` para membership ativa.
## MEMBERSHIP-BACKFILL-INVENTORY-001 - Inventario somente leitura
- `tools/membership_backfill_inventory.js` fornece inventario read-only para classificar usuarios/perfis/convites/memberships existentes antes de qualquer proposta de backfill.
- A ferramenta nao possui modo `apply`, `write` ou `backfill`; a leitura real exige sinalizacao explicita com `--real-firestore --project PROJECT_ID`.
- A execucao padrao usa fixtures locais por `--fixture`, e nenhum relatorio real deve ser versionado.
- Uma falha de leitura entra em `readErrors`, torna a cobertura `incompleta` e classifica casos afetados como `dados incompletos/consulta falhou: conclusao indeterminada`; falha nao vira ausencia confirmada.
- As categorias emitidas sao: membership ativa existente; membership inativa/revogada a preservar; possivel candidato com evidencias consistentes; perfil sem evidencia suficiente; conflito de identidade/academia/papel/estado; dados incompletos ou consulta falhou.
- O relatorio minimiza dados pessoais: itens usam UID, academyId, paths de evidencia e campos propostos apenas quando sustentados; e-mail, nome e dados esportivos nao entram na saida estruturada.

Revisao direcionada do provisionamento:
- Reparos de convites aceitos preservam validacoes de identidade, academia e revogacao: `validateInviteForAuth`, `validateInviteAuthority` e `ensureMembershipForAcceptedInvite` mantem UID autenticado, `invite.academyId`, destinatario, estado do convite, role permitida e memberships revogadas/inativas como barreiras.
- Antes da transacao final, `acceptAcademyInviteCore` pode criar/migrar o perfil Auth e `copyConfirmedSubcollections` pode copiar `progress/profile`, `nutrition/profile`, `nutrition/profile/meals` e `training_sessions`.
- Se a transacao final falhar, pode existir perfil/subcolecoes copiados sem membership ativa e sem convite concluido. A repeticao foi projetada para revalidar o convite e completar a membership, mas esse estado parcial deve ser tratado como evidencia a revisar, nao como autorizacao automatica.

Categorias que podem avancar para revisao de backfill:
- `possivel candidato com evidencias consistentes`: pode ir para revisao humana/operacional porque combina Auth, convite aceito, `acceptedAuthUid`, perfil Auth migrado, academia, role permitida e autoridade staff consistente.
- `membership ativa existente`: nao precisa de backfill.
- `membership inativa/revogada: preservar`: nao deve ser reativada automaticamente.
- `perfil sem evidencia suficiente`, `conflito...` e `dados incompletos...`: exigem evidencia adicional ou correcao manual antes de qualquer proposta.

Proxima dependencia:
- Definir processo operacional de revisao e, somente depois, uma task separada para backfill assistido/server-side com dry-run, aprovacao explicita, auditoria e criterios de rollback.
