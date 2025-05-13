local json = require("json")
local M = {}


local config = {
    token = nil, 
    apiUrl = "https://api.telegram.org/bot",
    pollingTimeout = 30, 
    botName = nil -
}

-- Инициализация бота
function M.init(options)
    options = options or {}
    config.token = options.token or error("Bot token is required")
    config.botName = options.botName or ""
    config.apiUrl = config.apiUrl .. config.token .. "/"
end


local function makeRequest(method, params, callback)
    if not config.token then
        error("Bot not initialized. Call init() with a valid token.")
    end
    local url = config.apiUrl .. method
    local headers = {
        ["Content-Type"] = "application/json"
    }
    local body = json.encode(params)
    
    network.request(url, "POST", function(event)
        if not event.isError then
            local response = json.decode(event.response)
            if response.ok then
                if callback then
                    callback(response.result, nil)
                end
            else
                if callback then
                    callback(nil, "API Error: " .. (response.description or "Unknown error"))
                end
            end
        else
            if callback then
                callback(nil, "Network Error: " .. (event.status or "Unknown"))
            end
        end
    end, {
        headers = headers,
        body = body
    })
end

function M.sendMessage(chatId, text, options, callback)
    options = options or {}
    local params = {
        chat_id = chatId,
        text = text,
        parse_mode = options.parseMode or "Markdown",
        reply_markup = options.replyMarkup
    }
    makeRequest("sendMessage", params, callback)
end

function M.sendMedia(chatId, mediaType, mediaUrl, options, callback)
    options = options or {}
    local method = ({
        photo = "sendPhoto",
        video = "sendVideo",
        document = "sendDocument",
        audio = "sendAudio"
    })[mediaType]
    if not method then
        error("Invalid media type. Use: photo, video, document, audio")
    end
    local params = {
        chat_id = chatId,
        [mediaType] = mediaUrl,
        caption = options.caption,
        parse_mode = options.parseMode or "Markdown",
        reply_markup = options.replyMarkup
    }
    makeRequest(method, params, callback)
end


function M.sendInlineKeyboard(chatId, text, buttons, callback)
    local params = {
        chat_id = chatId,
        text = text,
        reply_markup = {
            inline_keyboard = buttons
        }
    }
    makeRequest("sendMessage", params, callback)
end

function M.answerCallbackQuery(callbackQueryId, text, showAlert, callback)
    local params = {
        callback_query_id = callbackQueryId,
        text = text or "",
        show_alert = showAlert or false
    }
    makeRequest("answerCallbackQuery", params, callback)
end

function M.getUpdates(offset, callback)
    local params = {
        offset = offset or 0,
        timeout = config.pollingTimeout,
        allowed_updates = {"message", "callback_query"} 
    }
    makeRequest("getUpdates", params, function(result, error)
        if result then
            for _, update in ipairs(result) do
                callback(update, nil)
            end
        else
            callback(nil, error)
        end
    end)
end

function M.startPolling(eventHandler)
    local lastUpdateId = 0
    local function poll()
        M.getUpdates(lastUpdateId + 1, function(update, error)
            if update then
                lastUpdateId = update.update_id
                if update.message then
                    local message = update.message
                    local chatId = message.chat.id
                    local text = message.text
                    local isGroup = message.chat.type == "group" or message.chat.type == "supergroup"
                    
                    if text and text:sub(1, 1) == "/" then
                        local command, args = text:match("^/(%w+)(.*)")
                        if command then
                            if isGroup and config.botName ~= "" then
                                local botCommand = text:match("^/(%w+)@" .. config.botName:sub(2) .. "(.*)")
                                if botCommand then
                                    command, args = botCommand:match("^(%w+)(.*)")
                                else
                                    command = nil
                                end
                            end
                            if command then
                                eventHandler("command", {
                                    chatId = chatId,
                                    command = command,
                                    args = args:match("^%s*(.-)%s*$") or "",
                                    message = message,
                                    isGroup = isGroup
                                })
                            end
                        end
                    elseif message.photo or message.video or message.document or message.audio then
                        eventHandler("media", {
                            chatId = chatId,
                            media = message.photo or message.video or message.document or message.audio,
                            message = message,
                            isGroup = isGroup
                        })
                    else
                        eventHandler("message", {
                            chatId = chatId,
                            text = text,
                            message = message,
                            isGroup = isGroup
                        })
                    end
                elseif update.callback_query then
                    local callbackQuery = update.callback_query
                    eventHandler("callback_query", {
                        callbackQueryId = callbackQuery.id,
                        chatId = callbackQuery.message.chat.id,
                        data = callbackQuery.data,
                        message = callbackQuery.message,
                        from = callbackQuery.from
                    })
                end
            elseif error then
                print("Polling error: " .. error)
            end
            timer.performWithDelay(1000, poll)
        end)
    end
    poll()
end


function M.setWebhook(url, callback)
    local params = {
        url = url
    }
    makeRequest("setWebhook", params, callback)
end


function M.deleteWebhook(callback)
    makeRequest("deleteWebhook", {}, callback)
end

return M