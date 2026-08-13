# Attendance Spec

## Objetivo do modulo
Definir presenca como feature futura para check-in em aulas, com suporte planejado a QR Code, NFC e integracao com treino, progresso e status do atleta.

## Responsabilidades
- Registrar presenca por academia, aula, modalidade e aluno.
- Suportar check-in por professor, QR e NFC.
- Alimentar progresso, frequencia, graduacao e analytics.
- Evitar duplicidade com sessoes de treino.

## Dados usados
- Academia ativa.
- Aluno/usuario.
- Aula ou evento de treino.
- Modalidade.
- Timestamp, metodo de check-in, validacao e responsavel.
- Dispositivo/token QR/NFC futuro.

## Telas envolvidas
- Futura tela de presenca.
- `master_panel_screen.dart`
- `training_screen.dart`
- `athlete_dashboard_screen.dart`
- `progress_screen.dart`

## Repositories envolvidas
- Futuro `AttendanceRepository`.
- `TrainingRepository`
- `UserProgressRepository`
- `StudentsRepository`

## Regras de negocio
- Presenca deve pertencer a academia.
- Athlete pode fazer check-in somente em aula autorizada.
- Professor/admin pode confirmar, corrigir ou remover presenca conforme permissao.
- QR/NFC deve expirar ou ser validado para evitar fraude.
- Presenca pode gerar treino derivado, mas com origem rastreavel.

## Problemas atuais
- Presenca QR/NFC ainda nao existe.
- Treinos podem ser usados como proxy de frequencia.
- Falta contrato para evitar duplicidade treino/presenca.

## Arquitetura desejada
Feature futura:

```text
features/attendance/
  data/
    repositories/attendance_repository.dart
    services/qr_check_in_service.dart
    services/nfc_check_in_service.dart
  domain/
    entities/attendance_record.dart
    entities/check_in_token.dart
    use_cases/register_attendance.dart
    use_cases/validate_check_in_token.dart
  presentation/
    screens/attendance_screen.dart
    widgets/check_in_scanner.dart
    view_models/attendance_view_model.dart
```

## Plano de migracao incremental
1. Definir schema de presenca.
2. Definir relacao com treino.
3. Implementar registro manual antes de QR/NFC.
4. Adicionar QR com tokens expiraveis.
5. Adicionar NFC quando houver decisao de hardware/plataforma.
6. Integrar progresso e status engine.

## Riscos de regressao
- Duplicar frequencia ao converter presenca em treino.
- Check-in fraudulento.
- Falha offline gerar perda de presenca.
- Professor corrigir presenca fora da academia.

## Criterios de aceite
- Feature futura esta mapeada.
- QR/NFC tem responsabilidades e riscos definidos.
- Integracao com treino/progresso esta documentada.
- Nenhuma tela de presenca foi criada nesta etapa.
