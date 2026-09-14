# SPORT-TRAINING-BJJ-FIELD-INVENTORY-001 - Inventario BJJ atual

## Resumo executivo

O estado atual do modulo de treino e BJJ-first em modelo, formulario, agregadores e telas analiticas. `TrainingSession` ainda nao possui `sportId`, `disciplineId`, `actorUid`, `targetUid`, `duration`, `sportPayload` ou `evidenceRefs`. O alvo operacional e representado por `uid` e pela path `academies/{academyId}/users/{uid}/training_sessions/{sessionId}` em `TrainingRepository`.

O que pode ser considerado Core hoje e limitado a identidade, escopo, tempo, lifecycle, notas, origem e intensidade. A maior parte da leitura rica do produto depende de campos BJJ: `position`, `technique`, `techniques`, `applicationContext`, `techniqueOutcome`, `successes`, `difficulties`, taxonomia Jiu-Jitsu e categorias tecnicas. Game Map, Skill Matrix, Radar tecnico, recomendações de treino, Home e CoachEvaluation dependem dessa semantica.

Conclusao: nao ha bloqueio conceitual para especificar um BJJ Sport Pack, mas ha bloqueio para implementar SportPack/adapters sem antes congelar o contrato BJJ. O proximo passo recomendado e `BJJ-SPORT-PACK-SPEC-001`, porque os achados mostram que o pack BJJ precisa ser explicitado antes de uma spec generica de capabilities.

## Arquivos analisados

- `lib/model/training_session.dart`
- `lib/repository/training_repository.dart`
- `lib/service/training_aggregator.dart`
- `lib/service/training_batch.dart`
- `lib/widgets/quick_log_sheet.dart`
- `lib/screen/add_training_session_screen.dart`
- `lib/screen/training_screen.dart`
- `lib/screen/athlete_dashboard_screen.dart`
- `lib/screen/game_map_screen.dart`
- `lib/screen/skills_screen.dart`
- `lib/screen/skill_detail_screen.dart`
- `lib/screen/progress_screen.dart`
- `lib/features/training/domain/training_models.dart`
- `lib/features/training/application/training_use_cases.dart`
- `lib/features/home/domain/home_dashboard_models.dart`
- `lib/features/home/application/home_dashboard_use_cases.dart`
- `lib/features/progress/domain/progress_models.dart`
- `lib/features/progress/application/progress_use_cases.dart`
- `lib/features/technical_domain/domain/technical_models.dart`
- `lib/features/technical_domain/domain/technical_taxonomy.dart`
- `lib/model/jiu_jitsu_taxonomy_item.dart`
- `lib/repository/jiu_jitsu_taxonomy_repository.dart`
- `lib/model/coach_evaluation.dart`
- `lib/repository/coach_evaluation_repository.dart`
- `lib/widgets/charts/titans_technical_radar.dart`
- `test/service/training_session_lifecycle_test.dart`
- `test/service/training_aggregator_recommended_focus_test.dart`
- `test/service/training_aggregator_next_training_test.dart`
- `test/screen/training_intent_confirmation_compile_test.dart`
- `test/screen/add_training_session_debrief_picker_test.dart`
- specs em `lib/specs`, com foco em `README.md`, `training_spec.md`, `training_core_multimodality_spec.md`, `progress_spec.md`, `product_spec.md` e `architecture_spec.md`.

## Tabela de campos atuais de TrainingSession

