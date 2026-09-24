# SPORT-TRAINING-CORE-SPEC-001 - Training Core multi-modalidade

## Contexto

O Titans BJJ esta evoluindo para Titans Performance OS sem abandonar o principio BJJ-first. Esta spec documenta uma proposta tecnica e de produto para tratar `TrainingSession` como um envelope core comum entre modalidades, mantendo o Jiu-Jitsu como experiencia padrao, mais profunda e imediatamente suportada.

Esta etapa e somente documental. Nao altera codigo, schema, repositories, Firestore Rules, UI, actor/target, fluxo de registrar treino, migration, dropdown, pacote ou experiencia publica multi-esporte.

## Objetivo

Definir uma direcao segura para que o registro de treino possa receber, no futuro, diferentes modalidades/esportes por meio de `SportContext` e `SportPack`, sem quebrar os dados atuais de BJJ, Game Map, Skill Matrix, Training lifecycle, evidencias tecnicas ou contratos de academia/aluno.

## Conceitos

### Training Core

Training Core e o envelope comum de uma sessao de treino. Ele descreve quem registrou, para quem a sessao vale, em qual academia/contexto, quando ocorreu, qual modalidade representa, qual foi a carga basica e quais evidencias futuras podem se conectar a ela.

O core nao tenta modelar todos os esportes diretamente. Ele deve conter apenas campos transversais e estaveis. Detalhes especificos de cada modalidade ficam em `sportPayload`, validado por capacidades do respectivo Sport Pack.

### SportContext

`SportContext` e o contexto resolvido para criar, ler ou apresentar uma sessao de treino. Ele combina:

- `sportId`: identificador do esporte principal, como `bjj`, `running` ou `strength`.
- `disciplineId`: recorte opcional dentro do esporte, como `gi`, `noGi`, `trail`, `road`, `hypertrophy` ou `conditioning`.
- `workspaceContext`: Personal ou Academy resolvido separadamente; quando for
  Academy, contem a `academyId` e a membership ativa.
- `actorUid`: usuario logado que executa a acao.
- `targetUid`: usuario visualizado/editado pela acao.
- capabilities ativas: quais campos, taxonomias, evidencias e visualizacoes podem aparecer.

O `SportContext` nunca substitui workspace nem actor/target. Atleta comum
continua criando e vendo dados proprios. Professor/admin continua operando
apenas o aluno alvo autorizado dentro da academia ativa. Modalidade, local
fisico e vinculo institucional sao eixos independentes.

### SportPack

SportPack e o pacote de produto/taxonomia/capacidades de uma modalidade. Ele define quais campos especificos existem, quais taxonomias sao confiaveis, quais evidencias podem ser extraidas e como a UI futura deve adaptar o formulario.

Um SportPack deve declarar:

- `sportId` e disciplinas suportadas.
- campos de entrada especificos.
- taxonomias e categorias confiaveis.
- mapeamento de evidencias para Progress, Game Map, Skill Matrix ou outros motores.
- regras de leitura de legado.
- limites claros para nao inferir dominio sem evidencia.

## BJJ como default

BJJ permanece o default operacional e de produto. Enquanto nao houver `sportId` explicito, uma sessao legada deve ser interpretada como `sportId: bjj` e `disciplineId` ausente ou resolvido pelo contexto futuro da academia.

Essa regra e apenas uma proposta de compatibilidade futura. Nao autoriza gravar `sportId` agora, nao muda schema agora e nao cria dropdown agora.

O app tambem nao vira multi-esporte publico nesta etapa. A profundidade de BJJ continua prioridade: tecnica, posicao, contexto de aplicacao, resultado tecnico, Game Map, Skill Matrix, graduacao e evidencias de aula coletiva continuam ancorados no BJJ Pack.

## Envelope conceitual de TrainingSession

Campos core futuros propostos:

