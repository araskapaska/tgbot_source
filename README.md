TGBOT SOLAR API
Плагин для Solar2D, чтобы создавать Telegram-ботов: отправка сообщений, медиа, inline-кнопки, polling и вебхуки. Создан @xqss_DEVELOPER.
Установка

Скопируй telegram_bot.lua в корень проекта.
Инициализируй бота:

local telegram = require("telegram_bot")
telegram.init({ token = "YOUR_BOT_TOKEN", botName = "@YourBotName" })

Токен получи у @BotFather.
Пример
Отправка сообщения:
telegram.sendMessage(chatId, "привет от solar2d!", { parseMode = "Markdown" }, function(result, error)
    if error then print("ошибка: " .. error) else print("сообщение ушло!") end
end)

Документация
Подробности: https://yourdomain.com/docs
Поддержка

Исходный код: GitHub
Обсуждение: Telegram-канал
Контакт: @xqss_DEVELOPER

Лицензия
MIT