| Campo | Tipo atual | Obrigatorio/opcional | Origem | Persistido/derivado | Core/BJJ/ambiguo | Onde e usado | Risco de mudanca |
|---|---|---|---|---|---|---|---|
| `id` | `String` | Obrigatorio no modelo | `Uuid`, doc id ou id derivado de presenca | Derivado do doc id e usado na escrita | Core | Repository, dedupe, historico, lifecycle | Alto: quebraria update/delete e dedupe. |
| `date` | `DateTime` | Obrigatorio | formulario, quick log, lifecycle, Firestore `date` | Persistido | Core | Repository orderBy, Home, Progress, Training, charts, dedupe | Alto: eixo temporal de todo o app. |
| `place` | `TrainingPlace` | Obrigatorio no modelo; default leitura `academy` | formulario/quick log ou default | Persistido | BJJ/ambiguo | Registro e historico; pouco usado em agregados | Medio: pode ser local generico, mas labels atuais sao BJJ/academia. |
| `notes` | `String?` | Opcional | formulario/quick log | Persistido | Core | Historico, cards e debrief | Baixo: serve para qualquer modalidade. |
| `scores` | `Map<String,int>` | Opcional com default `{}` | legado | Persistido | Legado/BJJ ambiguo | Modelo e leitura; uso atual fraco | Medio: sem contrato claro. Nao migrar agora. |
| `academyId` | `String?` | Opcional no modelo; obrigatorio no repository/fluxo | props de tela, target/contexto | Persistido quando presente e tambem path | Core/escopo | Repository, AddTraining, QuickLog, Progress, GameMap, Skills | Alto: risco de misturar academias. |
| `uid` | `String?` | Opcional no modelo; obrigatorio no repository/fluxo | props de tela; representa alvo | Persistido quando presente e tambem path | Core/target legado | Repository, actor/target logs, dedupe attendance, telas | Alto: hoje equivale a `targetUid`; nao trocar sem adapter. |
| `source` | `String?` | Opcional | aula/presenca/importacao futura/manual | Persistido | Core/ambiguo | Modelo e escrita preservada; pouco consumido | Medio: precisa enum/contrato antes de expandir. |
| `attendanceSessionId` | `String?` | Opcional | presenca/aula derivada | Persistido | Core de evidencia/aula | Repository id derivado, dedupe, class session futura | Alto: liga aula/presenca a treino individual. |
| `attendanceCheckInUid` | `String?` | Opcional | presenca/check-in | Persistido | Core de evidencia/aula | Repository id derivado, dedupe | Alto: evitar duplicidade e associacao errada. |
| `classType` | `String?` | Opcional | aula/presenca | Persistido | BJJ/academia ambiguo | Modelo e exibicoes futuras | Medio: pode ser modalidade ou tipo de aula; precisa contrato. |
| `instructorUid` | `String?` | Opcional | aula/professor | Persistido | Core de autoria/aula | Modelo, possivel aula derivada | Medio: nao confundir com actor da escrita. |
| `instructorName` | `String?` | Opcional | aula/professor | Persistido | Core de apresentacao/aula | Modelo/exibicao | Baixo/medio: dado denormalizado. |
| `status` | `TrainingSessionStatus?` | Opcional por compatibilidade legado | formulario/lifecycle | Persistido quando presente; derivado quando ausente | Core | Training lifecycle, Home pending, Progress, Training metrics | Alto: define o que conta como realizado. |
| `plannedFor` | `DateTime?` | Opcional | planejamento/recorrencia/lifecycle | Persistido | Core | Home pending, Training lifecycle | Alto: sessoes planejadas nao podem virar treino realizado automaticamente. |
| `effectiveDate` | `DateTime?` | Opcional | confirmacao/conclusao | Persistido | Core | Modelo/lifecycle; menos usado que `date` | Medio: precisa alinhar com `occurredAt` futuro. |
| `confirmedAt` | `DateTime?` | Opcional | quick log, confirmacao, lifecycle | Persistido | Core/auditoria | Modelo/lifecycle | Medio: evidencia de confirmacao, nao desempenho. |
| `position` | `String?` | Opcional | formulario, quick log, legado | Persistido | BJJ Pack | Game Map, Skill Matrix, Radar, Home debrief, filtros Training, Skill Detail | Alto: campo central BJJ. Corrida/forca nao deveriam preencher. |
| `technique` | `String?` | Opcional, mas central na pratica | formulario, quick log, legado | Persistido | BJJ Pack | `effectiveTechniqueEntries`, Game Map, Skills, Radar, Home, recomendacoes | Alto: muitas telas assumem tecnica como unidade de evidencia. |
| `techniques` | `List<TrainingTechniqueEntry>` | Opcional com default `[]` | formulario multi-tecnica/quick log | Persistido quando nao vazio; delete tecnico em update | BJJ Pack | Agregador, Game Map, Skill Matrix, Radar, historico | Alto: principal estrutura BJJ atual. |
| `successes` | `String?` | Opcional | formulario/debrief | Persistido | BJJ/ambiguo | Skill Matrix, Game Map, Home debrief, recomendacoes | Medio: pode existir em outros esportes, mas hoje texto e semantica sao BJJ. |
| `difficulties` | `String?` | Opcional | formulario/debrief | Persistido | BJJ/ambiguo | Skill Matrix, Game Map, Home debrief, recomendacoes | Medio/alto: alimenta foco tecnico. |
| `intensity` | `int?` 1..5 | Opcional | formulario/quick log | Persistido | Core/ambiguo | Home media, Training overview, Game Map/Skill Matrix summaries, Next Training | Medio: escala subjetiva pode ser core, mas precisa SportCapabilities. |
| `debriefNotes` | `String?` | Opcional | formulario/quick log | Persistido | BJJ/ambiguo | Modelo; display indireto/nota | Baixo/medio: pode virar nota core ou payload BJJ. |
| `applicationContext` | `String?` | Opcional | formulario/quick log | Persistido; tambem pode existir por tecnica | BJJ Pack | Radar/RTCA, RecommendedFocus, Skill Matrix, historico | Alto: enum semantico de aplicacao BJJ. |
| `techniqueOutcome` | `String?` | Opcional | formulario/quick log | Persistido; tambem pode existir por tecnica | BJJ Pack | Radar/RTCA, RecommendedFocus, Skill Matrix, historico | Alto: resultado tecnico BJJ, nao serve para corrida/forca. |
| `updatedAt` | server timestamp | Gravado em `toMap`, nao campo do modelo | repository/model toMap | Persistido, nao lido no modelo | Core/auditoria | Firestore somente | Baixo: auditoria tecnica. |
| `statusChangedAt` | server timestamp | Gravado em lifecycle, nao campo do modelo | `updateSessionLifecycle` | Persistido, nao lido no modelo | Core/auditoria | Firestore somente | Baixo/medio: util para auditoria futura. |