- `id`: identificador da sessao.
- `academyId`: academia dona do dado quando houver Academy Workspace.
- `actorUid`: usuario que registrou ou alterou a sessao.
- `targetUid`: atleta para quem a sessao vale.
- `sportId`: esporte principal; default conceitual futuro `bjj`.
- `disciplineId`: disciplina/submodalidade opcional.
- `occurredAt`: data/hora efetiva ou planejada da sessao, compatibilizada com `date`, `plannedFor` e `effectiveDate`.
- `duration`: duracao normalizada.
- `intensity`: intensidade normalizada quando fizer sentido para o SportPack.
- `notes`: observacao geral.
- `source`: origem, como manual, quickLog, planned, attendance, classSession ou importacao futura.
- `sportPayload`: dados especificos da modalidade.
- `evidenceRefs`: referencias futuras para evidencias derivadas, sem embutir todo o motor de evidencias na sessao.

## Separacao de campos

### Campos core

- Identidade: `id`.
- Escopo: `academyId`, `actorUid`, `targetUid`.
- Contexto esportivo: `sportId`, `disciplineId`.
- Tempo: `occurredAt`, status/lifecycle compativel com `planned`, `completed`, `missed` e `canceled`.
- Carga basica: `duration`, `intensity`.
- Narrativa: `notes`.
- Origem: `source`.
- Extensao controlada: `sportPayload`.
- Evidencias: `evidenceRefs`.

### Campos especificos de BJJ

Campos atuais ou equivalentes conceituais que pertencem ao BJJ Pack:

- `place`: academia, casa ou outro.
- `position`: posicao trabalhada.
- `technique`: tecnica principal legada.
- `techniques`: lista estruturada de tecnicas.
- `category`: categoria tecnica.
- `side`: lado da tecnica.
- `applicationContext`: drill, posicional, rola, competicao ou nao aplicada.
- `techniqueOutcome`: funcionou, quase, falhou, defendida ou nao testada.
- `successes`: pontos positivos percebidos.
- `difficulties`: dificuldades percebidas.
- `debriefNotes`: debrief tecnico/pessoal.
- `scores`: pontuacoes legadas por aluno quando aplicavel.
- `classType`, `instructorUid`, `instructorName`: metadados de aula.
- `attendanceSessionId`, `attendanceCheckInUid`: vinculos de presenca/aula quando existirem.

### Campos futuros para corrida

Campos candidatos para um Running Pack, ainda sem schema:

- distancia.
- pace medio.
- tempo em movimento.
- ganho de elevacao.
- rota ou tipo de terreno.
- frequencia cardiaca media/maxima.
- zona de treino.
- perceived effort.
- splits.
- fonte do dispositivo/importacao.

### Campos futuros para forca e condicionamento

Campos candidatos para Strength/Conditioning Pack, ainda sem schema:

- blocos de treino.
- exercicios.
- series, repeticoes e carga.
- volume total.
- RPE/RIR.
- intervalo.
- tipo de estimulo.
- circuito, AMRAP, EMOM ou treino livre.
- PRs ou marcas.
- foco corporal/motor.

## Exemplos conceituais

### BJJ

```json
{
  "id": "session_123",
  "academyId": "academy_abc",
  "actorUid": "coach_1",
  "targetUid": "athlete_9",
  "sportId": "bjj",
  "disciplineId": "gi",
  "occurredAt": "2026-09-13T19:00:00-03:00",
  "duration": 90,
  "intensity": 4,
  "notes": "Treino com foco em passagem.",
  "source": "manual",
  "sportPayload": {
    "place": "academy",
    "techniques": [
      {
        "position": "closedGuard",
        "technique": "standingGuardPass",
        "category": "passing",
        "side": "both",
        "applicationContext": "positionalSparring",
        "techniqueOutcome": "almost"
      }
    ],
    "successes": "Boa postura antes da abertura.",
    "difficulties": "Perdeu controle do quadril."
  },
  "evidenceRefs": []
}
```

### Corrida

```json
{
  "id": "session_456",
  "academyId": "academy_abc",
  "actorUid": "athlete_9",
  "targetUid": "athlete_9",
  "sportId": "running",
  "disciplineId": "road",
  "occurredAt": "2026-09-13T06:30:00-03:00",
  "duration": 42,
  "intensity": 3,
  "notes": "Rodagem leve.",
  "source": "manual",
  "sportPayload": {
    "distanceKm": 7.2,
    "averagePaceSecondsPerKm": 350,
    "elevationGainMeters": 35,
    "surface": "asphalt",
    "trainingZone": "z2",
    "perceivedEffort": 3
  },
  "evidenceRefs": []
}
```

