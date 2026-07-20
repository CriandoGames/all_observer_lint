# copied_reactive_collection_outside_tracking

- **Categoria:** reactiveCycle
- **Severidade:** info
- **Bloqueante:** não
- **Preset:** `strict`, `all` (não está em `recommended`)
- **Quick fix:** não
- **Versão do `all_observer`:** qualquer versão
- **Status:** experimental

## O que a regra faz

Sinaliza uma variável local que copia uma `ObservableList`/`ObservableMap`/
`ObservableSet` para um snapshot comum (`.toList()`/`.toSet()`) antes de um
escopo de rastreamento `Observer`/`Computed`/`effect`, quando esse
snapshot — e não a coleção reativa original — é o que é lido dentro do
escopo de rastreamento.

## Motivo

```dart
final visibleItems = items.toList();
return Observer(
  () => ListView(children: visibleItems.map(buildItem).toList()),
);
```

`visibleItems` é uma `List` comum, copiada antes do builder do `Observer`
sequer rodar. O `Observer` lê `visibleItems`, não `items` — ele não
rastreia nada, e nunca reconstrói quando `items` mudar. Este é um erro
comum e fácil de não perceber: o código compila, renderiza corretamente
uma vez, e só silenciosamente para de atualizar depois.

## Exemplo incorreto

```dart
final visibleItems = items.toList();
return Observer(
  () => Column(children: visibleItems.map((i) => Text('$i')).toList()),
);
```

## Exemplo correto

Mova a cópia para dentro do escopo de rastreamento, para que a própria
leitura de `items` seja o que é rastreado:

```dart
return Observer(
  () => Column(
    children: items.map((i) => Text('$i')).toList(),
  ),
);
```

Ou, se a lista derivada for reaproveitada em outros lugares, derive-a com
`Computed` em vez de um snapshot avulso:

```dart
late final visibleItems = Computed(() => items.toList());

return Observer(
  () => Column(children: visibleItems.value.map((i) => Text('$i')).toList()),
);
```

## Escopo de detecção

Esta regra só reconhece:

- uma declaração de variável **local** `final`/`var` (um snapshot em campo
  está fora do escopo desta versão — provar "lido dentro deste escopo de
  rastreamento, neste método" para um campo exigiria análise de fluxo de
  toda a classe, que esta regra não tenta fazer);
- um snapshot via `.toList()`/`.toSet()` (um snapshot por spread de
  coleção literal, ex.: `[...items]`, ainda não é reconhecido — ver o
  backlog do projeto). A coleção reativa pode ser alcançada através de uma
  propriedade intermediária, ex.: `counters.keys.toList()` ou
  `map.values.toSet()` sobre um `ObservableMap` — a cadeia é percorrida de
  volta até a coleção original de qualquer forma;
- o tipo estático da própria variável não pode ser uma coleção reativa,
  então `final same = items;` (que continua rastreando `items`
  diretamente) nunca é sinalizado;
- a variável snapshot nunca pode ser reatribuída em nenhum lugar do
  arquivo — uma variável atualizada antes de cada uso não é um snapshot
  obsoleto;
- a coleção original precisa ser uma referência simples resolvível
  estaticamente (`items`, `this.items`, `widget.items`);
- a coleção original precisa estar confirmadamente **não lida** dentro do
  mesmo callback de rastreamento — quando o original também é lido ali, o
  `Observer`/`Computed`/`effect` já rastreia corretamente através dessa
  leitura, então esta regra permanece silenciosa em vez de arriscar um
  falso positivo.

## Limitações

- Nenhum quick fix ou assist acompanha esta regra ainda — apenas o
  diagnóstico. Mover a expressão do snapshot para dentro do escopo de
  rastreamento, ou extraí-la para um `Computed`, ambos exigem prova de
  segurança adicional (uso único, pureza, um ponto de inserção seguro)
  ainda não implementada.
- Insensível a instância: a checagem "o original também foi lido aqui"
  compara o elemento de campo resolvido, não a instância receptora
  específica. No caso raro em que duas instâncias diferentes da mesma
  classe expõem cada uma seu próprio campo `items` e apenas o campo de uma
  delas é lido junto do snapshot, esta regra pode permanecer silenciosa
  (um falso negativo, não um falso positivo) em vez de arriscar atribuir a
  leitura à instância errada.
- Um snapshot passado para uma função/método auxiliar que por si só
  constrói um `Observer` não é seguido — só um escopo de rastreamento
  diretamente alcançável no mesmo corpo de função é considerado.

## Como desativar

```yaml
custom_lint:
  rules:
    - copied_reactive_collection_outside_tracking: false
```

## Evidência

Severidade `info`; uma sugestão que aponta um padrão de rastreamento
obsoleto provável estaticamente, não uma falha verificada em runtime.
Nenhum documento de evidência é exigido.
