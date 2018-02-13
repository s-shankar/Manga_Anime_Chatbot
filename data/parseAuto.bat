cls
SET doc=C:\Users\Shankar\github\manga-anime-chatbot\data
for /r %%i in (manga\*.json) do py %doc%\parserAnime.py -m %%~nxi
for /r %%i in (anime\*.json) do py %doc%\parserAnime.py -a %%~nxi
goto :eof