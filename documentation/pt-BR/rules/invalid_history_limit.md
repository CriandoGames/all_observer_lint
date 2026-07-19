# invalid_history_limit

## Objetivo

Avisa quando `ObservableHistory` recebe um `limit` constante menor ou igual a
zero. O contrato do runtime exige pelo menos uma entrada.

## Código incorreto

```dart
value.withHistory(limit: 0);
ObservableHistory(value, limit: -1);
```

## Código correto

```dart
value.withHistory(limit: 1);
value.withHistory(limit: configuredLimit);
```

## Severidade

`warning`; disponível em `recommended`, `strict` e `all`.

## Limitações e falsos positivos possíveis

Somente chamadas resolvidas da extensão/construtor de `all_observer` e
constantes conhecidas são verificadas. Valores dinâmicos ficam silenciosos,
portanto falsos negativos são possíveis. Não há formato conhecido de falso
positivo semântico.

## Quando ignorar

Ignore apenas se um runtime modificado aceitar limites não positivos.

## Fix ou assist

Não há correção automática: o limite positivo correto depende do domínio.
