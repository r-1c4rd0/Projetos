# Freemium Entitlements Spec

Task: `TITANS-FREEMIUM-ENTITLEMENTS-SPEC-001`

Status: contrato documental. Nao implementa cobranca, bloqueios, schema, rules ou mudancas no app.

## Objetivo
Documentar o contrato de acesso comercial para:

- acesso gratuito;
- acesso `Titans Plus` por assinatura;
- acesso `Titans Plus` por cortesia administrativa sem vencimento automatico.

Entitlements definem recursos concedidos por plano. Eles nao substituem autorizacao, contexto de workspace, membership, role, actor/target ou rules.

## Decisoes de produto
- Registro rapido de treino e consulta ao proprio historico sao gratuitos.
- Home mantem card dinamico alternando perspectivas.
- Gratuito oferece resumos uteis; Plus oferece aprofundamentos.
- A divisao exata de recursos e proposta a validar por piloto.
- Cortesia libera plano sem cobranca e sem vencimento automatico.
- Somente administrador autorizado da plataforma concede ou revoga cortesia.
- Professor/admin de academia nao recebe poder de cortesia automaticamente.
- Encerrar Plus nao apaga registros pessoais.
- Assinatura valida e cortesia ativa sao concessoes independentes.
- Revogar uma concessao nao invalida a outra.
- Cortesia nao deve presumir acesso a todos os futuros produtos.
- A permissao atual do aluno sobre `belt`/`degree` nao muda nesta task; risco aceito por decisao de produto.

## Separacoes obrigatorias
- `TrainingSession`: registro esportivo, nao armazena plano comercial.
- `SportContext`/`SportPack`: modalidade e capacidades esportivas especificas. Ainda nao existem com estes nomes no codigo atual.
- `WorkspaceContext`: contexto pessoal ou academia. Documentado em `personal_mode_context_spec.md`; ainda nao implementado como contrato de runtime.
- Autorizacao: quem pode acessar dados e executar acoes.
- Entitlements: quais recursos de produto o plano concede.

Plano pago ou cortesia nunca concedem acesso a dados sem autorizacao. Professor Plus nao acessa dados pessoais privados por ser Plus.

## Estado atual comprovado

### Usuario, actor/target e academia
- `lib/auth_gate.dart` carrega memberships, filtra `isActive` e resolve academia ativa; se nao houver membership ativa, ainda usa fallback em `AppConfig.resolveActiveAcademyId()`.
- `lib/auth_gate.dart` trata `permission-denied` e `unavailable` na leitura de membership retornando lista vazia. Isso deve ser estado de erro/indeterminado em entitlements, nao ausencia comprovada.
- `lib/service/user_session.dart` expoe `UserScope` com `user`, `activeAcademyId`, memberships e activeMembership.
- `lib/service/target_resolver.dart` define `TargetMode.self` e `TargetMode.selectedStudent`; self usa usuario logado, selectedStudent usa aluno selecionado.
- `lib/screen/athlete_console_screen.dart` e `lib/screen/training_screen.dart` possuem checks locais de `canEditTarget` baseados em role, uid e academyId.

### Personal Mode, membership e fallback
- `lib/specs/personal_mode_context_spec.md` separa Personal privado de Academy Workspace.
- Personal Workspace privado ainda nao existe como runtime/schema.
- `lib/config/app_config.dart` define `defaultAcademyId` com default `default`.
- `lib/model/app_user.dart` ainda aplica fallback de academy quando o documento nao traz `academyId`.
- `lib/model/academy_membership.dart` considera membership ativa salvo quando `isActive == false`.
- `lib/repository/academy_membership_repository.dart` le `users/{uid}/academyMemberships`.

### Planos, flags e acesso comercial
- Nao foi encontrada implementacao de `entitlements`, `Titans Plus`, assinatura, cortesia, paywall ou feature flag comercial no app.
- HITS de `premium` no codigo atual sao icones/linguagem visual, nao concessao comercial.
- Arquivos `.entitlements` de macOS sao entitlements nativos da plataforma e nao representam plano do produto.
- `product_spec.md` cita feature flags futuras, mas nao ha contrato de plano implementado.

