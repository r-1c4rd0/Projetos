# Product Spec

## Objetivo do modulo
Definir o produto Titans BJJ como plataforma para gestao de academias, professores e atletas, com foco em treino, progresso, graduacao, nutricao, eventos e acompanhamento pelo mestre.

## Responsabilidades
- Clarificar personas: admin, professor e athlete.
- Definir modulos de produto atuais e futuros.
- Preservar o legado enquanto a arquitetura evolui.
- Priorizar robustez, modularidade e specs antes de refatorar codigo.

## Dados usados
- Usuario: uid, nome, email, role, status, academyId.
- Academia: identidade, configuracoes, professores, modalidades e tema.
- Atleta: dados cadastrais, faixa, grau, objetivos, restricoes e historico.
- Produto: treinos, progresso, nutricao, eventos, presencas e graduacoes.

## Telas envolvidas
- Login, cadastro e gate de autenticacao.
- Cadastro de atleta.
- Console do atleta e dashboard.
- Painel do mestre.
- Treinos, progresso, nutricao, eventos e academia.

## Repositories envolvidas
- `UserRepository`
- `StudentsRepository`
- `AthleteRegistrationRepository`
- `TrainingRepository`
- `UserProgressRepository`
- `NutritionRepository`
- `EventRepository` / `FirebaseEventRepository`
- `GradingRulesRepository`

## Regras de negocio
- Admin gerencia academia, configuracoes, professores e visao global.
- Professor acompanha alunos da academia autorizada e opera presenca, progresso, treinos e graduacao.
- Athlete ve dados proprios e conteudos liberados pela academia.
- Todo dado operacional deve pertencer a uma academia.
- Toda regra sensivel deve ser refletida em Firestore Rules no futuro.

## Problemas atuais
- `academyId` default pode misturar dados.
- Multi-academia ainda nao e um requisito implementado ponta a ponta.
- Status do atleta e graduacao ainda precisam de fonte unica.
- Painel do mestre pode crescer sem limites claros.
- Experiencia visual nao esta consolidada como sistema.

## Arquitetura desejada
- Produto organizado por features independentes.
- Cada feature com domain models, repositories e presentation isolados.
- App shell comum para sessao, tema, roteamento e escopos globais.
- Configuracoes por academia consumidas por modulos sem acoplamento direto.

## Plano de migracao incremental
1. Congelar comportamento atual como baseline.
2. Documentar regras por modulo.
3. Corrigir fundacoes: auth, sessao, academyId.
4. Migrar features de baixo risco antes das features criticas.
5. Adicionar capacidades futuras por feature flag ou rollout controlado.

## Riscos de regressao
- Usuarios existentes perderem acesso por role mal interpretada.
- Dados historicos ficarem invisiveis apos mudanca de schema.
- Telas divergirem do novo contrato visual.
- Professor acessar aluno de outra academia se regras forem incompletas.

## Criterios de aceite
- Personas e modulos estao documentados.
- Problemas conhecidos aparecem como itens explicitos.
- Expansoes futuras estao alinhadas ao roadmap modular.
- Nao ha prescricao de mudanca funcional imediata.
