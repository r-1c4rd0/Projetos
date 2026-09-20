# Titans BJJ Quality Gate Skill

## Quando usar

Use esta skill antes e depois de qualquer task que altere:
- UI;
- telas;
- widgets;
- navegacao;
- strings;
- tema;
- dados exibidos;
- repositories;
- use cases;
- rules;
- AuthGate;
- actor/target;
- Game Map;
- Home;
- Training;
- Progress;
- Skills;
- Master Panel.

## Regra principal

Nenhuma task esta pronta apenas porque o codigo compila.

Uma entrega so pode ser considerada aceitavel se passar por:
1. escopo correto;
2. texto e icones integros;
3. validacao estatica;
4. validacao de dominio;
5. QA visual ou limitacao explicitamente reportada;
6. ausencia de alteracao acidental em arquivos proibidos.

## Gates obrigatorios

### Gate 1 - Escopo

Antes de editar:
- listar arquivos que serao alterados;
- confirmar arquivos proibidos;
- nao usar `git add .`;
- nao fazer refactor amplo fora do pedido.

Depois de editar:
- rodar `git status --short`;
- rodar `git diff --name-only`;
- confirmar que so os arquivos esperados mudaram.

### Gate 2 - Texto e icones

Rodar:
```powershell
powershell -ExecutionPolicy Bypass -File tools/check_text_icon_integrity.ps1
```

Falhar se houver:
- replacement char;
- mojibake conhecido;
- literal `\uFFFD`;
- ausencia de `uses-material-design: true`.

Gerar warning para:
- `IconData(`;
- `fontFamily`;
- `fontPackage`;
- emoji usado como icone principal.

### Gate 3 - Dominio

Confirmar explicitamente:
- actor/target preservado;
- academy/personal context preservado;
- professor nao acessa dado indevido;
- aluno self nao afeta outro target;
- treino continua sendo evidencia, nao nota;
- Game Map nao promete dominio automatico;
- nenhum calculo foi alterado sem pedido;
- nenhuma rule/schema/repository/use case foi alterada sem autorizacao.

### Gate 4 - Flutter

Rodar no minimo:
```powershell
dart format <arquivos_alterados>
dart analyze --no-fatal-warnings <arquivos_alterados>
git diff --check -- <arquivos_alterados>
```

Se analyzer global travar:
- rodar por arquivos focados;
- registrar limitacao;
- nao fingir que passou globalmente.

### Gate 5 - QA visual

Para alteracoes de UI:
- testar mobile 360/390/412;
- testar tema escuro;
- testar tema claro, quando aplicavel;
- testar fluxo actor/target quando aplicavel;
- confirmar sem overflow;
- confirmar sem texto quebrado;
- confirmar sem icone tofu;
- confirmar sem tela vermelha;
- confirmar sem mouse_tracker se a tela ja teve esse problema.

## Classificacao de risco

P0:
- quebra seguranca;
- mistura academia/personal mode;
- altera target errado;
- texto ilegivel app-wide;
- icones quebrados globais;
- rules/schema mexidos sem autorizacao;
- dados reais sobrescritos.

P1:
- fluxo importante sem QA;
- performance claramente pior;
- analyzer parcial sem justificativa;
- tela principal com overflow;
- feature com dados inconsistentes.

P2:
- polish visual;
- microcopy;
- alinhamento;
- extracao pequena.

## Entrega final obrigatoria

Toda task deve responder:
1. arquivos alterados;
2. motivo da alteracao;
3. escopo confirmado;
4. resultado do gate de texto/icone;
5. resultado do format;
6. resultado do analyze;
7. resultado do diff check;
8. QA visual executado ou limitacao;
9. confirmacao de actor/target, se aplicavel;
10. confirmacao de que nao alterou rules/schema/repositories/use cases, se nao era escopo;
11. riscos restantes;
12. comando de commit com arquivos explicitos.