### Home dinamica e detalhes
- `lib/features/home/application/home_dashboard_use_cases.dart` monta `HomeDashboardSummary` a partir de `TrainingSession` e use cases tecnicos.
- `lib/screen/athlete_dashboard_screen.dart` transforma o summary em view model e exibe `_HomeIntelligenceDeck`.
- `_HomeIntelligenceDeck` alterna paginas de Radar, Treinos, Progresso e Repertorio.
- As entradas de detalhe atuais abrem Treinos, formulario de treino, Quick Log, Nutricao, Game Map e Skills.
- `_GameMapLiteCard` mostra resumo baseado nos ultimos treinos e abre mapa completo.

### TrainingSession e dominio esportivo
- `lib/model/training_session.dart` guarda data, local, notas, scores, academyId, uid, origem, dados de presenca e evidencias tecnicas.
- Nao ha campo comercial em `TrainingSession`.
- `lib/repository/training_repository.dart` persiste sessoes sob `academies/{academyId}/users/{uid}/training_sessions`.
- `lib/features/technical_domain` oferece taxonomia BJJ, radar tecnico e evidencias, mas nao `SportContext`/`SportPack` genericos.

### Firestore Rules e servidor
- `firestore.rules` define `isSelf`, `isAcademyMember`, `isAcademyAdmin`, `isAcademyProfessor` e `isAcademyStaff` baseados em perfil de academia.
- Rules atuais permitem dados de usuario, treino, progresso e nutricao por self ou staff de academia, conforme o path.
- `users/{uid}/academyMemberships/{academyId}` permite leitura pelo proprio usuario e bloqueia escrita direta.
- `functions/index.js` usa `firebase-admin` e implementa `acceptAcademyInvite`.
- Nao foi encontrada autoridade administrativa de plataforma confiavel para conceder cortesia, como custom claim, allowlist server-side ou callable admin-only.

## Divergencias com documentos antigos
- Docs de multi-academia e Personal Mode registram que fallback default e temporario; o codigo ainda usa fallback em sessao e `AppUser.fromMap`.
- Docs de schema indicam memberships como fronteira; rules atuais ainda derivam membership de perfil em `academies/{academyId}/users/{uid}` para `isAcademyMember`.
- Docs citam feature flags futuras; o codigo nao possui camada central de flags/entitlements.
- Docs de Personal Mode separam Personal privado; o codigo ainda grava treino apenas em paths de academia.

## Arquitetura proposta

### EntitlementGrant
Contrato proposto de concessao comercial:

```text
EntitlementGrant(
  ownerUid,
  plan,
  origin,
  status,
  startsAt,
  expiresAt?,
  grantedByUid?,
  grantedByAuthority?,
  revokedAt?,
  revokedByUid?,
  auditReason?,
  sourceRef?
)
```

Campos:
- `ownerUid`: titular da conta beneficiada.
- `plan`: `free` ou `titans_plus`.
- `origin`: `default_free`, `subscription`, `admin_courtesy`.
- `status`: `active`, `past_due`, `expired`, `revoked`, `canceled`, `unknown`.
- `startsAt`: inicio da concessao.
- `expiresAt`: opcional; cortesia administrativa pode nao ter vencimento.
- `grantedByUid`: admin de plataforma que concedeu cortesia.
- `grantedByAuthority`: autoridade validada no servidor.
- `revokedAt`/`revokedByUid`: auditoria de revogacao.
- `auditReason`: motivo administrativo.
- `sourceRef`: referencia opaca para provedor de cobranca ou evento administrativo.

Dados comerciais nao podem ser alterados pelo titular da conta no cliente.

### EntitlementSnapshot
Contrato de leitura para o cliente:

```text
EntitlementSnapshot(
  ownerUid,
  effectivePlan,
  grants,
  confirmedAt,
  state,
  staleReason?
)
```

`effectivePlan` e `titans_plus` se houver assinatura valida ou cortesia ativa. Caso contrario, e `free`.

