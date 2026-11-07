import AppKit

/// Every tool of Overdrive, in the order shown in the settings and the menu.
@MainActor
enum ToolCatalog {
    static func all() -> [Tool] {
        finder() + windows() + dock() + apps() + keyboard() + mouse() + screen() + screenshots()
            + audio() + clipboard() + files() + display() + system() + utilities()
    }

    private static func action(_ id: String, _ category: ToolCategory, _ symbol: String, _ title: String, _ detail: String,
                               inMenu: Bool = true, perms: [Permission] = [], perform: @escaping @MainActor () -> Void) -> Tool {
        Tool(id, category, .action, symbol: symbol, title: title, detail: detail).with {
            $0.defaultOn = inMenu
            $0.permissions = perms
            $0.perform = perform
        }
    }

    private static func tweak(_ id: String, _ category: ToolCategory, _ symbol: String, _ title: String, _ detail: String,
                              perms: [Permission] = [], beta: Bool = false, options: [ToolOption] = [],
                              start: @escaping @MainActor () -> Void, stop: @escaping @MainActor () -> Void) -> Tool {
        Tool(id, category, .tweak, symbol: symbol, title: title, detail: detail).with {
            $0.permissions = perms
            $0.beta = beta
            $0.options = options
            $0.start = start
            $0.stop = stop
        }
    }

    // MARK: Finder

    private static func finder() -> [Tool] {
        [
            tweak("finder.cutPaste", .finder, "scissors",
                  tr("Cut and paste files", "Couper-coller les fichiers", "Cortar y pegar archivos", "Dateien ausschneiden und einfügen", "ファイルのカット＆ペースト"),
                  tr("⌘X then ⌘V moves the selected files, like on Windows.", "⌘X puis ⌘V déplace les fichiers sélectionnés, comme sous Windows.", "⌘X y luego ⌘V mueve los archivos, como en Windows.", "⌘X und dann ⌘V verschiebt die Dateien, wie unter Windows.", "⌘X → ⌘V で選択したファイルを移動します（Windows と同じ）。"),
                  perms: [.accessibility, .automation], start: FinderTools.startCutPaste, stop: FinderTools.stopCutPaste),
            tweak("finder.returnOpens", .finder, "return",
                  tr("Return opens, F2 renames", "Entrée ouvre, F2 renomme", "Intro abre, F2 renombra", "Eingabe öffnet, F2 benennt um", "Return で開き F2 で名前変更"),
                  tr("Return opens the selection; Shift-Return or F2 renames it.", "Entrée ouvre la sélection ; Maj-Entrée ou F2 la renomme.", "Intro abre la selección; Mayús-Intro o F2 la renombra.", "Eingabe öffnet; Umschalt-Eingabe oder F2 benennt um.", "Return で開き、Shift-Return または F2 で名前を変更します。"),
                  perms: [.accessibility], start: FinderTools.startReturnOpens, stop: FinderTools.stopReturnOpens),
            tweak("finder.deleteToTrash", .finder, "trash",
                  tr("Delete key moves to Trash", "Touche Effacer : mettre à la corbeille", "Tecla Borrar envía a la Papelera", "Löschtaste legt in den Papierkorb", "Delete キーでゴミ箱へ"),
                  tr("No need for ⌘⌫.", "Plus besoin de ⌘⌫.", "Sin necesidad de ⌘⌫.", "Ohne ⌘⌫.", "⌘⌫ は不要です。"),
                  perms: [.accessibility], start: FinderTools.startDeleteToTrash, stop: FinderTools.stopDeleteToTrash),
            tweak("finder.newTextFile", .finder, "doc.badge.plus",
                  tr("⌥N creates a text file", "⌥N crée un fichier texte", "⌥N crea un archivo de texto", "⌥N erstellt eine Textdatei", "⌥N でテキストファイルを作成"),
                  tr("Creates an empty text file in the current folder and lets you name it.", "Crée un fichier texte vide dans le dossier ouvert et te laisse le nommer.", "Crea un archivo de texto vacío en la carpeta actual.", "Erstellt eine leere Textdatei im aktuellen Ordner.", "現在のフォルダに空のテキストファイルを作成します。"),
                  perms: [.accessibility, .automation], start: FinderTools.startNewFileShortcut, stop: FinderTools.stopNewFileShortcut),
            tweak("finder.openWindow", .finder, "macwindow.badge.plus",
                  tr("Open a window when Finder is activated", "Ouvrir une fenêtre quand le Finder est activé", "Abrir una ventana al activar el Finder", "Fenster öffnen, wenn der Finder aktiviert wird", "Finder をアクティブにしたらウインドウを開く"),
                  tr("From the Dock or ⌘Tab, when no Finder window is open (not when clicking the desktop).", "Depuis le Dock ou ⌘Tab, s'il n'y a aucune fenêtre (pas en cliquant sur le bureau).", "Desde el Dock o ⌘Tab, si no hay ventanas (no al hacer clic en el escritorio).", "Über Dock oder ⌘Tab, wenn kein Fenster offen ist (nicht beim Klick auf den Schreibtisch).", "Dock や ⌘Tab から開いたとき（デスクトップのクリックは除く）。"),
                  perms: [.accessibility, .automation], start: FinderTools.startOpenWindowOnActivate, stop: FinderTools.stopOpenWindowOnActivate),
            tweak("finder.extension", .finder, "contextualmenu.and.cursorarrow",
                  tr("Context menu actions", "Actions du menu contextuel", "Acciones del menú contextual", "Kontextmenü-Aktionen", "コンテキストメニューのアクション"),
                  tr("Right-click › Overdrive: new text file, copy path or name, Markdown link, open in Terminal, SHA-256, make executable, symlink, unquarantine, hidden files, delete immediately. Turn it on in System Settings › Login Items & Extensions too.", "Clic droit › Overdrive : nouveau fichier texte, copier le chemin ou le nom, lien Markdown, ouvrir dans le Terminal, SHA-256, rendre exécutable, lien symbolique, retirer la quarantaine, fichiers cachés, supprimer immédiatement. À activer aussi dans Réglages Système › Ouverture et extensions.", "Clic derecho › Overdrive: nuevo archivo, copiar ruta, enlace Markdown, Terminal, SHA-256, ejecutable, enlace simbólico, quitar cuarentena, archivos ocultos, eliminar ya. Actívalo también en Ajustes del Sistema.", "Rechtsklick › Overdrive: neue Textdatei, Pfad kopieren, Markdown-Link, Terminal, SHA-256, ausführbar, Symlink, Quarantäne entfernen, versteckte Dateien, sofort löschen. Auch in den Systemeinstellungen aktivieren.", "右クリック › Overdrive：新規テキスト、パスのコピー、Markdown リンク、ターミナル、SHA-256、実行可能化、シンボリックリンク、隔離解除、不可視ファイル、即時削除。システム設定でも有効にしてください。"),
                  start: FinderTools.startExtension, stop: FinderTools.stopExtension),
            action("finder.copyPath", .finder, "doc.on.doc",
                   tr("Copy path of selection", "Copier le chemin de la sélection", "Copiar ruta de la selección", "Pfad der Auswahl kopieren", "選択項目のパスをコピー"),
                   tr("Copies the full path of the selected Finder items.", "Copie le chemin complet des éléments sélectionnés dans le Finder.", "Copia la ruta completa de los elementos seleccionados.", "Kopiert den vollständigen Pfad der ausgewählten Objekte.", "選択した項目のフルパスをコピーします。"),
                   inMenu: false, perms: [.automation], perform: FinderTools.copyPathOfSelection),
            action("finder.terminal", .finder, "terminal",
                   tr("Open Terminal here", "Ouvrir le Terminal ici", "Abrir Terminal aquí", "Terminal hier öffnen", "ここでターミナルを開く"),
                   tr("Opens Terminal in the folder shown in Finder.", "Ouvre le Terminal dans le dossier affiché par le Finder.", "Abre Terminal en la carpeta del Finder.", "Öffnet Terminal im Finder-Ordner.", "Finder のフォルダでターミナルを開きます。"),
                   inMenu: false, perms: [.automation], perform: FinderTools.openTerminalHere),
            action("finder.toggleHidden", .finder, "eye",
                   tr("Show hidden files", "Afficher les fichiers cachés", "Mostrar archivos ocultos", "Versteckte Dateien zeigen", "不可視ファイルを表示"),
                   tr("Shows or hides hidden files everywhere in Finder.", "Affiche ou masque les fichiers cachés dans tout le Finder.", "Muestra u oculta los archivos ocultos.", "Zeigt oder verbirgt versteckte Dateien.", "Finder の不可視ファイルを表示／非表示にします。"),
                   perform: FinderTools.toggleHiddenFiles).with { $0.state = { FinderTools.hiddenFilesShown } },
            action("finder.toggle", .finder, "folder",
                   tr("Show or hide Finder", "Afficher ou masquer le Finder", "Mostrar u ocultar el Finder", "Finder zeigen/ausblenden", "Finder の表示／非表示"),
                   tr("Best with a shortcut.", "Idéal avec un raccourci.", "Ideal con un atajo.", "Am besten mit Kurzbefehl.", "ショートカットでの利用がおすすめ。"),
                   inMenu: false, perform: FinderTools.toggleFinder),
        ]
    }

