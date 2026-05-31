import Foundation

enum FinderContextMenuItem: String, CaseIterable, Identifiable {
    case open
    case openWith
    case showPackageContents
    case moveToTrash
    case getInfo
    case rename
    case compress
    case decompress
    case duplicate
    case makeAlias
    case quickLook
    case copy
    case share
    case colorTags
    case tags
    case quickActions
    case terminal
    case revealInFinder
    case git
    case create

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: "Открыть"
        case .openWith: "Открыть с помощью"
        case .showPackageContents: "Показать содержимое пакета"
        case .moveToTrash: "Переместить в Корзину"
        case .getInfo: "Свойства"
        case .rename: "Переименовать"
        case .compress: "Сжать"
        case .decompress: "Разархивировать"
        case .duplicate: "Дублировать"
        case .makeAlias: "Создать псевдоним"
        case .quickLook: "Быстрый просмотр"
        case .copy: "Скопировать"
        case .share: "Поделиться..."
        case .colorTags: "Цветные теги"
        case .tags: "Теги..."
        case .quickActions: "Быстрые действия"
        case .terminal: "Терминал по адресу папки"
        case .revealInFinder: "Показать в Finder"
        case .git: "Git"
        case .create: "Создать"
        }
    }
}

enum ContextMenuPreferences {
    private static let key = "Extremum.ContextMenu.EnabledItems"

    static func isEnabled(_ item: FinderContextMenuItem) -> Bool {
        guard let stored = UserDefaults.standard.array(forKey: key) as? [String] else {
            return true
        }
        return stored.contains(item.rawValue)
    }

    static func set(_ item: FinderContextMenuItem, enabled: Bool) {
        var values = Set(enabledItems().map(\.rawValue))
        if enabled {
            values.insert(item.rawValue)
        } else {
            values.remove(item.rawValue)
        }
        UserDefaults.standard.set(Array(values), forKey: key)
    }

    static func enabledItems() -> [FinderContextMenuItem] {
        guard let stored = UserDefaults.standard.array(forKey: key) as? [String] else {
            return FinderContextMenuItem.allCases
        }
        return stored.compactMap(FinderContextMenuItem.init(rawValue:))
    }
}

enum FinderTagColor: String, CaseIterable, Identifiable {
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
    case gray = "Gray"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .red: "Красный"
        case .orange: "Оранжевый"
        case .yellow: "Желтый"
        case .green: "Зеленый"
        case .blue: "Синий"
        case .purple: "Фиолетовый"
        case .gray: "Серый"
        }
    }

    var systemColorName: String {
        switch self {
        case .red: "red"
        case .orange: "orange"
        case .yellow: "yellow"
        case .green: "green"
        case .blue: "blue"
        case .purple: "purple"
        case .gray: "gray"
        }
    }
}
