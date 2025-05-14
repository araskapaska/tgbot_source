-- Единый плагин для ботов и юзерботов в Telegram
-- Автор: @xqss_DEVELOPER

local json = require("json")
local http = require("socket.http")
local ltn12 = require("ltn12")
local mime = require("mime")
local mtproto = require("lua-telegram-mtproto") -- Требуется MTProto-библиотека

local telegram = {}
local baseUrl = "https://api.telegram.org/bot"
local botToken = nil
local lastChatId = nil
local lastEventData = {}
local apiId = nil
local apiHash = nil
local sessionData = nil

-- Замена констант в тексте
local function replaceConstants(text)
    if not text or type(text) ~= "string" then return text end
    local replacements = {
        ["$first_name$"] = lastEventData.first_name or "Неизвестно",
        ["$last_name$"] = lastEventData.last_name or "",
        ["$age$"] = lastEventData.age or "0",
        ["$last_message_text$"] = lastEventData.last_message_text or "",
        ["$username$"] = lastEventData.username or "Нет",
        ["$chat_id$"] = lastEventData.chat_id or "Неизвестно"
    }
    for key, value in pairs(replacements) do
        text = text:gsub(key, value)
    end
    return text
end

-- === API для ботов ===

-- Инициализация бота
function telegram.initBot(params)
    botToken = params.token
    if not botToken then
        error("Токен обязателен!")
    end
    telegram.botName = params.botName or "UnknownBot"
end

-- Отправка HTTP-запроса для бота
local function sendBotRequest(method, params, callback)
    if not botToken then
        if callback then callback(nil, "Бот не инициализирован") end
        return
    end
    local url = baseUrl .. botToken .. "/" .. method
    local body = {}
    for k, v in pairs(params) do
        body[#body + 1] = k .. "=" .. mime.b64(tostring(v))
    end
    body = table.concat(body, "&")
    local response = {}
    local _, code = http.request{
        url = url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Content-Length"] = #body
        },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(response)
    }
    local result = table.concat(response)
    if code == 200 then
        local decoded = json.decode(result)
        if decoded.ok then
            if callback then callback(decoded.result, nil) end
        else
            if callback then callback(nil, decoded.description or "Ошибка API") end
        end
    else
        if callback then callback(nil, "HTTP ошибка: " .. code) end
    end
end

