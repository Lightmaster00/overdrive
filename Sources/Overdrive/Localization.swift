import Foundation

/// Interface language, taken from the system language (Settings › General › Language & Region).
enum Lang: String {
    case en, fr, es, de, ja

    static let current: Lang = {
        for identifier in Locale.preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?.identifier
                ?? String(identifier.prefix(2))
            if let lang = Lang(rawValue: code) { return lang }
        }
        return .en
    }()
}

func tr(_ en: String, _ fr: String, _ es: String, _ de: String, _ ja: String) -> String {
    switch Lang.current {
    case .en: return en
    case .fr: return fr
    case .es: return es
    case .de: return de
    case .ja: return ja
    }
}

/// Every interface string (the tools' own texts are in Tools*.swift).
enum S {
    // MARK: Updates
    static var updateFailed: String { tr("Update failed", "La mise à jour a échoué", "Error al actualizar", "Aktualisierung fehlgeschlagen", "アップデートに失敗しました") }
    static var upToDate: String { tr("Overdrive is up to date", "Overdrive est à jour", "Overdrive está actualizado", "Overdrive ist aktuell", "Overdrive は最新です") }
    static func upToDateDetail(_ v: String) -> String { tr("You have the latest version (\(v)).", "Tu as la dernière version (\(v)).", "Tienes la última versión (\(v)).", "Du hast die neueste Version (\(v)).", "最新バージョン (\(v)) です。") }
    static func updateAvailable(_ v: String) -> String { tr("Overdrive \(v) is available", "Overdrive \(v) est disponible", "Overdrive \(v) está disponible", "Overdrive \(v) ist verfügbar", "Overdrive \(v) が利用可能です") }
    static func updateAvailableDetail(current: String) -> String { tr("You have version \(current). The update installs in a few seconds and Overdrive restarts.", "Tu as la version \(current). La mise à jour s'installe en quelques secondes, puis Overdrive redémarre.", "Tienes la versión \(current). La actualización se instala en unos segundos y Overdrive se reinicia.", "Du hast Version \(current). Das Update wird in Sekunden installiert, dann startet Overdrive neu.", "現在のバージョンは \(current) です。数秒でインストールされ、Overdrive が再起動します。") }
    static var installAndRestart: String { tr("Install and Restart", "Installer et redémarrer", "Instalar y reiniciar", "Installieren und neu starten", "インストールして再起動") }
    static var later: String { tr("Later", "Plus tard", "Más tarde", "Später", "後で") }
    static var skipVersion: String { tr("Skip This Version", "Ignorer cette version", "Omitir esta versión", "Diese Version überspringen", "このバージョンをスキップ") }
    static var downloadingUpdate: String { tr("Downloading the update…", "Téléchargement de la mise à jour…", "Descargando la actualización…", "Update wird geladen …", "アップデートをダウンロード中…") }
    static var installingUpdate: String { tr("Installing…", "Installation…", "Instalando…", "Installation …", "インストール中…") }
    static var restarting: String { tr("Restarting Overdrive…", "Redémarrage de Overdrive…", "Reiniciando Overdrive…", "Overdrive startet neu …", "Overdrive を再起動中…") }
    static var updateCheckFailed: String { tr("Could not check for updates", "Impossible de vérifier les mises à jour", "No se pudieron buscar actualizaciones", "Updates konnten nicht geprüft werden", "アップデートを確認できませんでした") }
    static var downloadManually: String { tr("Download Manually", "Télécharger manuellement", "Descargar manualmente", "Manuell laden", "手動でダウンロード") }
    static var updateNoAsset: String { tr("The release has no .zip file.", "La version publiée ne contient pas de fichier .zip.", "La versión no contiene un archivo .zip.", "Die Version enthält keine .zip-Datei.", "リリースに .zip ファイルがありません。") }
    static var updateBadArchive: String { tr("The downloaded archive is damaged.", "L'archive téléchargée est endommagée.", "El archivo descargado está dañado.", "Das geladene Archiv ist beschädigt.", "ダウンロードしたアーカイブが破損しています。") }
    static var updateBadSignature: String { tr("The downloaded app is not signed like this one: it was not installed.", "L'app téléchargée n'a pas la même signature que celle-ci : elle n'a pas été installée.", "La app descargada no tiene la misma firma: no se instaló.", "Die geladene App ist anders signiert und wurde nicht installiert.", "ダウンロードしたアプリの署名が一致しないため、インストールしませんでした。") }
    static func updateCannotReplace(_ folder: String) -> String { tr("Overdrive cannot write to \(folder).", "Overdrive ne peut pas écrire dans \(folder).", "Overdrive no puede escribir en \(folder).", "Overdrive kann nicht in \(folder) schreiben.", "Overdrive は \(folder) に書き込めません。") }


