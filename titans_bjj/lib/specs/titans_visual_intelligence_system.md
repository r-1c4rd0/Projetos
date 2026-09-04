# Titans Visual Intelligence System

## 1. Principio central

Dados tecnicos devem virar leitura visual clara, viva e client-first.

O TITANS BJJ nao deve parecer um dashboard generico. A interface deve parecer um sistema de evolucao tecnica de Jiu-Jitsu: dados reais, leitura rapida, energia visual controlada e detalhes tecnicos disponiveis sob demanda.

Toda visualizacao precisa preservar a fonte real de dados. UI nao inventa score, ranking, comparacao entre atletas ou metrica falsa para parecer mais completa.

## 2. Assinatura visual TITANS

1. Escuro premium: fundos profundos, contraste forte e superficies discretas.
2. Energia tecnica: acentos dourados, azuis tecnicos e sinais visuais de movimento com baixa opacidade.
3. Glow controlado: brilho como orientacao visual, nunca como ruido ou neon dominante.
4. Movimento com proposito: animacao comunica entrada, leitura, foco ou progresso.
5. Graficos autorais: dados de treino devem virar linguagem propria, nao widgets genericos.
6. Hierarquia emocional: primeiro responder onde estou, como evoluo e qual proximo foco.
7. Detalhes sob demanda: tecnicalidade fica acessivel, mas nao domina a primeira leitura.
8. Performance segura: visual premium precisa funcionar em Android intermediario.

Visual forte nao pode prejudicar leitura, acessibilidade, navegacao ou estabilidade.

## 3. Padrao de tela principal

Quando fizer sentido, cada tela principal deve seguir esta ordem:

1. Hero de contexto.
2. Insight principal.
3. Visualizacao autoral.
4. Acao clara.
5. Detalhes sob demanda.

Exemplos de aplicacao:

| Tela | Intencao visual |
|---|---|
| Home | Cockpit do atleta |
| Training | Energia de treino |
| Progress | Evolucao e graduacao |
| Game Map | Leitura do jogo |
| Skills | Biblioteca tecnica viva |
| Nutrition | Rotina acompanhada |
| Events | Agenda de evolucao |
| Master | Cockpit de alunos |

## 4. Familia de graficos autorais

### Particle Flow Line

Uso correto: evolucao temporal, regularidade e tendencias de treino.

Camadas visuais: grid sutil, linha principal suave, trilha discreta, pontos como nos/particulas, destaque no ponto atual ou selecionado.

Comportamento: entrada progressiva curta; toque mostra detalhe; reduced motion renderiza direto.

Performance: preferir painter ou configuracao leve; usar `RepaintBoundary` quando animado; nao recalcular series no paint.

Nao fazer: neon exagerado, particulas demais, esconder valores, animacao continua chamativa.

### Energy Impact Bars

Uso correto: volume, distribuicao por periodo, contagem por categoria ou impacto de treino.

Camadas visuais: base discreta, preenchimento com gradiente controlado, brilho baixo no topo, labels legiveis.

Comportamento: entrada curta por barra; toque ou selecao deve revelar detalhe quando houver dado real.

Reduced motion: barras aparecem completas sem sequencia animada.

Nao fazer: barras competindo com todos os cards, escala falsa, comparacao entre atletas.

### Core Energy Orb

Uso correto: consolidar energia/volume/estado de uma area quando ha um unico indicador principal real.

Camadas visuais: nucleo circular, anel de progresso, glow leve, texto central claro.

Comportamento: pulse discreto apenas quando agrega leitura; reduced motion mostra estado final.

Nao fazer: transformar em score, ranking ou indicador sem fonte canonica.

### Holographic Combat Radar

Uso correto: mapa tecnico vivo por eixos reais, como Retencao, Transicao, Controle e Ataque.

Camadas visuais: base escura, aneis holograficos, eixos tecnicos, poligono de dados reais, nos energeticos, sweep circular, glow externo, particulas discretas e pulso sincronizado.

Comportamento: toque no eixo preserva detalhe; perspectiva/camera pode existir apenas em modo opt-in; Home deve manter modo compacto.

Reduced motion: sem sweep animado, sem tilt continuo e sem pulse permanente.

Nao fazer: 3D real pesado, engine externa, mudar valores, mudar labels, mudar ordem dos eixos, criar score.

## 5. Movimento com proposito

Permitido:

- fade-in;
- scale sutil;
- sweep lento;
- pulse controlado;
- entrada progressiva;
- glow com baixa opacidade;
- animacao curta e direcionada;
- 2.5D leve com `Matrix4`.

Proibido:

- animacao infinita pesada;
- piscar;
- neon exagerado;
- hover como dependencia;
- `Tooltip` widget em area animada;
- `MouseRegion`;
- `setState` em hover;
- random dentro de `paint`;
- efeito que esconda dados.

## 6. Regras de performance

1. Usar `RepaintBoundary` em painter animado.
2. Evitar multiplos `AnimationController` na mesma tela.
3. Nao animar scaffold inteiro.
4. Nao animar listas grandes.
5. Respeitar `MediaQuery.disableAnimationsOf(context)`.
6. Nao recalcular dados pesados dentro do `paint`.
7. Usar `shouldRepaint` corretamente.
8. Manter fallback estatico.
9. Testar Android intermediario.
10. Validar mobile 360, 390 e 412 px.

## 7. Regras de acessibilidade

- Usar `Semantics` quando o visual representa dado acionavel ou informativo.
- Nao depender apenas de cor para comunicar estado.
- Manter texto legivel em tema claro e escuro.
- Respeitar reduced motion.
- Evitar microcopy tecnica demais para atleta.
- Deixar detalhes tecnicos sob demanda.
- Preferir icones Material reais, sem emoji ou glyph customizado nao registrado.

