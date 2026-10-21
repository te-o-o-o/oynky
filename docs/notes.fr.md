# Notes

## Décisions

- libproc seulement (`proc_listpids`, `proc_pid_rusage` v6, `proc_pidpath`) : public, sans entitlement, sans framework privé, quelques millisecondes pour ~500 processus.
- CPU et énergie sont des écarts entre deux échantillons : les compteurs de rusage sont cumulés depuis le lancement, une seule lecture ne donne qu'une moyenne sur la vie du processus.
- Un processus est la paire (pid, `ri_proc_start_abstime`) : un pid réutilisé pendant l'intervalle est un nouveau processus, compté depuis zéro.
- Regroupement par le `.app` le plus extérieur du chemin de l'exécutable : les helpers de Chrome sont des bundles `.app` imbriqués dans `Google Chrome.app`. Hors bundle, le nom de l'exécutable.
- L'énergie est `ri_energy_nj`, pas `ri_billed_energy` : ce dernier ne compte que le travail facturé via des vouchers et valait 0 pour Zen à 6 % de CPU.
- La mémoire est `ri_phys_footprint`, le chiffre que le Moniteur d'activité affiche comme Mémoire.

## Pas encore géré

- Les exécutables nommés par leur version (Claude Code lance `~/.local/share/claude/versions/2.1.306`) apparaissent comme `2.1.306` ; `proc_name` dit pareil. Seul argv[0] (`KERN_PROCARGS2`) dirait `claude`.
- Les agents lancés hors de tout `.app` (`/Library/Application Support/<éditeur>/…`) ne sont pas rattachés à leur app.
- Historique, alertes, icône dans la barre des menus.

## Vérifié

| OS | État |
|---|---|
| macOS 27.0.1 (arm64) | `oynky top` lancé en utilisateur : 330 processus lus, 178 d'autres utilisateurs ignorés ; CPU en ns vérifié par un test (boucle de 200 ms) ; `--sort energy` donne des mW non nuls ; le binaire release prend ~10 Mo de RAM et aucun CPU mesurable pour 0,1 s. Pas lancé avec sudo, pas lancé sur Intel. |

## Pièges

- `ri_user_time` et `ri_system_time` sont en ticks mach, pas en nanosecondes : 125/3 ns par tick sur Apple Silicon, oublier `mach_timebase_info` donne des valeurs 41× trop basses. Sur Intel le rapport vaut 1, ce qui cache le bug.
- `proc_listpids` avec un buffer nul renvoie une taille en octets, pas un nombre de pids.
- `proc_pid_rusage` échoue (EPERM) sur les processus d'autres utilisateurs sauf en root : 178 sur 508 dans une session de bureau.
