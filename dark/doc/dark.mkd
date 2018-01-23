
## Séquences

Les séquences forment la base des données manipulées par DARK. Une séquence est
une suite de tokens annotée représentant généralement une phrase ainsi que les
éléments que l'on cherche à repérérer dans celle-ci.

La fonction `dark.sequence(...)` permet de construire un nouvel objet séquence
contenant une suite de tokens non annotés. Elle peut être utilisée de deux
manière différentes.

L'utilisation la plus simple consiste à lui donner un argument de type chaine
de caractères qui va être découpé en tokens suivant les caractères
d'espacement.  Cette approche à l'avantage d'être simple mais peut flexible sur
la notion de tokens, il est par exemple impossible d'avoir des tokens contenant
des espaces de cette manière.

La deuxième approche consiste à réaliser la tokenization manuellement et
fournir la séquence sous la forme d'un tableau de chaines de caractères. Chaque
élément de ce tableau sera considérer comme un unique token.

### Les tags

DARK est un outil conçu pour faire de l'extraction d'information principalement
à partir de règles. Toutes les annotations sont représentées sous la forme de
tags, c'est-à-dire d'étiquettes sur un segment contigu de tokens. Afin de
différencier les tags des tokens et autres informations manipulées par DARK,
tous les tags commencent par le caractère '#' et sont composés de caractères
alphanumériques, du trait d'union, du tiret bas et du symbole d'égalitée.

La plupart des tags seront placés de manière indirecte via les règles où les
lexiques mais il est possible de les ajouter manuellement via la méthode `add`
de l'objet séquence :

	seq:add(tag, from, to)

Un appel à cette méthode permet d'ajouter sur la séquence un tag annotant le
segment allant du token 'from' au token 'to'. Si un seul token doit être annoté,
il n'est pas nécéssaire de fournir le paramètre 'to'.

Il est rarement nécessaire de supprimer des tags mais cela peut arriver et se
fait à l'aide de la méthode `rem` :

	seq:rem(tag, from, to)

Un appel à cette fonction supprime le tag sur le segment indiqué si un tel tag
est présent. Si le paramètre 'to' est omis, tous les tags ayant ce nom et
commencant à la position indiquée sont supprimés. De même, si les deux
paramètres de segment sont omis, tous les tags de ce nom sont supprimés sur la
séquence entière. Enfin, si aucun des trois paramètres n'est donné, tous les
tags de la séquence sont supprimés.

La méthode `seq:dump()` destinée principalement au debogage permet d'afficher
sur la sortie d'erreur standard une séquence et ses tags, le code suivant :

	seq = dark.sequence("Le petit chat dort sur la table .")
	seq:add("#animal", 2, 3)
	seq:add("#action", 4)
	seq:add("#lieu", 7, 7)
	seq:dump()

