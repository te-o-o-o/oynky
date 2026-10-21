# Notes

## Décisions

- libproc seulement (`proc_listpids`, `proc_pid_rusage` v6, `proc_pidpath`) : public, sans entitlement, sans framework privé.
- CPU et énergie sont des écarts entre deux échantillons : les compteurs de rusage sont cumulés depuis le lancement, un pic entre deux échantillons est donc compté, seulement moyenné.
- Un processus est la paire (pid, heure de lancement) : un pid réutilisé pendant l'intervalle est un nouveau processus, compté depuis zéro. Son chemin et son nom d'app sont lus une fois, puis repris d'un échantillon à l'autre.
- Regroupement par le `.app` le plus extérieur du chemin de l'exécutable : les helpers de Chrome sont des bundles `.app` imbriqués dans `Google Chrome.app`. Hors bundle, le nom de l'exécutable.
- L'énergie est `ri_energy_nj`, pas `ri_billed_energy` : ce dernier ne compte que le travail facturé via des vouchers et valait 0 pour Zen à 6 % de CPU.
- La mémoire est `ri_phys_footprint`, le chiffre que le Moniteur d'activité affiche comme Mémoire.
- Rythme : toutes les 5 s sur secteur, 15 s sur batterie, chaque seconde menu ouvert, tout de suite au réveil et en cas de pression mémoire. Les timers ont 20 % de tolérance pour que macOS regroupe les réveils. L'historique garde une ligne par app et par minute (CPU et énergie moyennés sur la minute, mémoire à son pic), seulement pour les apps au-dessus de 0,1 % de CPU ou 50 Mo : environ 5 Mo par jour (~50 apps par minute mesurées), ~33 Mo pour la semaine.
- Écartés pour le rythme : Endpoint Security (entitlement accordé par Apple, extension système en root, accès complet au disque), powermetrics (root), DTrace (SIP), API privées.
- « Processus de macOS » veut dire lancé depuis `/System/`, `/usr/`, `/bin/`, `/sbin/` ou `/Library/Apple/`. Les constats les ignorent : ce n'est pas ce que traque oynky et on n'y peut rien.
- App active en arrière-plan : tierce, ≥ 5 % de CPU en moyenne sur 30 minutes, pas mise au premier plan pendant ces 30 minutes, avec au moins 24 des 30 minutes dans l'historique (pas de verdict juste après le lancement ou le réveil).
- Mémoire qui grimpe : tierce, vue à chacune des 6 dernières heures, le point le plus bas de chaque heure au moins égal à celui de l'heure d'avant, et +300 Mo et +25 % au total.
- Installations : ce qui est arrivé dans `/Applications`, `~/Applications`, `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons` ces 7 derniers jours, daté par `addedToDirectoryDate` (l'arrivée dans le dossier, pas la compilation). Un plist de lancement est rattaché à l'app qui contient son `Program`. Les dossiers sont surveillés (DispatchSource), sans scrutation.
- Rapports de macOS : les fichiers `.diag` de `/Library/Logs/DiagnosticReports`, lisibles par les administrateurs sans root (groupe `_analyticsusers`). Seuls les 4 premiers Ko sont lus. Datés par leur `End time` : la date du fichier change quand macOS déplace les fichiers. Événements vus : `disk writes`, `cpu usage`.

- Notifications : une par clé de constat (`hog:Zen`, `climb:Zen`, `report:Zen:disk writes`, `install:Zen`), au plus une fois par jour, dates gardées dans UserDefaults (`told`), oubliées après 7 jours. Les rapports de macOS ne notifient que s'ils ont moins d'un jour, pour qu'un premier lancement ne ressorte pas toute la semaine. Les installations notifient quand elles laissent des processus tourner depuis plus d'une heure.
- « Utilisée » couvre aussi ce qu'une app utilisée a lancé : `node` ou une compilation lancés depuis le terminal où vous tapez ne sont pas des apps actives en arrière-plan. Trouvé parce que Claude Code, qui tourne dans Ghostty, a été signalé.
- Vérifié de bout en bout : un programme de test à ~10 % de CPU, jamais mis au premier plan, a été signalé et notifié au bout de ~18 minutes (la moyenne sur 30 minutes a franchi 5 %).
- Batterie : la capacité est la charge complète d'aujourd'hui (`BatteryData.FullChargeCapacity` × tension), pas la capacité d'origine. L'énergie d'une app sur 24 h est la somme de ses minutes dans l'historique. Les minutes de batterie utilisent la consommation habituelle du Mac sur batterie (`InstantAmperage` × tension, moyennée sur les minutes sur batterie, gardée dans UserDefaults `draw`) : pas de minutes tant que le Mac n'a pas tourné sur batterie.
- Énergie vérifiée : un cœur performance à fond donne 2,97 W via `ri_energy_nj`. La plupart des apps affichent quelques mW parce qu'elles tournent sur les cœurs basse consommation.
- Explications, toutes lues sur le Mac : l'auteur depuis la signature du code (`SecStaticCode`, non validée : elle nomme l'auteur, elle ne garantit pas le code) ; « lancée par » en remontant les processus parents jusqu'au premier autre `.app` (shells sautés, arrêt à launchd) ; « se lance toute seule » quand un plist de lancement lance ce programme (~850 plists, ~40 ms, indexés une fois) ; la ligne `.Nd` de la page de manuel ; et `Glossary.swift`, écrit à la main pour ~60 processus de macOS, en anglais et en français.
- Programmes sans auteur : les signatures ad hoc (drapeau 0x2, ce que produisent l'éditeur de liens et Homebrew) sont distinguées de l'absence de signature. Ensuite : le script qu'exécute un interpréteur (seulement son nom, et seulement s'il ressemble à un nom de fichier ou de module : une ligne de commande peut contenir des jetons), l'emplacement du binaire (`Place`), son dossier de travail, sa date de création, et la marque de quarantaine (`com.apple.quarantine` : app de téléchargement et date ; le site vient de `QuarantineEventsV2`, en lecture seule, quand l'app l'a noté : Zen et Homebrew ne le font pas).
- Un fichier nommé comme une version (le `2.1.306` de Claude Code) prend le nom d'argv[0] (`claude`), lu seulement pour ces fichiers.
- Parents : `PROC_PIDT_SHORTBSDINFO`, pas `PROC_PIDTBSDINFO` : le complet est refusé pour les processus de root, et le `login` de root se trouve entre un terminal et son shell, ce qui cassait « lancée par Ghostty » et la règle d'usage pour les outils du terminal.
- Le code d'Apple se reconnaît à l'émetteur de sa signature (`Apple Code Signing Certification Authority`) : le nom du certificat est passé de « Software Signing » à « macOS Software Signing ».