## Campos de TrainingTechniqueEntry

| Campo | Tipo atual | Obrigatorio/opcional | Origem | Persistido/derivado | Core/BJJ/ambiguo | Onde e usado | Risco de mudanca |
|---|---|---|---|---|---|---|---|
| `technique` | `String` | Obrigatorio para entrada | formulario/quick log | Persistido | BJJ Pack | Toda evidencia tecnica | Alto. |
| `position` | `String?` | Opcional | formulario/quick log | Persistido | BJJ Pack | Game Map, Skill Matrix, Radar, Skill Detail | Alto. |
| `category` | `String?` | Opcional | formulario/futuro | Persistido, mas agregador recalcula por taxonomia | BJJ Pack | Pouco usado diretamente | Medio: hoje nao e fonte unica. |
| `side` | `TrainingTechniqueSide` | Opcional com default `unknown` | formulario/futuro | Persistido sempre no entry | BJJ Pack | Modelo/display futuro | Medio: sem consumo forte atual. |
| `applicationContext` | `String?` | Opcional | formulario/quick log | Persistido | BJJ Pack | Agregador, Radar/RTCA, historico | Alto. |
| `techniqueOutcome` | `String?` | Opcional | formulario/quick log | Persistido | BJJ Pack | Agregador, Radar/RTCA, recomendacoes | Alto. |
| `notes` | `String?` | Opcional | formulario | Persistido | BJJ/ambiguo | Historico/possivel detalhe | Baixo/medio. |

## Campos derivados e obrigatorios na pratica

- `effectiveTechniqueEntries`: derivado; se `techniques` estiver vazio, cria entrada legada a partir de `technique`, `position`, `applicationContext` e `techniqueOutcome`. E o principal adapter legado atual.
- `effectiveStatus`: derivado; se `status` estiver ausente, sessoes futuras viram `planned` e sessoes ate hoje viram `completed`.
- `isCompleted`, `isPlanned`, `isAwaitingConfirmation`: derivados de `effectiveStatus` e `date`.
- `TrainingHistoryItem.positionKeys` e `techniqueKeys`: derivados para filtros da tela Treinos.
- `SkillEvidence.skillId`, `normalizedTechniqueName`, `category` e `TechnicalRadarAxis`: derivados por `JiuJitsuTaxonomy`.
- Obrigatorios na pratica para leitura rica BJJ: `date`, `academyId`, `uid`, ao menos uma `technique` e preferencialmente `position`, `applicationContext` e `techniqueOutcome`.
- Obrigatorios na pratica para metricas basicas: `date` e status resolvido como `completed`.

## Mapa de dependencias

### Registro de treino

