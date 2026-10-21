<h1 align="center">oynky</h1>
<p align="center">Débusque les apps qui dévorent votre Mac en douce. Observe, ne tue jamais : un détective, pas un videur.</p>
<p align="center"><sub>pas encore publié · Swift · macOS · MIT</sub></p>
<p align="center"><a href="#fonctionnalités">Fonctionnalités</a> · <a href="#installation">Installation</a> · <a href="#utilisation">Utilisation</a> · <a href="#développement">Développement</a> · <a href="README.md">English</a></p>

## Fonctionnalités

Le Moniteur d'activité dit combien. oynky dit qui, depuis quand, et si c'est normal.

- **Actives en arrière-plan** : une app que vous n'avez pas mise au premier plan depuis 30 minutes et qui occupe toujours le CPU.
- **Mémoire qui ne redescend pas** : une app dont la mémoire a grimpé heure après heure pendant 6 heures.
- **Signalées par macOS** : macOS écrit ses propres rapports quand un processus dépasse ses limites de CPU, de réveils ou d'écritures disque, dans un dossier que personne ne lit. oynky le lit.
- **Installées récemment** : les apps et services d'arrière-plan ajoutés ces 7 derniers jours, ce que chacun a consommé depuis, et les processus qu'il a laissés tourner pour de bon.
- **Des noms qui parlent** : sous chaque processus, ce qu'il fait, qui l'a fait et comment il démarre : `mediaanalysisd` devient « Analyse photos et vidéos · Apple », un helper « Google LLC · se lance toute seule ». Les programmes sans auteur disent plutôt d'où ils viennent : `node` devient « mcp-pdf-server · signée localement, sans auteur · Homebrew · lancée par Ghostty », une app « téléchargée avec Zen », un outil « dans un dossier temporaire · depuis ~/workspace/oynky ». Au survol : quand il tourne et si c'est normal.
- **Coût en batterie** : la part d'une charge complète prise par chaque app sur les dernières 24 heures, et les minutes de batterie qu'elle coûte une fois que le Mac a tourné sur batterie.
- **Notifications** : au plus une fois par jour et par constat, seulement quand il est nouveau. Un clic ouvre le menu.
- **Vue en direct** : les apps qui consomment le plus de CPU, d'énergie et de mémoire en ce moment et sur la dernière heure, leurs helpers comptés avec elles (les renderers de Chrome sont Chrome).
- **Discret et léger** : une icône dans la barre des menus qui change quand quelque chose mérite un coup d'œil, environ 0,2 % d'un cœur basse consommation, rien à régler.
- **Lecture seule** : oynky lit ce que macOS suit déjà. Pas de root, pas de réseau, pas de helper ; il n'envoie aucun signal, ne ralentit rien, ne tue rien. Chaque explication vient du Mac lui-même (signatures, services de lancement, pages de manuel) ou d'un petit glossaire écrit à la main.

**Pas encore** : le vrai design de l'icône et du menu, avec de petits graphiques.

## Installation

Depuis les sources (outils en ligne de commande Xcode requis, macOS 14 ou plus récent) :

```sh
git clone https://github.com/te-o-o-o/oynky && cd oynky
./bundle.sh
cp -R .build/oynky.app /Applications/
open /Applications/oynky.app
```

Cliquez sur l'icône puis **Ouvrir à la connexion** pour la lancer avec la session. macOS demande une fois si oynky peut envoyer des notifications.

## Utilisation

Cliquez sur l'icône de la barre des menus : d'abord ce qui est suspect, puis la vue en direct. Menu ouvert, tout se met à jour chaque seconde ; survolez une ligne suspecte pour le détail.

Le même binaire est un outil en ligne de commande :

```sh
alias oynky=/Applications/oynky.app/Contents/MacOS/oynky
oynky top                    # les 15 apps qui ont le plus consommé de CPU sur 5 s
oynky top --sort energy      # ou --sort memory
oynky top --interval 30 --limit 5
sudo oynky top               # inclut les démons système, qui appartiennent à d'autres utilisateurs
```

```
APP                                   CPU    ENERGY    MEMORY  PROCS
Zen                                 8.3 %      3 mW   7,52 GB     36
Ghostty                             4.6 %      4 mW  736,2 MB      1
Music                               2.9 %      2 mW  980,4 MB      1
```

Le CPU est un pourcentage d'un cœur, comme `top` : 250 % veut dire deux cœurs et demi occupés.

L'historique est dans `~/Library/Application Support/oynky/`, un fichier par jour séparé par tabulations, 7 jours gardés.

## Développement

```sh
swift test
swift run oynky              # l'app de la barre des menus
swift run oynky top          # la commande
```

`OynkyCore` échantillonne les processus, garde l'historique et porte les règles, sans interface ; la cible `oynky` est l'app de la barre des menus et la commande, de fines couches dessus. Décisions et pièges dans [docs/notes.fr.md](docs/notes.fr.md).

## Licence

[MIT](LICENSE)