Estados:
- `loading`: cliente ainda nao sabe o plano.
- `confirmedFree`: plano gratuito confirmado.
- `confirmedPlus`: Plus confirmado por assinatura e/ou cortesia.
- `unknownOffline`: nao houve confirmacao recente; nao promover para Plus novo.
- `errorPermission`: erro de permissao ao ler snapshot.
- `errorUnavailable`: servico indisponivel; nao tratar como ausencia de assinatura.
- `revokedOrExpired`: ultimo snapshot confirma perda de Plus.

## Assinatura, cortesia e coexistencia
- Assinatura e cortesia sao grants independentes.
- `effectivePlan` escolhe Plus quando qualquer grant Plus esta ativo.
- Revogar cortesia nao cancela assinatura.
- Cancelar/expirar assinatura nao revoga cortesia.
- Cortesia sem `expiresAt` permanece ativa ate revogacao administrativa.
- Cortesia nao implica acesso automatico a produtos futuros; grants futuros devem declarar escopo.
- Eventos do provedor de cobranca devem ser processados no servidor.
- Eventos administrativos de cortesia devem ser processados no servidor.

## Matriz proposta de recursos
Esta matriz e proposta para validacao, nao bloqueio implementado.

```text
Area/Recurso                         Free                         Titans Plus
Quick Log de treino                  liberar                      liberar
Historico proprio de treinos         liberar                      liberar
Editar treino proprio                liberar                      liberar
Home card dinamico                   resumos uteis                perspectivas aprofundadas
Radar/Game Map na Home               preview/resumo               detalhes e leituras comparativas
Game Map completo                    leitura basica               filtros/insights aprofundados
Skills                               resumo por repertorio        detalhe tecnico e historico expandido
Progresso                            indicadores principais       tendencias e diagnosticos avancados
Nutricao                            registro/visao simples       analises/planos aprofundados se validados
Export/relatorios                    nao definido                 candidato Plus
Academia/professor sobre aluno       depende de autorizacao       depende de autorizacao + recurso se aplicavel
Graduacao oficial                    fora de entitlement          fora de entitlement
```

A divisao fina deve ser validada em piloto. O contrato fixa apenas os gratuitos obrigatorios e a separacao entre plano e autorizacao.

## Politica central de acesso
Candidata adequada ao codigo atual: uma policy isolada de leitura, inicialmente sem bloquear telas.

Responsabilidade futura:

```text
AccessDecision = AccessPolicy.evaluate(
  actor,
  target,
  workspaceContext,
  authorizationContext,
  entitlementSnapshot,
  featureKey,
)
```

Por que cabe no codigo atual:
- `UserScope` ja fornece usuario, academia ativa e memberships.
- `TargetResolver` ja centraliza self versus aluno selecionado.
- Home ja tem use case de resumo que pode receber um snapshot de acesso futuramente sem alterar `TrainingSession`.
- Checks locais em telas podem ser inventariados antes de migrar para policy.

Regra essencial: `AccessPolicy` deve consultar autorizacao antes de entitlements. Se actor nao pode ver o target/workspace, Plus nao muda a decisao.

## Cliente versus servidor
Cliente:
- Le `EntitlementSnapshot` confirmado pelo servidor.
- Renderiza estados `loading`, `confirmedFree`, `confirmedPlus`, `unknownOffline` e erros.
- Pode mostrar previews, CTAs ou explicacoes sem bloquear dados gratuitos.
- Nao grava grants comerciais.
- Nao decide cortesia.

Servidor:
- Recebe webhooks/eventos de assinatura.
- Concede/revoga cortesia apenas com autoridade administrativa de plataforma.
- Materializa snapshot de leitura para o cliente.
- Mantem auditoria de quem concedeu/revogou, quando e por qual motivo.
- Nao usa professor/admin de academia como autoridade de plataforma por padrao.

## Armazenamento proposto
Opcao proposta, a validar antes de schema/rules:

```text
users/{uid}/private/entitlements/snapshot
users/{uid}/private/entitlements/grants/{grantId}
platformAdminAudit/{auditId}
```

Motivos:
- O titular consegue ler o proprio snapshot.
- Grants ficam ligados ao titular, mas escrita e server-only.
- Auditoria administrativa fica separada do dado esportivo.
- Nao mistura plano comercial com `TrainingSession`, membership ou perfil de academia.

