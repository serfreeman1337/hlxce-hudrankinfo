# HLStatsX:CE HUD Rank Info
HUD информер о текущем звании игрока в статистке HLStatsX:CE

## Квары
* **hlxce_host** "localhost" - хост бд
* **hlxce_user** "root" - пользователь бд
* **hlxce_password** "" - пароль бд
* **hlxce_db** "hlxce" - название бд hlstatsx
* **hlxce_game** "valve" - код игры сервера
* **hlxce_informer_update** "1.5" - время обновления информера в секундах
* **hlxce_informer_pos** "0.11 0.05" - позиция информера на экране
* **hlxce_informer_color** "100 100 100" - цвет информера в формате rgb или random для случайного цвета

## Информация
* colorchat.inc можно скачать на странице компилятора AGHL.ru (http://aghl.ru/webcompiler/include/colorchat.inc)
* для поддержки русских званий вам потребуется модуль MySQL с AMXX 1.8.3-dev-git3799 или выше (http://www.amxmodx.org/snapshots.php)
* звания считываются с БД в файл **data/hlxce_ranks.ini**
* поддерживается только учет игроков по steamid