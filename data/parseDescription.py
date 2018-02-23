# -*- coding: utf-8 -*-

import sys
import io
import json
import requests
import argparse

def normalize_string(raw_string):
    raw_string = raw_string.replace("\"","\\\"")
    raw_string = raw_string.replace("&#039;","'")
    return raw_string

if __name__ == '__main__':
    #reload(sys)
    #sys.setdefaultencoding('utf-8')
    argparser = argparse.ArgumentParser()
    argparser.add_argument("-a","--anime",help='anime sheet in json file')
    args = argparser.parse_args()

    pathName = str(args.anime)

    with io.open(pathName,encoding="utf8") as fp:
        data = json.load(fp,encoding="utf8")
    print(args.anime)
    orig_stdout = sys.stdout
    persos = data["character"]
    luaFileName = str("perso/perso_")+pathName.replace("json","lua")
    luaFile = open(luaFileName,"w")
    sys.stdout = luaFile
    print("return {")
    print("\t[\"id\"] = "+str(data["mal_id"])+",")
    title_alternative = ""
    if "title_synonyms" in data is not None and data["title_synonyms"] is not None:
        altern_title = ""
        at = (data["title_synonyms"]).split(",")
        for nn in at:
            altern_title= "%s \"%s\"," % (altern_title,nn)
        title_alternative = "%s%s" % (title_alternative,altern_title)

    title_alternative = "%s \" %s \" " % (title_alternative,data["title_english"])
    title_alternative = normalize_string(title_alternative)
    print("\t[\"title_alternative\"] = {{{0}}},".format(title_alternative))
    charaW = ""
    for chara in persos:
        cid = chara["mal_id"]

        api_url = "https://api.jikan.me/character/"+str(cid)
        res = requests.get(api_url)
        if res.status_code == 200:
            cW = ""
            chara_data = res.json()
            cW = cW+"[\"mal_id\"] = %s, " % (cid)
            characterW = ""
            for c in data["character"]:
                name = chara_data["name"].split(" ")
                characterW = " [\"firstname\"] = \"%s\", [\"lastname\"] = \"%s\", " % (normalize_string(name[-1]),normalize_string(name[0]))
            cW = "%s %s"% (cW,characterW)
            if chara_data["about"] is not None:
                descrp = normalize_string(chara_data["about"])
            nickname = ""
            if "nicknames" in chara_data is not None and chara_data["nicknames"] is not None:
                n = normalize_string(chara_data["nicknames"]).split(",")
                for nn in n:
                    nickname = "%s \"%s\"," % (nickname,nn)
        else:
            print("ERROR ECHEC REST CALL",file=sys.stdout)
            '''fp.close()
            luaFile.close()
            exit()'''
        cW = "%s [\"nicknames\"] = { %s }, [\"description\"] = \"%s\"," %(cW,nickname,descrp)
        charaW = "%s {%s},"%(charaW,cW)
    charaW = charaW.encode('utf-8')
    charaW = charaW[:-1]
    print("\t[\"characters\"] = {{{0}}},".format(str(charaW)))
    print("}")
    sys.stdout = orig_stdout
    luaFile.close()
    fp.close()