    // MARK: Windows

    private static func windows() -> [Tool] {
        [
            action("windows.hideAll", .windows, "eye.slash",
                   tr("Hide all windows", "Masquer toutes les fenêtres", "Ocultar todas las ventanas", "Alle Fenster ausblenden", "すべてのウインドウを隠す"),
                   tr("Hides every app to show the desktop.", "Masque toutes les apps pour montrer le bureau.", "Oculta todas las apps para ver el escritorio.", "Blendet alle Apps aus und zeigt den Schreibtisch.", "すべてのアプリを隠してデスクトップを表示します。"),
                   perform: WindowTools.hideAll),
            action("windows.hideOthers", .windows, "rectangle.on.rectangle.slash",
                   tr("Isolate the front app", "Isoler l'app au premier plan", "Aislar la app activa", "Vordere App isolieren", "前面のアプリだけを表示"),
                   tr("Hides every other app.", "Masque toutes les autres apps.", "Oculta las demás apps.", "Blendet alle anderen Apps aus.", "他のアプリをすべて隠します。"),
                   perform: WindowTools.hideOthers),
            action("windows.minimizeAll", .windows, "arrow.down.right.and.arrow.up.left",
                   tr("Minimize all windows", "Réduire toutes les fenêtres", "Minimizar todas las ventanas", "Alle Fenster im Dock ablegen", "すべてのウインドウをしまう"),
                   tr("Sends every window to the Dock.", "Envoie toutes les fenêtres dans le Dock.", "Envía todas las ventanas al Dock.", "Legt alle Fenster im Dock ab.", "すべてのウインドウを Dock にしまいます。"),
                   inMenu: false, perms: [.accessibility]) { WindowTools.minimizeAll(exceptFront: false) },
            action("windows.minimizeOthers", .windows, "rectangle.2.swap",
                   tr("Minimize all but the front app", "Réduire tout sauf l'app au premier plan", "Minimizar todo salvo la app activa", "Alles außer der vorderen App ablegen", "前面以外をしまう"),
                   tr("Keeps only the windows of the app you're using.", "Garde seulement les fenêtres de l'app utilisée.", "Deja solo las ventanas de la app activa.", "Nur die Fenster der aktiven App bleiben.", "使用中のアプリのウインドウだけを残します。"),
                   inMenu: false, perms: [.accessibility]) { WindowTools.minimizeAll(exceptFront: true) },
            action("windows.unminimize", .windows, "arrow.up.left.and.arrow.down.right",
                   tr("Restore the front app's windows", "Restaurer les fenêtres de l'app", "Restaurar las ventanas de la app", "Fenster der App wiederherstellen", "前面アプリのウインドウを戻す"),
                   tr("Brings back its minimized windows.", "Ramène ses fenêtres réduites dans le Dock.", "Recupera sus ventanas minimizadas.", "Holt abgelegte Fenster zurück.", "しまったウインドウを戻します。"),
                   inMenu: false, perms: [.accessibility], perform: WindowTools.unminimizeFrontApp),
            action("windows.center", .windows, "rectangle.center.inset.filled",
                   tr("Center the front window", "Centrer la fenêtre", "Centrar la ventana", "Fenster zentrieren", "ウインドウを中央に"),
                   tr("Moves it to the middle of its screen.", "La place au milieu de son écran.", "La coloca en el centro de la pantalla.", "Setzt es in die Bildschirmmitte.", "画面の中央に移動します。"),
                   inMenu: false, perms: [.accessibility], perform: WindowTools.centerFrontWindow),
            action("windows.fill", .windows, "rectangle.inset.filled",
                   tr("Fill the screen with the front window", "Remplir l'écran avec la fenêtre", "Llenar la pantalla con la ventana", "Fenster bildschirmfüllend", "ウインドウを画面いっぱいに"),
                   tr("Without full screen mode; again to restore.", "Sans mode plein écran ; une deuxième fois pour revenir.", "Sin pantalla completa; otra vez para restaurar.", "Ohne Vollbild; erneut zum Zurücksetzen.", "フルスクリーンにせず拡大。もう一度で元に戻ります。"),
                   inMenu: false, perms: [.accessibility], perform: WindowTools.fillFrontWindow),
            tweak("windows.greenFills", .windows, "plus.circle",
                  tr("Green button fills the screen", "Le bouton vert remplit l'écran", "El botón verde llena la pantalla", "Grüne Taste füllt den Bildschirm", "緑ボタンで画面いっぱいに"),
                  tr("Instead of full screen mode. Hold ⌥ for the usual behavior.", "Au lieu du mode plein écran. Garde ⌥ pour le comportement habituel.", "En lugar de pantalla completa. Mantén ⌥ para lo habitual.", "Statt Vollbild. ⌥ für das normale Verhalten.", "フルスクリーンの代わりに拡大。⌥ で通常動作。"),
                  perms: [.accessibility], start: WindowTools.startButtonTweaks, stop: WindowTools.stopButtonTweaksIfUnused),
            tweak("windows.yellowHides", .windows, "minus.circle",
                  tr("Yellow button hides the app", "Le bouton jaune masque l'app", "El botón amarillo oculta la app", "Gelbe Taste blendet die App aus", "黄ボタンでアプリを隠す"),
                  tr("Instead of minimizing the window. Hold ⌥ for the usual behavior.", "Au lieu de réduire la fenêtre. Garde ⌥ pour le comportement habituel.", "En lugar de minimizar. Mantén ⌥ para lo habitual.", "Statt Ablegen. ⌥ für das normale Verhalten.", "しまう代わりに隠します。⌥ で通常動作。"),
                  perms: [.accessibility], start: WindowTools.startButtonTweaks, stop: WindowTools.stopButtonTweaksIfUnused),
            tweak("windows.unminimizeOnActivate", .windows, "macwindow",
                  tr("Restore minimized windows when switching", "Restaurer les fenêtres réduites en changeant d'app", "Restaurar ventanas al cambiar de app", "Abgelegte Fenster beim Wechsel zurückholen", "切り替え時にしまったウインドウを戻す"),
                  tr("⌘Tab to an app whose windows are all in the Dock brings them back.", "⌘Tab vers une app dont toutes les fenêtres sont dans le Dock les ramène.", "⌘Tab a una app con todo minimizado las recupera.", "⌘Tab zu einer App mit nur abgelegten Fenstern holt sie zurück.", "すべてしまわれたアプリに ⌘Tab すると戻します。"),
                  perms: [.accessibility], start: WindowTools.startUnminimizeOnActivate, stop: WindowTools.stopUnminimizeOnActivate),
        ]
    }

