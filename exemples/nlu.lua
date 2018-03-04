dark = require("dark")


tags = {
   ["#nomAuteur"] = "red",
   ["#Qauteur"] = "blue",
   ["#Qdate"] = "cyan",
   ["#Qtitre"] = "green",
}

pipe = dark.pipeline()
pipe:basic()

pipe:lexicon("#nomAuteur", "dic/nomAuteur.txt")
pipe:lexicon("#Qauteur", {"qui a écrit", "écrit par qui", "auteur"})
pipe:lexicon("#Qtitre", {"le titre de", "quel livre","quel roman","quels romans"})
pipe:lexicon("#Qdate", {"quand"})

