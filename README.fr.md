<h1 align="center">oynky</h1>
<p align="center">Débusque les apps qui dévorent votre Mac en douce. Observe, ne tue jamais : c'est un cochon, pas un boucher.</p>
<p align="center"><sub>pas encore publié · Swift · macOS · MIT</sub></p>
<p align="center"><a href="#fonctionnalités">Fonctionnalités</a> · <a href="#installation">Installation</a> · <a href="#utilisation">Utilisation</a> · <a href="#développement">Développement</a> · <a href="README.md">English</a></p>

## Fonctionnalités

- **Un tableau par app** : CPU, énergie et mémoire de chaque app, ses helpers et processus d'arrière-plan comptés avec elle (les renderers de Chrome sont Chrome).
- **De vrais chiffres** : CPU et énergie sont mesurés sur un intervalle, pas tirés d'une moyenne depuis le démarrage ; la mémoire est l'empreinte qu'affiche le Moniteur d'activité.
- **Lecture seule** : oynky lit ce que macOS suit déjà pour chaque processus. Il n'envoie aucun signal, ne ralentit rien, ne tue rien.
- **Rien à régler** : aucune permission à accorder, aucune config, aucune dépendance.

**Pas encore** : le cochon dans la barre des menus, l'historique sur 7 jours et les alertes (CPU en arrière-plan, mémoire qui ne redescend jamais, nouveaux processus permanents après une installation).

## Installation

Depuis les sources (outils en ligne de commande Xcode requis, macOS 14 ou plus récent) :

```sh
git clone https://github.com/te-o-o-o/oynky && cd oynky
swift build -c release
cp .build/release/oynky /usr/local/bin/
```

## Utilisation

```sh
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

## Développement

```sh
swift test
swift run oynky top
```

`OynkyCore` échantillonne les processus avec libproc et transforme deux échantillons en consommation par app, sans interface ; la commande `oynky` n'est qu'une fine couche dessus. Décisions et pièges dans [docs/notes.fr.md](docs/notes.fr.md).

## Licence

[MIT](LICENSE)
