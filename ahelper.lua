require 'lib.moonloader'

local sampev = require 'lib.samp.events'


-- =========================================================
-- КОНФИГ
-- =========================================================

local moonloaderPath = getWorkingDirectory()
local configPath = moonloaderPath .. '\\config\\'

local adminSessionFile = configPath .. 'admin_session.cfg'
local checkStateFile = configPath .. 'check_state.cfg'


-- =========================================================
-- CHECK
-- =========================================================

local killStreaks = {}
local checkEnabled = false

local CHECK_COLOR = 0xE3B776


-- =========================================================
-- НАСТРОЙКИ
-- =========================================================

local pinfo_id = -1
local pinfo_dialog_id = 7777
local at_dialog_id = 7778

-- Цвет сообщений в чате
local CHAT_COLOR = 0x88AA62

-- Состояние админ-сессии
local adminSession = false


-- =========================================================
-- СОЗДАНИЕ ПАПКИ CONFIG
-- =========================================================

function createConfigFolder()

    if not doesDirectoryExist(configPath) then
        createDirectory(configPath)
    end

end


-- =========================================================
-- СОХРАНЕНИЕ СОСТОЯНИЯ АДМИН-СЕССИИ
-- =========================================================

function saveAdminSession(state)

    local file = io.open(adminSessionFile, 'w')

    if file then

        if state then
            file:write('1')
        else
            file:write('0')
        end

        file:close()

    end

end


-- =========================================================
-- ЗАГРУЗКА СОСТОЯНИЯ АДМИН-СЕССИИ
-- =========================================================

function loadAdminSession()

    local file = io.open(adminSessionFile, 'r')

    if file then

        local value = file:read('*a')

        file:close()

        if value == '1' then
            return true
        end

    end

    return false

end


-- =========================================================
-- СОХРАНЕНИЕ CHECK
-- =========================================================

function saveCheckState(state)

    local file = io.open(checkStateFile, 'w')

    if file then

        if state then
            file:write('1')
        else
            file:write('0')
        end

        file:close()

    end

end


-- =========================================================
-- ЗАГРУЗКА CHECK
-- =========================================================

function loadCheckState()

    local file = io.open(checkStateFile, 'r')

    if file then

        local value = file:read('*a')

        file:close()

        if value == '1' then
            return true
        end

    end

    return false

end


-- =========================================================
-- MAIN
-- =========================================================

function main()

    while not isSampAvailable() do
        wait(100)
    end


    -- Создаём папку config
    createConfigFolder()


    -- Восстанавливаем состояние после Ctrl+R
    adminSession = loadAdminSession()
    checkEnabled = loadCheckState()


    -- Сообщение о загрузке
    sampAddChatMessage(
        '{E37676}[Admin Helper] {FFFFFF}Скрипт загружен | Активация /at or /atools | Автор: еклипс',
        -1
    )


    -- =====================================================
    -- РЕГИСТРАЦИЯ КОМАНД
    -- =====================================================

    sampRegisterChatCommand('pinfo', cmd_pinfo)
    sampRegisterChatCommand('proverka', cmd_proverka)

    sampRegisterChatCommand('checkon', cmd_checkon)
    sampRegisterChatCommand('checkoff', cmd_checkoff)

    sampRegisterChatCommand('at', cmd_at)
    sampRegisterChatCommand('atools', cmd_at)


    while true do
        wait(0)
    end

end


-- =========================================================
-- ОБРАБОТКА СЕРВЕРНЫХ СООБЩЕНИЙ
-- =========================================================

function sampev.onServerMessage(color, text)

    -- Убираем цветовые коды
    local cleanText = text:gsub('{%x%x%x%x%x%x}', '')


    -- =====================================================
    -- ВХОД В АДМИН-СЕССИЮ
    -- =====================================================

    if cleanText:find('Админ-сессия запущена', 1, true) then

        adminSession = true

        -- Сохраняем состояние
        saveAdminSession(true)

        return

    end


    -- =====================================================
    -- ВЫХОД ИЗ АДМИН-СЕССИИ
    -- =====================================================

    if cleanText:find('Админ-сессия завершена', 1, true) then

        adminSession = false

        -- Сбрасываем сохранённое состояние
        saveAdminSession(false)

        -- Если PINFO был открыт
        if pinfo_id ~= -1 then
            pinfo_id = -1
        end

        return

    end


    -- =====================================================
    -- ЕСЛИ АДМИН-СЕССИЯ НЕ АКТИВНА
    -- =====================================================

    if not adminSession then
        return
    end


    -- =====================================================
    -- ВОПРОС
    -- =====================================================

    if cleanText:find('ВОПРОС от %S+%[%d+%]:', 1) then

        printStyledString(
            '~y~+AQUESTION',
            3000,
            2
        )

        return

    end


    -- =====================================================
    -- ЖАЛОБА
    -- =====================================================

    if cleanText:find('Жалоба от %S+%[%d+%]:', 1) then

        printStyledString(
            '~r~+REPORT',
            3000,
            2
        )

        return

    end

