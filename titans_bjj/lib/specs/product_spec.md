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
- AUTH-REAL-USERS: atletas/professores convidados so devem ganhar acesso real apos aceitar convite e criar/usar conta propria do Firebase Auth vinculada ao cadastro da academia; mestre/professor nao define senha do aluno.
- O convite AUTH-REAL-USERS usa `academies/{academyId}/invites/{inviteId}` com status `pending`, `accepted`, `expired` ou `revoked`.
- O UUID atual do cadastro legado deve ser tratado como `pendingProfileId`; apos aceite, o Firebase Auth UID vira identidade principal em `academies/{academyId}/users/{firebaseUser.uid}`.
- Todo dado operacional deve pertencer a uma academia.
- Toda regra sensivel deve ser refletida em Firestore Rules no futuro.

## Problemas atuais
- `academyId` default pode misturar dados.
- Atletas cadastrados somente como perfil/documento Firestore podem ficar sem acesso real por falta de conta Firebase Auth e vinculo correto `uid`/`academyId`/`role`.
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
3. Corrigir fundacoes: auth, sessao, academyId e AUTH-REAL-USERS como P0 antes de uso real em academia.
4. Migrar features de baixo risco antes das features criticas.
5. Adicionar capacidades futuras por feature flag ou rollout controlado.

## UX minima AUTH-REAL-USERS

O Painel do Mestre deve exibir o estado de acesso de cada atleta/professor:
- Ativo
- Convite pendente
- Sem acesso
- Expirado

Acoes futuras:
- Enviar convite
- Reenviar
- Revogar

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
