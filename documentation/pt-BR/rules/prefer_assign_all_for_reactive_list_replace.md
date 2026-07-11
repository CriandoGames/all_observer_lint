# prefer_assign_all_for_reactive_list_replace

- **Categoria:** performance
- **Severidade:** info
- **Bloqueante:** nao
- **Preset:** `strict`, `all` (nao esta em `recommended`)
- **Quick fix:** nao
- **Versao do `all_observer`:** versoes que expoem `ObservableList.assign` e `ObservableList.assignAll`
- **Status:** experimental

## O que a regra faz

Sinaliza uma chamada `ObservableList.clear()` imediatamente seguida de
`add(...)` ou `addAll(...)` na mesma lista observavel.

## Motivo

Substituir uma lista reativa com `clear()` e depois `add`/`addAll` transforma
uma unica atualizacao logica em duas mutacoes. Observadores podem ser
notificados duas vezes, e o codigo pode observar uma lista vazia entre as duas
instrucoes.

Use `assign(...)` para substituir por um unico item e `assignAll(...)` para
substituir por uma colecao. Essas APIs expressam substituicao diretamente e
notificam em uma unica operacao.

## Exemplo incorreto

```dart
void replace(List<Todo> nextTodos) {
  todos.clear();
  todos.addAll(nextTodos);
}
```

```dart
void replaceWithOne(Todo todo) {
  todos.clear();
  todos.add(todo);
}
```

## Exemplo sugerido

```dart
void replace(List<Todo> nextTodos) {
  todos.assignAll(nextTodos);
}
```

```dart
void replaceWithOne(Todo todo) {
  todos.assign(todo);
}
```

## Excecoes

A regra sinaliza apenas instrucoes consecutivas no mesmo bloco e na mesma
`ObservableList`.

Ela nao sinaliza:

- `clear()` sem `add`/`addAll` logo em seguida.
- `List` comum do Dart.
- mutacoes em outra lista.
- chamadas condicionais ou atrasadas de `add`/`addAll`.

## Limitacoes

Esta regra nao tenta inferir intencao entre branches, metodos auxiliares ou
aliases. Ela e intencionalmente estreita para que o diagnostico continue sendo
uma sugestao clara de substituicao, nao um alerta geral sobre mutacao de
colecoes.

## Como desativar

```yaml
custom_lint:
  rules:
    - prefer_assign_all_for_reactive_list_replace: false
```

## Evidencia

Severidade `info`; esta e uma sugestao de otimizacao e clareza. Nao e uma regra
bloqueante de corretude.