    // MARK: Dock

    private static func dock() -> [Tool] {
        [
            tweak("dock.clickToHide", .dock, "cursorarrow.click",
                  tr("Click the active app's icon to hide it", "Cliquer sur l'icône de l'app active la masque", "Clic en el icono de la app activa la oculta", "Klick aufs Symbol der aktiven App blendet sie aus", "アクティブなアプリのアイコンをクリックで隠す"),
                  tr("Like the Windows taskbar.", "Comme la barre des tâches de Windows.", "Como la barra de tareas de Windows.", "Wie die Windows-Taskleiste.", "Windows のタスクバーと同じ。"),
                  perms: [.accessibility], start: DockTools.startClickToHide, stop: DockTools.stopClickToHide),
            tweak("dock.noDelay", .dock, "timer",
                  tr("Show the hidden Dock instantly", "Afficher le Dock masqué sans délai", "Mostrar el Dock oculto al instante", "Ausgeblendetes Dock sofort zeigen", "隠した Dock をすぐ表示"),
                  tr("Removes the delay before an automatically hidden Dock appears.", "Supprime le délai avant l'apparition du Dock masqué automatiquement.", "Quita el retraso del Dock oculto.", "Entfernt die Verzögerung des ausgeblendeten Docks.", "自動的に隠れる Dock の遅延をなくします。"),
                  start: { DockTools.setNoDelay(true) }, stop: { DockTools.setNoDelay(false) }),
            action("dock.spacer", .dock, "rectangle.split.3x1",
                   tr("Add a spacer to the Dock", "Ajouter un espace au Dock", "Añadir un espacio al Dock", "Abstand zum Dock hinzufügen", "Dock にスペースを追加"),
                   tr("Drag it where you want; drag it out to remove it.", "Glisse-le où tu veux ; sors-le du Dock pour le retirer.", "Arrástralo; sácalo para quitarlo.", "Verschieben oder herausziehen zum Entfernen.", "ドラッグで移動、外へ出すと削除。"),
                   inMenu: false) { DockTools.addSpacer(small: false) },
            action("dock.smallSpacer", .dock, "rectangle.split.3x1",
                   tr("Add a small spacer to the Dock", "Ajouter un petit espace au Dock", "Añadir un espacio pequeño", "Kleinen Abstand hinzufügen", "小さなスペースを追加"),
                   tr("Half the width of an icon.", "La moitié de la largeur d'une icône.", "La mitad de un icono.", "Halbe Symbolbreite.", "アイコンの半分の幅。"),
                   inMenu: false) { DockTools.addSpacer(small: true) },
        ]
    }

    // MARK: Apps

