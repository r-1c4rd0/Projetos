# Training Spec

## Objetivo do modulo
Definir o modulo de treinos como registro, consulta e agregacao de sessoes de treino por atleta, academia e modalidade.

## Responsabilidades
- Criar, listar e agregar sessoes de treino.
- Diferenciar treinos cadastrados por atleta, professor ou sistema.
- Alimentar progresso, status e criterios de graduacao.
- Preservar recorrencia e batch quando aplicavel.

## Dados usados
- `TrainingSession`
- Modelos em `training_models.dart`
- Aluno/usuario alvo.
- Academia ativa.
- Modalidade, data, duracao, intensidade, observacoes e origem.

## Telas envolvidas
- `training_screen.dart`
- `add_training_session_screen.dart`
- `athlete_dashboard_screen.dart`
- `master_panel_screen.dart`

## Repositories envolvidas
- `TrainingRepository`
- `StudentsRepository`
- Futuro `AttendanceRepository` para presenca ligada a treino.

## Regras de negocio
- Athlete so cria/ve treinos proprios, salvo regras de compartilhamento.
- Professor cria/consulta treinos dos alunos da academia.
- Treino deve pertencer a academia e modalidade.
- Agregados nao devem ser calculados de forma duplicada em varias telas.

- O painel atual de evidencias R/T/C/A no Game Map representa dados operacionais de treino, nao o futuro Radar Tecnico.
- O futuro Radar Tecnico Retencao/Transicao/Controle/Ataque nao deve usar Recorrencia/Tecnicas/Consistencia/Aplicacao como eixos semanticos.
- Nenhum score, peso, percentual ou formula final deve ser criado sem taxonomia validada e evidencia minima por eixo.

## Radar Tecnico - contrato semantico futuro

O Radar Tecnico deve ser tratado como um perfil tecnico em formacao ate que as tecnicas tenham classificacao confiavel por eixo.

Eixos:
- `retention`: capacidade de manter posicao, vantagem ou conexao tecnica.
- `transition`: capacidade de mover entre posicoes ou fases do jogo.
- `control`: capacidade de estabilizar, dominar e reduzir respostas do oponente.
- `attack`: capacidade de ameacar, pontuar, raspar, passar ou finalizar.
- `unclassified`: tecnica ou categoria sem classificacao segura.

Mapeamento inicial seguro por categoria:
- `submissions` -> `attack`.
- `escapes` -> `transition`.

Categorias que exigem revisao antes de pontuar:
- `guard`
- `passing`
- `takedowns`
- `mount`
- `back`
- `defense`
- `other`

Enquanto a revisao nao existir, a UI futura deve exibir Radar Preview com a copy "Perfil tecnico em formacao" e evidencias reais, sem score.

## Problemas atuais
- Agregacao de treino pode estar em service separado e telas.
- Streams em build podem afetar performance.
- `academyId` default impacta queries de treino.
- Presenca futura precisa se integrar sem duplicar sessao.

## Arquitetura desejada
Feature futura:

```text
features/training/
  data/
    repositories/training_repository.dart
    services/training_firestore_service.dart
  domain/
    entities/training_session.dart
    entities/training_summary.dart
    use_cases/create_training_session.dart
    use_cases/watch_training_summary.dart
  presentation/
    screens/training_screen.dart
    screens/add_training_session_screen.dart
    view_models/training_view_model.dart
```

## Plano de migracao incremental
1. Documentar queries atuais.
2. Centralizar agregacoes no repository/use case.
3. Garantir filtro explicito por academia e aluno.
4. Migrar telas para view model.
5. Integrar presenca como origem possivel.
6. Adicionar modalidade ao contrato.

## Riscos de regressao
- Perda de sessoes antigas.
- Totais divergirem dos totais atuais.
- Professor criar treino para aluno errado.
- Recorrencia gerar duplicatas.

## Criterios de aceite
- Regras por role e academia estao documentadas.
- Agregacao tem destino futuro claro.
- Integracao com presenca e progresso esta prevista.
- Nenhum treino foi alterado nesta etapa.