Nao implementar nesta task.

## Comportamento apos expiracao ou revogacao
- Dados pessoais existentes permanecem preservados.
- Registros de treino continuam visiveis no historico proprio gratuito.
- Recursos Plus voltam para resumo/free no proximo snapshot confirmado.
- Conteudo gerado enquanto Plus estava ativo nao deve ser apagado automaticamente.
- Dados derivados comerciais podem deixar de ser recalculados/exibidos se forem recurso Plus, mas a fonte esportiva permanece.
- Falha de rede, `permission-denied` ou `unavailable` nao deve ser interpretada como ausencia de assinatura; deve virar estado indeterminado/erro.

## Dependencias e ordem de implementacao
1. Concluir contrato de Personal/Workspace e remover ambiguidades criticas de fallback default.
2. Definir autoridade administrativa de plataforma no servidor.
3. Criar modelo documental de entitlements e grants server-only.
4. Criar snapshot de leitura para cliente.
5. Criar policy central em modo observabilidade, sem bloquear telas.
6. Instrumentar Home/Training/Game Map com decisoes calculadas, ainda sem paywall.
7. Validar matriz Free/Plus no piloto.
8. Implementar bloqueios/CTAs apenas depois de regras, testes e decisao de produto fina.

## Proxima task de codigo recomendada
Task: `TITANS-ACCESS-POLICY-SKELETON-001`.

Objetivo: criar a menor base de codigo util para politica central sem bloquear telas.

Arquivos previstos:
- `lib/features/entitlements/domain/entitlement_models.dart`
- `lib/features/entitlements/domain/access_feature_key.dart`
- `lib/features/entitlements/domain/access_policy.dart`
- `test/features/entitlements/domain/access_policy_test.dart`

Escopo:
- Modelos imutaveis puros de `EntitlementSnapshot`, `EntitlementGrant`, `AccessFeatureKey` e `AccessDecision`.
- Policy pura que retorna decisoes para Free/Plus/cortesia, mas nao e chamada por telas.
- Nenhuma mudanca em Firestore, app, Home, Game Map, Training, Skills ou graduacao.

Criterios de aceite:
- Plus por assinatura e Plus por cortesia geram `effectivePlan == titans_plus` independentemente.
- Revogar uma concessao nao invalida a outra.
- `unknownOffline` nao concede Plus novo.
- Recursos gratuitos obrigatorios retornam permitido para self autorizado.
- Professor Plus nao acessa Personal privado de aluno sem autorizacao.
- Testes unitarios cobrem coexistencia assinatura/cortesia, expiracao, revogacao e autorizacao antes de entitlement.

## QA documental
- Confirmar que nao existe spec concorrente de entitlements.
- Confirmar que a spec esta indexada em `README.md`.
- Confirmar que nenhuma conclusao de implementacao foi declarada sem evidencia em codigo.
- Confirmar que a validacao runtime fica para a proxima task de codigo.
## TITANS-ACCESS-POLICY-SKELETON-001 - Implementacao minima realizada
- Modelos puros criados em `lib/features/entitlements/domain`.
- Policy comercial isolada criada sem conexao com telas, Auth, Firestore ou pagamentos.
- Testes unitarios cobrem acesso gratuito, assinatura, cortesia, expiracao, revogacao, titular e estados indeterminados.
- Esta etapa nao bloqueia nenhuma funcionalidade existente.
- Entradas futuras de assinatura e cortesia continuam exigindo fonte confiavel no servidor.
## MEMBERSHIP-AND-PLATFORM-AUTHORITY-AUDIT-001 - Dependencia de autorizacao
- A auditoria detalhada esta em `membership_platform_authority_audit.md`.
- O estado atual ainda separa parcialmente membership, perfil de academia e convite aceito.
- Administrador de academia e professor/mestre nao sao administradores de plataforma.
- Cortesia exige funcao server-only com autoridade de plataforma confiavel e auditoria administrativa.
- Essa dependencia nao altera a policy comercial pura ja criada.
