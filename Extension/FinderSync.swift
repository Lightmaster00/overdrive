import Cocoa
import FinderSync

/// Overdrive's Finder extension: adds an "Overdrive" submenu to Finder's context menu.
/// It is sandboxed: copying to the clipboard is done here, everything that touches files is
/// sent to the Overdrive app with a distributed notification (only local processes can send those).
@objc(ODFinderSync)
final class ODFinderSync: FIFinderSync {
    private static let notification = Notification.Name("com.lightmaster.overdrive.finder.action")

    private enum Item: Int, CaseIterable {
        case newTextFile, copyPath, copyName, copyURL, copyMarkdown, copyContents, terminal,
             checksum, executable, symlink, unquarantine, toggleHidden, deleteNow

        var symbol: String {
            switch self {
            case .newTextFile: return "doc.badge.plus"
            case .copyPath: return "doc.on.doc"
            case .copyName: return "textformat"
            case .copyURL: return "link"
            case .copyMarkdown: return "text.badge.plus"
            case .copyContents: return "doc.on.clipboard"
            case .terminal: return "terminal"
            case .checksum: return "number"
            case .executable: return "gearshape"
            case .symlink: return "arrowshape.turn.up.right"
            case .unquarantine: return "checkmark.shield"
            case .toggleHidden: return "eye"
            case .deleteNow: return "trash.slash"
            }
        }

        var title: String {
            switch self {
            case .newTextFile: return t("New Text File", "Nouveau fichier texte", "Nuevo archivo de texto", "Neue Textdatei", "新規テキストファイル")
            case .copyPath: return t("Copy Path", "Copier le chemin", "Copiar ruta", "Pfad kopieren", "パスをコピー")
            case .copyName: return t("Copy Name", "Copier le nom", "Copiar nombre", "Namen kopieren", "名前をコピー")
            case .copyURL: return t("Copy File URL", "Copier l'URL du fichier", "Copiar URL del archivo", "Datei-URL kopieren", "ファイル URL をコピー")
            case .copyMarkdown: return t("Copy Markdown Link", "Copier un lien Markdown", "Copiar enlace Markdown", "Markdown-Link kopieren", "Markdown リンクをコピー")
            case .copyContents: return t("Copy Text Contents", "Copier le contenu texte", "Copiar contenido de texto", "Textinhalt kopieren", "テキスト内容をコピー")
            case .terminal: return t("Open in Terminal", "Ouvrir dans le Terminal", "Abrir en Terminal", "Im Terminal öffnen", "ターミナルで開く")
            case .checksum: return t("Copy SHA-256", "Copier le SHA-256", "Copiar SHA-256", "SHA-256 kopieren", "SHA-256 をコピー")
            case .executable: return t("Make Executable", "Rendre exécutable", "Hacer ejecutable", "Ausführbar machen", "実行可能にする")
            case .symlink: return t("Make Symbolic Link", "Créer un lien symbolique", "Crear enlace simbólico", "Symbolischen Link erstellen", "シンボリックリンクを作成")
            case .unquarantine: return t("Remove Quarantine", "Retirer la quarantaine", "Quitar cuarentena", "Quarantäne entfernen", "隔離を解除")
            case .toggleHidden: return t("Show/Hide Hidden Files", "Afficher/masquer les fichiers cachés", "Mostrar/ocultar archivos ocultos", "Versteckte Dateien ein/aus", "不可視ファイルの表示切替")
            case .deleteNow: return t("Delete Immediately…", "Supprimer immédiatement…", "Eliminar inmediatamente…", "Sofort löschen …", "すぐに削除…")
            }
        }

        /// Items that need a selection (the others work on the folder too).
        var needsSelection: Bool {
            switch self {
            case .newTextFile, .terminal, .toggleHidden: return false
            default: return true
            }
        }
    }

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else { return nil }
        let hasSelection = menuKind == .contextualMenuForItems
        let submenu = NSMenu(title: "Overdrive")
        let groups: [[Item]] = [
            [.newTextFile, .terminal],
            [.copyPath, .copyName, .copyURL, .copyMarkdown, .copyContents, .checksum],
            [.executable, .symlink, .unquarantine],
            [.toggleHidden],
            [.deleteNow],
        ]
        for group in groups {
            let items = group.filter { !$0.needsSelection || hasSelection }
            guard !items.isEmpty else { continue }
            if !submenu.items.isEmpty { submenu.addItem(.separator()) }
            for item in items {
                let entry = NSMenuItem(title: item.title, action: #selector(runItem(_:)), keyEquivalent: "")
                entry.tag = item.rawValue
                entry.target = self
                entry.image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)
                submenu.addItem(entry)
            }
        }
        let menu = NSMenu(title: "")
        let root = NSMenuItem(title: "Overdrive", action: nil, keyEquivalent: "")
        root.image = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: nil)
        root.submenu = submenu
        menu.addItem(root)
        return menu
    }

    @objc private func runItem(_ sender: NSMenuItem) {
        guard let item = Item(rawValue: sender.tag) else { return }
        let controller = FIFinderSyncController.default()
        let selected = controller.selectedItemURLs() ?? []
        let target = controller.targetedURL()

        switch item {
        case .copyPath:
            copy(selected.map(\.path).joined(separator: "\n"))
        case .copyName:
            copy(selected.map(\.lastPathComponent).joined(separator: "\n"))
        case .copyURL:
            copy(selected.map(\.absoluteString).joined(separator: "\n"))
        case .copyMarkdown:
            copy(selected.map { "[\($0.lastPathComponent)](\($0.absoluteString))" }.joined(separator: "\n"))
        default:
            let action: String
            switch item {
            case .newTextFile: action = "newTextFile"
            case .terminal: action = "terminal"
            case .copyContents: action = "copyContents"
            case .checksum: action = "checksum"
            case .executable: action = "executable"
            case .symlink: action = "symlink"
            case .unquarantine: action = "unquarantine"
            case .toggleHidden: action = "toggleHidden"
            default: action = "deleteNow"
            }
            var payload: [String: Any] = ["action": action, "paths": selected.map(\.path)]
            if let target { payload["target"] = target.path }
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else { return }
            DistributedNotificationCenter.default().postNotificationName(Self.notification, object: json,
                                                                         userInfo: nil, deliverImmediately: true)
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private func t(_ en: String, _ fr: String, _ es: String, _ de: String, _ ja: String) -> String {
    for identifier in Locale.preferredLanguages {
        switch String(identifier.prefix(2)) {
        case "en": return en
        case "fr": return fr
        case "es": return es
        case "de": return de
        case "ja": return ja
        default: continue
        }
    }
    return en
}
