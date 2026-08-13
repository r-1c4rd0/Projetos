# AGENTS.md - Titans BJJ

Regras permanentes para qualquer agente Codex trabalhando neste repositorio.

## Antes de qualquer alteracao

1. Leia lib/specs/README.md antes de alterar qualquer arquivo.
2. Leia a spec especifica do modulo antes de mexer em codigo:
   - Auth/sessao: lib/specs/auth_session_spec.md
   - Multi-academia: lib/specs/multi_academy_spec.md
   - Graduacao: lib/specs/graduation_spec.md
   - Treinos: lib/specs/training_spec.md
   - Progresso: lib/specs/progress_spec.md
   - Nutricao: lib/specs/nutrition_spec.md
   - Presenca: lib/specs/attendance_spec.md
   - Eventos: lib/specs/events_spec.md
   - Firebase/schema: lib/specs/firebase_schema_spec.md
   - Design system: lib/specs/design_system_spec.md
   - Produto: lib/specs/product_spec.md
   - Arquitetura: lib/specs/architecture_spec.md
   - Migracao: lib/specs/refactor_migration_plan.md
3. Use .agents/skills/flutter-architecting-apps e .agents/skills/flutter-managing-state` como referencias obrigatorias para arquitetura Flutter e estado.

## Regras de escopo

1. Nao faca refatoracao ampla sem fase aprovada no plano de migracao.
2. Nao altere arquivos fora do escopo da tarefa.
3. Preserve o legado atual quando a tarefa for documental ou preparatoria.
4. Nao mova arquivos para lib/app, lib/core ou lib/features sem uma fase de migracao aprovada.
5. Nao altere Firebase, Android, iOS, Web, desktop ou configuracoes de build sem pedido explicito.

## Regras tecnicas

1. Nao crie Future ou Stream dentro de build.
2. Nao acesse Firestore diretamente em screen; use repository.
3. Nao use academyId "default" como fallback silencioso.
4. Preserve o fluxo mestre/aluno, incluindo aluno selecionado e gates relacionados.
5. Preserve biometria, session lock e lifecycle de sessao.
6. Preserve suporte e contratos de multi-academia.
7. Regras por role devem respeitar admin, professor e athlete.
8. UI deve seguir o design system documentado e evitar estilos locais divergentes.
9. Se uma spec citada nao existir ou estiver incompleta, pare a tarefa e informe antes de alterar codigo.

## Entrega obrigatoria

Toda entrega deve incluir:

- Arquivos alterados.
- Motivo da alteracao.
- Codigo completo dos arquivos alterados.
- Validacao rapida usada.

Se nao for possivel validar, informe claramente o motivo.