    // MARK: General
    static var tagline: String { tr("Power tools for your Mac", "Des super-pouvoirs pour ton Mac", "Superpoderes para tu Mac", "Power-Werkzeuge für deinen Mac", "Mac のためのパワーツール") }
    static var ok: String { "OK" }
    static var on: String { tr("On", "Activé", "Activado", "An", "オン") }
    static var off: String { tr("Off", "Désactivé", "Desactivado", "Aus", "オフ") }
    static var cancel: String { tr("Cancel", "Annuler", "Cancelar", "Abbrechen", "キャンセル") }
    static var delete: String { tr("Delete", "Supprimer", "Eliminar", "Löschen", "削除") }
    static var quit: String { tr("Quit Overdrive", "Quitter Overdrive", "Salir de Overdrive", "Overdrive beenden", "Overdrive を終了") }
    static var settingsMenu: String { tr("Settings…", "Réglages…", "Ajustes…", "Einstellungen …", "設定…") }
    static var general: String { tr("General", "Général", "General", "Allgemein", "一般") }
    static var tools: String { tr("Tools", "Outils", "Herramientas", "Werkzeuge", "ツール") }
    static var updates: String { tr("Updates", "Mises à jour", "Actualizaciones", "Updates", "アップデート") }
    static var permissions: String { tr("Permissions", "Autorisations", "Permisos", "Berechtigungen", "アクセス許可") }
    static var launchAtLogin: String { tr("Open at login", "Ouvrir à l'ouverture de session", "Abrir al iniciar sesión", "Bei Anmeldung öffnen", "ログイン時に開く") }
    static var autoCheckUpdates: String { tr("Check for updates automatically", "Rechercher les mises à jour automatiquement", "Buscar actualizaciones automáticamente", "Automatisch nach Updates suchen", "アップデートを自動確認") }
    static var checkForUpdates: String { tr("Check for Updates…", "Rechercher les mises à jour…", "Buscar actualizaciones…", "Nach Updates suchen …", "アップデートを確認…") }
    static var checkNow: String { tr("Check Now", "Vérifier", "Comprobar", "Jetzt prüfen", "今すぐ確認") }
    static func versionLabel(_ v: String) -> String { tr("Version \(v)", "Version \(v)", "Versión \(v)", "Version \(v)", "バージョン \(v)") }
    static var website: String { tr("Website", "Site web", "Sitio web", "Website", "ウェブサイト") }
    static var reportIssue: String { tr("Report a Problem", "Signaler un problème", "Informar de un problema", "Problem melden", "問題を報告") }
    static var resetShortcuts: String { tr("Remove All Shortcuts", "Supprimer tous les raccourcis", "Quitar todos los atajos", "Alle Kurzbefehle entfernen", "すべてのショートカットを削除") }
    static var defaultBrowser: String { tr("Default web browser", "Navigateur par défaut", "Navegador predeterminado", "Standardbrowser", "デフォルトの Web ブラウザ") }
    static var searchTools: String { tr("Search tools", "Rechercher un outil", "Buscar herramientas", "Werkzeuge suchen", "ツールを検索") }
    static var searchResults: String { tr("Search Results", "Résultats", "Resultados", "Ergebnisse", "検索結果") }
    static var noResults: String { tr("No tool matches.", "Aucun outil ne correspond.", "Ninguna herramienta coincide.", "Kein Werkzeug gefunden.", "一致するツールはありません。") }
    static var run: String { tr("Run", "Lancer", "Ejecutar", "Ausführen", "実行") }
    static var showInMenu: String { tr("Show in the menu bar menu", "Afficher dans le menu de la barre des menus", "Mostrar en el menú", "Im Menü anzeigen", "メニューに表示") }
    static var shortcut: String { tr("Shortcut", "Raccourci", "Atajo", "Kurzbefehl", "ショートカット") }
    static var shortcutToggles: String { tr("Shortcut to turn on or off", "Raccourci pour activer ou désactiver", "Atajo para activar o desactivar", "Kurzbefehl zum Ein-/Ausschalten", "オン／オフのショートカット") }
    static var typeShortcut: String { tr("Type shortcut…", "Tape le raccourci…", "Pulsa el atajo…", "Kurzbefehl drücken …", "キーを入力…") }
    static var none: String { tr("None", "Aucun", "Ninguno", "Keiner", "なし") }
    static var clearShortcut: String { tr("Remove shortcut", "Supprimer le raccourci", "Quitar atajo", "Kurzbefehl entfernen", "ショートカットを削除") }
    static var addApp: String { tr("Add App…", "Ajouter une app…", "Añadir app…", "App hinzufügen …", "アプリを追加…") }
    static var choose: String { tr("Choose…", "Choisir…", "Elegir…", "Wählen …", "選択…") }
    static var exceptApps: String { tr("Except these apps", "Sauf ces apps", "Excepto estas apps", "Außer diesen Apps", "除外するアプリ") }
    static var after: String { tr("After", "Après", "Después de", "Nach", "経過時間") }
    static var olderThan: String { tr("Older than", "Plus anciens que", "Más antiguos que", "Älter als", "期間") }
    static var maximum: String { tr("Maximum", "Maximum", "Máximo", "Maximum", "最大") }
    static var minutes: String { tr("min", "min", "min", "Min.", "分") }
    static var seconds: String { tr("s", "s", "s", "s", "秒") }
    static var days: String { tr("days", "jours", "días", "Tage", "日") }
    static var folder: String { tr("Folder", "Dossier", "Carpeta", "Ordner", "フォルダ") }
    static var format: String { tr("Format", "Format", "Formato", "Format", "形式") }
    static var capsAloneEscape: String { tr("Caps Lock alone acts as Escape", "Verr. Maj seule fait Échap", "Bloq Mayús sola actúa como Esc", "Feststelltaste allein = Escape", "単独で押すと Escape") }
    static var keepDisplayOn: String { tr("Keep the display on too", "Garder aussi l'écran allumé", "Mantener también la pantalla", "Auch Display anlassen", "ディスプレイもオンのまま") }
    static var notAvailable: String { tr("Not available on this Mac", "Indisponible sur ce Mac", "No disponible en este Mac", "Auf diesem Mac nicht verfügbar", "この Mac では利用できません") }