## UI futura de registrar treino

A tela futura poderia resolver o `SportContext` antes de montar o formulario:

1. Se nao houver SportCapabilities ativas, manter exatamente a experiencia atual BJJ-first.
2. Se houver apenas BJJ Pack ativo, nao exibir seletor publico de modalidade.
3. Se houver mais de um SportPack habilitado para o usuario/contexto, exibir seletor de modalidade antes ou no topo do formulario.
4. Ao escolher a modalidade, renderizar somente os campos declarados pelo SportPack.
5. O BJJ continua selecionado por padrao para usuarios e academias atuais.
6. Trocar modalidade nao deve apagar silenciosamente dados preenchidos; a UI deve confirmar ou preservar rascunho por contexto.

Esta spec nao autoriza implementar o seletor agora.

## Impacto no Evidence Engine

TrainingSession vira uma fonte de evidencias, nao o proprio motor de evidencias. O Evidence Engine futuro deve ler o envelope core, identificar `sportId`/`disciplineId`, consultar o SportPack e emitir evidencias tipadas.

Para BJJ:

- tecnicas, posicoes, contexto de aplicacao e resultado tecnico continuam alimentando Game Map, Skill Matrix e Radar Tecnico apenas quando a taxonomia for confiavel.
- sessoes `completed` continuam sendo a base de evidencias realizadas.
- sessoes `planned`, `missed` e `canceled` nao podem contar como desempenho tecnico realizado.
- aula coletiva derivada deve preservar referencias explicitas de aula/presenca.

Para outras modalidades:

- evidencias devem nascer isoladas por `sportId`.
- nenhum dado de corrida ou forca deve contaminar Game Map/Skill Matrix de BJJ.
- agregacoes cross-sport so devem aparecer depois de contrato especifico.

## Riscos

- Schema prematuro: gravar campos antes de validar os SportPacks pode criar legado ruim.
- Payload generico demais: `sportPayload` sem capacidades vira saco de campos sem semantica.
- Multi-esporte superficial: adicionar dropdown sem profundidade por modalidade dilui o produto.
- Quebra de Game Map/Skill Matrix: misturar evidencias de outros esportes pode corromper leitura tecnica de BJJ.
- Perda de profundidade do BJJ: tratar BJJ como apenas mais uma categoria pode enfraquecer taxonomia, graduacao e coaching.
- Actor/target incorreto: qualquer adaptacao futura precisa manter actor como usuario logado e target como atleta visualizado/editado.
- Academy context fraco: `academyId` nao pode voltar a fallback silencioso.

## Ordem segura

1. Documentacao desta proposta.
2. Inventario dos campos BJJ atuais.
3. Definicao de `SportCapabilities`.
4. Definicao do BJJ Pack.
5. Definicao de `sportId` default conceitual para leitura compativel.
6. Adapter compativel entre legado e envelope core.
7. UI com seletor de modalidade apenas quando houver mais de um SportPack habilitado.
8. POC de outra modalidade, preferencialmente privada/experimental.

## Proxima task recomendada

`SPORT-TRAINING-BJJ-FIELD-INVENTORY-001` - inventariar os campos atuais de `TrainingSession`, `AddTrainingSessionScreen`, `QuickLogSheet`, `TrainingRepository`, Game Map e Skill Matrix, separando:

- campos core ja existentes.
- campos tecnicos BJJ.
- campos de lifecycle.
- campos de aula/presenca.
- consumidores atuais de cada campo.
- riscos de compatibilidade para um adapter futuro.

Essa task tambem deve ser documental e nao deve alterar codigo, schema, UI, repositories ou rules.

## Criterios de aceite

- A proposta preserva BJJ-first.
- Nenhuma implementacao imediata e prescrita.
- `sportPayload` e tratado como extensao controlada por SportPack, nao como campo livre sem contrato.
- Actor/target e academy context permanecem explicitos.
- Game Map, Skill Matrix e Evidence Engine nao recebem dados de outras modalidades sem contrato futuro.
