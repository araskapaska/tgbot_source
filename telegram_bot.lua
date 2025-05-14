-- единый плагин для ботов и юзерботов в telegram
-- автор: @xqss_DEVELOPER

local json = require("json")
local http = require("socket.http")
local ltn12 = require("ltn12")
local mime = require("mime")
local mtproto = require("lua-telegram-mtproto") -- заглушка, нужна mtproto-библиотека

local telegram = {}
local baseUrl = "https://api.telegram.org/bot"
local botToken = nil
local lastChatId = nil
local lastEventData = {}
local apiId = nil
local apiHash = nil
local sessionData = nil

-- заменяем константы в тексте
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

-- инициализация бота
function telegram.initBot(params)
    botToken = params.token
    if not botToken then
        error("токен обязателен!")
    end
    telegram.botName = params.botName or "UnknownBot"
end

-- отправка http-запроса для бота
local function sendBotRequest(method, params, callback)
    if not botToken then
        if callback then callback(nil, "бот не инициализирован") end
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
            if callback then callback(nil, decoded.description or "ошибка api") end
        end
    else
        if callback then callback(nil, "http ошибка: " .. code) end
    end
end

-- отправка сообщения
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

-- отправка медиа
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

-- отправка inline-клавиатуры
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

-- ответ на callback-запрос
function telegram.answerCallbackQuery(callbackQueryId, text, showAlert, callback)
    local params = {
        callback_query_id = callbackQueryId
    }
    if text then params.text = replaceConstants(text) end
    if showAlert then params.show_alert = showAlert end
    sendBotRequest("answerCallbackQuery", params, callback)
end

-- редактирование сообщения
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

-- удаление сообщения
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

-- получение информации о чате
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

-- получение администраторов чата
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

-- получение участника чата
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

-- кик участника чата
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

-- ограничение участника чата
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

-- повышение участника до админа
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

-- установка заголовка чата
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

-- установка описания чата
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

-- закрепление сообщения
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

-- открепление сообщения
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

-- выход из чата
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

-- получение фото профиля
function telegram.getUserProfilePhotos(userId, callback)
    local params = {
        user_id = userId
    }
    sendBotRequest("getUserProfilePhotos", params, callback)
end

-- отправка стикера
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

-- отправка голосового сообщения
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

-- отправка видеозаметки
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

-- отправка геолокации
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

-- отправка контакта
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

-- пересылка сообщения
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

-- копирование сообщения
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

-- получение информации о боте
function telegram.getMe(callback)
    sendBotRequest("getMe", {}, callback)
end

-- выход из аккаунта бота
function telegram.logOut(callback)
    sendBotRequest("logOut", {}, callback)
end

-- закрытие сессии бота
function telegram.close(callback)
    sendBotRequest("close", {}, callback)
end

-- запуск polling (бот)
function telegram.startBotPolling(eventHandler)
    local offset = 0
    local function poll()
        sendBotRequest("getUpdates", {offset = offset + 1, timeout = 30}, function(result, error)
            if error then
                print("ошибка polling: " .. error)
                timer.performWithDelay(1000, poll)
                return
            end
            for _, update in ipairs(result) do
                offset = math.max(offset, update.update_id)
                local data = {}
                if update.message then
                    data.chatId = update.message.chat.id
                    data.command = update.message.text and update.message.text:match("^/(%w+)")
                    data.text = update.message.text
                    lastChatId = data.chatId
                    lastEventData = {
                        first_name = update.message.from.first_name or "",
                        last_name = update.message.from.last_name or "",
                        age = update.message.from.age or "0",
                        last_message_text = update.message.text or "",
                        username = update.message.from.username or "",
                        chat_id = tostring(data.chatId)
                    }
                    eventHandler(update.message.text and "command" or "message", data)
                elseif update.callback_query then
                    data.callbackQueryId = update.callback_query.id
                    data.data = update.callback_query.data
                    data.chatId = update.callback_query.message.chat.id
                    lastChatId = data.chatId
                    lastEventData = {
                        first_name = update.callback_query.from.first_name or "",
                        last_name = update.callback_query.from.last_name or "",
                        age = update.callback_query.from.age or "0",
                        last_message_text = update.callback_query.message.text or "",
                        username = update.callback_query.from.username or "",
                        chat_id = tostring(data.chatId)
                    }
                    eventHandler("callback_query", data)
                end
            end
            poll()
        end)
    end
    poll()
end

-- настройка вебхука
function telegram.setWebhook(url, callback)
    sendBotRequest("setWebhook", {url = url}, callback)
end

-- удаление вебхука
function telegram.deleteWebhook(callback)
    sendBotRequest("deleteWebhook", {}, callback)
end

-- === API для юзерботов ===

-- инициализация юзербота
function telegram.initUserbot(params)
    apiId = params.apiId
    apiHash = params.apiHash
    if not apiId or not apiHash then
        error("apiId и apiHash обязательны! получи их на my.telegram.org")
    end
    telegram.phoneNumber = params.phoneNumber
end

-- авторизация: запрос кода
function telegram.requestCode(callback)
    if not telegram.phoneNumber then
        if callback then callback(nil, "номер телефона не указан") end
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