affiche :

	[ 1] Le         { }
	[ 2] petit      { #animal:2 }
	[ 3] chat       { }
	[ 4] dort       { #action:1 }
	[ 5] sur        { }
	[ 6] la         { }
	[ 7] table      { #lieu:1 }
	[ 8] .          { }

### L'objet séquence

Un objet séquence se comporte dans beaucoup de cas de la même manière qu'une
table Lua. Il est possible d'obtenir sa longueur en nombre de token à l'aide de
l'opérateur `#` est de l'indexer avec la syntaxe `[]`. Lorsque une séquence est
indexée par un entier, le résultat est une table représentant le token à la
position demandée et tous les tags commencant à cette position. Par exemple, sur
la séquence définie dans la section précédente, `seq[2]` renvoie :

	{ token = "petit,
	  1     = { name = "#animal", length = 2 },
	}

Il est à noter que les tokens sont indexer à partir de 1 comme les tableaux en
Lua et qu'il est possible d'utiliser des nombres négatifs afin d'indexer à
partir de la fin de la séquence.

Si la séquence est indexée par un tag, un tableau contenant les paires début/fin
de toutes les occurence de ce tag est renvoyée. Par exemple, toujours sur la
même séquence, le code `seq["#animal"]` renvoie :

	{ 1 = { 2, 3 } }

Il est donc simple, à l'aide de `#` et `[]` de consulter à la fois la séquence
de tokens et les annotations qui ont été placée dessus.

Une méthode d'extraction basique est fournie permettant de gérer les cas les
plus simples. Sous sa forme la plus simple elle prend en paramètre un tag et
renvoie une table contenant toute les chaine de caractère marquées par ce tag :

	seq:tag2str("#animal")

renvoie par exemple :

	{ "chat", "loup des bois" }

Il est possible de fournir en argument plusieurs tags, dans ce cas il
définissent une chaine d'inclusion :

	seq:tag2str("#date", "#jour")

renvoie une table contenant les chaines de caractères marqués par le tag #jour à
l'interieur d'un tag #date.

### Texte balisé

La méthode `seq:dump()` permet d'obtenir sur la sortie d'erreur un affichage de
la séquence utile pour le debugage, mais celui-ci n'est pas adapté au traitement
informatique, ou au stockage du résultat. L'objet séquence dispose d'une méthode
`seq:tostring()` permet d'obtenir une représentation textuelle balisée d'une
séquence et de ses tags :

	seq:tostring()

Renvoie la chaine :

	Le <animal>petit chat</animal> <action>dort</action> sur la
	<lieu>table</lieu> .

Cette methode prend un argument optionel décrivant les tags qui doivent être
inclus sous forme de balises. Cela permet par exemple de n'afficher que les tags
pertinents. Cet argument est une table dont les clés sont les tags à afficher :

	local tags = {"#animal" = true}
	seq:tostring(tags)

Renvoie la chaine :

	Le <animal>petit chat</animal> dort sur la table .

Les valeur associées au clés peuvent êtres des nom de couleurs. Dans ce cas, la
chaine inclura des commande destinée à afficher les tags dans la couleur voulue
si la chaine est envoyée vers le terminal :

	local tags = {"#animal" = "green"}
	seq:tostring(tags)

Cette commande renvoie la même chaine avec quelques caratères supplémentaires
destiné à changer la couleur de l'affichage du tag. Les couleurs acceptées sont:

	black, red, green, yellow, blue, magenta, cyan, white

La methode `tostring` est appellée automatiquement dans Lua quand une chaine de
caractères est attendue, cela permet d'écrire directement `print(seq)` sans
avoir à appeller explicitement la méthode. Il n'est par contre pas possible de
passer la liste des tags dans ce cas là.

## Modèles statistiques

Les modèles statistiques permettent d'apprendre des taggeurs automatiques pour
des tâche simple telles que l'analyse morpho-syntaxique. Le modèle utilisé ici
est très basique et utilise relativement peu de caractéristiques, ses
performances ne sont donc générallement pas état de l'art mais reste en
suffisantes dans de nombreux cas.

### Utilisation

L'utilisation d'un modèle statistique repose sur une fonction `dark.model(file)`
qui permet aussi bien d'entrainer un nouveau modèle que d'en utiliser un
existant.  Si un fichier avec l'extention ".mdl" existe, il est chargé comme
modèle, sinon un fichier avec l'extention ".dat" est chercher et supposé
contenir les données d'entrainement.

Par exemple, si l'on dispose de données morpho syntaxique pour le français dans
un fichier "postag.dat":

	La|#POS=DET force|#POS=NNC que|#POS=PRO le|#POS=DET ...
	Il|#POS=PRO est|#POS=VRB vrai|#POS=ADJ ,|#POS=PCT si|#POS=CON ...
	D'|#POS=ADP après|#POS=ADP les|#POS=DET conclusions|#POS=NNC ...
	Il|#POS=PRO y|#POS=PRO avait|#POS=VRB un|#POS=DET moyen|#POS=NNC ...
	Placer|#POS=VRB la|#POS=DET construction|#POS=NNC ...
	On|#POS=PRO veut|#POS=VRB au|#POS=ADV contraire|#POS=ADV ...
	Le|#POS=DET rapport|#POS=NNC Delors|#POS=NNP est|#POS=VRB ...

La commande `dark.model("postag")` va charger ces données, entrainer un modèle
dessus et le sauvegarder dans un fichier "postag.mdl". Un second appel à cette
même commande rechargera simplement ce fichier.

Un modèle statistique est un objet Lua qui possède une méthode : `label`. Si
elle est appellé avec en paramètre une séquence, elle va prédire un tag pour
chaque token de cette séquence.

Exemple d'utilisation d'un modèle d'analyse morpho-syntaxique du français :

	mem = dark.model("dat/postag-fr")
	seq = dark.sequence("Le petit chat dort sur la table .")
	mem:label(seq)
	seq:dump()

Ce code affiche sur la console :

	[ 1] Le         { #POS=DET:1 }
	[ 2] petit      { #POS=ADJ:1 }
	[ 3] chat       { #POS=NNC:1 }
	[ 4] dort       { #POS=VRB:1 }
	[ 5] sur        { #POS=ADP:1 }
	[ 6] la         { #POS=DET:1 }
	[ 7] table      { #POS=NNC:1 }
	[ 8] .          { #POS=PCT:1 }

### Modèles fournis

Deux modèles d'analyse morpho-syntaxique sont fournis de base avec DARK,
`dat/postag-fr`pour le français et `dat/postag-en` pour l'anglais. Ces modèles
utilisent l'ensemble de tags suivant :

	PRO -- Pronoms
	DET -- Déterminants
	CON -- Conjonctions
	ADP -- Pré/post-positions
	NNC -- Noms communs
	NNP -- Noms propres
	VRB -- Verbes
	ADJ -- Adjectifs
	ADV -- Adverbes
	PRT -- Particules
	NUM -- Numeraux et cardinaux
	OTH -- Autres
	PCT -- Ponctuations

Ces modèles n'ont pas pour but d'être état-de-l'art mais uniquement suffisament
bon et rapide. Ils ont un taux d'erreur d'environ 5% sur du texte de type
journalistique ou similaire.

## Lexiques

Les lexiques sont la méthode la plus simple pour ajouter des tags basiques sur
une séquence. Ils permettent de tagger des informations pour lesquelles il est
posible de définir fiablement une liste plus ou moins exaustive des éléments à
annoter. Par exemple, ils sont adaptés pour la reconnaissance des jours de la
semaine ou des mois de l'année, ou bien pour les prénom de personnes ou nom de
pays.

Lorsque la liste d'alternative est réduite, elle peut être fournie directement à
la fonction `dark.lexicon(tag, liste)` sous la forme d'une table. Cette fonction
retourne un objet lexique qui reconnait toute les séquence de tokens spécifiées
et leur ajoute le tag fourni en paramètre. Par exemple :

	local lex = dark.lexicon("#jour", {"lundi", "mardi", ..., "dimanche"})

permet de créer un lexique qui reconnait les jours de la semaine et leur ajoute
le tag `#jour`. Quand la liste est trop importante pour qu'il soit pratique de
la spécifier directement, il est possible de la placée dans un fichier séparé
contenant une séquence de tokens par ligne. Il suffit ensuite de donner le nom
de ce fichier à la fonction `lexicon` :

	local lex = dark.lexicon("#prenom", "prenoms.txt")

Une fois le lexique créer, il suffit d'appeler la méthode `lex:exec(seq)` pour
l'appliquer sur une séquence. Toutes les occurences de tokens ou de séquence de
tokens présentes dans le lexique recevront un tag supplémentaire.

## Patterns

Les patterns sont des expressions régulières sur les tokens et les tags
composant les séquences. Ils permettent de reconnaitre certains motifs
et d'ajouter de nouveaux tags à une séquence en fonction des motifs reconus.

### Syntaxe de base

La syntaxe est similaire à celle des expressions régulière dans la majorité des
langages, mais adaptée au fait que l'on ne travail pas sur les caractères. Les
composants atomiques ne sont pas de simple caractère, mais des tokens ou des
tags. (ou des construction plus complèxes comme on va le voir)

Par exemple, le pattern suivant `Le petit chat` va reconnaître une séquence de
trois tokens spécifiés explicitement. Lorsqu'il sont constitués uniquement de
caractères alphanumériques, les tokens peuvent être écris tels quels. S'ils
contiennent d'autres caractère tels que de la ponctuation ou des espaces, il
doivent être entourés de guillemets simples ou doubles. (le caractère % permet
d'échaper le caractère suivant) On peut donc écrire `la table "."`.

Pour reconnaître un tag il suffit de spécifier sont nom sans oublier le prefixe
"#" : `Le #POS=ADJ chat` permet de reconnaître la même séquence que ci-dessus
mais avec n'importe quel adjectif à la place du token `petit`.

Les quantifieurs classiques `?`, `*` et`+` permettent de reconnaître
respectivement 0 ou 1, 0 ou plus et 1 ou plus instance de l'expression qu'ils
quantifient. Les parenthèses permettent de les appliquer sur une sous expression
plutôt que sur un seul token. Par exemple, `#POS=ADJ* #POS=NNC+` reconnait une
séquence d'au moins un nom commun précédé d'un nombre quelconque d'adjectifs.

Un quatrième quantifieur générique est disponible sous la forme `{n,m}`. Il
reconnait au minimum `n` instances de l'expression et au maximum `m` instances.
Il peut être utilisé sous la forme `{n}` afin de reconnaître exactement `n`
instance, sous la forme `{n,}` afin de ne pas préciser de maximum, ou bien sous
la forme `{,m}` afin de spécifier uniquement le nombre maximum d'instances.

La trois quantifieurs de base sont exprimable uniquement avec ce dernier
quantifieur généralisé :
    - `?` s'exprimme sous la forme `{,1}`
    - `*` s'exprimme sous la forme `{0,}`
    - `+` s'exprimme sous la forme `{1,}`

Par défaut les quantifieurs sont *greedy* c'est-à-dire qu'ils reconnaîtront la
plus longue séquence possible. Des versions *lazy* reconnaissant la plus petite
séquence possible sont aussi disponibles via `??`, `*?`, `+?` et `{n,m}?`.

Les alternatives `|` sont aussi disponibles et permettent de laisser le choix
entre différent patterns. Par exemple `(#POS=NNC | #POS=NNP)+` reconnait une
séquence non nulle de nom commun et de nom propres.

La reconnaissance des tokens est relativement peu flexible, pour plus de
libertées il est possible d'utiliser des expressions régulières. Pour cela, il
suffit de placer une expression régulière Lua entre `/` et un token n'est
reconnu que s'il match cette expression régulière : `( #POS=NNP | /^%u/ )+` par
exemple reconnaît une séquence non vide de nom propre et de tokens commencant
par une majuscule.

### Look-around

Deux opérateurs supplémentaire permette de réaliser des test complexes autour
du point courant. L'opérateur `<( expr )` vérifie si l'expression régulière
donnée entre parenthèse match la séquence de token précédent le point courant,
si ce n'est pas le cas, le matching échoue. L'opérateur `>( expr )` réalise la
même opération mais sur la séquence de tokens suivant le point courant.

Ces opérateurs permettent par exemple de tester si deux condition
s'appliquent, par exemple pour placer le tag `#X` sur un mot qui est à la fois
un nom propre et qui commence par une majuscule il est possible d'écrire le
patron suivant :

	[#X >( /^%u/ ) #POS=NNP ]

Ce patron commence par vérifier si le token suivant commence par une majuscule
à l'aide d'une expression régulière, et si c'est le cas, il vérifie qu'il à les
tag nom propre. Si les deux conditions sont vérifiée le tag `#X` sera ajouté.

### Captures

Le mécanisme des captures permet d'ajouter des tags sur les morceaux de séquence
reconnus par une expression régulière. Il suffit pour cela d'encadrer
l'expression régulière par des crochets `[...]` en faisant suivre le crochet
ouvran par le nom du tag à ajouter sur le segment reconnu. Par exemple,
l'expression suivante :

	[#personne ( #POS=NNP | /^%u/ )+ ]

Ajoutera le tag `#personne` à tous les segments non vides de noms propres et de
tokens commencant par une majuscule. Le nombre de captures par pattern et leur
imbrication n'est pas limité.

### Appel à Lua

Pour les pattrons les plus complexes, les opérateurs proposés peuvent ne pas
être suffisants, dans ce cas, il est possible de placer des appels à des
fonctions Lua au sein du pattron en précédant le nom de la fonction d'une
arobase. Quand un tel appel est rencontré lors de l'éxecution du patron, la
fonction Lua est appelée avec en paramètre la séquence et la position courante,
cette fonction doit renvoyer `true` si l'éxecution doit continuer et `false`
sinon. Seule des fonction globale peuvent être appelée de cette manière et un
tel appel n'est pas réalisable dans le cas d'un look-behind.

Par exemple, si l'on souhaite matcher les nom communs uniquement aux positions
paire d'une séquence, on peut utiliser le patron suivant :

	function mytest(seq, pos)
		return (pos % 2) == 0
	end

	[#X @mytest #POS=NNC ]

### Utilisation

L'utilisation des patterns est très similaire à celle des lexiques. La fonction
`dark.pattern(pat)` permet de créer un objet pattern et sont utilisation se fait
via la méthode `pat:exec(seq)` de cet objet:

	local pat = dark.pattern("[#personne ( #POS=NNP | /^%u/ )+ ]")
	pat:exec(seq)

## Pipelines

L'annotation à l'aide de DARK fait générallement intervenir des modèles, des
léxiques et des patterns qui sont appliqués successivement afin de construire
progressivement des annotation complèxes. Par exemple, la reconnaissance des
noms de personnes nécessite un lexique pour reconnaitre les prénoms, un
analyseur morpho-syntaxique pour reconnaître les noms propres, et un pattern qui
utilise les informations des deux étapes précédentes pour reconnaitre les noms
complets.

### Principe

Les pipelines fournisse un outils pour gérer simplement l'enchainement de ces
différentes étapes. La fonction `dark.pipeline()` permet de construire un
nouveau pipeline vide dans lequel il est possible d'ajouter des étapes qui
seront éxecutées successivement. L'éxecution d'un pipeline ce fait en
l'utilisant comme une fonction classique : `pipeline(seq)`. Cette éxecution
prend en paramètre soit une séquence soit une chaine de caractère qui sera
convertie automatiquement en séquence. L'ensemble des étapes sera appliquée sur
cette séquence qui sera retournée ensuite. Il est par exemple possible de
traiter toutes les ligne d'un fichier simplement avec le code suivant :

	local p = dark.pipeline()
	-- ... ajout des étapes
	for line in io.lines("fichier.txt") do
		local seq = p(line)
		print(seq)
	end

Ce code crée un nouveau pipeline, ajoute les étapes du traitement puis lit le
fichier ligne par ligne. Chaque ligne est convertie en séquence, les étapes du
pipeline sont appliquées dessus et la séquence résultat est affichée sous forme
balisée.

### Ajout des étapes

Les pipelines supportent tous les outils d'anotations présentés au dessus.
L'objet pipeline dispose des méthodes `p:model(file)`, `p:lexicon(tag, lst)` et
`p:pattern(pat)` qui se comportent comme les fonctions correspondate du module
`dark` mais ajoute l'objet créer au pipeline plutôt que de le donné à
l'utilisateur.

Il est donc facile de créer un pipeline pour reconnaitre les noms de personnes
avec le code suivant par exemple :

	local p = dark.pipeline()
	p:model("dat/postag-fr")
	p:lexicon("#prenom", "prenoms.txt")
	p:pattern("[#person #prenom #NNP*]")

Afin de permettre la réutilisation facile des pipelines, il est possible de les
imbriqués. Il est par exemple possible de construire des pipeline afin de
reconnaitre les personnes, les lieu et les évenement, puis de construire un
pipeline principal qui utilise chacun d'eux successivement :

	local p_pers = dark.pipeline()
	local p_lieu = dark.pipeline()
	local p_even = dark.pipeline()
	-- ... Remplissage des pipelines
	local main = dark.pipelin()
	main:add(p_pers)
	main:add(p_lieu)
	main:add(p_even)

## Serialization des tables

DARK fournis une fonction `serialize` qui permet de convertir facilement une
table sous la forme d'une chaine de caractère rechargeable facilement par Lua.
Le code suivant :

	local tab = {1, 2, "abc", { toto = 3}}
	print(serialize(tab))

Affichera :

	{
	  [1] = 1,
	  [2] = 2,
	  [3] = "abc",
	  [4] = {
	    toto = 3,
	  },
	}

Cette méthode gère les types de base de Lua qui sont directement convertible
ainsi que les tables sans cycles. Elle s'occupe d'échaper correctement tout ce
qui doit l'être et fait sont possible pour obtenir un affichage lisible pour un
humain.

## Extension supplémentaires

DARK fournis quelque fonction supplémentaires dans le module os de Lua afin de
faciliter la gestion des fichiers et répertoires.

  os.getcwd() : renvoie le répertoire courant
  os.chdir(path) : change le répetoire courant
  os.dir(path) : renvoie un itérateur sur le contenu d'un répertoire
  os.fileexists(path) : renvoie true si le fichier existe


