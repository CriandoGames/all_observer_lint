import 'diagnostic_message_key.dart';
import 'diagnostic_messages.dart';

/// Mensagens de diagnóstico em português do Brasil.
///
/// Disponível por configuração explícita (`all_observer: language: pt-BR`
/// em `analysis_options.yaml`). O significado técnico é equivalente ao das
/// mensagens em inglês; a tradução é adaptada à terminologia usada por
/// desenvolvedores brasileiros, não é uma tradução literal.
class DiagnosticMessagesPtBr implements DiagnosticMessages {
  const DiagnosticMessagesPtBr();

  static const Map<DiagnosticMessageKey, String> _messages = {
    DiagnosticMessageKey.reactiveCreationInsideBuild:
        'Evite criar estado reativo dentro do build. Esse recurso será '
            'recriado sempre que o widget for reconstruído. Mova-o para um '
            'campo do State, para o initState, um controller, uma view model ou '
            'outro objeto controlado pelo ciclo de vida.',
    DiagnosticMessageKey.effectCreationInsideBuild:
        'Evite registrar effects ou workers dentro do build. Rebuilds podem '
            'criar subscriptions duplicadas. Registre o recurso em um local '
            'controlado pelo ciclo de vida e descarte-o quando apropriado.',
    DiagnosticMessageKey.invalidWatchContext:
        'Use watch(context) apenas durante a construção de um widget. Fora '
            'do build, leia o valor diretamente ou use um listener/effect '
            'explícito.',
    DiagnosticMessageKey.reactiveResourceNotDisposed:
        'Este recurso reativo não é descartado. Descarte-o junto com o '
            'ciclo de vida responsável para evitar listeners obsoletos e '
            'efeitos colaterais duplicados.',
    DiagnosticMessageKey.reactiveWriteInsideComputed:
        'Não escreva em um valor reativo dentro de um callback de Computed. '
            'O Computed deve derivar um valor sem alterar estado reativo; mova '
            'a escrita para uma action, effect ou worker.',
    DiagnosticMessageKey.setStateInsideComputed:
        'Não chame setState dentro de um callback de Computed. Callbacks de '
            'Computed podem executar fora do ciclo de vida do widget e não '
            'devem tocar diretamente no estado do widget.',
    DiagnosticMessageKey.workerCreationInsideComputed:
        'Não crie effects ou workers dentro de um callback de Computed. O '
            'Computed pode ser recomputado múltiplas vezes, o que registraria '
            'subscriptions duplicadas.',
    DiagnosticMessageKey.ioInsideComputed:
        'Evite chamadas de I/O dentro de um callback de Computed. Callbacks '
            'de Computed podem executar de forma síncrona e repetida durante o '
            'rastreamento de dependências, o que torna o I/O aqui '
            'imprevisível e custoso.',
    DiagnosticMessageKey.observableWriteDuringObserverBuild:
        'Evite alterar estado reativo enquanto um Observer está '
            'construindo. Mantenha callbacks de renderização somente leitura e '
            'faça alterações de estado em actions, event handlers, effects ou '
            'controllers.',
    DiagnosticMessageKey.selfReferencingComputed:
        'Um Computed não pode ler o próprio valor dentro do callback. Isso '
            'cria um ciclo reativo que não consegue estabilizar; derive o valor '
            'a partir de outros estados reativos.',
    DiagnosticMessageKey.preferComputedForDerivedState:
        'Este observável parece ser mantido manualmente em sincronia com '
            'outros observáveis. Considere derivá-lo com Computed em vez de '
            'atribuí-lo manualmente.',
    DiagnosticMessageKey.preferBatchForMultipleRelatedWrites:
        'Múltiplas escritas reativas relacionadas ocorrem aqui sem batch. '
            'Se listeners externos observam estados intermediários, considere '
            'envolver essas escritas em batch(() { ... }).',
    DiagnosticMessageKey.preferAssignAllForReactiveListReplace:
        'Prefira assignAll(...) ou assign(...) ao substituir uma ObservableList. '
            'Chamar clear() e depois add/addAll notifica em duas etapas '
            'separadas e pode expor uma lista vazia intermediária.',
  };

  @override
  String message(DiagnosticMessageKey key) => _messages[key] ?? key.toString();
}