-- авторизация: вход
function telegram.signIn(params, callback)
    if not sessionData or not sessionData.phone_code_hash then
        if callback then callback(nil, "сначала запроси код через requestCode") end
        return
    end
    local authParams = {
        api_id = apiId,
        api_hash = apiHash,
        phone_number = telegram.phoneNumber,
        phone_code_hash = sessionData.phone_code_hash,
        phone_code = params.code
    }
    if params.password then
        authParams.password = params.password
    end
    mtproto.auth.signIn(authParams, function(result, error)
        if error then
            if error == "SESSION_PASSWORD_NEEDED" then
                if callback then callback(nil, "нужен пароль 2FA") end
            else
                if callback then callback(nil, error) end
            end
        else
            sessionData = { auth_key = result.auth_key, user_id = result.user.id }
            if callback then callback(result, nil) end
        end
    end)
end

-- отправка mtproto-запроса
local function sendUserbotRequest(method, params, callback)
    if not sessionData or not sessionData.auth_key then
        if callback then callback(nil, "юзербот не авторизован") end
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

-- методы юзербота (30)

-- отправка сообщения
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
    end
    sendUserbotRequest("messages.sendMessage", params, callback)
end

-- отправка медиа
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

-- получение участников чата
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

-- пересылка сообщения
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

-- редактирование сообщения
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

-- удаление сообщения
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

-- создание чата
function telegram.userbotCreateChat(title, users, callback)
    local params = {
        title = title,
        users = users
    }
    sendUserbotRequest("messages.createChat", params, callback)
end

-- присоединение к каналу
function telegram.userbotJoinChannel(channelId, callback)
    local params = {
        channel = { ["@type"] = "inputChannel", channel_id = channelId }
    }
    sendUserbotRequest("channels.joinChannel", params, callback)
end

-- выход из канала
function telegram.userbotLeaveChannel(channelId, callback)
    local params = {
        channel = { ["@type"] = "inputChannel", channel_id = channelId }
    }
    sendUserbotRequest("channels.leaveChannel", params, callback)
end

-- приглашение пользователей в чат
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

-- кик пользователя из чата
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

-- получение истории чата
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

-- поиск сообщений
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

-- установка статуса ввода
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

-- получение информации о пользователе
function telegram.userbotGetUserInfo(userId, callback)
    local params = {
        user_id = userId
    }
    sendUserbotRequest("users.getUsers", params, callback)
end

-- добавление контакта
function telegram.userbotAddContact(userId, firstName, lastName, callback)
    local params = {
        user_id = userId,
        first_name = firstName,
        last_name = lastName or ""
    }
    sendUserbotRequest("contacts.addContact", params, callback)
end

-- удаление контакта
function telegram.userbotDeleteContact(userId, callback)
    local params = {
        user_id = userId
    }
    sendUserbotRequest("contacts.deleteContact", params, callback)
end

-- получение списка контактов
function telegram.userbotGetContacts(callback)
    sendUserbotRequest("contacts.getContacts", {}, callback)
end

-- отправка стикера
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

-- отправка голосового сообщения
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

-- отметка сообщения как прочитанного
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

-- создание супергруппы
function telegram.userbotCreateSupergroup(title, callback)
    local params = {
        title = title
    }
    sendUserbotRequest("channels.createChannel", params, callback)
end

-- установка фото профиля
function telegram.userbotSetProfilePhoto(photoUrl, callback)
    local params = {
        photo = { ["@type"] = "inputPhoto", url = photoUrl }
    }
    sendUserbotRequest("photos.uploadProfilePhoto", params, callback)
end

-- обновление статуса
function telegram.userbotUpdateStatus(status, callback)
    local params = {
        status = status
    }
    sendUserbotRequest("account.updateStatus", params, callback)
end

-- блокировка пользователя
function telegram.userbotBlockUser(userId, callback)
    local params = {
        user_id = userId
    }
    sendUserbotRequest("contacts.block", params, callback)
end

-- разблокировка пользователя
function telegram.userbotUnblockUser(userId, callback)
    local params = {
        user_id = userId
    }
    sendUserbotRequest("contacts.unblock", params, callback)
end

-- получение списка чатов
function telegram.userbotGetChats(callback)
    sendUserbotRequest("messages.getChats", {}, callback)
end

-- пин сообщения
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

-- отключение уведомлений
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

-- экспорт данных чата
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

-- запуск polling (юзербот)
function telegram.startUserbotPolling(eventHandler)
    mtproto.updates.startPolling(function(update)
        local data = {}
        if update["@type"] == "updateNewMessage" then
            data.chatId = update.message.chat_id
            data.text = update.message.content.text
            lastChatId = data.chatId
            lastEventData = {
                first_name = update.message.sender.first_name or "",
                last_name = update.message.sender.last_name or "",
                age = update.message.sender.age or "0",
                last_message_text = data.text or "",
                username = update.message.sender.username or "",
                chat_id = tostring(data.chatId)
            }
            eventHandler("message", data)
        elseif update["@type"] == "updateCallbackQuery" then
            data.callbackQueryId = update.id
            data.data = update.data
            data.chatId = update.chat_id
            lastChatId = data.chatId
            lastEventData = {
                first_name = update.sender.first_name or "",
                last_name = update.sender.last_name or "",
                age = update.sender.age or "0",
                last_message_text = update.message.text or "",
                username = update.sender.username or "",
                chat_id = tostring(data.chatId)
            }
            eventHandler("callback_query", data)
        end
    end)
end

return telegram