    private static func apps() -> [Tool] {
        [
            tweak("apps.quitGuard", .apps, "hand.raised",
                  tr("Press ⌘Q twice to quit", "Appuyer deux fois sur ⌘Q pour quitter", "Pulsar ⌘Q dos veces para salir", "⌘Q zweimal zum Beenden", "⌘Q を 2 回押して終了"),
                  tr("No more apps quit by accident.", "Fini les apps quittées par erreur.", "Se acabaron los cierres accidentales.", "Kein versehentliches Beenden mehr.", "誤って終了するのを防ぎます。"),
                  perms: [.accessibility], options: [.apps(key: "quitGuardExclusions", title: S.exceptApps)],
                  start: AppTools.startQuitGuard, stop: AppTools.stopQuitGuard),
            action("apps.quitAll", .apps, "xmark.circle",
                   tr("Quit all apps", "Quitter toutes les apps", "Salir de todas las apps", "Alle Apps beenden", "すべてのアプリを終了"),
                   tr("Except Finder and the apps you exclude.", "Sauf le Finder et les apps exclues.", "Excepto el Finder y las excluidas.", "Außer Finder und ausgeschlossenen Apps.", "Finder と除外したアプリ以外。"),
                   inMenu: true, perform: { AppTools.quitAll(exceptFront: false) }).with {
                $0.options = [.apps(key: "quitExclusions", title: S.exceptApps)]
            },
            action("apps.quitOthers", .apps, "xmark.circle.fill",
                   tr("Quit all apps but the front one", "Quitter toutes les apps sauf celle au premier plan", "Salir de todas salvo la activa", "Alle außer der vorderen App beenden", "前面以外のアプリを終了"),
                   tr("Same exclusions as above.", "Mêmes exclusions que ci-dessus.", "Mismas exclusiones.", "Gleiche Ausnahmen.", "上と同じ除外設定。"),
                   inMenu: false, perform: { AppTools.quitAll(exceptFront: true) }),
            tweak("apps.autoHide", .apps, "clock.arrow.circlepath",
                  tr("Hide inactive apps", "Masquer les apps inactives", "Ocultar apps inactivas", "Inaktive Apps ausblenden", "使っていないアプリを隠す"),
                  tr("Hides apps you haven't used for a while.", "Masque les apps que tu n'as pas utilisées depuis un moment.", "Oculta las apps que no usas desde hace un rato.", "Blendet länger nicht genutzte Apps aus.", "しばらく使っていないアプリを隠します。"),
                  options: [.number(key: "autoHideMinutes", title: S.after, range: 1...240, step: 1, defaultValue: 10, unit: S.minutes),
                            .apps(key: "autoHideExclusions", title: S.exceptApps)],
                  start: AppTools.startAutoHide, stop: AppTools.stopAutoHide),
            tweak("apps.dmgInstall", .apps, "externaldrive.badge.plus",
                  tr("Offer to install apps from disk images", "Proposer d'installer les apps des images disque", "Ofrecer instalar apps de imágenes de disco", "Installation aus Disk-Images anbieten", "ディスクイメージのアプリをインストール"),
                  tr("Opening a DMG with an app offers to copy it to Applications and eject the disk.", "À l'ouverture d'un DMG, propose de copier l'app dans Applications puis d'éjecter le disque.", "Al abrir un DMG, ofrece copiar la app a Aplicaciones.", "Beim Öffnen eines DMG: App nach Programme kopieren und auswerfen.", "DMG を開くとアプリをアプリケーションにコピーして取り出します。"),
                  start: AppTools.startDMGInstall, stop: AppTools.stopDMGInstall),
            tweak("apps.stopMusic", .apps, "music.note",
                  tr("Stop Music from opening by itself", "Empêcher Musique de s'ouvrir tout seul", "Evitar que Música se abra sola", "Musik nicht von selbst öffnen", "ミュージックの自動起動を止める"),
                  tr("After the Play key or when headphones connect.", "Après la touche Lecture ou à la connexion d'un casque.", "Tras la tecla Reproducir o al conectar auriculares.", "Nach der Play-Taste oder beim Verbinden von Kopfhörern.", "再生キーやヘッドフォン接続のあと。"),
                  perms: [.accessibility], start: AppTools.startStopMusic, stop: AppTools.stopStopMusic),
        ]
    }

    // MARK: Keyboard and mouse

    private static func keyboard() -> [Tool] {
        [
            tweak("keyboard.hyper", .keyboard, "capslock",
                  tr("Hyper key", "Touche Hyper", "Tecla Hyper", "Hyper-Taste", "Hyper キー"),
                  tr("Caps Lock becomes ⌃⌥⇧⌘: a modifier of its own for your shortcuts.", "Verr. Maj devient ⌃⌥⇧⌘ : un modificateur rien qu'à toi pour tes raccourcis.", "Bloq Mayús pasa a ser ⌃⌥⇧⌘ para tus atajos.", "Feststelltaste wird zu ⌃⌥⇧⌘ für eigene Kurzbefehle.", "Caps Lock を ⌃⌥⇧⌘ として使います。"),
                  perms: [.accessibility],
                  options: [.toggle(key: "keyboard.hyper.escape", title: S.capsAloneEscape, defaultValue: true)],
                  start: KeyboardTools.startHyper, stop: KeyboardTools.stopHyper),
            tweak("keyboard.capsDelay", .keyboard, "bolt",
                  tr("Remove the Caps Lock delay", "Supprimer le délai de Verr. Maj", "Quitar el retraso de Bloq Mayús", "Feststelltasten-Verzögerung entfernen", "Caps Lock の遅延をなくす"),
                  tr("Caps Lock turns on with a quick tap.", "Verr. Maj s'active avec un appui rapide.", "Se activa con una pulsación rápida.", "Aktiviert sich mit kurzem Tippen.", "短く押すだけでオンになります。"),
                  start: { KeyboardTools.setCapsLockDelay(removed: true) }, stop: { KeyboardTools.setCapsLockDelay(removed: false) }),
            tweak("keyboard.safariDelete", .keyboard, "safari",
                  tr("Delete goes back in Safari", "Effacer revient en arrière dans Safari", "Borrar vuelve atrás en Safari", "Löschtaste geht in Safari zurück", "Safari で Delete で戻る"),
                  tr("Shift-Delete goes forward.", "Maj-Effacer avance.", "Mayús-Borrar avanza.", "Umschalt-Löschen geht vorwärts.", "Shift-Delete で進む。"),
                  perms: [.accessibility], start: KeyboardTools.startSafariDelete, stop: KeyboardTools.stopSafariDelete),
            tweak("keyboard.sound", .keyboard, "speaker.wave.1",
                  tr("Play a sound when a shortcut runs", "Jouer un son quand un raccourci s'exécute", "Sonido al usar un atajo", "Ton bei Kurzbefehlen", "ショートカット実行時に音を鳴らす"),
                  tr("For Overdrive's shortcuts.", "Pour les raccourcis d'Overdrive.", "Para los atajos de Overdrive.", "Für Overdrive-Kurzbefehle.", "Overdrive のショートカット用。"),
                  start: { Prefs.playSoundOnShortcut = true }, stop: { Prefs.playSoundOnShortcut = false }),
        ]
    }