    // MARK: Permissions
    static var permAccessibility: String { tr("Accessibility", "Accessibilité", "Accesibilidad", "Bedienungshilfen", "アクセシビリティ") }
    static var permAccessibilityDetail: String { tr("For shortcuts in Finder, windows, Dock and keyboard tweaks.", "Pour les raccourcis du Finder, les fenêtres, le Dock et le clavier.", "Para Finder, ventanas, Dock y teclado.", "Für Finder, Fenster, Dock und Tastatur.", "Finder、ウインドウ、Dock、キーボード機能に必要です。") }
    static var permScreenRecording: String { tr("Screen Recording", "Enregistrement de l'écran", "Grabación de pantalla", "Bildschirmaufnahme", "画面収録") }
    static var permScreenRecordingDetail: String { tr("To read text and QR codes on the screen.", "Pour lire le texte et les QR codes à l'écran.", "Para leer texto y códigos QR.", "Um Text und QR-Codes zu lesen.", "画面上の文字や QR コードを読むために必要です。") }
    static var permAutomation: String { tr("Automation", "Automatisation", "Automatización", "Automation", "オートメーション") }
    static var permAutomationDetail: String { tr("macOS asks once for Finder and System Events, the first time a tool needs them.", "macOS demande une fois pour le Finder et System Events, la première fois qu'un outil en a besoin.", "macOS lo pide una vez para Finder y System Events.", "macOS fragt einmal für Finder und System Events.", "初回に Finder と System Events の許可を求めます。") }
    static var grant: String { tr("Allow…", "Autoriser…", "Permitir…", "Erlauben …", "許可…") }
    static var granted: String { tr("Allowed", "Autorisé", "Permitido", "Erlaubt", "許可済み") }
    static var openSettings: String { tr("Open Settings", "Ouvrir les réglages", "Abrir ajustes", "Einstellungen öffnen", "設定を開く") }
    static func needsPermission(_ p: String) -> String { tr("Needs \(p).", "Nécessite : \(p).", "Requiere: \(p).", "Benötigt: \(p).", "\(p) が必要です。") }
    static var extensionHint: String { tr("Also turn on “Overdrive” under Finder extensions.", "Active aussi « Overdrive » dans les extensions du Finder.", "Activa también «Overdrive» en las extensiones del Finder.", "Aktiviere auch „Overdrive“ bei den Finder-Erweiterungen.", "Finder 拡張機能で「Overdrive」もオンにしてください。") }
    static var openExtensionSettings: String { tr("Open Extensions…", "Ouvrir les extensions…", "Abrir extensiones…", "Erweiterungen öffnen …", "拡張機能を開く…") }

