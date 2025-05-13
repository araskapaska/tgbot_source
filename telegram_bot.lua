-- плагин для работы с telegram bot api в solar2d
-- автор: @xqss_DEVELOPER

local json = require("json")
local http = require("socket.http")
local ltn12 = require("ltn12")
local mime = require("mime")

local telegram = {}
local baseUrl = "https://api.telegram.org/bot"
local botToken = nil
local lastChatId = nil
local lastEventData = {}

-- заменяем константы в тексте на данные из последнего события
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

-- инициализация бота
function telegram.init(params)
    botToken = params.token
    if not botToken then
        error("токен обязателен!")
    end
    -- сохраняем имя бота, если указано
    telegram.botName = params.botName or "UnknownBot"
end

-- отправка http-запроса
local function sendRequest(method, params, callback)
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
    end
    sendRequest("sendMessage", params, callback)
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
    sendRequest("send" .. type:gsub("^%l", string.upper), params, callback)
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
    sendRequest("sendMessage", params, callback)
end

-- ответ на callback-запрос
function telegram.answerCallbackQuery(callbackQueryId, text, showAlert, callback)
    local params = {
        callback_query_id = callbackQueryId
    }
    if text then params.text = replaceConstants(text) end
    if showAlert then params.show_alert = showAlert end
    sendRequest("answerCallbackQuery", params, callback)
end

-- запуск polling
function telegram.startPolling(eventHandler)
    local offset = 0
    local function poll()
        sendRequest("getUpdates", {offset = offset + 1, timeout = 30}, function(result, error)
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
    sendRequest("setWebhook", {url = url}, callback)
end

-- удаление вебхука
function telegram.deleteWebhook(callback)
    sendRequest("deleteWebhook", {}, callback)
end

return telegram
