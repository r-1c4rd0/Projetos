# Refactor Migration Plan

## Objetivo do modulo
Definir as fases de migracao spec-driven do Titans BJJ para uma arquitetura robusta, modular e orientada por features, sem quebrar o legado atual.

## Responsabilidades
- Sequenciar mudancas por risco e dependencia.
- Preservar comportamento atual durante a transicao.
- Criar checkpoints de aceite por fase.
- Evitar refatoracoes amplas sem contrato e validacao.

## Dados usados
- Codigo legado atual em `lib/core`, `lib/model`, `lib/repository`, `lib/screen`, `lib/service` e `lib/widgets`.
- Specs em `lib/specs`.
- Firebase Auth/Firestore.
- Usuarios, academias, roles, graduacao, treinos, progresso, nutricao, presenca e eventos.

## Telas envolvidas
- Todas as telas atuais devem ser tratadas como legado funcional ate migracao planejada.
- Gates e escopos globais devem ser priorizados nas fases iniciais.

## Repositories envolvidas
- Todas as repositories atuais.
- Repositories futuras por feature serao criadas somente em fases de implementacao, nao nesta etapa.

## Regras de negocio
- Cada fase deve ter escopo pequeno, teste/validacao e rollback conceitual.
- Nenhuma fase deve depender de mover tudo de uma vez.
- Dados legados devem continuar legiveis enquanto a migracao estiver ativa.
- Alteracoes em Firebase Rules devem acompanhar contratos de acesso.

## Problemas atuais
- `academyId` default.
- Graduacao duplicada.
- Multi-academia pendente.
- Rules de professor/admin.
- Streams em build.
- Inconsistencia visual.
- Estrutura por camadas genericas.

## Arquitetura desejada
Estado final desejado:

```text
lib/app/
lib/core/
lib/features/
```

Cada feature:

```text
features/<feature>/
  data/
  domain/
  presentation/
```

## Plano de migracao incremental
### Fase 1: estabilizacao de sessao, auth e academyId
- Mapear fluxo `AuthGate`, `UserScope`, `SelectedStudentScope`, session lock e biometria.
- Criar contrato explicito de usuario, role, academia ativa e aluno selecionado.
- Eliminar uso conceitual de `academyId` default, mantendo fallback temporario se necessario.
- AUTH-REAL-USERS — Onboarding real de atletas e professores convidados (P0 antes de uso real em academia): prever diagnostico do cadastro atual; modelo de convite; aceite com criacao/vinculo de conta Firebase Auth propria; regras Firestore/Auth; migracao de atletas sem login; UX no Painel do Mestre com status Ativo/Pendente/Sem acesso/Expirado.
- Definir Firestore Rules esperadas para admin/professor/athlete.
- Aceite: usuario autenticado sempre possui estado claro de perfil, role, academia ativa e, quando convidado, vinculo real entre conta Auth e cadastro da academia.

### Fase 2: fonte unica de graduacao
- Inventariar campos de faixa/grau.
- Escolher fonte canonica.
- Criar historico de graduacao como contrato.
- Adaptar leituras antes de remover campos duplicados.
- Aceite: telas leem graduacao do mesmo contrato.

### Fase 3: repositories e Firestore schema
- Documentar colecoes reais e queries.
- Padronizar campos comuns e ownership por academia.
- Separar services stateless de repositories como SSOT.
- Preparar adapters para legado e novo schema.
- Aceite: cada repository tem responsabilidade clara e filtro por academia quando aplicavel.

### Fase 4: feature modules
- Criar `lib/app`, consolidar bootstrap/rotas/providers quando fase for executada.
- Criar `lib/features` por dominio.
- Migrar uma feature por vez: events, nutrition, training, progress, graduation, athletes, academy, auth_session.
- Manter imports/export temporarios.
- Aceite: feature migrada possui `data`, `domain`, `presentation` e testes/validacao basica.

### Fase 5: design system personalizavel
- Inventariar componentes e tokens.
- Definir tema Titans base.
- Criar resolver de tema por academia com fallback.
- Migrar widgets compartilhados e depois telas.
- Aceite: telas principais usam tokens consistentes e aceitam branding por academia.

### Fase 6: presenca QR/NFC
- Modelar `attendanceRecords`.
- Implementar presenca manual como base.
- Adicionar QR com token expiravel.
- Avaliar NFC conforme suporte de plataforma.
- Integrar presenca com treino/progresso.
- Aceite: presenca registra aluno, academia, modalidade, metodo e origem sem duplicar treino.

### Fase 7: multi-modalidade
- Introduzir `modalities`.
- Generalizar graduacao, treinos, eventos e presenca por modalidade.
- Permitir academia configurar modalidades alem de BJJ.
- Aceite: BJJ continua funcionando e nova modalidade pode ser configurada sem alterar core.

### Fase 8: analytics/status engine
- Definir indicadores oficiais.
- Criar engine de status automatico do atleta.
- Alimentar painel avancado do mestre.
- Criar agregados por academia, modalidade e periodo.
- Aceite: status e dashboards sao derivados de fontes canonicas e auditaveis.

## Riscos de regressao
- Migrar auth antes de conhecer todos os estados reais.
- Alterar schema sem adapters.
- Trocar fonte de graduacao sem reconciliar dados antigos.
- Criar feature modules duplicando logica antiga.
- Introduzir QR/NFC sem politica antifraude.
- Tema por academia quebrar acessibilidade.

## Criterios de aceite
- O plano contem as oito fases pedidas.
- Cada fase possui objetivo pratico e aceite.
- O plano respeita a regra de nao alterar codigo funcional agora.
- A migracao pode ser executada incrementalmente.