    // MARK: App shortcuts
    static var appShortcuts: String { tr("App Shortcuts", "Raccourcis d'apps", "Atajos de apps", "App-Kurzbefehle", "アプリのショートカット") }
    static var appShortcutsDetail: String { tr("A shortcut opens the app, or hides it if it's already in front.", "Un raccourci ouvre l'app, ou la masque si elle est déjà au premier plan.", "Un atajo abre la app, o la oculta si ya está delante.", "Ein Kurzbefehl öffnet die App oder blendet sie aus.", "ショートカットでアプリを開き、前面なら隠します。") }
    static var shortcutsApp: String { tr("Shortcuts", "Raccourcis", "Atajos", "Kurzbefehle", "ショートカット") }
    static var noShortcuts: String { tr("No shortcuts", "Aucun raccourci", "Sin atajos", "Keine Kurzbefehle", "ショートカットなし") }

    // MARK: Feedback
    static func itemsCut(_ n: Int) -> String { tr("\(n) item(s) cut — ⌘V to move", "\(n) élément(s) coupé(s) — ⌘V pour déplacer", "\(n) elemento(s) cortado(s) — ⌘V para mover", "\(n) Objekt(e) ausgeschnitten — ⌘V", "\(n) 項目をカット — ⌘V で移動") }
    static var untitledFileName: String { tr("untitled.txt", "sans titre.txt", "sin título.txt", "unbenannt.txt", "名称未設定.txt") }
    static var hiddenFilesShown: String { tr("Hidden files shown", "Fichiers cachés affichés", "Archivos ocultos visibles", "Versteckte Dateien sichtbar", "不可視ファイルを表示") }
    static var hiddenFilesHidden: String { tr("Hidden files hidden", "Fichiers cachés masqués", "Archivos ocultos ocultos", "Versteckte Dateien ausgeblendet", "不可視ファイルを非表示") }
    static var nothingSelected: String { tr("Nothing selected in Finder", "Rien n'est sélectionné dans le Finder", "No hay nada seleccionado", "Nichts im Finder ausgewählt", "Finder で何も選択されていません") }
    static var pathCopied: String { tr("Path copied", "Chemin copié", "Ruta copiada", "Pfad kopiert", "パスをコピーしました") }
    static func madeExecutable(_ n: Int) -> String { tr("\(n) file(s) made executable", "\(n) fichier(s) rendu(s) exécutable(s)", "\(n) archivo(s) ejecutable(s)", "\(n) Datei(en) ausführbar", "\(n) 個を実行可能にしました") }
    static func symlinkName(_ name: String) -> String { tr("\(name) symlink", "\(name) lien", "\(name) enlace", "\(name) Link", "\(name) リンク") }
    static func unquarantined(_ n: Int) -> String { tr("Quarantine removed (\(n))", "Quarantaine retirée (\(n))", "Cuarentena quitada (\(n))", "Quarantäne entfernt (\(n))", "隔離を解除 (\(n))") }
    static var contentsCopied: String { tr("Contents copied", "Contenu copié", "Contenido copiado", "Inhalt kopiert", "内容をコピーしました") }
    static var checksumCopied: String { tr("SHA-256 copied", "SHA-256 copié", "SHA-256 copiado", "SHA-256 kopiert", "SHA-256 をコピーしました") }
    static func deleteNowTitle(_ n: Int) -> String { tr("Delete \(n) item(s) immediately?", "Supprimer \(n) élément(s) immédiatement ?", "¿Eliminar \(n) elemento(s) ya?", "\(n) Objekt(e) sofort löschen?", "\(n) 項目をすぐに削除しますか？") }
    static var deleteNowDetail: String { tr("They won't go to the Trash: this can't be undone.", "Ils ne passeront pas par la corbeille : c'est irréversible.", "No irán a la Papelera: no se puede deshacer.", "Sie landen nicht im Papierkorb: nicht widerrufbar.", "ゴミ箱を経由しないため元に戻せません。") }
    static var spacerAdded: String { tr("Spacer added to the Dock", "Espace ajouté au Dock", "Espacio añadido al Dock", "Abstand hinzugefügt", "Dock にスペースを追加") }
    static func appsQuit(_ n: Int) -> String { tr("\(n) app(s) quit", "\(n) app(s) quittée(s)", "\(n) app(s) cerrada(s)", "\(n) App(s) beendet", "\(n) 個のアプリを終了") }
    static func pressAgainToQuit(_ app: String) -> String { tr("Press ⌘Q again to quit \(app)", "Appuie encore sur ⌘Q pour quitter \(app)", "Pulsa ⌘Q otra vez para salir de \(app)", "Erneut ⌘Q, um \(app) zu beenden", "もう一度 ⌘Q で \(app) を終了") }
    static func installTitle(_ app: String) -> String { tr("Install \(app)?", "Installer \(app) ?", "¿Instalar \(app)?", "\(app) installieren?", "\(app) をインストールしますか？") }
    static var installDetail: String { tr("Overdrive copies it to Applications, then ejects the disk image.", "Overdrive la copie dans Applications, puis éjecte l'image disque.", "Overdrive la copia a Aplicaciones y expulsa la imagen.", "Overdrive kopiert sie nach Programme und wirft das Image aus.", "アプリケーションにコピーしてディスクイメージを取り出します。") }
    static var installReplaceDetail: String { tr("The version in Applications goes to the Trash and is replaced.", "La version dans Applications part à la corbeille et est remplacée.", "La versión actual va a la Papelera y se reemplaza.", "Die vorhandene Version kommt in den Papierkorb.", "既存のバージョンはゴミ箱に入れて置き換えます。") }
    static var install: String { tr("Install", "Installer", "Instalar", "Installieren", "インストール") }
    static var notNow: String { tr("Not Now", "Plus tard", "Ahora no", "Später", "後で") }
    static func installFailed(_ app: String) -> String { tr("Could not install \(app)", "Impossible d'installer \(app)", "No se pudo instalar \(app)", "\(app) konnte nicht installiert werden", "\(app) をインストールできませんでした") }
    static func installed(_ app: String) -> String { tr("\(app) installed", "\(app) installée", "\(app) instalada", "\(app) installiert", "\(app) をインストールしました") }
    static var captureFailed: String { tr("Could not capture the screen", "Impossible de capturer l'écran", "No se pudo capturar la pantalla", "Bildschirm konnte nicht aufgenommen werden", "画面を取得できませんでした") }
    static var noTextFound: String { tr("No text found", "Aucun texte trouvé", "No se encontró texto", "Kein Text gefunden", "テキストが見つかりません") }
    static var textCopied: String { tr("Text copied", "Texte copié", "Texto copiado", "Text kopiert", "テキストをコピーしました") }
    static var noCodeFound: String { tr("No code found", "Aucun code trouvé", "No se encontró ningún código", "Kein Code gefunden", "コードが見つかりません") }
    static var codeCopied: String { tr("Code content copied", "Contenu du code copié", "Contenido del código copiado", "Code-Inhalt kopiert", "コードの内容をコピーしました") }
    static var colorCopied: String { tr("Color copied", "Couleur copiée", "Color copiado", "Farbe kopiert", "色をコピーしました") }
    static var noScreenshot: String { tr("No screenshot found", "Aucune capture trouvée", "No hay capturas", "Kein Bildschirmfoto gefunden", "スクリーンショットがありません") }
    static var screenshotArchiveName: String { tr("Screenshots Archive", "Archive des captures", "Archivo de capturas", "Bildschirmfoto-Archiv", "スクリーンショットのアーカイブ") }
    static var archiveFolderName: String { tr("Archive", "Archive", "Archivo", "Archiv", "アーカイブ") }
    static var micMuted: String { tr("Microphone muted", "Micro coupé", "Micrófono silenciado", "Mikrofon stumm", "マイクを消音") }
    static var micOn: String { tr("Microphone on", "Micro activé", "Micrófono activado", "Mikrofon an", "マイクをオン") }
    static var soundMuted: String { tr("Sound muted", "Son coupé", "Sonido silenciado", "Ton aus", "消音") }
    static var soundOn: String { tr("Sound on", "Son rétabli", "Sonido activado", "Ton an", "サウンドオン") }
    static var clipboardCleared: String { tr("Clipboard cleared", "Presse-papiers vidé", "Portapapeles vaciado", "Zwischenablage geleert", "クリップボードを消去") }
    static var emptyTrashTitle: String { tr("Empty the Trash?", "Vider la corbeille ?", "¿Vaciar la Papelera?", "Papierkorb entleeren?", "ゴミ箱を空にしますか？") }
    static var emptyTrashDetail: String { tr("Its items will be deleted for good.", "Son contenu sera supprimé définitivement.", "Su contenido se eliminará definitivamente.", "Der Inhalt wird endgültig gelöscht.", "項目は完全に削除されます。") }
    static var emptyTrash: String { tr("Empty Trash", "Vider", "Vaciar", "Entleeren", "空にする") }
    static func disksEjected(_ n: Int) -> String { tr("\(n) disk(s) ejected", "\(n) disque(s) éjecté(s)", "\(n) disco(s) expulsado(s)", "\(n) Volume(s) ausgeworfen", "\(n) 個のディスクを取り出しました") }
    static var hotCornersOff: String { tr("Hot Corners off", "Coins actifs désactivés", "Esquinas activas desactivadas", "Aktive Ecken aus", "ホットコーナーをオフ") }
    static var hotCornersOn: String { tr("Hot Corners restored", "Coins actifs rétablis", "Esquinas activas restauradas", "Aktive Ecken wiederhergestellt", "ホットコーナーを復元") }
    static var dnsFlushed: String { tr("DNS cache flushed", "Cache DNS vidé", "Caché DNS vaciada", "DNS-Cache geleert", "DNS キャッシュを消去しました") }
    static var keepAwakeOn: String { tr("Mac stays awake", "Le Mac reste éveillé", "El Mac seguirá despierto", "Mac bleibt wach", "スリープしません") }
    static var keepAwakeOff: String { tr("Mac can sleep again", "Le Mac peut de nouveau se mettre en veille", "El Mac puede dormir", "Mac darf wieder schlafen", "スリープ可能に戻しました") }
    static var cleaningMode: String { tr("Cleaning Mode", "Mode nettoyage", "Modo limpieza", "Reinigungsmodus", "クリーニングモード") }
    static var catMode: String { tr("Cat Mode", "Mode chat", "Modo gato", "Katzenmodus", "ネコモード") }
    static var holdEscape: String { tr("Keyboard and mouse are locked. Hold Esc for 2 seconds to leave.", "Clavier et souris bloqués. Garde Échap enfoncée 2 secondes pour sortir.", "Teclado y ratón bloqueados. Mantén Esc 2 segundos para salir.", "Tastatur und Maus gesperrt. Esc 2 Sekunden halten zum Beenden.", "入力はロック中。Esc を 2 秒押すと終了します。") }
    static var notificationsCleared: String { tr("Notifications cleared", "Notifications effacées", "Notificaciones borradas", "Mitteilungen gelöscht", "通知を消去しました") }
    static var noNotifications: String { tr("No notification to clear", "Aucune notification à effacer", "No hay notificaciones", "Keine Mitteilungen", "消去する通知はありません") }
}
