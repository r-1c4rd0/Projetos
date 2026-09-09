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
## TITANS-TRAINING-LIFECYCLE-AND-CLASS-SESSION-001

### Ciclo de vida individual implementado

Estados minimos de `TrainingSession`:
- `planned`: treino planejado, nÃ£o conta como realizado.
- `completed`: treino realizado, elegÃ­vel para frequÃªncia, progresso, evidÃªncias tÃ©cnicas e Ãºltimo treino realizado.
- `missed`: treino nÃ£o realizado, mantido no histÃ³rico sem contar como realizado.
- `canceled`: treino cancelado, mantido no histÃ³rico sem contar como realizado.

Compatibilidade legado:
- Registro sem `status` e com data atÃ© hoje Ã© tratado como `completed` em leitura.
- Registro sem `status` e com data futura Ã© tratado como `planned` em leitura.
- NÃ£o hÃ¡ reclassificaÃ§Ã£o em massa nesta fase.

Regras implementadas nesta fatia:
- Cadastro rÃ¡pido cria treino `completed` na data atual.
- Cadastro completo em data futura cria treino `planned`.
- Cadastro completo retroativo cria treino `completed`.
- RecorrÃªncia cria ocorrÃªncias independentes `planned`, cada uma com id prÃ³prio e `plannedFor`.
- Indicadores e evidÃªncias usam somente sessÃµes `completed`.
- Planejados vencidos aparecem como aguardando confirmaÃ§Ã£o por derivaÃ§Ã£o de data, sem escrita automÃ¡tica por relÃ³gio.
- Confirmar uma ocorrÃªncia planejada marca apenas aquela sessÃ£o como `completed` e registra `confirmedAt` pelo servidor.
- O formulario completo exige intencao explicita: `completed` para "Ja treinei" ou `planned` para "Planejar treino".
- Entrada de registro inicia em "Ja treinei"; entrada de agendamento inicia em "Planejar treino".
- "Ja treinei" aceita somente hoje ou passado por comparacao de dia local; data futura deve bloquear salvamento e oferecer troca para planejamento sem apagar o preenchimento.
- "Planejar treino" preserva hoje/futuro como `planned`; no dia planejado, a ocorrencia fica elegivel para confirmacao manual.
- Recorrencia representa repeticao planejada, nao comprovacao de realizacao.
- Em "Ja treinei" com recorrencia, somente a data escolhida e criada como `completed`; repeticoes futuras viram `planned` e a ocorrencia inicial nao pode ser duplicada.
- Em "Planejar treino" com recorrencia, todas as ocorrencias geradas permanecem `planned`.
- Antes de salvar recorrencia, a UI deve mostrar resumo curto calculado pelas datas reais, como "1 treino realizado + 4 agendados".
- A tela Treinos deve mostrar pendencias elegiveis no proprio card com "Voce fez este treino?", acao principal "Ja treinei" e acoes secundarias "Reagendar" e "Nao fiz".
- Confirmacao em um toque atualiza o mesmo documento, preserva o identificador, nao exige tecnica/intensidade/observacao e oferece "Complementar treino" apos sucesso.
- Confirmacao pessoal de treino planejado nao concede presenca oficial em aula coletiva.

### Contrato para aula coletiva do professor - proxima task

Conceitos:
- Aula programada: ocorrÃªncia coletiva da academia, criada por professor/admin autorizado no contexto da academia.
- PresenÃ§a: vÃ­nculo oficial entre aluno e aula programada.
- `TrainingSession`: registro individual derivado da participaÃ§Ã£o confirmada.
- TÃ©cnicas planejadas e tÃ©cnicas efetivamente trabalhadas devem vir do Sport Pack/taxonomia aplicÃ¡vel.
- Resultado pessoal do aluno e avaliaÃ§Ã£o oficial do professor sÃ£o evidÃªncias distintas.

Regras para implementar depois:
- Check-in solicitado pelo aluno nÃ£o confirma presenÃ§a oficial.
- PresenÃ§a oficial exige autoridade vÃ¡lida no Academy Workspace e membership ativa verificada no servidor.
- Aula futura, mesmo com check-in pendente, nÃ£o gera treino realizado.
- Aula concluÃ­da com presenÃ§a confirmada pode gerar uma Ãºnica `TrainingSession` derivada por aluno e ocorrÃªncia.
- A sessÃ£o derivada deve referenciar explicitamente `classSessionId`, `attendanceRecordId`, `academyId`, `uid`, origem e taxonomia usada.
- A geraÃ§Ã£o deve ser idempotente por `(academyId, classSessionId, uid)` e tolerar repetiÃ§Ã£o, concorrÃªncia e falha parcial.
- Professor nÃ£o grava no Personal Workspace privado do aluno.
- Aluno pode complementar o prÃ³prio debrief sem alterar presenÃ§a oficial ou dados coletivos da aula.
- CorreÃ§Ãµes de presenÃ§a, cancelamento de aula ou remoÃ§Ã£o de aluno precisam de reconciliaÃ§Ã£o auditÃ¡vel, preservando complementos pessoais.
- NÃ£o fundir treino manual e aula derivada somente por coincidÃªncia de data; qualquer associaÃ§Ã£o deve ser explÃ­cita.

Proxima task concreta:
1. Criar modelo/repositorio de `ClassSession` e `AttendanceRecord` sob `academies/{academyId}`.
2. Definir ids determinÃ­sticos para sessÃ£o derivada: `class_<classSessionId>_<uid>` ou equivalente doc-safe.
3. Implementar use case servidor/repository para concluir aula e materializar sessÃµes individuais idempotentes.
4. Adicionar testes de membership, idempotÃªncia, falha parcial, cancelamento e complemento pessoal.
5. Ajustar rules localmente sem deploy apenas se a escrita nova exigir permissÃ£o inexistente.
