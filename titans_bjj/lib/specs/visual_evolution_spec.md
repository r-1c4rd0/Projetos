# Visual Evolution Spec

## Objetivo do modulo
Definir regras de governanca para evolucao visual incremental do Titans BJJ sem criar metricas falsas, quebrar actor/target ou alterar contratos de dados fora do escopo aprovado.

## Protocolo economico
- Nao rodar `flutter run` em modo economico.
- Nao rodar `graphify update` sem autorizacao explicita.
- Usar `graphify query` ou `graphify explain` apenas se `graphify-out/graph.json` ja existir e houver duvida real.
- Nao usar scripts grandes.
- Nao usar regex gigante para substituir blocos.
- Preferir edicao manual, pequena e cirurgica.
- Nao colar codigo completo no relatorio.

## Protocolo de validacao
- Rodar `git diff --check`.
- Rodar `dart format` somente nos arquivos alterados.
- Rodar `dart analyze --no-fatal-warnings` somente nos arquivos alterados.
- Entregar relatorio curto com arquivos alterados, validacao usada e riscos restantes.
- Se a fase proibir format/analyze, respeitar a fase e registrar a limitacao.

## Regras actor/target
- `actor` e o usuario logado.
- `target` e o usuario visualizado.
- Atleta comum usa dados proprios.
- Professor/admin vendo aluno usa dados do aluno.
- Professor/admin em Meu Perfil usa dados proprios.
- Nunca reaproveitar `selectedStudent` em `TargetMode.self`.

## Regras para widgets visuais
- Widget visual nao acessa Firebase.
- Widget visual nao acessa repository.
- Widget visual nao usa `UserScope` ou `TargetResolver`.
- Screen resolve dados, permissao e alvo.
- ViewModel entrega dados renderizaveis.
- Widget apenas desenha.

## Regras para graficos
- Nao criar metrica falsa.
- Nao usar performance, proficiencia, score ou dominio sem contrato explicito.
- Nao usar duracao, volume ou intensidade se o dado nao for confiavel para a leitura proposta.
- Tooltip deve mostrar dado real.
- Empty state deve ser seguro e honesto.
- Projetar mobile first.
- Validar por inspecao em 360, 390, 412 e 480 px em modo economico.
- Nao adicionar dependencia nova sem justificativa e aceite explicito.

## Roadmap visual atual
- V1 Collapsing Athlete Console: concluido.
- V2 Progress Area Chart: concluido.
- V3 Consistency Heatmap: concluido.
- V4 Skill Matrix Visual Summary: concluido.
- V5 Training Chart 2.0: concluido.
- V6 Game Map Visual Incremental: proximo.
- V7 Radar R/T/C/A somente com metrica validada.
- V8 Microinteractions & Polish.
- V9 Runtime QA / Performance.

## Responsabilidades
- Proteger a integridade de dados reais em componentes visuais.
- Manter as fases visuais pequenas, reversiveis e validaveis.
- Evitar acoplamento entre widgets visuais e fontes de dados.
- Padronizar a entrega economica das fases.

## Dados usados
- Dados ja carregados pela screen.
- ViewModels privados/locais quando a fase nao aprovar migracao estrutural.
- Contratos existentes de model, repository e service.

## Telas envolvidas
- `athlete_console_screen.dart`
- `progress_screen.dart`
- `game_map_screen.dart`
- `training_screen.dart`
- `athlete_dashboard_screen.dart`

## Repositories envolvidas
- Nenhuma repository deve ser acessada diretamente por widget visual.
- Screens continuam usando repositories ja existentes quando isso for o padrao atual.

## Riscos de regressao
- Misturar actor e target.
- Criar score visual sem contrato.
- Duplicar informacao entre telas.
- Poluir mobile 360 px.
- Introduzir dependencia sem necessidade.
- Quebrar comportamento legado durante evolucao visual.

## Criterios de aceite
- Fase visual altera somente arquivos permitidos.
- Dados exibidos sao reais ou explicitamente marcados como vazios/pendentes.
- Validacao economica passa quando permitida.
- Relatorio informa riscos restantes sem colar codigo completo.
