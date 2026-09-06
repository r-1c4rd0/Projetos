---
name: titans-bjj-visual-evolution
description: Govern visual evolution work in the Titans BJJ Flutter app. Use for visual phases, chart/card/dashboard UI changes, economic QA, actor/target-sensitive screens, and local ViewModel/widget work that must preserve real metrics and avoid broad refactors.
---

# Titans BJJ Visual Evolution

Use this skill for visual evolution tasks in the Titans BJJ repository.

## Required Context
- Read `lib/specs/README.md`.
- Read `lib/specs/visual_evolution_spec.md`.
- Read the module spec for the touched area, such as `training_spec.md`, `progress_spec.md`, `nutrition_spec.md` or `design_system_spec.md`.
- Use the generic Flutter skills only as references; do not edit them.

## Economic Protocol
- Do not run `flutter run` unless explicitly authorized.
- Do not run `graphify update` unless explicitly authorized.
- Use `graphify query` or `graphify explain` only when `graphify-out/graph.json` exists and there is a real uncertainty.
- Do not use large scripts.
- Do not use huge regex replacements for blocks.
- Prefer manual, surgical edits.
- Do not paste complete files in the report.

## Validation Protocol
- Run `git diff --check`.
- Run `dart format` only on changed files.
- Run `dart analyze --no-fatal-warnings` only on changed files.
- Keep the report short: changed files, what changed, validation, remaining risks.

## Actor And Target
- `actor` is the logged-in user.
- `target` is the viewed or edited user.
- A regular athlete uses their own data.
- Professor/admin viewing a student uses the student's data.
- Professor/admin in Meu Perfil uses their own data.
- Never reuse `selectedStudent` in `TargetMode.self`.

## Visual Widget Rules
- A visual widget does not access Firebase.
- A visual widget does not access repositories.
- A visual widget does not use `UserScope` or `TargetResolver`.
- The screen resolves data, permissions and target.
- A ViewModel provides renderable data.
- The widget only draws.

## Chart Rules
- Do not create fake metrics.
- Do not use performance, proficiency, score or domain without an explicit contract.
- Do not use duration, volume or intensity when the data is not reliable for the visual claim.
- Tooltips must show real data.
- Empty states must be honest and safe.
- Design mobile first and inspect 360, 390, 412 and 480 px in economic mode.
- Do not add dependencies without justification and explicit approval.

## Roadmap
- V1 Collapsing Athlete Console: complete.
- V2 Progress Area Chart: complete.
- V3 Consistency Heatmap: complete.
- V4 Skill Matrix Visual Summary: complete.
- V5 Training Chart 2.0: complete.
- V6 Game Map Visual Incremental: next.
- V7 Radar R/T/C/A only with validated metric.
- V8 Microinteractions & Polish.
- V9 Runtime QA / Performance.
