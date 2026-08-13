# Design System Spec

## Objetivo do modulo
Definir um design system consistente e futuramente personalizavel por academia, preservando os widgets e temas atuais ate a migracao visual ser planejada.

## Responsabilidades
- Padronizar cores, tipografia, espacamento, superficies e componentes.
- Separar tema base Titans de customizacoes por academia.
- Reduzir divergencias visuais entre Console do Atleta, Painel do Mestre e modulos.
- Definir tokens consumiveis por widgets.

## Dados usados
- Tema base em `app_colors.dart`, `titans_theme.dart`, `titans_ui.dart` e `theme_controller.dart`.
- Branding de academia: logo, cores, nome, modalidade principal e assets.
- Preferencias visuais por role ou academia.

## Telas envolvidas
- Todas as telas visuais.
- Widgets compartilhados: `app_card.dart`, `app_surface.dart`, `background_scaffold.dart`, `glass_card.dart`, `neo_card.dart`, `glow_progress.dart`, `titans_logo.dart`, `titans_scaffold.dart`.

## Repositories envolvidas
- Repositories atuais nao devem ser acopladas a UI.
- Futuro `AcademySettingsRepository` ou equivalente deve fornecer branding.
- `firebase_logo_service.dart` pode ser adaptado para fonte de assets.

## Regras de negocio
- Design tokens devem ser resolvidos por academia quando disponiveis.
- Fallback visual deve ser o tema Titans.
- Personalizacao nao pode quebrar contraste, legibilidade ou estados de erro.
- Componentes compartilhados nao devem conter regra de negocio.

## Problemas atuais
- Inconsistencia visual entre componentes.
- Possivel sobreposicao de estilos locais nas telas.
- Widgets similares podem existir com responsabilidades sobrepostas.
- Branding por academia ainda nao esta consolidado.

## Arquitetura desejada
Estrutura futura:

```text
features/design_system/
  data/
    repositories/academy_theme_repository.dart
  domain/
    entities/design_tokens.dart
    policies/contrast_policy.dart
  presentation/
    theme/academy_theme_resolver.dart
    widgets/
```

`core/theme` deve manter somente tokens base, helpers e contratos compartilhados.

## Plano de migracao incremental
1. Inventariar widgets e tokens atuais.
2. Definir tokens base: color, type, radius, spacing, elevation, feedback.
3. Criar resolver de tema com fallback Titans.
4. Migrar componentes compartilhados antes das telas.
5. Migrar telas por feature.
6. Adicionar configuracao visual por academia.

## Riscos de regressao
- Mudancas visuais afetarem usabilidade.
- Cores de academia reduzirem acessibilidade.
- Tela antiga e nova parecerem produtos diferentes durante migracao.
- Customizacao carregar tarde e causar flicker.

## Criterios de aceite
- Tokens e fonte de branding estao documentados.
- Fallback Titans esta definido.
- Personalizacao por academia aparece no roadmap.
- Nenhum widget existente foi alterado nesta etapa.