-- Отправка сообщения
function telegram.sendMessage(chatId, text, options, callback)
    local params = {
        chat_id = chatId or lastChatId,
        text = replaceConstants(text)
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    if options then
        if options.parseMode then params.parse_mode = options.parseMode end
        if options.disableWebPagePreview then params.disable_web_page_preview = options.disableWebPagePreview end
        if options.replyMarkup then params.reply_markup = json.encode(options.replyMarkup) end
    end
    sendBotRequest("sendMessage", params, callback)
end

-- Отправка медиа
function telegram.sendMedia(chatId, type, media, options, callback)
    local params = {
        chat_id = chatId or lastChatId,
        [type] = media
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    if options then
        if options.caption then params.caption = replaceConstants(options.caption) end
        if options.parseMode then params.parse_mode = options.parseMode end
    end
    sendBotRequest("send" .. type:gsub("^%l", string.upper), params, callback)
end

-- Отправка inline-клавиатуры
function telegram.sendInlineKeyboard(chatId, text, keyboard, callback)
    local params = {
        chat_id = chatId or lastChatId,
        text = replaceConstants(text),
        reply_markup = json.encode({inline_keyboard = keyboard})
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("sendMessage", params, callback)
end

-- Ответ на callback-запрос
function telegram.answerCallbackQuery(callbackQueryId, text, showAlert, callback)
    local params = {
        callback_query_id = callbackQueryId
    }
    if text then params.text = replaceConstants(text) end
    if showAlert then params.show_alert = showAlert end
    sendBotRequest("answerCallbackQuery", params, callback)
end

-- Редактирование сообщения
function telegram.editMessage(chatId, messageId, text, options, callback)
    local params = {
        chat_id = chatId or lastChatId,
        message_id = messageId,
        text = replaceConstants(text)
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    if options then
        if options.parseMode then params.parse_mode = options.parseMode end
        if options.replyMarkup then params.reply_markup = json.encode(options.replyMarkup) end
    end
    sendBotRequest("editMessageText", params, callback)
end

-- Удаление сообщения
function telegram.deleteMessage(chatId, messageId, callback)
    local params = {
        chat_id = chatId or lastChatId,
        message_id = messageId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("deleteMessage", params, callback)
end

-- Получение информации о чате
function telegram.getChat(chatId, callback)
    local params = {
        chat_id = chatId or lastChatId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("getChat", params, callback)
end

-- Получение администраторов чата
function telegram.getChatAdministrators(chatId, callback)
    local params = {
        chat_id = chatId or lastChatId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("getChatAdministrators", params, callback)
end

-- Получение участника чата
function telegram.getChatMember(chatId, userId, callback)
    local params = {
        chat_id = chatId or lastChatId,
        user_id = userId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("getChatMember", params, callback)
end

-- Кик участника чата
function telegram.kickChatMember(chatId, userId, untilDate, callback)
    local params = {
        chat_id = chatId or lastChatId,
        user_id = userId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    if untilDate then params.until_date = untilDate end
    sendBotRequest("kickChatMember", params, callback)
end

-- Ограничение участника чата
function telegram.restrictChatMember(chatId, userId, permissions, callback)
    local params = {
        chat_id = chatId or lastChatId,
        user_id = userId,
        permissions = json.encode(permissions)
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("restrictChatMember", params, callback)
end

-- Повышение участника до админа
function telegram.promoteChatMember(chatId, userId, options, callback)
    local params = {
        chat_id = chatId or lastChatId,
        user_id = userId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    if options then
        for k, v in pairs(options) do
            params[k] = v
        end
    end
    sendBotRequest("promoteChatMember", params, callback)
end

-- Установка заголовка чата
function telegram.setChatTitle(chatId, title, callback)
    local params = {
        chat_id = chatId or lastChatId,
        title = title
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("setChatTitle", params, callback)
end

-- Установка описания чата
function telegram.setChatDescription(chatId, description, callback)
    local params = {
        chat_id = chatId or lastChatId,
        description = description
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("setChatDescription", params, callback)
end

-- Закрепление сообщения
function telegram.pinChatMessage(chatId, messageId, callback)
    local params = {
        chat_id = chatId or lastChatId,
        message_id = messageId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("pinChatMessage", params, callback)
end

-- Открепление сообщения
function telegram.unpinChatMessage(chatId, messageId, callback)
    local params = {
        chat_id = chatId or lastChatId,
        message_id = messageId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("unpinChatMessage", params, callback)
end

-- Выход из чата
function telegram.leaveChat(chatId, callback)
    local params = {
        chat_id = chatId or lastChatId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("leaveChat", params, callback)
end

-- Получение фото профиля
function telegram.getUserProfilePhotos(userId, callback)
    local params = {
        user_id = userId
    }
    sendBotRequest("getUserProfilePhotos", params, callback)
end

-- Отправка стикера
function telegram.sendSticker(chatId, sticker, callback)
    local params = {
        chat_id = chatId or lastChatId,
        sticker = sticker
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("sendSticker", params, callback)
end

-- Отправка голосового сообщения
function telegram.sendVoice(chatId, voice, options, callback)
    local params = {
        chat_id = chatId or lastChatId,
        voice = voice
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    if options then
        if options.caption then params.caption = replaceConstants(options.caption) end
    end
    sendBotRequest("sendVoice", params, callback)
end

-- Отправка видеозаметки
function telegram.sendVideoNote(chatId, videoNote, callback)
    local params = {
        chat_id = chatId or lastChatId,
        video_note = videoNote
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("sendVideoNote", params, callback)
end

-- Отправка геолокации
function telegram.sendLocation(chatId, latitude, longitude, callback)
    local params = {
        chat_id = chatId or lastChatId,
        latitude = latitude,
        longitude = longitude
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("sendLocation", params, callback)
end

-- Отправка контакта
function telegram.sendContact(chatId, phoneNumber, firstName, lastName, callback)
    local params = {
        chat_id = chatId or lastChatId,
        phone_number = phoneNumber,
        first_name = firstName
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    if lastName then params.last_name = lastName end
    sendBotRequest("sendContact", params, callback)
end

-- Пересылка сообщения
function telegram.forwardMessage(chatId, fromChatId, messageId, callback)
    local params = {
        chat_id = chatId or lastChatId,
        from_chat_id = fromChatId,
        message_id = messageId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("forwardMessage", params, callback)
end

-- Копирование сообщения
function telegram.copyMessage(chatId, fromChatId, messageId, callback)
    local params = {
        chat_id = chatId or lastChatId,
        from_chat_id = fromChatId,
        message_id = messageId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendBotRequest("copyMessage", params, callback)
end

-- Получение информации о боте
function telegram.getMe(callback)
    sendBotRequest("getMe", {}, callback)
end

-- Выход из аккаунта бота
function telegram.logOut(callback)
    sendBotRequest("logOut", {}, callback)
end

-- Закрытие сессии бота
function telegram.close(callback)
    sendBotRequest("close", {}, callback)
end

-- Запуск polling (бот)
function telegram.startBotPolling(eventHandler)
    local offset = 0
    local function poll()
        sendBotRequest("getUpdates", {offset = offset + 1, timeout = 30}, function(result, error)
            if error then
                print("Ошибка polling: " .. error)
                timer.performWithDelay(1000, poll)
                return
            end
            for _, update in ipairs(result) do
                offset = math.max(offset, update.update_id)
                local data = {}
                if update.message then
                    data.chat_id = update.message.chat.id
                    data.command = update.message.text and update.message.text:match("^/(%w+)")
                    data.text = update.message.text
                    lastChatId = data.chat_id
                    lastEventData = {
                        first_name = update.message.from.first_name or "",
                        last_name = update.message.from.last_name or "",
                        age = update.message.from.age or "0",
                        last_message_text = update.message.text or "",
                        username = update.message.from.username or "",
                        chat_id = tostring(data.chat_id)
                    }
                    eventHandler(update.message.text and "command" or "message", data)
                elseif update.callback_query then
                    data.callbackQueryId = update.callback_query.id
                    data.data = update.callback_query.data
                    data.chat_id = update.callback_query.message.chat.id
                    lastChatId = data.chat_id
                    lastEventData = {
                        first_name = update.callback_query.from.first_name or "",
                        last_name = update.callback_query.from.last_name or "",
                        age = update.callback_query.from.age or "0",
                        last_message_text = update.callback_query.message.text or "",
                        username = update.callback_query.from.username or "",
                        chat_id = tostring(data.chat_id)
                    }
                    eventHandler("callback_query", data)
                end
            end
            poll()
        end)
    end
    poll()
end

-- Настройка вебхука
function telegram.setWebhook(url, callback)
    sendBotRequest("setWebhook", {url = url}, callback)
end

-- Удаление вебхука
function telegram.deleteWebhook(callback)
    sendBotRequest("deleteWebhook", {}, callback)
end

-- === API для юзерботов ===

-- Инициализация юзербота
function telegram.initUserbot(params)
    apiId = params.apiId
    apiHash = params.apiHash
    if not apiId or not apiHash then
        error("apiId и apiHash обязательны! Получи их на my.telegram.org")
    end
    telegram.phoneNumber = params.phoneNumber
end

-- Авторизация: запрос кода
function telegram.requestCode(callback)
    if not telegram.phoneNumber then
        if callback then callback(nil, "Номер телефона не указан") end
        return
    end
    mtproto.auth.sendCode({
        api_id = apiId,
        api_hash = apiHash,
        phone_number = telegram.phoneNumber
    }, function(result, error)
        if error then
            if callback then callback(nil, error) end
        else
            sessionData = { phone_code_hash = result.phone_code_hash }
            if callback then callback(result, nil) end
        end
    end)
end

-- Авторизация: вход
function telegram.signIn(params, callback)
    if not sessionData or not sessionData.phone_code_hash then
        if callback then callback(nil, "Сначала запроси код через requestCode") end
        return
    end
    local authParams = {
        api_id = apiId,
        api_hash = apiHash,
        phone_number = telegram.phoneNumber,
        phone_code_hash = sessionData.phone_code_hash,
        phone_code = params.code
    }
    if params.cloudPassword then
        authParams.cloud_password = params.cloudPassword
    end
    mtproto.auth.signIn(authParams, function(result, error)
        if error then
            if error == "SESSION_PASSWORD_NEEDED" then
                if callback then callback(nil, "Нужен облачный пароль") end
            else
                if callback then callback(nil, error) end
            end
        else
            sessionData = { auth_key = result.auth_key, user_id = result.user.id }
            if callback then callback(result, nil) end
        end
    end)
end

-- Отправка MTProto-запроса
local function sendUserbotRequest(method, params, callback)
    if not sessionData or not sessionData.auth_key then
        if callback then callback(nil, "Юзербот не авторизован") end
        return
    end
    mtproto.invoke({
        method = method,
        params = params,
        auth_key = sessionData.auth_key
    }, function(result, error)
        if error then
            if callback then callback(nil, error) end
        else
            if callback then callback(result, nil) end
        end
    end)
end

-- Отправка сообщения
function telegram.userbotSendMessage(chatId, text, options, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        message = replaceConstants(text)
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    if options then
        if options.parseMode then params.parse_mode = options.parseMode end
        if options.replyMarkup then params.reply_markup = json.encode(options.replyMarkup) end
    end
    sendUserbotRequest("messages.sendMessage", params, callback)
end

-- Отправка медиа
function telegram.userbotSendMedia(chatId, type, media, options, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        media = { ["@type"] = "inputMedia" .. type:gsub("^%l", string.upper), url = media }
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    if options then
        if options.caption then params.media.caption = replaceConstants(options.caption) end
    end
    sendUserbotRequest("messages.sendMedia", params, callback)
end

-- Получение участников чата
function telegram.userbotGetChatMembers(chatId, callback)
    local params = {
        chat_id = chatId or lastChatId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.getChatMembers", params, callback)
end

-- Пересылка сообщения
function telegram.userbotForwardMessage(fromChatId, messageId, toChatId, callback)
    local params = {
        from_peer = { ["@type"] = "inputPeerChat", chat_id = fromChatId },
        id = messageId,
        to_peer = { ["@type"] = "inputPeerChat", chat_id = toChatId or lastChatId }
    }
    if not params.to_peer.chat_id then
        if callback then callback(nil, "toChatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.forwardMessages", params, callback)
end

-- Редактирование сообщения
function telegram.userbotEditMessage(chatId, messageId, text, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        id = messageId,
        message = replaceConstants(text)
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.editMessage", params, callback)
end

-- Удаление сообщения
function telegram.userbotDeleteMessage(chatId, messageId, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        id = messageId
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.deleteMessages", params, callback)
end

-- Создание чата
function telegram.userbotCreateChat(title, users, callback)
    local params = {
        title = title,
        users = users
    }
    sendUserbotRequest("messages.createChat", params, callback)
end

-- Присоединение к каналу
function telegram.userbotJoinChannel(channelId, callback)
    local params = {
        channel = { ["@type"] = "inputChannel", channel_id = channelId }
    }
    sendUserbotRequest("channels.joinChannel", params, callback)
end

-- Выход из канала
function telegram.userbotLeaveChannel(channelId, callback)
    local params = {
        channel = { ["@type"] = "inputChannel", channel_id = channelId }
    }
    sendUserbotRequest("channels.leaveChannel", params, callback)
end

-- Приглашение пользователей в чат
function telegram.userbotInviteToChat(chatId, userIds, callback)
    local params = {
        chat_id = chatId or lastChatId,
        users = userIds
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.addChatUsers", params, callback)
end

-- Кик пользователя из чата
function telegram.userbotKickChatMember(chatId, userId, callback)
    local params = {
        chat_id = chatId or lastChatId,
        user_id = userId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.deleteChatUser", params, callback)
end

-- Получение истории чата
function telegram.userbotGetChatHistory(chatId, limit, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        limit = limit or 100
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.getHistory", params, callback)
end

-- Поиск сообщений
function telegram.userbotSearchMessages(chatId, query, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        query = query
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.search", params, callback)
end

-- Установка статуса ввода
function telegram.userbotSetTyping(chatId, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        action = { ["@type"] = "sendMessageTypingAction" }
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.setTyping", params, callback)
end

-- Получение информации о пользователе
function telegram.userbotGetUser(userId, callback)
    local params = {
        user_id = userId
    }
    sendUserbotRequest("users.getUsers", params, callback)
end

-- Добавление контакта
function telegram.userbotAddContact(userId, firstName, lastName, callback)
    local params = {
        user_id = userId,
        first_name = firstName,
        last_name = lastName or ""
    }
    sendUserbotRequest("contacts.addContact", params, callback)
end

-- Удаление контакта
function telegram.userbotDeleteContact(userId, callback)
    local params = {
        user_id = userId
    }
    sendUserbotRequest("contacts.deleteContact", params, callback)
end

-- Получение списка контактов
function telegram.userbotGetContacts(callback)
    sendUserbotRequest("contacts.getContacts", {}, callback)
end

-- Отправка стикера
function telegram.userbotSendSticker(chatId, stickerId, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        media = { ["@type"] = "inputMediaSticker", id = stickerId }
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.sendMedia", params, callback)
end

-- Отправка голосового сообщения
function telegram.userbotSendVoice(chatId, voiceUrl, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        media = { ["@type"] = "inputMediaVoice", url = voiceUrl }
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.sendMedia", params, callback)
end

-- Отметка сообщения как прочитанного
function telegram.userbotMarkMessageRead(chatId, messageId, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        id = messageId
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.readMessageContents", params, callback)
end

-- Создание супергруппы
function telegram.userbotCreateSupergroup(title, callback)
    local params = {
        title = title
    }
    sendUserbotRequest("channels.createChannel", params, callback)
end

-- Установка фото профиля
function telegram.userbotSetProfilePhoto(photoUrl, callback)
    local params = {
        photo = { ["@type"] = "inputPhoto", url = photoUrl }
    }
    sendUserbotRequest("photos.uploadProfilePhoto", params, callback)
end

-- Обновление статуса
function telegram.userbotUpdateStatus(status, callback)
    local params = {
        status = status
    }
    sendUserbotRequest("account.updateStatus", params, callback)
end

-- Блокировка пользователя
function telegram.userbotBlockUser(userId, callback)
    local params = {
        user_id = userId
    }
    sendUserbotRequest("contacts.block", params, callback)
end

-- Разблокировка пользователя
function telegram.userbotUnblockUser(userId, callback)
    local params = {
        user_id = userId
    }
    sendUserbotRequest("contacts.unblock", params, callback)
end

-- Получение списка чатов
function telegram.userbotGetChats(callback)
    sendUserbotRequest("messages.getChats", {}, callback)
end

-- Установка реакции на сообщение
function telegram.userbotSetMessageReaction(chatId, messageId, reaction, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        msg_id = messageId,
        reaction = { ["@type"] = "reactionEmoji", emoticon = reaction }
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.sendReaction", params, callback)
end

-- Чтение сообщений
function telegram.userbotReadMessages(chatId, messageIds, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        id = messageIds
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.readMessages", params, callback)
end

-- Получение списка активных сессий
function telegram.userbotGetSessions(callback)
    sendUserbotRequest("account.getAuthorizations", {}, callback)
end

-- Завершение сессии
function telegram.userbotTerminateSession(sessionId, callback)
    local params = {
        session_id = sessionId
    }
    sendUserbotRequest("account.resetAuthorization", params, callback)
end

-- Пин сообщения
function telegram.userbotPinMessage(chatId, messageId, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId },
        id = messageId
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.updatePinnedMessage", params, callback)
end

-- Отключение уведомлений
function telegram.userbotMuteChat(chatId, callback)
    local params = {
        peer = { ["@type"] = "inputPeerChat", chat_id = chatId or lastChatId }
    }
    if not params.peer.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.toggleNoNotifications", params, callback)
end

-- Экспорт данных чата
function telegram.userbotExportChat(chatId, callback)
    local params = {
        chat_id = chatId or lastChatId
    }
    if not params.chat_id then
        if callback then callback(nil, "chatId не указан и нет активного чата") end
        return
    end
    sendUserbotRequest("messages.exportChatInvite", params, callback)
end

-- Запуск polling (юзербот)
function telegram.userbotStartPolling(eventHandler)
    mtproto.updates.startPolling(function(update)
        local data = {}
        if update["@type"] == "updateNewMessage" then
            data.chat_id = update.message.chat_id
            data.text = update.message.content.text
            data.channel_post = update.message.is_channel_post
            lastChatId = data.chat_id
            lastEventData = {
                first_name = update.message.sender.first_name or "",
                last_name = update.message.sender.last_name or "",
                age = update.message.sender.age or "0",
                last_message_text = data.text or "",
                username = update.message.sender.username or "",
                chat_id = tostring(data.chat_id)
            }
            eventHandler(data.channel_post and "channel_post" or "message", data)
        elseif update["@type"] == "updateCallbackQuery" then
            data.callbackQueryId = update.id
            data.data = update.data
            data.chat_id = update.chat_id
            lastChatId = data.chat_id
            lastEventData = {
                first_name = update.sender.first_name or "",
                last_name = update.sender.last_name or "",
                age = update.sender.age or "0",
                last_message_text = update.message.text or "",
                username = update.sender.username or "",
                chat_id = tostring(data.chat_id)
            }
            eventHandler("callback_query", data)
        end
    end)
end

return telegram