## 8. Regras de arquitetura

1. Telas nao devem acessar Firestore diretamente quando houver repository/use case apropriado.
2. UI nao altera dominio.
3. Actor/target sempre preservado.
4. Graficos nao criam metricas falsas.
5. Painter recebe dados ja preparados.
6. Componente visual nao muda calculo.
7. Nao instalar pacote para efeito visual sem justificativa forte.
8. Visual nao pode quebrar AuthGate, HomeShell ou navegacao.

## 9. Estado atual por tela

| Tela | Estado visual atual | Padrao aplicado | Lacunas | Prioridade |
|---|---|---|---|---|
| Home | Forte, com cockpit e radar tecnico compacto observado em `athlete_dashboard_screen.dart`. | Cockpit do atleta, QuickLog como CTA, cards tecnicos compactos. | Consolidar widgets comuns e validar excesso de cards em mobile. | P1 |
| Training | Forte, com `Particle Flow Line`, orb/energia e QuickLog. | Energia de treino, graficos autorais e acao clara. | Extrair graficos apenas depois de estabilizar repeticao real. | P1 |
| Progress | Forte, com hero de graduacao, pulso de evolucao e constelacao de consistencia. | Evolucao e graduacao, detalhes sob demanda. | Validar regra visual para kids e fallback quando nao ha regra oficial. | P1 |
| Game Map | Forte, com radar holografico, camera/perspectiva e cluster de leitura do jogo. | Leitura do jogo, radar autoral, CTAs para evidencias, repertorio e avaliacao. | Reduzir warnings orfaos e validar gesto livre em device. | P0 |
| Skills | Moderado/forte, com biblioteca e matriz tecnica viva observadas em `skills_screen.dart`. | Biblioteca tecnica viva e detalhe sob demanda. | Aproximar linguagem dos graficos autorais sem mudar dados. | P2 |
| Nutrition | Moderado, com cards de energia e rotina acompanhada observados em `nutrition_screen.dart`. | Rotina acompanhada, status e registro de refeicoes. | Ainda mais funcional que autoral; precisa hero/insight mais claro. | P2 |
| Events | Nao localizada como `events_screen.dart`; existe `event_screen.dart`. | Agenda funcional. | Auditar tela real antes de aplicar padrao. | P3 |
| Master Panel | Moderado, com `Cockpit da turma` observado em `master_panel_screen.dart`. | Cockpit de alunos. | Pode ganhar leitura agregada mais client-first sem ranking falso. | P2 |

## 10. Componentes candidatos futuros

| Componente | Origem atual | Onde poderia ser usado | Risco de extracao | Prioridade |
|---|---|---|---|---|
| `TitansVisualHero` | Home, Progress, Skills, Nutrition | Telas principais | Alto se carregar regra de dominio junto | P1 |
| `TitansInsightCard` | Home, Game Map, Progress | Insights principais e empty states | Medio por variacoes de copy/CTA | P1 |
| `TitansMetricPulse` | Progress e Training | Metricas vivas de consistencia/volume | Medio por animacao/reduced motion | P2 |
| `TitansEnergyBarChart` | Training e Game Map mini bars | Volume, distribuicao e categorias | Medio se escala for acoplada a dominio | P2 |
| `TitansCoreEnergyOrb` | Training | Indicador circular consolidado | Alto se virar score falso | P2 |
| `TitansParticleLineChart` | Training e Progress | Series temporais | Medio por dependencia de dados de grafico | P1 |
| `TitansTrainingConstellation` | Progress heatmap | Consistencia, presenca e rotina | Medio por responsividade mobile | P2 |
| `TitansHolographicRadar` | `TitansTechnicalRadar` | Game Map e detalhes tecnicos | Alto por performance e interacao | P1 |
| `TitansPerspectiveControl` | Radar holografico | Visualizacoes 2.5D opt-in | Medio por gesto e acessibilidade | P2 |
| `TitansDetailSheet` | Game Map, QuickLog, Nutrition | Detalhes sob demanda | Medio por formularios e scroll | P1 |

## 11. Plano de rollout seguro

### Fase 1 - Estabilizacao

- Limpar warnings orfaos em telas visuais sem apagar funcionalidade ativa.
- Validar `mouse_tracker.dart` apos qualquer mudanca em area animada.
- Validar overflow mobile em 360, 390 e 412 px.
- Validar encoding dos textos visiveis.
- Validar QA visual das telas alteradas.

### Fase 2 - Componentizacao minima

- Extrair apenas padroes realmente repetidos.
- Comecar por componentes sem estado.
- Manter painters recebendo dados prontos.
- Nao mover dominio, repositories ou use cases.

### Fase 3 - Aplicacao por tela

1. Home.
2. Training.
3. Progress.
4. Game Map.
5. Skills.
6. Nutrition.
7. Events.
8. Master Panel.

### Fase 4 - QA app-wide

- Navegacao.
- Performance.
- Reduced motion.
- Acessibilidade.
- Responsividade.
- Tema claro/escuro.

## 12. Checklist para qualquer nova tela/refino

- A tela tem hero claro?
- Tem insight principal?
- Tem acao principal?
- Os dados sao reais?
- A UI nao inventa metrica?
- Tem detalhe sob demanda?
- Reduced motion funciona?
- Sem `Tooltip`/`MouseRegion`?
- Sem hover como dependencia?
- Sem overflow mobile?
- Sem alteracao de actor/target?
- Sem Firestore direto na tela?
- `dart analyze` passa?