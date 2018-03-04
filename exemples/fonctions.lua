db = dofile("database.lua")

--Fonction pour récupérer les informations
function getFromDB(nomAuteur, ...)
  b=0
  local arg = {...}
  for k,v in pairs(db) do
    if(k == nomAuteur) then
      b=1
      tab = v
      --parcours en profondeur
      for i,champ in ipairs(arg) do
        tab = tab[champ]
      end
      --On a detecte des elements
      if(tab ~= nil) then
	      return tab
	    else
	  	  return 0 --"Désolé, je n'ai pas cette information"
	    end
    end
  end
  if b==0 then
  	return -1 --"Désolé, je ne comprends pas de quel pays vous parlez"
  end
end