# Notes

## Décisions

- libproc seulement (`proc_listpids`, `proc_pid_rusage` v6, `proc_pidpath`) : public, sans entitlement, sans framework privé.
- CPU et énergie sont des écarts entre deux échantillons : les compteurs de rusage sont cumulés depuis le lancement, un pic entre deux échantillons est donc compté, seulement moyenné.
- Un processus est la paire (pid, heure de lancement) : un pid réutilisé pendant l'intervalle est un nouveau processus, compté depuis zéro. Son chemin et son nom d'app sont lus une fois, puis repris d'un échantillon à l'autre.
- Regroupement par le `.app` le plus extérieur du chemin de l'exécutable : les helpers de Chrome sont des bundles `.app` imbriqués dans `Google Chrome.app`. Hors bundle, le nom de l'exécutable.
- L'énergie est `ri_energy_nj`, pas `ri_billed_energy` : ce dernier ne compte que le travail facturé via des vouchers et valait 0 pour Zen à 6 % de CPU.
- La mémoire est `ri_phys_footprint`, le chiffre que le Moniteur d'activité affiche comme Mémoire.
- Rythme : toutes les 5 s sur secteur, 15 s sur batterie, chaque seconde menu ouvert, tout de suite au réveil et en cas de pression mémoire. Les timers ont 20 % de tolérance pour que macOS regroupe les réveils. L'historique garde une ligne par app et par minute (CPU et énergie moyennés sur la minute, mémoire à son pic), seulement pour les apps au-dessus de 0,1 % de CPU ou 50 Mo : environ 2 Mo par jour.
- Écartés pour le rythme : Endpoint Security (entitlement accordé par Apple, extension système en root, accès complet au disque), powermetrics (root), DTrace (SIP), API privées.
- « Processus de macOS » veut dire lancé depuis `/System/`, `/usr/`, `/bin/`, `/sbin/` ou `/Library/Apple/`. Les constats les ignorent : ce n'est pas ce que traque oynky et on n'y peut rien.
- App active en arrière-plan : tierce, ≥ 5 % de CPU en moyenne sur 30 minutes, pas mise au premier plan pendant ces 30 minutes, avec au moins 24 des 30 minutes dans l'historique (pas de verdict juste après le lancement ou le réveil).
- Mémoire qui grimpe : tierce, vue à chacune des 6 dernières heures, le point le plus bas de chaque heure au moins égal à celui de l'heure d'avant, et +300 Mo et +25 % au total.
- Installations : ce qui est arrivé dans `/Applications`, `~/Applications`, `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons` ces 7 derniers jours, daté par `addedToDirectoryDate` (l'arrivée dans le dossier, pas la compilation). Un plist de lancement est rattaché à l'app qui contient son `Program`. Les dossiers sont surveillés (DispatchSource), sans scrutation.
- Rapports de macOS : les fichiers `.diag` de `/Library/Logs/DiagnosticReports`, lisibles par les administrateurs sans root (groupe `_analyticsusers`). Seuls les 4 premiers Ko sont lus. Datés par leur `End time` : la date du fichier change quand macOS déplace les fichiers. Événements vus : `disk writes`, `cpu usage`.

## Pas encore géré

- Les exécutables nommés par leur version (Claude Code lance `~/.local/share/claude/versions/2.1.306`) apparaissent comme `2.1.306` ; `proc_name` dit pareil. Seul argv[0] (`KERN_PROCARGS2`) dirait `claude`.
- Les agents lancés hors de tout `.app` et pas installés ces 7 derniers jours ne sont pas rattachés à leur app.
- « Utilisée » veut dire mise au premier plan : une app qui lit une vidéo dans une fenêtre derrière une autre compte comme en arrière-plan.
- Les éléments d'ouverture enregistrés avec `SMAppService` vivent dans leur app et n'apparaissent pas comme installations ; leurs processus comptent quand même pour l'app.
- Un processus qui vit moins d'un intervalle d'échantillonnage n'est pas vu du tout.
- Notifications, vrai design de l'icône et du menu.

## Vérifié

| OS | État |
|---|---|
| macOS 27.0.1 (arm64) | `oynky top` lancé en utilisateur : ~370 processus lus, ~180–240 d'autres utilisateurs ignorés ; CPU en ns vérifié par un test (boucle de 200 ms) ; l'app de la barre des menus tourne depuis `oynky.app`, écrit l'historique, utilise 0,21 s de CPU en 2 min au repos (0,18 % d'un cœur) et 50 Mo de RAM ; installations trouvées : Thaw, AltTab (via son agent), copycopy ; rapports trouvés : Zen, rustc, cargo (tiers) et ceux d'Apple filtrés. Contenu du menu pas encore vérifié à l'œil. Pas lancé avec sudo, pas lancé sur Intel. |

## Pièges

- `ri_user_time`, `ri_system_time` et `ri_proc_start_abstime` sont en ticks mach, pas en nanosecondes : 125/3 ns par tick sur Apple Silicon, oublier `mach_timebase_info` donne des valeurs 41× trop basses. Sur Intel le rapport vaut 1, ce qui cache le bug.
- `proc_listpids` avec un buffer nul renvoie une taille en octets, pas un nombre de pids.
- `proc_pid_rusage` échoue (EPERM) sur les processus d'autres utilisateurs sauf en root : environ un tiers dans une session de bureau.
- Une app d'arrière-plan tourne sur les cœurs basse consommation : 2,5 ms de travail mesurées sur un cœur performance deviennent ~18 ms de temps CPU là-bas. Mesurer l'app emballée (`ps -o time`), pas un benchmark.
- L'essentiel du coût d'un échantillon venait de `proc_pidpath` et du nom d'app : les lire une fois par processus a divisé par deux le CPU de l'app au repos.
- Rapports de macOS : les 4 premiers Ko contiennent aussi les lignes `Path` et `Is First Party` d'autres processus, et les rapports d'Apple n'ont pas de ligne `Is First Party` du tout. Prendre le premier `Path` et décider Apple ou non à partir de lui.
- Les regex littérales (`/…/`) demandent `-enable-bare-slash-regex` quand on compile le cœur directement avec `swiftc` ; SwiftPM le fait.