- `AddTrainingSessionScreen` recebe `academyId` e `uid`; `uid` e o alvo atual.
- Usa `UserScope` para obter actor e permitir adicao de taxonomia customizada por admin/professor da mesma academia.
- Carrega `JiuJitsuTaxonomyRepository.watchItems` para posicoes e tecnicas customizadas da academia.
- Monta `TrainingTechniqueEntry` a partir de tecnica, posicao, contexto de aplicacao e resultado tecnico.
- Cria `TrainingSession` com `status`, `plannedFor`, `effectiveDate`, `confirmedAt`, `position`, `technique`, `techniques`, `successes`, `difficulties`, `intensity`, `applicationContext` e `techniqueOutcome`.
- Recorrencia cria uma sessao `completed` ou multiplas sessoes `planned`, sempre com campos BJJ copiados.

### Quick Log

- `QuickLogSheet` recebe `academyId`, `uid`, sessoes recentes e repository.
- Prefill vem da ultima sessao: `intensity`, `techniqueOutcome`, `technique`, `position`.
- Salva sessao `completed` com `TrainingPlace.academy`, `effectiveDate`, `confirmedAt`, `position`, `technique`, `techniques`, `intensity`, `debriefNotes`, `applicationContext: sparring` e `techniqueOutcome`.
- O quick log assume BJJ por usar tecnica, posicao e resultado tecnico como campos centrais.

### TrainingRepository

- Fonte unica de persistencia de treinos.
- Path atual: `academies/{academyId}/users/{uid}/training_sessions/{sessionId}`.
- Lista/assiste por `date` ascendente.
- `upsertSession` e batch chamam `toMap(includeTechnicalDeletes: true)`, apagando campos tecnicos quando nao informados.
- `updateSessionLifecycle` altera apenas status/datas/auditoria, sem mexer em tecnica.
- `attendanceLinkedSessionId` e dedupe por presenca amarram aula/check-in a treino individual.

### Historico de treino

- `TrainingScreen` usa `GetTrainingDashboardSummary` e `TrainingSessionHistoryItem`.
- Filtros de historico incluem periodo, resultado, contexto, posicao e tecnica.
- Cards de historico exibem contagem de tecnicas, posicoes, contexto, resultado e notas.
- Uma sessao de corrida/forca sem adapter cairia como treino sem tecnica e perderia boa parte dos filtros/labels.

### Home

- `GetHomeDashboardSummary` usa sessoes completed e deduplicadas.
- Usa metricas gerais de frequencia, ultimos treinos, pending confirmation, Game Map Lite, Skill Matrix, Radar tecnico, Recommended Focus e Next Training.
- Debrief Insights percorre `effectiveTechniqueEntries`, `difficulties`, `successes` e `intensity`.
- Uma modalidade nao BJJ seria contada em metricas se fosse `completed`, mas nao deveria alimentar Game Map/Skill Matrix/Radar sem isolamento por esporte.

### Game Map

- `GameMapScreen` consome `buildGameMap`, `buildSkillMatrix`, `buildTechnicalEvidence` e `getTechnicalRadarSummary`.
- A matriz de posicao por eixo percorre `effectiveTechniqueEntries`, exige `position` e `technique`, usa `JiuJitsuTaxonomy.categoryFor` e `technicalRadarAxisForCategory`.
- RTCA operacional calcula recorrencia, tecnicas registradas, consistencia por dias e aplicacao registrada.
- CoachEvaluation na tela escolhe uma tecnica derivada de evidencia tecnica.
- Corrida/forca quebrariam o significado do Game Map se entrassem como sessoes completed no mesmo conjunto.

### Skill Matrix

- `buildSkillMatrix` agrupa por categoria Jiu-Jitsu e tecnica.
- Usa `applicationContext`, `techniqueOutcome`, `successes`, `difficulties`, `intensity` e contagem de sessoes para status tecnico.
- `SkillsScreen` navega por categorias, tecnicas e posicoes; `SkillDetailScreen` detalha evidencias por tecnica.
- Depende de skill ids de `JiuJitsuTaxonomy`; nao ha conceito multi-modalidade.

### Radar tecnico

- Radar tecnico usa categorias BJJ classificadas em eixos de retencao, transicao, controle, ataque ou unclassified.
- Tecnicas custom ou sem identidade podem ficar `unclassified`.
- A spec atual ja proibe criar score final sem taxonomia validada.
- Modalidade nao BJJ deve ser isolada para nao aparecer como eixo tecnico BJJ.

