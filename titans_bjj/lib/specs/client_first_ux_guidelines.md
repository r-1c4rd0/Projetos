# Client-First UX Guidelines

## Objetivo
Garantir que as próximas telas do Titans BJJ priorizem significado para o aluno, leitura acionável para professor/mestre e detalhes técnicos apenas sob demanda, evitando aparência de relatório técnico cru.

## Princípio Central
O aluno deve entender rapidamente:
- onde está
- o que evoluiu
- o que focar agora
- qual ação tomar

O app pode usar evidências internamente, mas não deve colocar linguagem de motor interno como protagonista da tela.

## Camadas De Informação

### Camada 1 — Cliente/Aluno
- foco recomendado
- progresso
- consistência
- frequência
- próximo passo
- leitura simples do jogo

### Camada 2 — Técnico Resumido
- eixo mais presente
- posições mais recorrentes
- técnicas registradas
- recorrência recente
- observações do professor

### Camada 3 — Motor Interno/Sob Demanda
- evidências classificadas
- aguardando classificação
- distribuição bruta
- rastreabilidade
- detalhes técnicos extensos

## Regras Por Tela

### Home
- cockpit
- foco recomendado e ação rápida primeiro
- radar/progresso como apoio

### Treinos
- frequência e hábito primeiro
- gráfico como hero
- histórico como apoio

### Progresso
- faixa/grau e consistência primeiro
- regras e métricas complementares sob demanda

### Game Map
- radar e leitura do jogo primeiro
- evidências técnicas detalhadas sob demanda
- evitar linguagem interna como protagonista

### Skills
- biblioteca técnica clara
- técnicas, posições e recorrência
- sem painel de banco de dados

### Nutrição
- leitura educativa
- sem prescrição agressiva
- sem foco em corpo/peso
- dados como apoio

### Eventos
- próximos compromissos primeiro
- detalhes sob demanda

### Professor/Mestre
- leitura acionável
- alunos que precisam atenção
- sem ranking ou comparação indevida

## Linguagem

### Usar
- foco do treino
- próximo passo
- evolução
- consistência
- recorrência
- leitura técnica
- observação do professor
- revisar em treino
- precisa ajuste
- funcionou

### Evitar Como Protagonista
- evidências classificadas
- aguardando classificação
- distribuição bruta
- matriz interna
- status técnico interno

### Proibido
- score
- ranking
- performance
- proficiência
- domínio
- cobertura
- nota geral do aluno
- comparação entre alunos

## Padrão Visual
Cada tela deve seguir:
- header mínimo
- hero principal
- metric rail compacta
- controle direto/animado
- painel visual principal
- detalhe sob demanda
- seções secundárias colapsadas

## Casos De Borda
- Se uma informação técnica for necessária por transparência, colocar sob demanda ou em detalhe colapsado.
- Se o dado não existir, usar empty state honesto.
- Se uma métrica não tiver definição clara, não exibir como hero.
- Professor pode ver mais leitura técnica que aluno, mas sem ranking/comparação indevida.
- Nutrição deve continuar educativa e não prescritiva.

## Critérios De Aceite Para Futuras Tasks
- Documento cobre princípio central, camadas, regras por tela, linguagem e critérios futuros.
- Nenhum arquivo Dart alterado.
- Nenhum schema/repository/rule alterado.
- Nenhuma feature criada.
- Nenhum score/ranking/performance/proficiência/cobertura introduzido.