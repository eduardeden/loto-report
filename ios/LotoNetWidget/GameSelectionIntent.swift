import AppIntents

@available(iOS 17.0, *)
enum WidgetGameOption: String, AppEnum {
    case loto649
    case joker

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Joc")
    }

    static var caseDisplayRepresentations: [WidgetGameOption: DisplayRepresentation] {
        [
            .loto649: DisplayRepresentation(title: "Loto 6/49"),
            .joker: DisplayRepresentation(title: "Joker"),
        ]
    }

    var game: LotoGame {
        switch self {
        case .loto649:
            return .loto649
        case .joker:
            return .joker
        }
    }
}

@available(iOS 17.0, *)
struct GameSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Alege joc"
    static var description = IntentDescription("Alege ce report sa afiseze widget-ul.")

    @Parameter(title: "Joc")
    var game: WidgetGameOption?

    init() {
        game = .loto649
    }
}