### Progress

- Progress usa `TrainingAggregator.metrics`, sessoes completed, series por periodo, heatmap de consistencia e progresso de graduacao.
- E o consumidor mais proximo de Core, porque depende principalmente de data/status/contagem.
- Ainda assim, graduacao BJJ e sessoes requeridas por faixa tornam o uso BJJ-first.

### CoachEvaluation

- `CoachEvaluation` e salvo por `skillId`, `athleteUid`, `academyId`, `evaluatorUid` e niveis `knowledge`, `drill`, `application`, `consistency`.
- Repositories ficam sob academia/usuario alvo, separados do documento `TrainingSession`.
- `GameMapScreen` e `SkillDetailScreen` permitem avaliacao por professor/admin quando actor e staff, nao e o proprio atleta e pertence a mesma academia.
- Depende de skill tecnico BJJ. Nao deve avaliar corrida/forca sem outro contrato.

## Actor, target, uid, academyId e isSelfProfile

- `actor` vem de `UserScope` nas telas e representa o usuario logado.
- `target` vem de `TargetResolver`, `explicitTarget` ou props de tela; em treino aparece como `uid` passado para repository e telas.
- `TrainingSession.uid` e o alvo legado. Nao ha `actorUid` persistido no modelo de treino manual.
- Logs de registro imprimem `actor.uid`, `target.uid`, `academyId` e `uid`, mas esses logs nao sao contrato de schema.
- `ProgressScreen` e outras telas resolvem `academyId`/`uid` do target antes de assistir sessoes.
- `isSelfProfile` aparece no fluxo de perfil/console, mas no inventario de treino o ponto critico e nao reaproveitar selectedStudent quando o modo for self.
- Para Sport Core futuro, `uid` precisa ser adapter para `targetUid`; `actorUid` nao pode ser inferido retroativamente sem auditoria.

## Assuncoes BJJ-first encontradas

- O formulario completo e o Quick Log oferecem tecnica, posicao, contexto e resultado, nao um formulario neutro por esporte.
- `TrainingAggregator._techniqueEvidencesFor` ignora sessoes sem tecnica, mas metricas gerais ainda contam sessoes completed.
- Game Map e Skill Matrix tratam tecnica/posicao como unidade principal de leitura.
- Radar tecnico depende de categoria Jiu-Jitsu.
- Home mistura metricas core com Game Map Lite, Skill Matrix e Radar tecnico a partir do mesmo conjunto de sessoes.
- CoachEvaluation avalia `skillId` tecnico BJJ.
- Testes de agregador usam posicoes e tecnicas BJJ como dados esperados.

## Telas que quebrariam ou perderiam sentido com Corrida/Forca sem adapter

- `add_training_session_screen.dart`: renderizaria campos BJJ para outra modalidade.
- `quick_log_sheet.dart`: salvaria sparring/tecnica/posicao para algo que nao e BJJ.
- `training_screen.dart`: historico e filtros por tecnica/posicao ficariam vazios ou enganadores.
- `game_map_screen.dart`: poderia ignorar sessoes sem tecnica ou classificar errado se campos fossem preenchidos genericamente.
- `skills_screen.dart` e `skill_detail_screen.dart`: nao possuem skill ids fora de Jiu-Jitsu.
- `athlete_dashboard_screen.dart` e Home: poderiam contar sessoes de outra modalidade nas metricas e, ao mesmo tempo, nao refletir no repertorio tecnico.
- `progress_screen.dart`: poderia contar sessoes para progresso/frequencia BJJ sem isolamento por modalidade.

## Classificacao

### Campos Core atuais

- `id`
- `date`
- `notes`
- `academyId`
- `uid` como target legado
- `source`
- `status`
- `plannedFor`
- `effectiveDate`
- `confirmedAt`
- `attendanceSessionId`
- `attendanceCheckInUid`
- `instructorUid`
- `instructorName`
- `updatedAt` e `statusChangedAt` como auditoria persistida

### Campos BJJ Pack

- `position`
- `technique`
- `techniques`
- `TrainingTechniqueEntry.technique`
- `TrainingTechniqueEntry.position`
- `TrainingTechniqueEntry.category`
- `TrainingTechniqueEntry.side`
- `TrainingTechniqueEntry.applicationContext`
- `TrainingTechniqueEntry.techniqueOutcome`
- `applicationContext`
- `techniqueOutcome`
- `successes`
- `difficulties`
- `debriefNotes`
- `place`, enquanto estiver ligado a academia/casa/outro no formulario BJJ atual
- `classType`, enquanto nao houver contrato de aula multi-modalidade

