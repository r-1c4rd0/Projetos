# Firebase Schema Spec

## Objetivo do modulo
Documentar o schema desejado de Firebase/Firestore para suportar multi-academia, roles, treinos, progresso, nutricao, eventos, presenca e graduacao com isolamento por academia.

## Responsabilidades
- Definir colecoes e ownership de dados.
- Explicitar campos obrigatorios para `academyId`.
- Orientar rules futuras para admin, professor e athlete.
- Reduzir duplicidade de fontes e inconsistencias.

## Dados usados
- Firebase Auth uid.
- Perfil de usuario e role.
- Academia e configuracoes.
- Alunos, treinos, presencas, progresso, nutricao, eventos e graduacao.

## Telas envolvidas
- AuthGate, login e cadastro.
- Cadastro de atleta.
- Painel do mestre.
- Console/dashboard do atleta.
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
- Todo documento de dominio deve ter `academyId` ou estar sob o path da academia.
- Admin acessa a academia administrada.
- Professor acessa alunos e operacoes das academias permitidas.
- Athlete acessa primariamente seu proprio perfil e dados derivados.
- Regras de leitura/escrita devem ser simetricas ao contrato de produto.

## Problemas atuais
- Uso de `academyId` default pode mascarar falta de configuracao real.
- Multi-academia ainda nao define fronteira unica de path.
- Rules de professor/admin estao pendentes.
- Graduacao pode estar duplicada entre perfil e regras.

## Arquitetura desejada
Schema alvo sugerido:

```text
academies/{academyId}
  settings/{settingsDoc}
  invites/{inviteId}
  memberships/{uid}
  students/{studentId}
  trainingSessions/{sessionId}
  attendanceRecords/{attendanceId}
  progressProfiles/{studentId}
  nutritionPlans/{planId}
  events/{eventId}
  gradingRules/{modalityId}
  modalities/{modalityId}

users/{uid}
  private/profile
  academyMemberships/{academyId}

```


Campos comuns:
- `academyId`
- `createdAt`
- `updatedAt`
- `createdBy`
- `updatedBy`
- `status`

## Convites AUTH-REAL-USERS

Path proposto:

```text
academies/{academyId}/invites/{inviteId}
```

Campos obrigatorios:
- `academyId`
- `emailNormalized`
- `role`: `athlete` ou `professor`
- `status`: `pending`, `accepted`, `expired` ou `revoked`
- `invitedByUid`
- `invitedByRole`
- `createdAt`
- `expiresAt`

Campos opcionais/controlados:
- `pendingProfileId`
- `acceptedAuthUid`
- `acceptedAt`
- `revokedAt`
- `lastSentAt`

Contrato de identidade:
- `pendingProfileId` aponta para cadastro legado criado com UUID local.
- `acceptedAuthUid` aponta para o UID real do Firebase Auth apos aceite.
- A fonte principal apos aceite deve ser `academies/{academyId}/users/{acceptedAuthUid}`.
- Alias permanente entre UUID legado e Auth UID nao deve ser fonte principal do MVP.

Migracao de aceite:
- Copiar/migrar dados de `progress/profile`, `training_sessions`, `nutrition/profile`, graduacao, `belt` e `degree` do `pendingProfileId` para o Auth UID.
- `MasterPanel` e `selectedStudent` devem resolver Auth UID para usuarios ativos e manter pendentes visiveis por status.

Rules futuras:
- Admin/professor da academia pode criar, reenviar e revogar convite.
- Usuario autenticado so pode aceitar convite cujo `emailNormalized` corresponda ao e-mail do Auth user.
- Convites `expired` ou `revoked` nao podem gravar vinculo.
- `acceptedAuthUid` e write-once.

## Radar Tecnico futuro

O Radar Tecnico Retencao/Transicao/Controle/Ataque deve ser derivado de classificacao explicita de taxonomia, nao de campos operacionais isolados.

Eixos aceitos:
- `retention`
- `transition`
- `control`
- `attack`
- `unclassified`

Contrato de persistencia futura:
- A classificacao oficial deve viver na taxonomia/contrato de treino antes de virar dado persistido por atleta.
- Taxonomias customizadas poderao receber um campo futuro `technicalRadarAxis`, mas este campo nao deve ser exigido no schema atual.
- Registros historicos sem classificacao devem permanecer como `unclassified`.
- Nenhum documento de treino deve salvar score, percentual ou formula do Radar nesta fase.

## Plano de migracao incremental
1. Inventariar colecoes reais antes de mudar schema.
2. Introduzir validacao de `academyId` em camada de repository.
3. Definir adapters para ler legado e novo schema.
4. Migrar dados por academia.
5. Ativar rules por role em rollout controlado.
6. Remover fallback default apos usuarios existentes estarem normalizados.

## Riscos de regressao
- Documentos legados sem `academyId` ficarem inacessiveis.
- Rules bloquearem usuarios validos.
- Duplicidade de paths durante migracao causar leituras divergentes.
- Queries exigirem indices nao criados.

## Criterios de aceite
- Schema alvo registra isolamento por academia.
- Roles e permissoes futuras estao documentadas.
- `academyId` default esta marcado como problema a eliminar.
- Nenhuma colecao foi alterada nesta etapa.
