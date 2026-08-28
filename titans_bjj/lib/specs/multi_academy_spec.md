# Multi Academy Spec

## Objetivo do modulo
Definir a evolucao para suporte real a multi-academia, incluindo memberships, configuracoes por academia, isolamento de dados e selecao de academia ativa.

## Responsabilidades
- Modelar relacao usuario-academia.
- Garantir isolamento de dados por academia.
- Permitir usuarios com multiplas academias e roles distintas.
- Servir como base para design system, rules e analytics por academia.

## Dados usados
- `academies`
- `users`
- `academyMemberships`
- Roles por academia.
- Configuracoes e modalidades por academia.
- Alunos, professores, eventos, treinos e presencas por academia.

## Telas envolvidas
- `academy_screen.dart`
- AuthGate e fluxos de cadastro.
- Painel do Mestre.
- Console do Atleta.
- Todas as telas que leem dados filtrados por academia.

## Repositories envolvidas
- `UserRepository`
- `StudentsRepository`
- `AthleteRegistrationRepository`
- Todos os repositories que dependem de `academyId`.
- Futuro `AcademyRepository` e `MembershipRepository`.

## Regras de negocio
- Nenhuma query operacional deve rodar sem academia ativa.
- Role deve ser avaliada no contexto da academia.
- Usuario pode ser athlete em uma academia e professor/admin em outra.
- Academia ativa deve ser persistida de forma segura e revalidada no login.

## Problemas atuais
- `academyId` default pode esconder ausencia de membership.
- Nao ha contrato unico para academia ativa.
- Configuracoes por academia ainda nao governam todas as features.

## Arquitetura desejada
Feature futura:

```text
features/academy/
  data/
    repositories/academy_repository.dart
    repositories/membership_repository.dart
  domain/
    entities/academy.dart
    entities/academy_membership.dart
    use_cases/resolve_active_academy.dart
  presentation/
    screens/academy_selector_screen.dart
    view_models/academy_scope_view_model.dart
```

## Plano de migracao incremental
1. Inventariar todas as leituras/escritas com `academyId`.
2. Criar contrato de academia ativa.
3. Validar usuarios existentes e preencher memberships.
4. Ajustar repositories para exigir academia ativa.
5. Criar seletor de academia para usuarios multi-academia.
6. Ativar rules por path e membership.

## Riscos de regressao
- Dados antigos sem academia sumirem.
- Usuario com uma academia cair em seletor desnecessario.
- Professor acessar dados fora do membership.
- Indices Firestore faltantes apos filtrar por academia.

## Criterios de aceite
- Multi-academia tem modelo e regras documentados.
- `academyId` e tratado como fronteira obrigatoria.
- Roles por academia estao previstas.
- Nenhum dado foi migrado nesta etapa.
## MULTI-ACADEMY-BASE-001 — Academia ativa sem Blaze

Base implementada: após login, o app deve tentar ler `users/{uid}/academyMemberships/{academyId}` e resolver a academia ativa antes de carregar `academies/{academyId}/users/{uid}`.

Regras da base:
- Memberships ativas são a fonte preferencial para `activeAcademyId`.
- Uma única membership ativa pode ser selecionada automaticamente.
- Múltiplas memberships ativas ficam preparadas no `UserScope` para futuro seletor de academia.
- Sem membership legível, o app mantém fallback legado via `AppConfig.resolveActiveAcademyId()` apenas para compatibilidade de desenvolvimento.
- O perfil `AppUser` continua sendo o documento da academia ativa em `academies/{academyId}/users/{uid}`.
- Esta base não cria Cloud Function, não usa Storage e não altera telas operacionais.