### Campos legados

- `technique` e `position` top-level, porque `effectiveTechniqueEntries` faz fallback para eles.
- `scores`, sem consumo forte atual.
- `applicationContext` e `techniqueOutcome` top-level, porque hoje tambem podem existir por entry.

### Campos candidatos a adapter

- `uid` -> `targetUid` futuro.
- `date` + `plannedFor` + `effectiveDate` -> `occurredAt`/datas lifecycle futuras.
- `technique`/`position` top-level -> `sportPayload.bjj.techniques[0]` ou equivalente.
- `techniques` -> payload BJJ estruturado.
- `intensity` -> campo core somente se a escala for declarada por capability.
- `source`, `attendanceSessionId`, `attendanceCheckInUid` -> referencias de origem/evidencia.
- `classType`, `instructorUid`, `instructorName` -> contexto de aula.

### Campos que nao devem ser migrados agora

- `scores`, por falta de contrato e consumo atual claro.
- `category`, enquanto a categoria efetiva ainda e recalculada por `JiuJitsuTaxonomy`.
- `sportId`, `disciplineId`, `sportPayload`, `evidenceRefs`, `actorUid` e `targetUid`, porque esta task e inventario e nao altera schema.
- Qualquer campo de corrida/forca, porque ainda nao existe SportCapabilities nem SportPack.

## Dados que precisariam de adapter no futuro

- Leitura de legado sem `sportId` como BJJ default.
- Conversao de `uid` para `targetUid` em camada de dominio, mantendo path atual ate migration aprovada.
- Conversao de `date`/`plannedFor`/`effectiveDate` para semantica temporal explicita.
- Conversao de `technique`, `position`, `applicationContext`, `techniqueOutcome`, `successes`, `difficulties` e `debriefNotes` para payload BJJ.
- Separacao de sessoes por modalidade antes de alimentar Game Map, Skill Matrix, Radar e graduacao.
- Protecao para Progress/Home nao contarem outra modalidade como frequencia BJJ sem regra explicita.

## Riscos

- Quebrar Game Map ao remover/renomear tecnica ou posicao sem adapter.
- Quebrar Radar ao misturar categorias nao BJJ com `JiuJitsuTaxonomy`.
- Quebrar Progress ao contar corrida/forca como treino valido para graduacao BJJ.
- Quebrar actor/target se `uid` for renomeado sem mapear target e sem preservar actor real.
- Misturar corrida/forca com taxonomia BJJ por preencher `technique` ou `position` com termos genericos.
- Migration prematura criando `sportId`/payload sem SportCapabilities validado.
- Payload generico demais, sem semantica, virar deposito de campos e quebrar Evidence Engine.
- Perder compatibilidade com sessoes legadas que usam top-level `technique`/`position`.
- Apagar campos tecnicos por causa de `includeTechnicalDeletes` em updates sem adapter cuidadoso.

## Bloqueio para SportPack

Nao ha bloqueio para especificar o BJJ Pack. Ha bloqueio para implementar SportPack, SportCapabilities, `sportId`, adapter ou UI multi-modalidade sem antes documentar o contrato BJJ atual como pack formal, incluindo quais consumidores aceitam somente BJJ e quais metricas podem ser core.

## Proxima task recomendada

`BJJ-SPORT-PACK-SPEC-001` - especificar o BJJ Sport Pack atual, congelando:

- campos BJJ oficiais.
- taxonomias e categorias suportadas.
- lifecycle e elegibilidade de evidencia.
- consumidores autorizados: Game Map, Skill Matrix, Radar, Home, Progress e CoachEvaluation.
- compatibilidade com campos legados top-level.
- fronteira entre metricas core e evidencias BJJ.

Somente depois disso faz sentido abrir `SPORT-CAPABILITIES-SPEC-001`, porque as capabilities devem nascer a partir do pack BJJ real e nao de um modelo generico abstrato.

## Validacao desta task

Esta task e documental. Nao altera codigo Dart, schema, repositories, Firestore Rules, UI, actor/target, migration, `sportId`, SportPack, adapter, lints, analyzer ou dependencias.