    private static func mouse() -> [Tool] {
        [
            tweak("mouse.middleClick", .mouse, "hand.tap",
                  tr("Three-finger click = middle click", "Clic à trois doigts = clic du milieu", "Clic con tres dedos = clic central", "Drei-Finger-Klick = Mittelklick", "3 本指クリックで中クリック"),
                  tr("Opens links in a new tab, closes tabs… on the trackpad.", "Ouvre les liens dans un onglet, ferme les onglets… au trackpad.", "Abre enlaces en pestañas, cierra pestañas…", "Links in neuem Tab öffnen, Tabs schließen …", "リンクを新しいタブで開くなど。"),
                  perms: [.accessibility], beta: true, start: MouseTools.startMiddleClick, stop: MouseTools.stopMiddleClick),
            tweak("mouse.centerOnWake", .mouse, "scope",
                  tr("Center the pointer after wake", "Centrer le pointeur au réveil", "Centrar el puntero al despertar", "Zeiger nach dem Aufwachen zentrieren", "スリープ解除時にポインタを中央へ"),
                  tr("Also after unlocking: easy to find on large screens.", "Aussi au déverrouillage : facile à retrouver sur un grand écran.", "También al desbloquear.", "Auch nach dem Entsperren.", "ロック解除後も。大画面で見つけやすく。"),
                  start: MouseTools.startCenterOnWake, stop: MouseTools.stopCenterOnWake),
        ]
    }

    // MARK: Screen

    private static func screen() -> [Tool] {
        [
            action("screen.ocr", .screen, "text.viewfinder",
                   tr("Copy text from the screen", "Copier du texte à l'écran", "Copiar texto de la pantalla", "Text vom Bildschirm kopieren", "画面のテキストをコピー"),
                   tr("Select an area: its text is recognized and copied, in any language.", "Sélectionne une zone : son texte est reconnu et copié, dans toutes les langues.", "Selecciona una zona: su texto se reconoce y copia.", "Bereich wählen: Text wird erkannt und kopiert.", "範囲を選ぶと文字を認識してコピーします。"),
                   perms: [.screenRecording], perform: ScreenTools.captureText),
            action("screen.codes", .screen, "qrcode.viewfinder",
                   tr("Scan a QR code or barcode", "Lire un QR code ou un code-barres", "Leer un código QR o de barras", "QR- oder Strichcode lesen", "QR コード／バーコードを読む"),
                   tr("Select the area: the content is copied.", "Sélectionne la zone : le contenu est copié.", "Selecciona la zona: se copia el contenido.", "Bereich wählen: Inhalt wird kopiert.", "範囲を選ぶと内容をコピーします。"),
                   perms: [.screenRecording], perform: ScreenTools.scanCodes),
            action("screen.color", .screen, "eyedropper",
                   tr("Pick a color", "Prélever une couleur", "Elegir un color", "Farbe aufnehmen", "色を取得"),
                   tr("Copies the color under the pointer.", "Copie la couleur sous le pointeur.", "Copia el color bajo el puntero.", "Kopiert die Farbe unter dem Zeiger.", "ポインタの下の色をコピーします。"),
                   perform: ScreenTools.pickColor).with {
                $0.options = [.choice(key: "colorFormat", title: S.format, values: ColorFormat.all, defaultValue: "hex")]
            },
        ]
    }

    private static func screenshots() -> [Tool] {
        [
            tweak("screenshots.copy", .screenshots, "doc.on.clipboard",
                  tr("Copy new screenshots", "Copier les nouvelles captures", "Copiar capturas nuevas", "Neue Bildschirmfotos kopieren", "新しいスクリーンショットをコピー"),
                  tr("Every screenshot is saved and also put on the clipboard.", "Chaque capture est enregistrée et aussi copiée dans le presse-papiers.", "Cada captura se guarda y se copia.", "Jedes Bildschirmfoto wird gesichert und kopiert.", "保存と同時にクリップボードにも入れます。"),
                  start: ScreenshotTools.startAutoCopy, stop: ScreenshotTools.stopAutoCopy),
            action("screenshots.latest", .screenshots, "photo",
                   tr("Open the latest screenshot", "Ouvrir la dernière capture", "Abrir la última captura", "Letztes Bildschirmfoto öffnen", "最新のスクリーンショットを開く"),
                   tr("In its default app.", "Dans son app par défaut.", "En su app predeterminada.", "In der Standard-App.", "既定のアプリで開きます。"),
                   inMenu: false, perform: ScreenshotTools.openLatest),
            tweak("screenshots.cursor", .screenshots, "cursorarrow",
                  tr("Show the pointer in screenshots", "Afficher le pointeur dans les captures", "Mostrar el puntero en capturas", "Zeiger in Bildschirmfotos", "スクリーンショットにポインタを含める"),
                  tr("For tutorials.", "Pour les tutoriels.", "Para tutoriales.", "Für Anleitungen.", "チュートリアル向け。"),
                  start: { ScreenshotTools.setSetting("showsCursor", true) }, stop: { ScreenshotTools.setSetting("showsCursor", false) }),
            tweak("screenshots.noThumbnail", .screenshots, "rectangle.badge.xmark",
                  tr("Save screenshots instantly", "Enregistrer les captures immédiatement", "Guardar capturas al instante", "Bildschirmfotos sofort sichern", "すぐに保存する"),
                  tr("Without the floating thumbnail.", "Sans la vignette flottante.", "Sin la miniatura flotante.", "Ohne schwebende Miniatur.", "フローティングサムネールなし。"),
                  start: { ScreenshotTools.setSetting("show-thumbnail", false) }, stop: { ScreenshotTools.setSetting("show-thumbnail", true) }),
            tweak("screenshots.archive", .screenshots, "archivebox",
                  tr("Archive old screenshots", "Archiver les anciennes captures", "Archivar capturas antiguas", "Alte Bildschirmfotos archivieren", "古いスクリーンショットを整理"),
                  tr("Moves them to a “Screenshots Archive” folder.", "Les range dans un dossier « Archive des captures ».", "Las mueve a una carpeta de archivo.", "Verschiebt sie in einen Archivordner.", "アーカイブフォルダに移動します。"),
                  options: [.number(key: "screenshotDays", title: S.olderThan, range: 1...365, step: 1, defaultValue: 7, unit: S.days)],
                  start: ScreenshotTools.startArchive, stop: ScreenshotTools.stopArchive),
        ]
    }

