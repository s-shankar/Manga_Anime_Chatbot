cls
SET doc=C:\Users\Shankar\github\manga-anime-chatbot\data\manga
for /r %%i in (*.json) do py %doc%\..\parseDescription.py -m %%~nxi
goto :eof