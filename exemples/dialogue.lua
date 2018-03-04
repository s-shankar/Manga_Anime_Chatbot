
dark = require("dark")

dofile("nlu.lua")
dofile("fonctions.lua")

-- Fonction pour récupérer la question de l'utilisateur
function getInput()
   print("Bonjour !\n")
   dialog_state = {}
   turn = 0
   print("Je connais tout sur les auteurs. Que voulez vous savoir? (ou appuyer q pour quitter)\n")
   while true do
      
      question = io.read()
      if question == "q" or question == "Q"  then
	 break;
      end
      question = question:gsub("(%p)", " %1 ")
      question = dark.sequence(question)
      pipe(question)
      print(pipe(question))
      -- contextual understanding
      -- on commence par recuperer hors contexte
      if (#question["#nomAuteur"]) ~= 0 then
		dialog_state.hckey = question:tag2str("#nomAuteur")[1]
      else
		dialog_state.hckey = nil
      end

      if (#question["#Qdate"]) ~= 0 then
		dialog_state.hctypes = "Qdate"
      elseif (#question["#Qauteur"]) ~= 0 then
		dialog_state.hctypes = "Qauteur"
      elseif (#question["#Qtitre"]) ~= 0 then
		dialog_state.hctypes = "Qtitre"
      else
		dialog_state.hctypes = nil
      end

      -- en contexte on veut récupérer ssi on a au moins un élément
      -- d'une autre classe (key ou types)
      if (dialog_state.hckey) then
		dialog_state.eckey = dialog_state.hckey
      elseif (dialog_state.hctypes) then
	 -- on conserve la key précédente
		dialog_state.eckey = dialog_state.eckey
      else
		dialog_state.eckey = nil
      end

      if (dialog_state.hctypes) then
		dialog_state.ectypes = dialog_state.hctypes
      elseif (dialog_state.hckey) then
	 -- on conserve la key précédente
		dialog_state.ectypes = dialog_state.ectypes
      else
		dialog_state.ectypes = nil
      end

      print(dialog_state.eckey, dialog_state.ectypes)
      turn = turn + 1

      -- on commence le dialogue
      if dialog_state.eckey then
	 if dialog_state.ectypes == "Qdate" then
	    keyValue = dialog_state.eckey
	    typesValue = "birthdate"
	    local res = getFromDB(keyValue, typesValue)
	    local firstname = getFromDB(keyValue, "firstname")
	    if res == 0 then
	       print("Désolé, je n'ai pas cette information")
	    elseif res == -1 then
	       print("Désolé, je n'ai pas ".. keyValue.." dans ma base d'auteurs.")
  	    else
	       print(firstname, keyValue, "est né le ", res)
	    end
	 end
	 if dialog_state.ectypes == "Qtitre" then
	    keyValue = dialog_state.eckey
	    typesValue = "livres"
	    local res = getFromDB(keyValue, typesValue)
	    local firstname = getFromDB(keyValue, "firstname")
	    if res == 0 then
	       print("Désolé, je n'ai pas cette information")
	    elseif res == -1 then
	       print("Désolé, je n'ai pas ".. keyValue.."dans ma base")
  	    else
	       print(firstname, keyValue, "a écrit ".. #res .." romans :")
	       -- c'est une table
	       for i,elem in ipairs(res) do
		  print(elem)
	       end

	    end
	 end
      end
      if dialog_state.ectypes and not dialog_state.eckey then
	 print("toto")
	 print("Sur quel auteur voulez-vous une information ?")
      end
   end
end
getInput()

-- key = nomAuteur
-- types = Qauteur Qtitre Qdate