    // MARK: Audio and clipboard

    private static func audio() -> [Tool] {
        [
            action("audio.mute", .audio, "speaker.slash",
                   tr("Mute sound", "Couper le son", "Silenciar", "Ton aus", "消音"),
                   tr("Of the current output.", "De la sortie actuelle.", "De la salida actual.", "Der aktuellen Ausgabe.", "現在の出力。"),
                   perform: { AudioTools.toggleMute(input: false) }).with { $0.state = { AudioTools.isMuted(input: false) } },
            action("audio.mic", .audio, "mic.slash",
                   tr("Mute the microphone", "Couper le micro", "Silenciar el micrófono", "Mikrofon stumm", "マイクを消音"),
                   tr("For calls: best with a shortcut.", "Pour les appels : idéal avec un raccourci.", "Para llamadas: ideal con un atajo.", "Für Anrufe, am besten per Kurzbefehl.", "通話用。ショートカットがおすすめ。"),
                   perform: { AudioTools.toggleMute(input: true) }).with { $0.state = { AudioTools.isMuted(input: true) } },
            action("audio.nextOutput", .audio, "hifispeaker",
                   tr("Next sound output", "Sortie audio suivante", "Siguiente salida de audio", "Nächste Tonausgabe", "次の出力"),
                   tr("Speakers, headphones, AirPods…", "Haut-parleurs, casque, AirPods…", "Altavoces, auriculares, AirPods…", "Lautsprecher, Kopfhörer, AirPods …", "スピーカー、ヘッドフォン、AirPods…"),
                   inMenu: false) { AudioTools.cycle(input: false) },
            action("audio.nextInput", .audio, "mic",
                   tr("Next sound input", "Entrée audio suivante", "Siguiente entrada de audio", "Nächster Toneingang", "次の入力"),
                   tr("Switches microphone.", "Change de micro.", "Cambia de micrófono.", "Wechselt das Mikrofon.", "マイクを切り替えます。"),
                   inMenu: false) { AudioTools.cycle(input: true) },
            tweak("audio.volumeCap", .audio, "speaker.badge.exclamationmark",
                  tr("Limit the volume after wake", "Limiter le volume au réveil", "Limitar el volumen al despertar", "Lautstärke nach dem Aufwachen begrenzen", "スリープ解除時に音量を制限"),
                  tr("No blast of sound when you open your Mac in a quiet room.", "Pas de son à fond en ouvrant ton Mac dans une pièce calme.", "Sin sustos de volumen al abrir el Mac.", "Kein lauter Ton beim Aufklappen.", "静かな場所で大音量にならないように。"),
                  options: [.number(key: "volumeCap", title: S.maximum, range: 5...100, step: 5, defaultValue: 50, unit: "%")],
                  start: AudioTools.startVolumeCap, stop: AudioTools.stopVolumeCap),
        ]
    }

    private static func clipboard() -> [Tool] {
        [
            action("clipboard.clear", .clipboard, "clipboard",
                   tr("Clear the clipboard", "Vider le presse-papiers", "Vaciar el portapapeles", "Zwischenablage leeren", "クリップボードを消去"),
                   tr("After copying a password, for example.", "Après avoir copié un mot de passe, par exemple.", "Tras copiar una contraseña, por ejemplo.", "Z. B. nach dem Kopieren eines Passworts.", "パスワードをコピーした後などに。"),
                   perform: ClipboardTools.clear),
            tweak("clipboard.autoClear", .clipboard, "timer",
                  tr("Clear the clipboard automatically", "Vider le presse-papiers automatiquement", "Vaciar el portapapeles automáticamente", "Zwischenablage automatisch leeren", "クリップボードを自動消去"),
                  tr("A while after the last copy.", "Un moment après la dernière copie.", "Un rato después de copiar.", "Eine Weile nach dem letzten Kopieren.", "最後のコピーからしばらく後。"),
                  options: [.number(key: "clipboardSeconds", title: S.after, range: 10...3600, step: 10, defaultValue: 60, unit: S.seconds)],
                  start: ClipboardTools.startAutoClear, stop: ClipboardTools.stopAutoClear),
            tweak("clipboard.onLock", .clipboard, "lock",
                  tr("Clear the clipboard when locking", "Vider le presse-papiers au verrouillage", "Vaciar al bloquear", "Beim Sperren leeren", "ロック時に消去"),
                  tr("And when the Mac goes to sleep.", "Et quand le Mac se met en veille.", "Y al dormir el Mac.", "Und beim Ruhezustand.", "スリープ時も。"),
                  start: ClipboardTools.startClearOnLock, stop: ClipboardTools.stopClearOnLock),
        ]
    }

    // MARK: Files

