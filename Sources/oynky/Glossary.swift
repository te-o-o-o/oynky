/// What macOS's own processes do, in plain words: their names say little ("mediaanalysisd")
/// and most have no manual page. `what` is the short line under the name in the menu; `note`,
/// for the ones that get busy, says when they run and whether that is normal.
/// ponytail: written by hand for the usual suspects; anything else falls back to its manual page.
struct Gloss {
    let what: (en: String, fr: String)
    var note: (en: String, fr: String)? = nil
}

let glossary: [String: Gloss] = [
    // Photos and media
    "mediaanalysisd": Gloss(
        what: ("Analyses photos and videos", "Analyse photos et vidéos"),
        note: ("Finds faces, objects, scenes and text for Photos and Visual Look Up. Runs mostly while the Mac is idle and plugged in; busy for a while after importing many photos, then calms down.",
               "Repère visages, objets, scènes et texte pour Photos et la recherche visuelle. Tourne surtout quand le Mac est inutilisé et branché ; occupé un moment après un gros import, puis se calme.")),
    "photoanalysisd": Gloss(
        what: ("Analyses the Photos library", "Analyse la photothèque"),
        note: ("Builds Memories, People and search in Photos. Same timing as mediaanalysisd: idle and plugged in, busy after an import.",
               "Construit les Souvenirs, les Personnes et la recherche de Photos. Même rythme que mediaanalysisd : inutilisé et branché, occupé après un import.")),
    "photolibraryd": Gloss(
        what: ("Manages the Photos library", "Gère la photothèque"),
        note: ("Keeps the library in order and syncs it with iCloud Photos: busy while photos upload or download.",
               "Tient la photothèque et la synchronise avec Photos iCloud : occupé pendant les envois et téléchargements de photos.")),
    "VTDecoderXPCService": Gloss(what: ("Decodes video for apps", "Décode la vidéo pour les apps"),
                                 note: ("Busy while a video plays, in any app.", "Occupé pendant la lecture d'une vidéo, dans n'importe quelle app.")),
    "VTEncoderXPCService": Gloss(what: ("Encodes video for apps", "Encode la vidéo pour les apps"),
                                 note: ("Busy during screen recording, video calls or exports.", "Occupé pendant un enregistrement d'écran, un appel vidéo ou un export.")),
    "coreaudiod": Gloss(what: ("Plays and records all sound", "Joue et enregistre tout le son")),
    "mediaremoted": Gloss(what: ("Now Playing and media keys", "« À l'écoute » et touches multimédia")),
    "AMPLibraryAgent": Gloss(what: ("Keeps the Music library in sync", "Synchronise la bibliothèque Musique")),

    // Spotlight and search
    "mds": Gloss(what: ("Spotlight's index server", "Serveur de l'index Spotlight")),
    "mds_stores": Gloss(
        what: ("Writes Spotlight's index", "Écrit l'index Spotlight"),
        note: ("Busy after many files change, a big copy or a macOS update, then calms down. Constant activity can mean a folder that keeps changing.",
               "Occupé après beaucoup de fichiers modifiés, une grosse copie ou une mise à jour de macOS, puis se calme. Une activité permanente peut venir d'un dossier qui change sans arrêt.")),
    "mdworker": Gloss(what: ("Reads files for Spotlight", "Lit les fichiers pour Spotlight")),
    "mdworker_shared": Gloss(what: ("Reads files for Spotlight", "Lit les fichiers pour Spotlight")),
    "mdbulkimport": Gloss(what: ("Imports files into Spotlight", "Importe des fichiers dans Spotlight")),
    "corespotlightd": Gloss(what: ("Indexes app content for Spotlight", "Indexe le contenu des apps pour Spotlight"),
                            note: ("Mail, Notes, Messages and other apps hand it their content to make it searchable.", "Mail, Notes, Messages et d'autres apps lui confient leur contenu pour le rendre cherchable.")),
    "spotlightknowledged": Gloss(what: ("Spotlight's knowledge for suggestions", "Connaissances de Spotlight pour les suggestions")),
    "spotlightknowledged.updater": Gloss(what: ("Refreshes Spotlight's knowledge", "Met à jour les connaissances de Spotlight"),
                                         note: ("Runs in the background from time to time; short bursts are normal.", "Tourne de temps en temps en arrière-plan ; de courts pics sont normaux.")),
    "Spotlight": Gloss(what: ("The Spotlight search window", "La fenêtre de recherche Spotlight")),

    // iCloud and sync
    "cloudd": Gloss(what: ("iCloud sync for apps (CloudKit)", "Synchro iCloud des apps (CloudKit)"),
                    note: ("Busy while apps sync their data with iCloud, for example after setting up a Mac.", "Occupé pendant que les apps synchronisent leurs données avec iCloud, par exemple après la configuration d'un Mac.")),
    "bird": Gloss(what: ("iCloud Drive sync", "Synchro iCloud Drive"),
                  note: ("Busy while files upload to or download from iCloud Drive.", "Occupé pendant les envois et téléchargements de fichiers iCloud Drive.")),
    "fileproviderd": Gloss(what: ("Syncs cloud folders", "Synchronise les dossiers cloud"),
                           note: ("iCloud Drive, Dropbox, Google Drive, OneDrive… go through it.", "iCloud Drive, Dropbox, Google Drive, OneDrive… passent par lui.")),
    "nsurlsessiond": Gloss(what: ("Background downloads and uploads", "Téléchargements et envois en arrière-plan"),
                           note: ("Runs transfers for apps and macOS (updates, iCloud, podcasts).", "Fait les transferts des apps et de macOS (mises à jour, iCloud, podcasts).")),
    "biomesyncd": Gloss(what: ("Syncs usage data between your devices", "Synchronise les données d'usage entre vos appareils")),
    "CalendarAgent": Gloss(what: ("Syncs calendars", "Synchronise les calendriers")),
    "remindd": Gloss(what: ("Syncs reminders", "Synchronise les rappels")),
    "contactsd": Gloss(what: ("Contacts service", "Service des contacts")),
    "AddressBookSourceSync": Gloss(what: ("Syncs contacts", "Synchronise les contacts")),

    // Updates, backups, security
    "softwareupdated": Gloss(what: ("macOS updates", "Mises à jour de macOS"),
                             note: ("Checks for, downloads and prepares updates: busy before an update is offered.", "Cherche, télécharge et prépare les mises à jour : occupé avant qu'une mise à jour soit proposée.")),
    "mobileassetd": Gloss(what: ("Downloads system assets", "Télécharge des ressources système"),
                          note: ("Voices, fonts, dictionaries and on-device models, in the background.", "Voix, polices, dictionnaires et modèles locaux, en arrière-plan.")),
    "backupd": Gloss(what: ("Time Machine backups", "Sauvegardes Time Machine")),
    "trustd": Gloss(what: ("Checks certificates", "Vérifie les certificats"),
                    note: ("For websites and app signatures: short bursts while browsing are normal.", "Pour les sites web et les signatures d'apps : de courts pics en naviguant sont normaux.")),
    "syspolicyd": Gloss(what: ("Gatekeeper: checks apps before they open", "Gatekeeper : vérifie les apps avant leur ouverture")),
    "XprotectService": Gloss(what: ("Apple's built-in malware scan", "L'antivirus intégré d'Apple")),
    "secd": Gloss(what: ("Keychain service", "Service du trousseau")),
    "akd": Gloss(what: ("Apple Account sign-in", "Connexion au compte Apple")),
    "triald": Gloss(what: ("Apple's feature trials and model updates", "Essais de fonctions et mises à jour de modèles d'Apple")),

    // Suggestions and usage
    "duetexpertd": Gloss(what: ("Learns your habits for suggestions", "Apprend vos habitudes pour les suggestions")),
    "knowledge-agent": Gloss(what: ("Records app usage for Screen Time and suggestions", "Note l'usage des apps pour Temps d'écran et les suggestions")),
    "suggestd": Gloss(what: ("Finds contacts and events in Mail and Messages", "Repère contacts et événements dans Mail et Messages")),
    "PerfPowerServices": Gloss(what: ("Records energy use for Battery settings", "Mesure l'énergie pour les réglages Batterie")),

    // Devices and network
    "sharingd": Gloss(what: ("AirDrop, Handoff and the shared clipboard", "AirDrop, Handoff et le presse-papiers partagé")),
    "rapportd": Gloss(what: ("Talks to your Apple devices nearby", "Dialogue avec vos appareils Apple proches")),
    "apsd": Gloss(what: ("Keeps the push notification connection", "Tient la connexion des notifications push")),
    "identityservicesd": Gloss(what: ("iMessage and FaceTime identity", "Identité iMessage et FaceTime")),
    "imagent": Gloss(what: ("Messages and FaceTime accounts", "Comptes Messages et FaceTime")),
    "searchpartyd": Gloss(what: ("Find My", "Localiser")),
    "locationd": Gloss(what: ("Location services", "Service de localisation")),

    // The desktop itself
    "WindowServer": Gloss(what: ("Draws everything on screen", "Affiche tout ce qui est à l'écran"),
                          note: ("Busy with many windows, animations, video or external displays.", "Occupé avec beaucoup de fenêtres, d'animations, de vidéo ou d'écrans externes.")),
    "WindowManager": Gloss(what: ("Stage Manager and window tiling", "Stage Manager et disposition des fenêtres")),
    "Dock": Gloss(what: ("The Dock, Mission Control and Launchpad", "Le Dock, Mission Control et Launchpad")),
    "WallpaperAgent": Gloss(what: ("Draws the desktop wallpaper", "Affiche le fond d'écran"),
                            note: ("Animated and video wallpapers keep it busy.", "Les fonds d'écran animés et vidéo l'occupent en continu.")),
    "ControlCenter": Gloss(what: ("Control Center and the menu bar's system icons", "Centre de contrôle et icônes système de la barre des menus")),
    "SystemUIServer": Gloss(what: ("System menu bar items", "Éléments système de la barre des menus")),
    "NotificationCenter": Gloss(what: ("Notification Center and widgets", "Centre de notifications et widgets")),
    "chronod": Gloss(what: ("Refreshes widgets", "Actualise les widgets")),
    "loginwindow": Gloss(what: ("Your session: login, lock and logout", "Votre session : ouverture, verrouillage et fermeture")),
    "Finder": Gloss(what: ("The Finder", "Le Finder")),
    "com.apple.WebKit.WebContent": Gloss(what: ("A web page, in Safari or an app", "Une page web, dans Safari ou une app"),
                                         note: ("One per tab or web view: a busy one is a page doing a lot (video, ads, a web app).", "Un par onglet ou vue web : s'il est occupé, c'est une page qui travaille beaucoup (vidéo, pubs, app web).")),
    "com.apple.WebKit.GPU": Gloss(what: ("Graphics for web pages", "Graphismes des pages web")),
    "com.apple.WebKit.Networking": Gloss(what: ("Network for web pages", "Réseau des pages web")),

    // Plumbing
    "launchd": Gloss(what: ("Starts and keeps every service running", "Lance et maintient tous les services")),
    "UserEventAgent": Gloss(what: ("Reacts to system events (network, power, devices)", "Réagit aux événements système (réseau, alimentation, appareils)")),
    "distnoted": Gloss(what: ("Delivers notifications between processes", "Distribue les notifications entre processus")),
    "cfprefsd": Gloss(what: ("Reads and writes app settings", "Lit et écrit les réglages des apps")),
    "lsd": Gloss(what: ("Knows which app opens what", "Sait quelle app ouvre quoi")),
    "backgroundtaskmanagementd": Gloss(what: ("Keeps the list of login items and background services", "Tient la liste des éléments d'ouverture et services d'arrière-plan")),
    "ReportCrash": Gloss(what: ("Writes crash and resource reports", "Écrit les rapports de plantage et de ressources")),
    "deleted": Gloss(what: ("Frees purgeable disk space", "Libère l'espace disque purgeable")),
]
