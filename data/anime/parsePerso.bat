cls
SET doc=C:\Users\Shankar\github\manga-anime-chatbot\data\anime
for /r %%i in (*.json) do py %doc%\..\parseDescription.py -a %%~nxi
goto :eof