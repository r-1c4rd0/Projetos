---
name: dart-readable-code
description: Aplicar escrita legível e idiomática antes e durante implementação, correção ou refatoração de código Dart/Flutter. Usar para reduzir duplicação e complexidade sem alterar contratos ou comportamentos fora do pedido, especialmente em condições, estados, datas, null safety e extração de helpers. Não executar limpeza global ou migração arquitetural por causa desta skill.
---

# Dart legível e idiomático

Priorizar, nesta ordem: comportamento correto, clareza da intenção, consistência com o projeto e concisão. Tratar elegância como facilidade de entender e manter o código; quantidade de linhas não é critério de aprovação.

## Antes de escrever

- Ler as instruções aplicáveis do projeto, a restrição do SDK em `pubspec.yaml`, os lints existentes e os trechos envolvidos. Usar uma busca direcionada por helpers, consumidores e testes antes de criar uma implementação paralela.
- Distinguir o comportamento solicitado dos comportamentos existentes que precisam permanecer. Em refatoração, preservar ambos os caminhos de cada decisão, contratos públicos, erros e efeitos observáveis. Em feature/correção, alterar apenas a regra explicitamente pedida.
- Confirmar o significado de `null`, estados explícitos e inferidos, fallback e erros. Não decidir uma regra de negócio por conveniência sintática.
- Antes de substituir helpers semelhantes, ler suas implementações: nomes como `_dateOnly` e `dateOnly` não provam equivalência. Conferir visibilidade, fuso, normalização, efeitos e possíveis sobrescritas.
- Escolher a solução mais direta dentro da arquitetura existente. Não criar service, extension, interface, mixin ou novo pacote para encurtar uma expressão.

Fazer essa avaliação de forma proporcional à tarefa. Não produzir uma auditoria longa nem parar para aprovação de escolhas rotineiras. Havendo regra ambígua, preservar o comportamento demonstrável e explicar a dúvida; perguntar somente quando ela bloquear a mudança pedida.

## Ao implementar

- Usar `=>` quando uma única expressão expuser bem a intenção. Manter bloco com variáveis nomeadas quando facilitar leitura, preservar uma fotografia do tempo/estado ou tratar efeitos e erros.
- Usar `??` para fallback de ausência quando for semanticamente equivalente. Preservar avaliação preguiçosa e não trocar ausência por valor vazio, erro ou estado inativo.
- Centralizar uma regra duplicada no helper apropriado existente, mantendo os contratos de seus consumidores. Não mover toda a regra para um helper distante que apenas esconda a complexidade.
- Usar nomes que revelem o domínio, retornos antecipados para reduzir aninhamento e expressões booleanas curtas. Evitar ternários aninhados, cadeias densas e abstrações que acrescentem indireção sem benefício.
- Usar `switch` expression para mapeamentos simples quando o SDK permitir. Em enums, preferir casos explícitos e exaustivos, evitando wildcard que esconda novos estados. Manter `switch` em bloco quando houver passos ou efeitos por ramo.
- Evitar `!` quando fluxo de controle, variável local ou operador de null safety resolverem claramente. Não substituir uma validação por um valor default que silencie erro.
- Manter método com parâmetro `now` quando ele fizer parte do contrato; não convertê-lo em getter e perder a capacidade de teste.
- Capturar relógio e estado uma vez quando a decisão exigir consistência. Repassar o mesmo `now` aos helpers. Não introduzir múltiplas leituras do relógio numa decisão que antes usava uma só.
- Preservar a convenção existente de datas e fuso. `DateTime(year, month, day)`, `.toLocal()`, `.toUtc()` e duração de 24 horas não são substituições automáticas entre si.
- Em Flutter, extrair widget quando houver responsabilidade visual ou reutilização concreta, preservando estado, keys, lifecycle e dependências herdadas. Não trocar o gerenciador de estado nem o design system por preferência estética.
- Preservar UTF-8, acentos, nomes de campos persistidos e contratos de API. Não reformular regras de sessão/permissão como melhoria de legibilidade.

## Antes de entregar

- Para simplificar condições de domínio, comparar resultados anteriores e propostos nos casos que distinguem as regras. Testar predicados observáveis, não o formato do código.
- Em status/data, considerar status nulo e explícito, data passada/hoje/futura e instante fixo perto da virada do dia. Ler [o exemplo de status](references/training-status.md) quando a tarefa envolver esse caso ou uma simplificação semelhante.
- Acrescentar ou ajustar testes direcionados se houver risco real de mudança de comportamento; reutilizar a infraestrutura existente. Não exigir testes novos para mudanças mecânicas de baixo impacto.
- Formatar apenas os arquivos alterados, rodar análise e testes pertinentes disponíveis e revisar o diff para detectar mudanças não solicitadas. Não alterar lints ou atualizar SDK/pacotes apenas para viabilizar estilo mais moderno.
- Informar brevemente a melhoria, os comportamentos preservados e a validação realmente executada. Se não houver SDK/runtime, declarar a limitação; inspeção textual não comprova compilação.

## Referências de linguagem

Consultar apenas se houver dúvida concreta; não navegar novamente para cada alteração trivial:
- [Effective Dart](https://dart.dev/effective-dart)
- [Arrow syntax](https://dart.dev/resources/dart-cheatsheet#arrow-syntax)
- [Switch expressions](https://dart.dev/language/branches#switch-expressions)