    private static func files() -> [Tool] {
        [
            action("files.emptyTrash", .files, "trash.slash",
                   tr("Empty the Trash", "Vider la corbeille", "Vaciar la Papelera", "Papierkorb entleeren", "ゴミ箱を空にする"),
                   tr("After confirmation.", "Après confirmation.", "Tras confirmar.", "Nach Bestätigung.", "確認後に実行。"),
                   perms: [.automation], perform: FileTools.emptyTrash),
            action("files.ejectAll", .files, "eject",
                   tr("Eject all disks", "Éjecter tous les disques", "Expulsar todos los discos", "Alle Volumes auswerfen", "すべてのディスクを取り出す"),
                   tr("External drives, disk images, SD cards…", "Disques externes, images disque, cartes SD…", "Discos externos, imágenes, tarjetas SD…", "Externe Laufwerke, Images, SD-Karten …", "外付けドライブ、ディスクイメージ、SD カード…"),
                   perform: FileTools.ejectAll),
            tweak("files.archiveDownloads", .files, "archivebox",
                  tr("Archive old downloads", "Archiver les anciens téléchargements", "Archivar descargas antiguas", "Alte Downloads archivieren", "古いダウンロードを整理"),
                  tr("Keeps the Downloads folder tidy: old items go to Downloads › Archive.", "Garde Téléchargements en ordre : les anciens éléments vont dans Téléchargements › Archive.", "Mueve lo antiguo a Descargas › Archivo.", "Alte Objekte nach Downloads › Archiv.", "古い項目をダウンロード › アーカイブへ。"),
                  options: [.number(key: "downloadsDays", title: S.olderThan, range: 1...365, step: 1, defaultValue: 30, unit: S.days)],
                  start: FileTools.startArchiveDownloads, stop: FileTools.stopArchiveDownloads),
            tweak("files.lowercase", .files, "textformat.abc",
                  tr("Lowercase download extensions", "Extensions en minuscules dans Téléchargements", "Extensiones en minúsculas en Descargas", "Endungen in Downloads klein schreiben", "ダウンロードの拡張子を小文字に"),
                  tr("PHOTO.JPG becomes PHOTO.jpg.", "PHOTO.JPG devient PHOTO.jpg.", "PHOTO.JPG pasa a PHOTO.jpg.", "PHOTO.JPG wird PHOTO.jpg.", "PHOTO.JPG → PHOTO.jpg。"),
                  start: FileTools.updateDownloadsWatcher, stop: FileTools.updateDownloadsWatcher),
            tweak("files.airdrop", .files, "airplayaudio",
                  tr("Put AirDropped files in a folder", "Ranger les fichiers reçus par AirDrop", "Guardar archivos de AirDrop en una carpeta", "AirDrop-Dateien in einen Ordner", "AirDrop のファイルをフォルダへ"),
                  tr("Instead of mixing them with your downloads.", "Au lieu de les mélanger aux téléchargements.", "En lugar de mezclarlos con descargas.", "Statt sie mit Downloads zu mischen.", "ダウンロードと混ざらないように。"),
                  options: [.folder(key: "airdropFolder", title: S.folder, defaultPath: "~/Downloads/AirDrop")],
                  start: FileTools.updateDownloadsWatcher, stop: FileTools.updateDownloadsWatcher),
        ]
    }

    // MARK: Display, system, utilities

    private static func display() -> [Tool] {
        [
            action("display.dark", .display, "circle.lefthalf.filled",
                   tr("Dark Mode", "Mode sombre", "Modo oscuro", "Dunkelmodus", "ダークモード"),
                   tr("Switches between light and dark.", "Bascule entre clair et sombre.", "Cambia entre claro y oscuro.", "Wechselt zwischen hell und dunkel.", "ライトとダークを切り替えます。"),
                   perms: [.automation], perform: DisplayTools.toggleDarkMode).with { $0.state = { DisplayTools.isDark } },
            action("display.nightShift", .display, "moon",
                   tr("Night Shift", "Night Shift", "Night Shift", "Night Shift", "Night Shift"),
                   tr("Warmer colors in the evening.", "Couleurs plus chaudes le soir.", "Colores más cálidos.", "Wärmere Farben am Abend.", "夜は暖かい色に。"),
                   perform: DisplayTools.toggleNightShift).with { $0.state = { DisplayTools.nightShiftOn } },
            action("display.trueTone", .display, "sun.max",
                   tr("True Tone", "True Tone", "True Tone", "True Tone", "True Tone"),
                   tr("On supported displays.", "Sur les écrans compatibles.", "En pantallas compatibles.", "Auf unterstützten Displays.", "対応ディスプレイのみ。"),
                   inMenu: false, perform: DisplayTools.toggleTrueTone).with { $0.state = { DisplayTools.trueToneOn } },
            action("display.grayscale", .display, "circle.righthalf.filled",
                   tr("Grayscale", "Niveaux de gris", "Escala de grises", "Graustufen", "グレイスケール"),
                   tr("Less distracting screen.", "Un écran moins distrayant.", "Una pantalla menos distractora.", "Weniger ablenkender Bildschirm.", "気が散りにくい画面に。"),
                   inMenu: false, perform: DisplayTools.toggleGrayscale).with { $0.state = { DisplayTools.grayscaleOn } },
            action("display.desktopIcons", .display, "menubar.dock.rectangle",
                   tr("Show desktop icons", "Afficher les icônes du bureau", "Mostrar iconos del escritorio", "Schreibtischsymbole zeigen", "デスクトップのアイコンを表示"),
                   tr("Hide them before sharing your screen.", "Masque-les avant de partager ton écran.", "Ocúltalos antes de compartir pantalla.", "Vor dem Bildschirmteilen ausblenden.", "画面共有の前に隠せます。"),
                   perform: DisplayTools.toggleDesktopIcons).with { $0.state = { DisplayTools.desktopIconsShown } },
            action("display.hotCorners", .display, "rectangle.dashed",
                   tr("Hot Corners", "Coins actifs", "Esquinas activas", "Aktive Ecken", "ホットコーナー"),
                   tr("Turn them off for a game or a presentation; your settings come back after.", "Désactive-les pour un jeu ou une présentation ; tes réglages reviennent ensuite.", "Desactívalas temporalmente.", "Vorübergehend ausschalten.", "一時的にオフにできます。"),
                   inMenu: false, perform: DisplayTools.toggleHotCorners).with { $0.state = { DisplayTools.hotCornersOn } },
            action("display.sleep", .display, "display",
                   tr("Turn off the displays", "Éteindre les écrans", "Apagar las pantallas", "Displays ausschalten", "ディスプレイをスリープ"),
                   tr("The Mac keeps running.", "Le Mac continue de tourner.", "El Mac sigue funcionando.", "Der Mac läuft weiter.", "Mac は動作したまま。"),
                   perform: DisplayTools.sleepDisplays),
            action("display.screenSaver", .display, "sparkles.tv",
                   tr("Start the screen saver", "Lancer l'économiseur d'écran", "Iniciar el salvapantallas", "Bildschirmschoner starten", "スクリーンセーバを開始"),
                   tr("Right now.", "Tout de suite.", "Ahora mismo.", "Sofort.", "今すぐ。"),
                   inMenu: false, perform: DisplayTools.startScreenSaver),
        ]
    }