end


-- =========================================================
-- ПРОВЕРКА СУЩЕСТВОВАНИЯ ИГРОКА
-- =========================================================

function isValidPlayer(id)

    if id < 0 or id > 1000 then
        return false
    end

    if not sampIsPlayerConnected(id) then
        return false
    end

    return true

end


-- =========================================================
-- /pinfo [id]
-- =========================================================

function cmd_pinfo(arg)

    -- Фильтр админ-сессии
    if not adminSession then
        return
    end


    local id = tonumber(arg)


    if not id then

        sampAddChatMessage(
            '-> Использование: /pinfo [id]',
            CHAT_COLOR
        )

        return

    end


    -- Проверка игрока
    if not isValidPlayer(id) then

        sampAddChatMessage(
            '-> ID ' .. id .. ' не найден',
            CHAT_COLOR
        )

        return

    end


    local nickname = sampGetPlayerNickname(id)


    if not nickname or nickname == '' then

        sampAddChatMessage(
            '-> Не удалось получить ник ID ' .. id,
            CHAT_COLOR
        )

        return

    end


    pinfo_id = id


    -- =====================================================
    -- ДИАЛОГ PINFO
    -- =====================================================

    sampShowDialog(

        pinfo_dialog_id,

        'Общая статистика ' ..
        nickname ..
        ' [' ..
        id ..
        ']',


        'Посмотреть статистику игрока\n' ..
        'Посмотреть HWID игрока\n' ..
        'Посмотреть IP и наличие вторых аккаунтов\n' ..
        'Посмотреть GPCI игрока\n' ..
        '                    \n' ..
        '                    \n' ..
        '                    \n' ..
        '                    \n' ..
        '{F5C87F}Вызвать игрока на проверку\n' ..
        '{F5C87F}Выдать принудительную авторизацию\n' ..
        '{F5C87F}Начать слежку за игроком',


        'Ок!',
        'Назад',
        2

    )


    -- =====================================================
    -- ОБРАБОТКА ДИАЛОГА
    -- =====================================================

    lua_thread.create(function()

        local result
        local button
        local listitem
        local input


        repeat

            wait(0)

            result, button, listitem, input =
                sampHasDialogRespond(pinfo_dialog_id)

        until result


        local target_id = pinfo_id


        -- =================================================
        -- ПРОВЕРЯЕМ АДМИН-СЕССИЮ
        -- =================================================

        if not adminSession then

            pinfo_id = -1

            return

        end


        -- =================================================
        -- КНОПКА "ОК!"
        -- =================================================

        if button == 0 then

            pinfo_id = -1

            return

        end


        -- =================================================
        -- ВЫБОР ПУНКТА
        -- =================================================

        if button == 1 then

            local command = nil


            -- Статистика
            if listitem == 0 then

                command = '/stats ' .. target_id


            -- HWID
            elseif listitem == 1 then

                command = '/historyhwid ' .. target_id


            -- AKA
            elseif listitem == 2 then

                command = '/aka ' .. target_id


            -- GPCI
            elseif listitem == 3 then

                command = '/getgpci ' .. target_id


            -- Вызов на проверку
            elseif listitem == 8 then

                sampCloseCurrentDialogWithButton(1)

                pinfo_id = -1

                startProverka(target_id)

                return


            -- Принудительная авторизация
            elseif listitem == 9 then

                command = '/forceauth ' .. target_id


            -- Слежка
            elseif listitem == 10 then

                command = '/re ' .. target_id

            end


            -- =================================================
            -- ОТПРАВКА КОМАНДЫ
            -- =================================================

            if command then

                sampCloseCurrentDialogWithButton(1)

                pinfo_id = -1

                wait(100)


                -- Ещё раз проверяем админ-сессию
                if adminSession then
                    sampSendChat(command)
                end

            end

        end

    end)

