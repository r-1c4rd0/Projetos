# Auth And Session Spec

## Objetivo do modulo
Definir o contrato de autenticacao, sessao, roles, escopos de usuario, aluno selecionado e bloqueio por biometria/session lock.

## Responsabilidades
- Resolver usuario autenticado.
- Carregar perfil e role.
- Resolver `academyId` ativo sem depender de default silencioso.
- Controlar bloqueio de sessao e biometria.
- Expor escopos globais para telas e features.

## Dados usados
- Firebase Auth uid e estado autenticado.
- Perfil `AppUser`.
- Role: admin, professor, athlete.
- Memberships por academia.
- Sessao local, estado bloqueado, timestamp de atividade e biometria.
- Aluno selecionado pelo professor/mestre.

## Telas envolvidas
- `auth_gate.dart`
- `login_screen.dart`
- `signup_screen.dart`
- `signup_gate_screen.dart`
- Telas protegidas por role e sessao.
- `require_selected_student_gate.dart`

## Repositories envolvidas
- `UserRepository`
- `StudentsRepository`
- Futuro repository de memberships por academia.

## Regras de negocio
- Usuario sem perfil completo deve ir para fluxo de cadastro/complemento.
- Usuario com mais de uma academia deve escolher ou resolver academia ativa.
- Professor precisa de aluno selecionado para operacoes direcionadas.
- Sessao bloqueada deve esconder dados sensiveis ate revalidacao.
- Athlete nao pode trocar target para outro aluno.

## Problemas atuais
- `academyId` default e risco central.
- Escopos globais podem misturar sessao, usuario, academia e aluno.
- Rules futuras precisam refletir roles reais.
- Streams em areas de build podem recriar consultas.

## Arquitetura desejada
Feature futura:

```text
features/auth_session/
  data/
    repositories/auth_session_repository.dart
    services/firebase_auth_service.dart
    services/local_session_lock_service.dart
  domain/
    entities/authenticated_user.dart
    entities/active_academy.dart
    policies/role_policy.dart
    use_cases/resolve_active_session.dart
  presentation/
    gates/auth_gate.dart
    gates/session_lock_gate.dart
    view_models/auth_session_view_model.dart
```

## Plano de migracao incremental
1. Documentar fluxo atual de login e gates.
2. Criar contrato explicito para `activeAcademyId`.
3. Remover dependencia conceitual de default, mantendo fallback temporario controlado.
4. Centralizar role checks.
5. Encapsular session lock e biometria.
6. Migrar telas para consumir estado imutavel da sessao.

## Riscos de regressao
- Usuarios ficarem presos no gate.
- Sessao bloquear indevidamente apos background/foreground.
- Professor perder aluno selecionado durante navegacao.
- Admin/professor receber permissoes erradas.

## Criterios de aceite
- Estados de auth, perfil, academia e lock estao definidos.
- `academyId` default e marcado como legado temporario.
- Roles possuem policy futura.
- Nenhum fluxo de login foi alterado nesta etapa.