    private static func system() -> [Tool] {
        [
            action("system.keepAwake", .system, "cup.and.saucer",
                   tr("Keep the Mac awake", "Garder le Mac éveillé", "Mantener el Mac despierto", "Mac wach halten", "Mac をスリープさせない"),
                   tr("Until you turn it off.", "Jusqu'à ce que tu l'arrêtes.", "Hasta que lo desactives.", "Bis zum Ausschalten.", "オフにするまで。"),
                   perform: SystemTools.toggleKeepAwake).with {
                $0.state = { SystemTools.isAwake }
                $0.options = [.toggle(key: "keepAwake.display", title: S.keepDisplayOn, defaultValue: true)]
            },
            action("system.lock", .system, "lock",
                   tr("Lock the screen", "Verrouiller l'écran", "Bloquear la pantalla", "Bildschirm sperren", "画面をロック"),
                   tr("Immediately.", "Immédiatement.", "Al instante.", "Sofort.", "すぐに。"),
                   perform: SystemTools.lockScreen),
            action("system.flushDNS", .system, "network",
                   tr("Flush the DNS cache", "Vider le cache DNS", "Vaciar la caché DNS", "DNS-Cache leeren", "DNS キャッシュを消去"),
                   tr("Fixes sites that don't load after a change. Asks for your password.", "Répare les sites qui ne chargent plus après un changement. Demande ton mot de passe.", "Arregla sitios que no cargan. Pide tu contraseña.", "Hilft bei nicht ladenden Seiten. Fragt nach dem Passwort.", "サイトが読み込めないときに。パスワードが必要です。"),
                   inMenu: false, perform: SystemTools.flushDNS),
            tweak("system.textEditBlank", .system, "doc.text",
                  tr("TextEdit opens a blank document", "TextEdit ouvre un document vierge", "TextEdit abre un documento en blanco", "TextEdit öffnet ein leeres Dokument", "テキストエディットで新規書類を開く"),
                  tr("Instead of the file dialog.", "Au lieu de la fenêtre d'ouverture.", "En lugar del diálogo de archivos.", "Statt des Öffnen-Dialogs.", "ファイルダイアログの代わりに。"),
                  start: { SystemTools.setTextEditBlank(true) }, stop: { SystemTools.setTextEditBlank(false) }),
            action("system.privateRelay", .system, "network.badge.shield.half.filled",
                   tr("Open VPN settings", "Ouvrir les réglages VPN", "Abrir ajustes de VPN", "VPN-Einstellungen öffnen", "VPN 設定を開く"),
                   tr("A pane that's hard to find.", "Un réglage difficile à trouver.", "Un ajuste difícil de encontrar.", "Schwer zu findende Einstellung.", "見つけにくい設定。"),
                   inMenu: false) { SystemTools.openPane("x-apple.systempreferences:com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension") },
        ]
    }

    private static func utilities() -> [Tool] {
        [
            action("utilities.cleaning", .utilities, "sparkles",
                   tr("Cleaning Mode", "Mode nettoyage", "Modo limpieza", "Reinigungsmodus", "クリーニングモード"),
                   tr("Black screen, keyboard and trackpad locked: clean them safely. Hold Esc to leave.", "Écran noir, clavier et trackpad bloqués : nettoie-les sans risque. Garde Échap enfoncée pour sortir.", "Pantalla negra y teclado bloqueado para limpiarlos. Mantén Esc para salir.", "Schwarzer Bildschirm, Eingaben gesperrt. Esc halten zum Beenden.", "画面を黒くし入力をロック。Esc 長押しで終了。"),
                   perms: [.accessibility]) { InputLock.start(cleaning: true) },
            action("utilities.cat", .utilities, "pawprint",
                   tr("Cat Mode", "Mode chat", "Modo gato", "Katzenmodus", "ネコモード"),
                   tr("Locks the keyboard and mouse but keeps the screen visible. Hold Esc to leave.", "Bloque le clavier et la souris mais laisse l'écran visible. Garde Échap enfoncée pour sortir.", "Bloquea teclado y ratón con la pantalla visible.", "Sperrt Tastatur und Maus, Bildschirm bleibt sichtbar.", "画面は見えたまま入力をロック。"),
                   inMenu: false, perms: [.accessibility]) { InputLock.start(cleaning: false) },
            action("utilities.notifications", .utilities, "bell.slash",
                   tr("Clear notifications", "Effacer les notifications", "Borrar notificaciones", "Mitteilungen löschen", "通知を消去"),
                   tr("Closes the notifications on screen.", "Ferme les notifications à l'écran.", "Cierra las notificaciones en pantalla.", "Schließt sichtbare Mitteilungen.", "表示中の通知を閉じます。"),
                   inMenu: false, perms: [.accessibility], perform: UtilityTools.clearNotifications).with { $0.beta = true },
            tweak("utilities.shortcuts", .utilities, "square.stack.3d.up",
                  tr("Shortcuts in the menu", "Raccourcis (app) dans le menu", "Atajos (app) en el menú", "Kurzbefehle im Menü", "メニューにショートカットを表示"),
                  tr("Run your shortcuts from the Shortcuts app from Overdrive's menu.", "Lance tes raccourcis de l'app Raccourcis depuis le menu d'Overdrive.", "Ejecuta tus atajos de la app Atajos desde el menú.", "Starte Kurzbefehle aus dem Overdrive-Menü.", "ショートカット App の項目を実行できます。"),
                  start: UtilityTools.refreshShortcuts, stop: {}),
        ]
    }
}