end


-- =========================================================
-- /proverka [id]
-- =========================================================

function cmd_proverka(arg)

    -- Фильтр админ-сессии
    if not adminSession then
        return
    end


    local id = tonumber(arg)


    if not id then

        sampAddChatMessage(
            '-> Использование: /proverka [id]',
            CHAT_COLOR
        )

        return

    end


    if not isValidPlayer(id) then

        sampAddChatMessage(
            '-> ID ' .. id .. ' не найден',
            CHAT_COLOR
        )

        return

    end


    startProverka(id)

end


-- =========================================================
-- АВТОМАТИЧЕСКИЙ ВЫЗОВ НА ПРОВЕРКУ
-- =========================================================

function startProverka(id)

    lua_thread.create(function()


        -- Проверяем админ-сессию
        if not adminSession then
            return
        end


        -- =================================================
        -- 1. GET HERE
        -- =================================================

        sampSendChat(
            '/gethere ' .. id
        )


        -- =================================================
        -- ЗАДЕРЖКА 1000 МС
        -- =================================================

        wait(1000)


        -- =================================================
        -- ПРОВЕРЯЕМ АДМИН-СЕССИЮ ЕЩЁ РАЗ
        -- =================================================

        if not adminSession then
            return
        end


        -- =================================================
        -- 2. PM
        -- =================================================

        sampSendChat(
            '/pm ' ..
            id ..
            ' афк офф = бан | пиши дискорд/телеграм/вк'
        )

    end)

end


-- =========================================================
-- CHECK ЗА СЕРИЮ УБИЙСТВ
-- =========================================================

function sampev.onPlayerDeathNotification(killerId, killedId, reason)

    if not adminSession then
        return
    end


    -- Сбрасываем серию умершего
    if killedId ~= 65535 then
        killStreaks[killedId] = 0
    end


    -- Нет убийцы
    if killerId == 65535 then
        return
    end


    -- Самоубийство
    if killerId == killedId then
        return
    end


    -- Проверяем убийцу
    if not sampIsPlayerConnected(killerId) then
        return
    end


    -- Создаём серию
    if killStreaks[killerId] == nil then
        killStreaks[killerId] = 0
    end


    -- Добавляем убийство
    killStreaks[killerId] = killStreaks[killerId] + 1


    local streak = killStreaks[killerId]


    -- Максимум 999
    if streak > 999 then

        killStreaks[killerId] = 999

        return

    end


    -- Чеки выключены
    if not checkEnabled then
        return
    end


    -- Каждые 5 убийств
    if streak >= 5 and streak % 5 == 0 then

        local nickname = sampGetPlayerNickname(killerId)


        if nickname and nickname ~= '' then

            sampAddChatMessage(

                '<Check> ' ..
                nickname ..
                '[' ..
                killerId ..
                '] сделал ' ..
                streak ..
                ' убийств подряд',

                CHECK_COLOR

            )

        end

    end

end


-- =========================================================
-- /checkon
-- =========================================================

function cmd_checkon()

    if not adminSession then
        return
    end


    checkEnabled = true

    saveCheckState(true)


    sampAddChatMessage(
        '-> Display checks enabled: true',
        CHAT_COLOR
    )

end


-- =========================================================
-- /checkoff
-- =========================================================

function cmd_checkoff()

    if not adminSession then
        return
    end


    checkEnabled = false

    saveCheckState(false)


    sampAddChatMessage(
        '-> Display checks enabled: false',
        CHAT_COLOR
    )

end


-- =========================================================
-- /at и /atools
-- ДОКУМЕНТАЦИЯ ADMIN HELPER
-- =========================================================

function cmd_at()

    sampShowDialog(

        at_dialog_id,

        '{E37676}Admin Helper by еклипс {FFFFFF}|| {5C5C5C}Version 1.0.0',


        '{DBC99C}Checks:\n' ..
        '{B4D1C3}/checkon                      Enable display checks in chat\n' ..
        '{B4D1C3}/checkoff                      Disable display checks in chat\n' ..
        '\n' ..
        '{DBC99C}Player info:\n' ..
        '{B4D1C3}/pinfo [id]                      Displays a dialog with the player\'s general statistics\n' ..
        '{B4D1C3}/proverka [id]               Auto-call for cheat check',


        'Ок',
        '',
        0

    )

end