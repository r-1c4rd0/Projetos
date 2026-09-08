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

## TITANS-UX-COMPACT-RESPONSIVE-001
- Escopo: ajustes compactos e responsivos em Painel do Mestre, registro de treino, seletores de debrief, eventos, nutricao e splash.
- Painel do Mestre: card de atencao inicia recolhido, preserva contador, preview e acesso aos alunos, e evita repetir a lista quando o filtro Atencao ja esta aplicado.
- Treino: acoes primarias mantem registro rapido e treino completo como caminhos separados.
- Debrief: seletores longos usam lista rolavel limitada, rodape persistente e dialog central em telas largas.
- Eventos: agenda semanal passa a filtrar a lista por dia selecionado, com calendario mensal expansivel e sem destaque duplicado do proximo evento.
- Nutricao: lista de alimentos carregada progressivamente no cliente e card de status deixa de duplicar as acoes de refeicao/perfil.
- Splash: usa logo leve e animacao curta, sem adicionar espera de rede, bootstrap ou dependencia nova.
- Limites: nao altera repositories, schema, firestore.rules, membership, billing, graduacao, radar, calculos ou dados persistidos.
- Validacao esperada: formatacao Dart, analise estatica direcionada, testes direcionados disponiveis e `git diff --check` nos arquivos alterados.

## TITANS-EVENTS-UX-FINISH-001
- Escopo: acabamento incremental da experiencia de Eventos sem alterar repositories, schema, rules, Auth, membership, Home, radar ou graduacao.
- Entrada: tela inicia em proximos eventos agendados, mantendo Hoje destacado na semana sem aplicar filtro de dia automaticamente.
- Navegacao: semana compacta preserva sete dias, controles anterior/proxima/Hoje e sincroniza dia, semana, mes e lista.
- Calendario mensal: permanece recolhido por padrao, abre por acao explicita, usa grade de sete colunas e navegacao entre meses.
- Lista: eventos sao agrupados por data, proximos seguem ordem cronologica, historico segue ordem do mais recente para o mais antigo, e listas longas sao reveladas progressivamente no cliente.
- Estados vazios: diferenciam dia sem eventos, ausencia de proximos eventos, historico vazio e erro de carregamento.
- Limites: nao altera dados persistidos, autorizacao, permissao de criacao, paginacao de servidor ou fluxos de detalhe existentes.
- Validacao esperada: formatacao Dart, analise estatica direcionada, testes direcionados quando disponiveis e `git diff --check` nos arquivos alterados.

## TITANS-HEADERS-ACTIONS-CONSISTENCY-001
- Escopo: padronizacao pontual de cabecalhos em Inicio, Treinos, Progresso e Nutricao sem alterar rotas, permissions, repositories, schema, rules, calculos ou graduacao.
- Cabecalhos: telas principais reutilizam o `AppLogoLeading` oficial quando nao ha rota de retorno; telas empilhadas preservam o botao Voltar nativo.
- Titulos: cada tela principal mantem um titulo no AppBar; subtitulos internos continuam quando trazem contexto diferente do titulo.
- Nutricao: o titulo interno duplicado fica oculto fora de embedded; Adicionar refeicao permanece como FAB no mobile e como acao textual da secao no desktop/embedded.
- Acoes preservadas: Registro rapido e Treino completo continuam como fluxos separados; filtros de Progresso e demais controles seguem acessiveis.
- Validacao esperada: formatacao Dart, analise estatica direcionada, `git diff --check` e revisao visual/responsiva quando houver ambiente local disponivel.

## TITANS-SPLASH-DESIGN-CONTINUITY-001
- Escopo: integrar a splash ao design system existente sem alterar AuthGate, bootstrap, Firebase, Home, repositories, schema, rules, membership, billing, radar ou graduacao.
- Asset: usa `assets/logo_icon.png`, inspecionado como imagem quase quadrada com a marca completa; assets `tela_inicial*` sao composicoes verticais completas e nao foram usados como logo.
- Visual: fundo segue tokens do tema Titans, com textura discreta de pontos e iluminacao dourada suave atras da logo, sem card, moldura ou lettering recriado.
- Movimento: entrada curta por opacidade e escala discreta; reducao de movimento usa apresentacao estatica e fade simples; nao ha duracao minima obrigatoria adicional.
- Integracao: o child/AuthGate continua montado por baixo da splash; a saida remove apenas a camada visual e nao navega, consulta ou inicializa servicos.
- Pendencia nativa: Android `android/app/src/main/res/drawable/launch_background.xml` e iOS `ios/Runner/Base.lproj/LaunchScreen.storyboard` ainda usam fundo branco; ajuste nativo deve ser task separada apos QA por plataforma.
- Validacao esperada: formatacao Dart, analise estatica direcionada, `git diff --check` e QA runtime/gravacao quando ambiente visual estiver disponivel.
