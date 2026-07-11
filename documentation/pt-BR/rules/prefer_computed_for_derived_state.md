# prefer_computed_for_derived_state

- **Categoria:** architecture
- **Severidade:** info
- **Bloqueante:** não
- **Preset:** `strict`, `all` (não está em `recommended`)
- **Quick fix:** não
- **Versão do `all_observer`:** qualquer versão
- **Status:** experimental

## O que a regra faz

Sinaliza um observável que recebe um valor derivado puramente de `.value`
de outros observáveis — uma re-derivação manual que `Computed` já resolve
de forma declarativa.

## Motivo

Estado mantido manualmente em sincronia tende a divergir: todo lugar que
altera um dos observáveis de origem precisa lembrar de também atualizar o
derivado. `Computed` torna essa relação automática e impossível de
esquecer.

## Exemplo incorreto

```dart
final firstName = ''.obs;
final lastName = ''.obs;
final fullName = ''.obs;

void updateFullName() {
  fullName.value = '${firstName.value} ${lastName.value}';
}
```

## Exemplo correto

```dart
final firstName = ''.obs;
final lastName = ''.obs;
final fullName = Computed(() => '${firstName.value} ${lastName.value}');
```

## Exceções

Uma atribuição que também lê o `.value` do próprio alvo (acumulação, por
exemplo `total.value = total.value + delta`) não é sinalizada — isso não é
uma re-derivação pura.

## Limitações

Esta regra é deliberadamente conservadora e experimental: analisa apenas o
lado direito de uma única atribuição simples (`=`), não o método inteiro.
Não está incluída em `recommended` porque falsos positivos são mais
prováveis aqui do que nas regras de ciclo de vida/pureza (por exemplo, um
valor que parece "puramente derivado" hoje pode legitimamente precisar de
estado adicional depois).

## Como desativar

```yaml
custom_lint:
  rules:
    - prefer_computed_for_derived_state: false
```

## Evidência

Severidade `info`; uma sugestão, não uma alegação de bug. Nenhum documento
de evidência é exigido.