## Pas encore géré

- « Lancée par » nomme la première autre app en remontant les parents : les serveurs MCP lancés par Claude Code dans Ghostty affichent « lancée par Ghostty », pas « par claude ».
- Les agents lancés hors de tout `.app` et pas installés ces 7 derniers jours ne sont pas rattachés à leur app.
- « Utilisée » veut dire mise au premier plan : une app qui lit une vidéo dans une fenêtre derrière une autre compte comme en arrière-plan.
- Les éléments d'ouverture enregistrés avec `SMAppService` vivent dans leur app et n'apparaissent pas comme installations ; leurs processus comptent quand même pour l'app.
- Un processus qui vit moins d'un intervalle d'échantillonnage n'est pas vu du tout.
- Les gestionnaires de barre des menus (Thaw, Bartender) interrogent sans arrêt l'élément de menu via l'Accessibilité : ce travail tombe dans le fil principal d'oynky et compte dans son CPU (0,28 % au repos avec Thaw, 0,18 % avant).
- Les résumés des pages de manuel sont en anglais seulement ; le glossaire couvre les processus de macOS les plus actifs, pas tous.
- Les services XPC (pages WebKit, décodeurs vidéo) sont lancés par launchd pour une app : l'app qui les a demandés n'est pas connue sans API privée.
- Les minutes de batterie sur un Mac qui n'a jamais tourné sur batterie ; la consommation sur batterie n'est pas encore vérifiée (le Mac de test est resté branché).
- Vrai design de l'icône et du menu, petits graphiques.

## Vérifié

| OS | État |
|---|---|
| macOS 27.0.1 (arm64) | `oynky top` lancé en utilisateur : ~370 processus lus, ~180–240 d'autres utilisateurs ignorés ; CPU en ns vérifié par un test (boucle de 200 ms) ; l'app de la barre des menus tourne depuis `oynky.app`, écrit l'historique, utilise 0,21 s de CPU en 2 min au repos (0,18 % d'un cœur) et 50 Mo de RAM ; installations trouvées : Thaw, AltTab (via son agent), copycopy ; rapports trouvés : Zen, rustc, cargo (tiers) et ceux d'Apple filtrés. Menu vérifié sur capture : explications sous chaque nom (auteurs, « lancée par Raycast », lignes du glossaire et des pages de manuel). Capacité de la batterie lue (72 Wh), consommation sur batterie pas vérifiée. Pas lancé avec sudo, pas lancé sur Intel. |

## Pièges

- `ri_user_time`, `ri_system_time` et `ri_proc_start_abstime` sont en ticks mach, pas en nanosecondes : 125/3 ns par tick sur Apple Silicon, oublier `mach_timebase_info` donne des valeurs 41× trop basses. Sur Intel le rapport vaut 1, ce qui cache le bug.
- `proc_listpids` avec un buffer nul renvoie une taille en octets, pas un nombre de pids.
- `proc_pid_rusage` échoue (EPERM) sur les processus d'autres utilisateurs sauf en root : environ un tiers dans une session de bureau.
- Une app d'arrière-plan tourne sur les cœurs basse consommation : 2,5 ms de travail mesurées sur un cœur performance deviennent ~18 ms de temps CPU là-bas. Mesurer l'app emballée (`ps -o time`), pas un benchmark.
- L'essentiel du coût d'un échantillon venait de `proc_pidpath` et du nom d'app : les lire une fois par processus a divisé par deux le CPU de l'app au repos.
- Rapports de macOS : les 4 premiers Ko contiennent aussi les lignes `Path` et `Is First Party` d'autres processus, et les rapports d'Apple n'ont pas de ligne `Is First Party` du tout. Prendre le premier `Path` et décider Apple ou non à partir de lui.
- Les regex littérales (`/…/`) demandent `-enable-bare-slash-regex` quand on compile le cœur directement avec `swiftc` ; SwiftPM le fait.
