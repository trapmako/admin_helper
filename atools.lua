script_name('Admin Helper')
script_author('еклипс')

require 'lib.moonloader'

local sampev = require 'lib.samp.events'
local imgui = require 'mimgui'
local ffi = require 'ffi'
local memory = require 'memory'

imgui.OnInitialize(function()
    local io = imgui.GetIO()

    io.MouseDrawCursor = false
    io.ConfigFlags =
        bit.bor(
            io.ConfigFlags,
            imgui.ConfigFlags.NoMouse
        )
end)

-- =========================================================
-- CONFIG
-- =========================================================

local moonloaderPath = getWorkingDirectory()
local configPath = moonloaderPath .. '\\config\\'

local adminSessionFile = configPath .. 'admin_session.cfg'
local checkStateFile = configPath .. 'check_state.cfg'
local whStateFile = configPath .. 'wh_state.cfg'


-- =========================================================
-- ОСНОВНЫЕ НАСТРОЙКИ
-- =========================================================

local pinfo_id = -1
local spectatePlayerId = -1

local pinfo_dialog_id = 7777
local at_dialog_id = 7778

local CHAT_COLOR = 0x88AA62
local CHECK_COLOR = 0xE3B776

local adminSession = false
local checkEnabled = false
local whEnabled = false
local tracersEnabled = false
local reDetectEnabled = false


-- =========================================================
-- WH
-- =========================================================

local players = {}

local WH_RADIUS = 500.0

local WH_SHOW_BOX = true
local WH_SHOW_BOX_FILL = false
local WH_SHOW_DOTS = true
local WH_SHOW_BONES = true


-- =========================================================
-- ЦВЕТА СКИНОВ
-- =========================================================

local skinGroups = {

    {
        name = 'Grove',
        ids = '105,106,107',
        color = {0.0, 0.80, 0.27, 1.0}
    },

    {
        name = 'Ballas',
        ids = '102,103,104',
        color = {0.80, 0.27, 1.0, 1.0}
    },

    {
        name = 'Vagos',
        ids = '108,109,110',
        color = {1.0, 0.93, 0.0, 1.0}
    },

    {
        name = 'Aztecas',
        ids = '114,115,116',
        color = {0.0, 0.75, 1.0, 1.0}
    },

    {
        name = 'Rifa',
        ids = '173,174,175',
        color = {0.0, 0.85, 0.75, 1.0}
    },

    {
        name = 'DaNang',
        ids = '121,122,123',
        color = {0.27, 0.53, 1.0, 1.0}
    },

    {
        name = 'Triads',
        ids = '117,118,120',
        color = {0.13, 0.33, 1.0, 1.0}
    },

    {
        name = 'Mafia',
        ids = '111,112,113',
        color = {0.67, 0.67, 0.67, 1.0}
    },

    {
        name = 'VietMafia',
        ids = '124,125,126,127',
        color = {0.53, 0.67, 1.0, 1.0}
    },

    {
        name = 'Bikers',
        ids = '247,248',
        color = {1.0, 0.55, 0.13, 1.0}
    }

}


-- =========================================================
-- BONE PRESETS
-- =========================================================

local BONE_PRESET = {

    ids = {
        1, 2, 3, 4, 6,
        22, 23, 24,
        32, 33, 34,
        41, 42, 43,
        51, 52, 53
    },

    pairs = {

        {1, 2},
        {2, 3},
        {3, 4},
        {4, 6},

        {3, 32},
        {32, 33},
        {33, 34},

        {3, 22},
        {22, 23},
        {23, 24},

        {1, 41},
        {41, 42},
        {42, 43},

        {1, 51},
        {51, 52},
        {52, 53}

    }

}


-- =========================================================
-- BONE FUNCTION
-- =========================================================

ffi.cdef[[
    typedef struct {
        float x;
        float y;
        float z;
    } RwV3d;

    typedef void (__thiscall *tGetBonePos)(
        void*,
        RwV3d*,
        unsigned int,
        int
    );
]]

local _getBoneFn = ffi.cast(
    'tGetBonePos',
    0x5E4280
)

local _boneOut = ffi.new('RwV3d[1]')


local function bonePos(ptr, id)

    _getBoneFn(
        ffi.cast('void*', ptr),
        _boneOut,
        id,
        0
    )

    return
        _boneOut[0].x,
        _boneOut[0].y,
        _boneOut[0].z

end


-- =========================================================
-- SCREEN
-- =========================================================

local screenW, screenH = getScreenResolution()


local function w2s(x, y, z)

    local sx, sy =
        convert3DCoordsToScreen(x, y, z)

    if not sx then
        return nil, nil
    end

    if sx < -screenW
        or sx > screenW * 2
        or sy < -screenH
        or sy > screenH * 2 then

        return nil, nil

    end

    return sx, sy

end


local function isPedVisible(x, y, z)

    return isPointOnScreen(
        x,
        y,
        z,
        1.0
    )

end


-- =========================================================
-- ЦВЕТА
-- =========================================================

local skinColorMap = {}


local function rebuildColorMap()

    skinColorMap = {}

    for _, group in ipairs(skinGroups) do

        local c = group.color

        local r =
            math.floor(c[1] * 255 + 0.5)

        local g =
            math.floor(c[2] * 255 + 0.5)

        local b =
            math.floor(c[3] * 255 + 0.5)

        local a =
            math.floor(c[4] * 255 + 0.5)


        local abgr =
            bit.bor(
                bit.lshift(a, 24),
                bit.lshift(b, 16),
                bit.lshift(g, 8),
                r
            )


        for idstr in
            (group.ids .. ','):gmatch('(%d+),') do

            local id = tonumber(idstr)

            if id then
                skinColorMap[id] = abgr
            end

        end

    end

end


local function skinColor(id)

    return skinColorMap[id]
        or 0xFFFFFFFF

end


-- =========================================================
-- ПОЛУЧЕНИЕ SKIN ID
-- =========================================================

local function getSampSkinId(sampPlayerId)

    local ok, skin =
        pcall(
            sampGetPlayerSkin,
            sampPlayerId
        )

    if ok and skin and skin > 0 then
        return skin
    end


    local ok2, ptr =
        pcall(
            sampGetPlayerStructPtr,
            sampPlayerId
        )

    if ok2 and ptr and ptr ~= 0 then

        local ok3, value =
            pcall(
                memory.getint16,
                ptr + 0x12,
                false
            )

        if ok3 and value and value > 0 then
            return value
        end

    end

    return nil

end


local function getPlayerSkin(sampId, ped)

    local skin =
        getSampSkinId(sampId)

    if skin then
        return skin
    end

    return getCharModel(ped)

end


-- =========================================================
-- STREAM IN / OUT
-- =========================================================

sampev.onPlayerStreamIn = function(id)

    local ok, ped =
        sampGetCharHandleBySampPlayerId(id)

    if ok then

        players[id] = {

            ped = ped,

            name =
                sampGetPlayerNickname(id),

            skin =
                getPlayerSkin(id, ped)

        }

    end

end


sampev.onPlayerStreamOut = function(id)

    players[id] = nil

end

-- =========================================================
-- /RE TARGET + AIM/SYNC
-- =========================================================

local reAimData = {}
local reShootState = {}

-- В SA-MP PlayerSync:
-- secondaryFire_shoot = бит 2 = значение 4
local SHOOT_KEY = 4

-- Примерные интервалы между выстрелами
local RE_SHOT_INTERVALS = {

    [22] = 0.25, -- Colt 45
    [23] = 0.25, -- Silenced
    [24] = 0.85, -- Deagle

    [25] = 0.80, -- Shotgun
    [26] = 0.80, -- Sawnoff
    [27] = 0.80, -- Combat Shotgun

    [28] = 0.10, -- UZI
    [29] = 0.10, -- MP5
    [30] = 0.09, -- AK
    [31] = 0.09, -- M4

    [32] = 0.10, -- Tec9

    [33] = 0.90, -- Rifle
    [34] = 0.90, -- Sniper

    [35] = 0.10, -- RPG
    [36] = 0.10, -- Heatseeker
    [37] = 0.10, -- Flamethrower
    [38] = 0.05  -- Minigun

}


local function getReShotInterval(weapon)

    return RE_SHOT_INTERVALS[weapon]
        or 0.10

end


-- =========================================================
-- ОТСЛЕЖИВАНИЕ /RE
-- =========================================================

function sampev.onSendCommand(command)

    if not command then
        return
    end

    local cmd, args =
        command:match(
            '^(/%S+)%s*(.*)'
        )

    if not cmd then
        return
    end

    cmd =
        cmd:lower()


    -- /re ID
    if cmd == '/re' then

        local id =
            tonumber(
                args
            )

        if id
            and id >= 0
            and id <= 1000 then

            spectatePlayerId = id

        else

            -- /re без ID = выход из слежки
            spectatePlayerId = -1

            reAimData = {}
            reShootState = {}

        end

    end

end


-- =========================================================
-- PLAYER SYNC
-- =========================================================

function sampev.onPlayerSync(
    id,
    data
)

    if not adminSession then
        return
    end

    if not tracersEnabled then
        return
    end

    if id ~= spectatePlayerId then
        return
    end

    if not data then
        return
    end


    local state =
        reShootState[id]


    if not state then

        state = {

            shooting = false,

            wasShooting = false,

            nextShot = 0,

            weapon = 0

        }

        reShootState[id] =
            state

    end


    state.weapon =
        tonumber(data.weapon)
        or 0


    local keys =
        tonumber(data.keysData)
        or 0


    state.shooting =
        bit.band(
            keys,
            SHOOT_KEY
        ) ~= 0

        if not state.shooting then
            state.wasShooting = false
        end


    -- Сохраняем позицию из sync
    if data.position then

        state.position = {

            x = data.position.x,

            y = data.position.y,

            z = data.position.z

        }

    end

end


-- =========================================================
-- AIM SYNC
-- =========================================================

function sampev.onAimSync(
    id,
    data
)

    if not adminSession then
        return
    end

    if not tracersEnabled then
        return
    end

    if id ~= spectatePlayerId then
        return
    end

    if not data then
        return
    end


    reAimData[id] = {

        camPos = {

            x = data.camPos.x,

            y = data.camPos.y,

            z = data.camPos.z

        },

        camFront = {

            x = data.camFront.x,

            y = data.camFront.y,

            z = data.camFront.z

        }

    }

end

-- =========================================================
-- ADMIN SESSION
-- =========================================================

function sampev.onServerMessage(color, text)

    local cleanText =
        text:gsub(
            '{%x%x%x%x%x%x}',
            ''
        )


    -- =====================================================
    -- ОПРЕДЕЛЕНИЕ НАЧАЛА /RE
    -- =====================================================

    if cleanText:find(
        'Наблюдение за',
        1,
        true
    ) then

        local id =
            cleanText:match(
                '%[(%d+)%]'
            )

        if id then

            spectatePlayerId =
                tonumber(id)

        end

    end


    -- =====================================================
    -- ВЫХОД ИЗ /RE
    -- =====================================================

    if cleanText:find(
        'Вы больше не следите',
        1,
        true
    )
    or cleanText:find(
        'слежки',
        1,
        true
    ) then

        spectatePlayerId = -1

    end


    -- =====================================================
    -- ВХОД В АДМИН-СЕССИЮ
    -- =====================================================

    if cleanText:find(
        'Админ-сессия запущена',
        1,
        true
    ) then

        adminSession = true

        saveAdminSession(true)

        return

    end


    -- =====================================================
    -- ВЫХОД ИЗ АДМИН-СЕССИИ
    -- =====================================================

    if cleanText:find(
        'Админ-сессия завершена',
        1,
        true
    ) then

        adminSession = false

        saveAdminSession(false)


        -- Выключаем WH
        whEnabled = false
        saveWhState(false)

        -- Выключаем трасеры
        tracersEnabled = false 

        tracerBullets = {}

        reDetectEnabled = false

        spectatePlayerId = -1

        reAimData = {}
        reShootState = {}


        pinfo_id = -1

        return

    end


    -- =====================================================
    -- ФИЛЬТР
    -- =====================================================

    if not adminSession then
        return
    end


    -- =====================================================
    -- ВОПРОС
    -- =====================================================

    if cleanText:find(
        'ВОПРОС от %S+%[%d+%]:',
        1
    ) then

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

    if cleanText:find(
        'Жалоба от %S+%[%d+%]:',
        1
    ) then

        printStyledString(
            '~r~+REPORT',
            3000,
            2
        )

        return

    end

end


-- =========================================================
-- CONFIG FOLDER
-- =========================================================

function createConfigFolder()

    if not doesDirectoryExist(configPath) then
        createDirectory(configPath)
    end

end


-- =========================================================
-- ADMIN SESSION SAVE
-- =========================================================

function saveAdminSession(state)

    local file =
        io.open(
            adminSessionFile,
            'w'
        )

    if file then

        file:write(
            state and '1' or '0'
        )

        file:close()

    end

end


function loadAdminSession()

    local file =
        io.open(
            adminSessionFile,
            'r'
        )

    if file then

        local value =
            file:read('*a')

        file:close()

        return value == '1'

    end

    return false

end


-- =========================================================
-- CHECK SAVE
-- =========================================================

function saveCheckState(state)

    local file =
        io.open(
            checkStateFile,
            'w'
        )

    if file then

        file:write(
            state and '1' or '0'
        )

        file:close()

    end

end


function loadCheckState()

    local file =
        io.open(
            checkStateFile,
            'r'
        )

    if file then

        local value =
            file:read('*a')

        file:close()

        return value == '1'

    end

    return false

end


-- =========================================================
-- WH SAVE
-- =========================================================

function saveWhState(state)

    local file =
        io.open(
            whStateFile,
            'w'
        )

    if file then

        file:write(
            state and '1' or '0'
        )

        file:close()

    end

end


function loadWhState()

    local file =
        io.open(
            whStateFile,
            'r'
        )

    if file then

        local value =
            file:read('*a')

        file:close()

        return value == '1'

    end

    return false

end


-- =========================================================
-- PINFO PLAYER CHECK
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
-- /pinfo
-- =========================================================

function cmd_pinfo(arg)

    if not adminSession then
        return
    end


    local id =
        tonumber(arg)


    if not id then

        sampAddChatMessage(
            '-> Использование: /pinfo [id]',
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


    local nickname =
        sampGetPlayerNickname(id)


    if not nickname
        or nickname == '' then

        sampAddChatMessage(
            '-> Не удалось получить ник ID ' .. id,
            CHAT_COLOR
        )

        return

    end


    pinfo_id = id


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


    lua_thread.create(function()

        local result
        local button
        local listitem
        local input


        repeat

            wait(0)

            result,
            button,
            listitem,
            input =
                sampHasDialogRespond(
                    pinfo_dialog_id
                )

        until result


        local target_id =
            pinfo_id


        if not adminSession then

            pinfo_id = -1

            return

        end


        if button == 0 then

            pinfo_id = -1

            return

        end


        if button == 1 then

            local command = nil


            if listitem == 0 then

                command =
                    '/stats ' ..
                    target_id


            elseif listitem == 1 then

                command =
                    '/historyhwid ' ..
                    target_id


            elseif listitem == 2 then

                command =
                    '/aka ' ..
                    target_id


            elseif listitem == 3 then

                command =
                    '/getgpci ' ..
                    target_id


            elseif listitem == 8 then

                sampCloseCurrentDialogWithButton(1)

                pinfo_id = -1

                startProverka(target_id)

                return


            elseif listitem == 9 then

                command =
                    '/forceauth ' ..
                    target_id


            elseif listitem == 10 then

                spectatePlayerId = target_id

                command =
                    '/re ' ..
                    target_id

            end


            if command then

                sampCloseCurrentDialogWithButton(1)

                pinfo_id = -1

                wait(100)


                if adminSession then

                    sampSendChat(
                        command
                    )

                end

            end

        end

    end)

end


-- =========================================================
-- /proverka
-- =========================================================

function cmd_proverka(arg)

    if not adminSession then
        return
    end


    local id =
        tonumber(arg)


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
-- ПРОВЕРКА
-- =========================================================

function startProverka(id)

    lua_thread.create(function()

        if not adminSession then
            return
        end


        sampSendChat(
            '/gethere ' .. id
        )


        wait(1000)


        if not adminSession then
            return
        end


        sampSendChat(
            '/pm ' ..
            id ..
            ' афк офф = бан | пиши дискорд/телеграм/вк'
        )

    end)

end


-- =========================================================
-- KILL STREAK CHECK
-- =========================================================

local killStreaks = {}


function sampev.onPlayerDeathNotification(
    killerId,
    killedId,
    reason
)

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


    if not sampIsPlayerConnected(killerId) then
        return
    end


    if killStreaks[killerId] == nil then
        killStreaks[killerId] = 0
    end


    killStreaks[killerId] =
        killStreaks[killerId] + 1


    local streak =
        killStreaks[killerId]


    if streak > 999 then

        killStreaks[killerId] = 999

        return

    end


    if not checkEnabled then
        return
    end


    if streak >= 5
        and streak % 5 == 0 then

        local nickname =
            sampGetPlayerNickname(
                killerId
            )


        if nickname
            and nickname ~= '' then

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
-- /at / /atools
-- =========================================================

function cmd_at()

    sampShowDialog(

        at_dialog_id,

        '{E37676}Admin Helper by еклипс {FFFFFF}|| {5C5C5C}Version 1.0.2',


        '{DBC99C}Checks:\n' ..
        '{B4D1C3}/checkon                      Enable display checks in chat\n' ..
        '{B4D1C3}/checkoff                      Disable display checks in chat\n' ..
        '\n' ..
        '{DBC99C}Player info:\n' ..
        '{B4D1C3}/pinfo [id]                      Displays a dialog with the player\'s general statistics\n' ..
        '{B4D1C3}/proverka [id]               Auto-call for cheat check\n' ..
        '\n' ..
        '{DBC99C}Visual:\n' ..
        '{B4D1C3}/whadmin                       Enable / disable admin WallHack\n' ..
        '{B4D1C3}/tracers                          Enable / disable display bullet tracers',


        'Ок',
        '',
        0

    )

end


-- =========================================================
-- /whadmin
-- =========================================================

function cmd_whadmin()

    -- WH доступен только во время активной админ-сессии.
    if not adminSession then
        whEnabled = false
        saveWhState(false)
        return
    end


    whEnabled =
        not whEnabled


    saveWhState(
        whEnabled
    )


    if whEnabled then

        sampAddChatMessage(
            '-> WallHack enabled: true',
            CHAT_COLOR
        )

    else

        sampAddChatMessage(
            '-> WallHack enabled: false',
            CHAT_COLOR
        )

    end

end


-- =========================================================
-- IMGUI HELPERS
-- =========================================================

local function v2(x, y)

    return imgui.ImVec2(
        x,
        y
    )

end


local function wa(col, alpha)

    return bit.bor(
        bit.band(col, 0x00FFFFFF),
        bit.lshift(alpha, 24)
    )

end


local function lerpColor(
    c1,
    c2,
    t
)

    local function ch(c, shift)

        return bit.band(
            bit.rshift(c, shift),
            0xFF
        )

    end


    local function lp(a, b)

        return math.floor(
            a + (b - a) * t
        )

    end


    return bit.bor(

        bit.lshift(
            lp(
                ch(c1, 24),
                ch(c2, 24)
            ),
            24
        ),

        bit.lshift(
            lp(
                ch(c1, 16),
                ch(c2, 16)
            ),
            16
        ),

        bit.lshift(
            lp(
                ch(c1, 8),
                ch(c2, 8)
            ),
            8
        ),

        lp(
            ch(c1, 0),
            ch(c2, 0)
        )

    )

end


local function hpColor(pct)

    if pct > 0.5 then

        return lerpColor(
            0xFF00FFFF,
            0xFF00FF00,
            (pct - 0.5) * 2
        )

    else

        return lerpColor(
            0xFF0000FF,
            0xFF00FFFF,
            pct * 2
        )

    end

end


-- =========================================================
-- BONE CACHE
-- =========================================================

local function buildBoneCache(ptr)

    local cache = {}


    for _, boneId in
        ipairs(BONE_PRESET.ids) do

        local ok, x, y, z =
            pcall(
                bonePos,
                ptr,
                boneId
            )


        if ok then

            local sx, sy =
                w2s(x, y, z)


            if sx then

                cache[boneId] = {
                    sx,
                    sy
                }

            end

        end

    end


    return cache

end


-- =========================================================
-- SKELETON
-- =========================================================

local function drawSkeleton(
    dl,
    cache,
    col,
    boxHeight
)

    if not WH_SHOW_BONES then
        return
    end


    local s =
        math.max(
            0.0,
            math.min(
                1.0,
                boxHeight / 100.0
            )
        )


    local lineW =
        0.8 + s * 1.4


    local glowW =
        lineW + 2.0


    local dotR =
        math.max(
            0.8,
            0.8 + s * 2.2
        )


    local glow =
        wa(col, 0x35)


    local main =
        wa(col, 0xDD)


    for _, pair in
        ipairs(BONE_PRESET.pairs) do

        local a =
            cache[pair[1]]

        local b =
            cache[pair[2]]


        if a and b then

            dl:AddLine(
                v2(a[1], a[2]),
                v2(b[1], b[2]),
                glow,
                glowW
            )


            dl:AddLine(
                v2(a[1], a[2]),
                v2(b[1], b[2]),
                main,
                lineW
            )

        end

    end


    if WH_SHOW_DOTS then

        local drawn = {}


        for _, pair in
            ipairs(BONE_PRESET.pairs) do

            for _, boneId in
                ipairs(pair) do

                if not drawn[boneId] then

                    drawn[boneId] = true


                    local point =
                        cache[boneId]


                    if point then

                        dl:AddCircleFilled(
                            v2(
                                point[1],
                                point[2]
                            ),
                            dotR,
                            wa(
                                col,
                                0xFF
                            )
                        )


                        dl:AddCircle(
                            v2(
                                point[1],
                                point[2]
                            ),
                            dotR + 0.5,
                            wa(
                                0xFF000000,
                                0xAA
                            ),
                            12,
                            1.0
                        )

                    end

                end

            end

        end

    end

end


-- =========================================================
-- DRAW ESP
-- =========================================================

local function drawESP(
    dl,
    player,
    sampId
)

    local ped =
        player.ped


    if not doesCharExist(ped) then
        return
    end


    local ok0, cx, cy, cz =
        pcall(
            getCharCoordinates,
            ped
        )


    if not ok0 then
        return
    end


    if not isPedVisible(
        cx,
        cy,
        cz
    ) then

        return

    end


    local ptr =
        getCharPointer(ped)


    local headX =
        cx

    local headY =
        cy

    local headZ =
        cz + 0.9


    local cache = {}


    if ptr and ptr ~= 0 then

        cache =
            buildBoneCache(ptr)


        local headBone =
            cache[6]


        if headBone then

            local ok,
            hx,
            hy,
            hz =

                pcall(
                    bonePos,
                    ptr,
                    6
                )


            if ok then

                headX = hx
                headY = hy
                headZ = hz + 0.12

            end

        end

    end


    local hsx, hsy =
        w2s(
            headX,
            headY,
            headZ
        )


    local fsx, fsy =
        w2s(
            cx,
            cy,
            cz - 0.85
        )


    if not hsx or not fsx then
        return
    end


    if hsy >= fsy then
        return
    end


    local h =
        fsy - hsy


    local w =
        h * 0.32


    local x1 =
        hsx - w

    local x2 =
        hsx + w


    local y1 =
        hsy

    local y2 =
        fsy


    local col =
        skinColor(
            player.skin
        )


    local cMid =
        wa(
            col,
            0xBB
        )


    local cFul =
        wa(
            col,
            0xFF
        )


    -- =====================================================
    -- BOX
    -- =====================================================

    if WH_SHOW_BOX then

        if WH_SHOW_BOX_FILL then

            dl:AddRectFilled(
                v2(x1, y1),
                v2(x2, y2),
                wa(
                    col,
                    0x22
                )
            )

        end


        dl:AddRectFilled(
            v2(
                x1 - 2,
                y1 - 2
            ),
            v2(
                x2 + 2,
                y2 + 2
            ),
            wa(
                col,
                0x18
            ),
            2
        )


        dl:AddRect(
            v2(
                x1 - 1,
                y1 - 1
            ),
            v2(
                x2 + 1,
                y2 + 1
            ),
            wa(
                0xFF000000,
                0xAA
            ),
            0,
            15,
            2.5
        )


        dl:AddRect(
            v2(x1, y1),
            v2(x2, y2),
            cMid,
            0,
            15,
            1.0
        )


        -- =================================================
        -- CORNERS
        -- =================================================

        local cl =
            math.max(
                4,
                h * 0.20
            )


        local bw = 2.0


        dl:AddLine(
            v2(x1, y1),
            v2(x1 + cl, y1),
            cFul,
            bw
        )


        dl:AddLine(
            v2(x1, y1),
            v2(x1, y1 + cl),
            cFul,
            bw
        )


        dl:AddLine(
            v2(x2, y1),
            v2(x2 - cl, y1),
            cFul,
            bw
        )


        dl:AddLine(
            v2(x2, y1),
            v2(x2, y1 + cl),
            cFul,
            bw
        )


        dl:AddLine(
            v2(x1, y2),
            v2(x1 + cl, y2),
            cFul,
            bw
        )


        dl:AddLine(
            v2(x1, y2),
            v2(x1, y2 - cl),
            cFul,
            bw
        )


        dl:AddLine(
            v2(x2, y2),
            v2(x2 - cl, y2),
            cFul,
            bw
        )


        dl:AddLine(
            v2(x2, y2),
            v2(x2, y2 - cl),
            cFul,
            bw
        )


        -- =================================================
        -- HP
        -- =================================================

        local hp = nil


        local ok,
        hpValue =

            pcall(
                sampGetPlayerHealth,
                sampId
            )


        if ok and hpValue then
            hp = hpValue
        end


        if not hp then

            local ok2,
            localHp =

                pcall(
                    getCharHealth,
                    ped
                )


            hp =
                ok2 and localHp
                or 100

        end


        hp =
            math.max(
                0,
                math.min(
                    100,
                    hp
                )
            )


        local pct =
            hp / 100


        local bh =
            h * pct


        local barW =
            math.max(
                5,
                w * 0.22
            )


        local hbx2 =
            x1 - 4


        local hbx1 =
            hbx2 - barW


        dl:AddRectFilled(
            v2(
                hbx1,
                y1
            ),
            v2(
                hbx2,
                y2
            ),
            wa(
                0xFF000000,
                0xCC
            ),
            1
        )


        dl:AddRectFilled(
            v2(
                hbx1,
                y2 - bh
            ),
            v2(
                hbx2,
                y2
            ),
            hpColor(pct),
            1
        )


        dl:AddRect(
            v2(
                hbx1,
                y1
            ),
            v2(
                hbx2,
                y2
            ),
            wa(
                0xFF000000,
                0x88
            ),
            1,
            15,
            0.8
        )


        -- =================================================
        -- ARMOR
        -- =================================================

        local armor = nil


        local ok3,
        armorValue =

            pcall(
                sampGetPlayerArmor,
                sampId
            )


        if ok3 and armorValue then
            armor = armorValue
        end


        if not armor then

            local ok4,
            localArmor =

                pcall(
                    getCharArmour,
                    ped
                )


            armor =
                ok4 and localArmor
                or 0

        end


        armor =
            math.max(
                0,
                math.min(
                    100,
                    armor
                )
            )


        if armor > 0 then

            local armorPct =
                armor / 100


            local armorHeight =
                h * armorPct


            local armorX2 =
                hbx1 - 3


            local armorX1 =
                armorX2 - barW


            dl:AddRectFilled(
                v2(
                    armorX1,
                    y1
                ),
                v2(
                    armorX2,
                    y2
                ),
                wa(
                    0xFF000000,
                    0xCC
                ),
                1
            )


            dl:AddRectFilled(
                v2(
                    armorX1,
                    y2 - armorHeight
                ),
                v2(
                    armorX2,
                    y2
                ),
                wa(
                    0xFFFFAA33,
                    0xFF
                ),
                1
            )


            dl:AddRect(
                v2(
                    armorX1,
                    y1
                ),
                v2(
                    armorX2,
                    y2
                ),
                wa(
                    0xFF000000,
                    0x88
                ),
                1,
                15,
                0.8
            )

        end

    end


    -- =====================================================
    -- SKELETON
    -- =====================================================

    drawSkeleton(
        dl,
        cache,
        col,
        h
    )

end


-- =========================================================
-- IMGUI FRAME
-- =========================================================

local whFrame = imgui.OnFrame(
    function()
        return whEnabled and adminSession
    end,

    function()

        local io = imgui.GetIO()

        io.MouseDrawCursor = false
        io.WantCaptureMouse = false
        io.WantCaptureKeyboard = false

        if not isSampAvailable() then
            return
        end

        if not adminSession then
            return
        end

        if not whEnabled then
            return
        end

        local dl =
            imgui.GetBackgroundDrawList()

        local ok0,
        mx,
        my,
        mz =
            pcall(
                getCharCoordinates,
                playerPed
            )

        if not ok0 then
            return
        end

        for id, player in pairs(players) do

            if not doesCharExist(player.ped) then

                players[id] = nil

            else

                local ok,
                x,
                y,
                z =
                    pcall(
                        getCharCoordinates,
                        player.ped
                    )

                if ok then

                    local gtaSkin =
                        getCharModel(player.ped)

                    if gtaSkin > 311 then

                        local sampSkin =
                            getSampSkinId(id)

                        player.skin =
                            (
                                sampSkin
                                and sampSkin > 0
                            )
                            and sampSkin
                            or gtaSkin

                    else

                        player.skin = gtaSkin

                    end

                    local dist =
                        (x - mx) ^ 2 +
                        (y - my) ^ 2 +
                        (z - mz) ^ 2

                    if dist <=
                        WH_RADIUS * WH_RADIUS then

                        drawESP(
                            dl,
                            player,
                            id
                        )

                    end

                end

            end

        end

    end
)


-- WH рисуется как прозрачный overlay, поэтому ImGui не должен
-- блокировать управление игроком и должен сам скрывать курсор.
whFrame.HideCursor = true
whFrame.LockPlayer = false

-- =========================================================
-- TRACERS
-- =========================================================

local tracerBullets = {}

local lastTracer = nil

local lastTracerTime = 0
local lastTracerOriginX = 0
local lastTracerOriginY = 0
local lastTracerOriginZ = 0

local TRACER_DUPLICATE_TIME = 0.05
local TRACER_DUPLICATE_DISTANCE = 0.35


local function isDuplicateTracer(data)

    -- Никаких ошибок наружу
    local ok, result = pcall(function()

        if not data then
            return false
        end

        if not data.origin then
            return false
        end

        local x = tonumber(data.origin.x)
        local y = tonumber(data.origin.y)
        local z = tonumber(data.origin.z)

        if not x or not y or not z then
            return false
        end

        local now = os.clock()

        -- Проверяем только время + точку выстрела
        if now - lastTracerTime <= TRACER_DUPLICATE_TIME then

            local dx = math.abs(x - lastTracerOriginX)
            local dy = math.abs(y - lastTracerOriginY)
            local dz = math.abs(z - lastTracerOriginZ)

            if dx < 0.05
                and dy < 0.05
                and dz < 0.05 then

                return true

            end

        end

        -- Запоминаем текущий выстрел
        lastTracerTime = now

        lastTracerOriginX = x
        lastTracerOriginY = y
        lastTracerOriginZ = z

        return false

    end)

    if not ok then
        -- Если что-то неожиданно пошло не так,
        -- просто НЕ блокируем трасер и не крашим скрипт.
        return false
    end

    return result

end

-- =========================================================
-- НАСТРОЙКИ ТРАСЕРОВ
-- =========================================================

local TRACER_TIMER = 3.0
local TRACER_TRANSITION = 0.2
local TRACER_STEP_ALPHA = 0.01
local TRACER_THICKNESS = 1.4
local TRACER_CIRCLE_RADIUS = 4
local TRACER_DEGREE_POLYGON = 15
local TRACER_DRAW_POLYGON = true


-- =========================================================
-- ЦВЕТА ТРАСЕРОВ
-- =========================================================

local TRACER_COLORS = {

    stats = {
        0.8,
        0.8,
        0.8,
        0.7
    },

    ped = {
        1.0,
        0.4,
        0.4,
        0.7
    },

    car = {
        0.8,
        0.8,
        0.0,
        0.7
    },

    dynam = {
        0.0,
        0.8,
        0.8,
        0.7
    },

    unknown = {
        1.0,
        0.0,
        1.0,
        1.0
    }

}


-- =========================================================
-- ПОЛУЧЕНИЕ ЦВЕТА
-- =========================================================

local function getTracerColor(targetType)

    if targetType == 0 then

        return TRACER_COLORS.stats

    elseif targetType == 1 then

        return TRACER_COLORS.ped

    elseif targetType == 2 then

        return TRACER_COLORS.car

    elseif targetType == 3
        or targetType == 4 then

        return TRACER_COLORS.dynam

    end


    return TRACER_COLORS.unknown

end


-- =========================================================
-- ПЛАВНОЕ ДВИЖЕНИЕ ТРАСЕРА
-- =========================================================

local function tracerLerp(
    from,
    dest,
    startTime,
    duration
)

    local timer =
        os.clock() - startTime


    if timer >= 0
        and timer <= duration then

        local count =
            timer / (duration / 100)


        return from +
            (count * (dest - from) / 100)

    end


    if timer > duration then
        return dest
    end


    return from

end


-- =========================================================
-- FIX SCREEN POS
-- =========================================================

local function tracerFixScreenPos(
    pos1,
    pos2,
    distance
)

    distance =
        math.abs(distance)


    local direct = {

        x = pos2.x - pos1.x,

        y = pos2.y - pos1.y,

        z = pos2.z - pos1.z

    }


    local length =
        math.sqrt(

            direct.x * direct.x +

            direct.y * direct.y +

            direct.z * direct.z

        )


    if length <= 0 then
        return pos1
    end


    direct.x =
        direct.x / length

    direct.y =
        direct.y / length

    direct.z =
        direct.z / length


    return {

        x =
            pos1.x +
            direct.x * distance,

        y =
            pos1.y +
            direct.y * distance,

        z =
            pos1.z +
            direct.z * distance

    }

end


-- =========================================================
-- ДОБАВЛЕНИЕ ТРАСЕРА
-- =========================================================

local function addTracer(data)

    -- Админ-сессия обязательна
    if not adminSession then
        return
    end

    -- Сам трасер выключен
    if not tracersEnabled then
        return
    end

    if not data then
        return
    end

    -- Защита от двойного события
    if isDuplicateTracer(data) then
        return
    end

    if not data.center
        or not data.origin
        or not data.target then

        return
    end

    if data.center.x == 0
        and data.center.y == 0
        and data.center.z == 0 then

        return
    end


    -- =====================================================
    -- АНТИДУБЛИКАТ
    -- =====================================================

    local now = os.clock()

    if lastTracer
        and now - lastTracerTime <= TRACER_DUPLICATE_TIME then

        local ox =
            data.origin.x - lastTracer.origin.x

        local oy =
            data.origin.y - lastTracer.origin.y

        local oz =
            data.origin.z - lastTracer.origin.z


        local tx =
            data.target.x - lastTracer.target.x

        local ty =
            data.target.y - lastTracer.target.y

        local tz =
            data.target.z - lastTracer.target.z


        local originDist =
            math.sqrt(
                ox * ox +
                oy * oy +
                oz * oz
            )


        local targetDist =
            math.sqrt(
                tx * tx +
                ty * ty +
                tz * tz
            )


        if originDist <= TRACER_DUPLICATE_DISTANCE
            and targetDist <= TRACER_DUPLICATE_DISTANCE
            and data.targetType == lastTracer.targetType then

            return

        end

    end


    -- Запоминаем последний зарегистрированный выстрел
    lastTracer = {

        origin = {
            x = data.origin.x,
            y = data.origin.y,
            z = data.origin.z
        },

        target = {
            x = data.target.x,
            y = data.target.y,
            z = data.target.z
        },

        targetType = data.targetType

    }

    lastTracerTime = now


    -- =====================================================
    -- ЦВЕТ
    -- =====================================================

    local color =
        getTracerColor(
            data.targetType
        )


    -- =====================================================
    -- СОЗДАЁМ ТРАСЕР
    -- =====================================================

    tracerBullets[#tracerBullets + 1] = {

        clock = now,

        timer = TRACER_TIMER,

        col4 = color,

        alpha = color[4],


        origin = {

            x = data.origin.x,

            y = data.origin.y,

            z = data.origin.z

        },


        target = {

            x = data.target.x,

            y = data.target.y,

            z = data.target.z

        },


        transition =
            TRACER_TRANSITION,

        thickness =
            TRACER_THICKNESS,

        circle_radius =
            TRACER_CIRCLE_RADIUS,

        step_alpha =
            TRACER_STEP_ALPHA,

        degree_polygon =
            TRACER_DEGREE_POLYGON,

        draw_polygon =
            TRACER_DRAW_POLYGON

    }

end

-- =========================================================
-- TRACERS В /RE ЧЕРЕЗ GTA PED
-- =========================================================

local reLastShot = {}
local reLastWeapon = {}

local RE_TRACER_DISTANCE = 300.0
local RE_SHOT_DELAY = 0.08


local function addRePedTracer(id)

    if not adminSession then
        return
    end

    if not tracersEnabled then
        return
    end

    if spectatePlayerId ~= id then
        return
    end


    local ok, ped =
        sampGetCharHandleBySampPlayerId(id)

    if not ok then
        return
    end

    if not ped or ped == 0 then
        return
    end

    if not doesCharExist(ped) then
        return
    end


    -- =====================================================
    -- ПРОВЕРЯЕМ СТРЕЛЬБУ НЕ ЧЕРЕЗ RPC/SYNC,
    -- А НЕПОСРЕДСТВЕННО ЧЕРЕЗ GTA PED
    -- =====================================================

    local shooting = false

    local okShoot =
        pcall(
            function()
                shooting =
                    isCharShooting(ped)
            end
        )

    if not okShoot then
        return
    end

    if not shooting then
        return
    end


    -- =====================================================
    -- ОРУЖИЕ
    -- =====================================================

    local weapon =
        getCurrentCharWeapon(ped)

    if not weapon
        or weapon <= 0 then

        return

    end


    -- =====================================================
    -- АНТИДУБЛЬ
    -- =====================================================

    local now =
        os.clock()


    if reLastShot[id]
        and now - reLastShot[id] < RE_SHOT_DELAY then

        return

    end


    reLastShot[id] = now
    reLastWeapon[id] = weapon


    -- =====================================================
    -- ПОЛУЧАЕМ ТОЧКУ ОРУЖИЯ
    -- =====================================================

    local origin = nil

    local ptr =
        getCharPointer(ped)


    if ptr and ptr ~= 0 then

        local okBone,
        bx,
        by,
        bz =
            pcall(
                bonePos,
                ptr,
                25
            )


        if okBone then

            origin = {

                x = bx,
                y = by,
                z = bz

            }

        end

    end


    -- =====================================================
    -- FALLBACK
    -- =====================================================

    if not origin then

        local okPos,
        x,
        y,
        z =
            pcall(
                getCharCoordinates,
                ped
            )

        if not okPos then
            return
        end


        origin = {

            x = x,
            y = y,
            z = z + 0.9

        }

    end


    -- =====================================================
    -- НАПРАВЛЕНИЕ ПО HEADING ПЕДа
    -- =====================================================

    local heading =
        getCharHeading(ped)


    local rad =
        math.rad(heading)


    local dirX =
        -math.sin(rad)


    local dirY =
        math.cos(rad)


    local dirZ = 0.0


    -- =====================================================
    -- ДЛИНА ТРАССЕРА
    -- =====================================================

    local target = {

        x =
            origin.x +
            dirX *
            RE_TRACER_DISTANCE,

        y =
            origin.y +
            dirY *
            RE_TRACER_DISTANCE,

        z =
            origin.z +
            dirZ *
            RE_TRACER_DISTANCE

    }


    -- =====================================================
    -- ДОБАВЛЯЕМ ТРАССЕР
    -- =====================================================

    addTracer({

        center = {

            x = origin.x,
            y = origin.y,
            z = origin.z

        },

        origin = origin,

        target = target,

        targetType = 1

    })

end

-- =========================================================
-- RE FALLBACK TRACER
-- =========================================================

local function addReFallbackTracer(id)

    if not adminSession then
        return
    end

    if not tracersEnabled then
        return
    end

    if id < 0 then
        return
    end

    if not sampIsPlayerConnected(id) then
        return
    end


    local state =
        reShootState[id]


    if not state then
        return
    end


    if not state.shooting then
        state.wasShooting = false
        return
    end

    local now =
        os.clock()

    if now < state.nextShot then
        return
    end


    local aim =
        reAimData[id]


    if not aim then
        return
    end


    local ok,
    ped =
        sampGetCharHandleBySampPlayerId(id)


    if not ok
        or not ped
        or not doesCharExist(ped) then

        return

    end


    -- =====================================================
    -- ТОЧКА ВЫСТРЕЛА
    -- =====================================================

    local origin = nil


    local ptr =
        getCharPointer(ped)


    if ptr and ptr ~= 0 then

        local okBone,
        bx,
        by,
        bz =
            pcall(
                bonePos,
                ptr,
                25
            )


        if okBone then

            origin = {

                x = bx,

                y = by,

                z = bz

            }

        end

    end


    -- Если руку получить нельзя
    -- используем тело игрока.

    if not origin then

        local okPos,
        x,
        y,
        z =
            pcall(
                getCharCoordinates,
                ped
            )


        if not okPos then
            return
        end


        origin = {

            x = x,

            y = y,

            z = z + 0.9

        }

    end


    -- =====================================================
    -- НАПРАВЛЕНИЕ
    -- =====================================================

    local dir =
        aim.camFront


    local length =
        math.sqrt(

            dir.x * dir.x +

            dir.y * dir.y +

            dir.z * dir.z

        )


    if length < 0.001 then
        return
    end


    dir = {

        x = dir.x / length,

        y = dir.y / length,

        z = dir.z / length

    }


    -- =====================================================
    -- КОНЕЦ ТРАССЕРА
    -- =====================================================

    local tracerDistance =
        250.0


    local target = {

        x =
            origin.x +
            dir.x * tracerDistance,

        y =
            origin.y +
            dir.y * tracerDistance,

        z =
            origin.z +
            dir.z * tracerDistance

    }


    -- =====================================================
    -- СОЗДАЁМ ТРАССЕР
    -- =====================================================

    addTracer({

        center = {

            x = origin.x,

            y = origin.y,

            z = origin.z

        },

        origin = origin,

        target = target,

        targetType = 1

    })


    -- =====================================================
    -- COOLDOWN
    -- =====================================================

    state.wasShooting = true

    state.nextShot =
        now +
        getReShotInterval(
            state.weapon
        )

end


-- =========================================================
-- ОТРИСОВКА
-- =========================================================

local tracerFrame = imgui.OnFrame(

    function()

        return

            adminSession

            and tracersEnabled

            and not isPauseMenuActive()

    end,


    function()

        -- ================================================
        -- RE FALLBACK
        -- ================================================

        if spectatePlayerId >= 0 then

            addReFallbackTracer(
                spectatePlayerId
            )

        end



        local DL =
            imgui.GetBackgroundDrawList()


        for i =
            #tracerBullets,
            1,
            -1 do


            local bullet =
                tracerBullets[i]


            -- =============================================
            -- ПЛАВНАЯ ЦЕЛЬ
            -- =============================================

            local target_offset = {

                x = tracerLerp(

                    bullet.origin.x,

                    bullet.target.x,

                    bullet.clock,

                    bullet.transition

                ),

                y = tracerLerp(

                    bullet.origin.y,

                    bullet.target.y,

                    bullet.clock,

                    bullet.transition

                ),

                z = tracerLerp(

                    bullet.origin.z,

                    bullet.target.z,

                    bullet.clock,

                    bullet.transition

                )

            }


            -- =============================================
            -- SCREEN
            -- =============================================

            local okOrigin,
                oX,
                oY,
                oZ,
                oSX,
                oSY =

                convert3DCoordsToScreenEx(

                    bullet.origin.x,

                    bullet.origin.y,

                    bullet.origin.z,

                    false,

                    false

                )


            local okTarget,
                tX,
                tY,
                tZ,
                tSX,
                tSY =

                convert3DCoordsToScreenEx(

                    target_offset.x,

                    target_offset.y,

                    target_offset.z,

                    false,

                    false

                )


            if okOrigin
                and okTarget then


                local col4u32 =

                    imgui.ImVec4(

                        bullet.col4[1],

                        bullet.col4[2],

                        bullet.col4[3],

                        bullet.alpha

                    )


                local color =
                    imgui.GetColorU32Vec4(
                        col4u32
                    )


                -- =========================================
                -- ОБЕ ТОЧКИ В КАДРЕ
                -- =========================================

                if oZ > 0
                    and tZ > 0 then


                    DL:AddLine(

                        imgui.ImVec2(
                            oX,
                            oY
                        ),

                        imgui.ImVec2(
                            tX,
                            tY
                        ),

                        color,

                        bullet.thickness

                    )


                    if bullet.draw_polygon then

                        DL:AddCircleFilled(

                            imgui.ImVec2(
                                tX,
                                tY
                            ),

                            bullet.circle_radius,

                            color,

                            bullet.degree_polygon

                        )

                    end


                -- =========================================
                -- НАЧАЛО ЗА КАМЕРОЙ
                -- =========================================

                elseif oZ <= 0
                    and tZ > 0 then


                    local newPos =

                        tracerFixScreenPos(

                            target_offset,

                            bullet.origin,

                            tZ

                        )


                    local fixedOk,
                        fixedX,
                        fixedY,
                        fixedZ,
                        fixedSX,
                        fixedSY =

                        convert3DCoordsToScreenEx(

                            newPos.x,

                            newPos.y,

                            newPos.z,

                            false,

                            false

                        )


                    if fixedOk then

                        DL:AddLine(

                            imgui.ImVec2(
                                fixedX,
                                fixedY
                            ),

                            imgui.ImVec2(
                                tX,
                                tY
                            ),

                            color,

                            bullet.thickness

                        )

                    end


                -- =========================================
                -- ЦЕЛЬ ЗА КАМЕРОЙ
                -- =========================================

                elseif oZ > 0
                    and tZ <= 0 then


                    local newPos =

                        tracerFixScreenPos(

                            bullet.origin,

                            target_offset,

                            oZ

                        )


                    local fixedOk,
                        fixedX,
                        fixedY,
                        fixedZ,
                        fixedSX,
                        fixedSY =

                        convert3DCoordsToScreenEx(

                            newPos.x,

                            newPos.y,

                            newPos.z,

                            false,

                            false

                        )


                    if fixedOk then

                        DL:AddLine(

                            imgui.ImVec2(
                                oX,
                                oY
                            ),

                            imgui.ImVec2(
                                fixedX,
                                fixedY
                            ),

                            color,

                            bullet.thickness

                        )

                    end

                end

            end


            -- =============================================
            -- ЗАТУХАНИЕ
            -- =============================================

            if

                os.clock() -
                bullet.clock >
                bullet.timer

                and bullet.alpha > 0

            then

                bullet.alpha =

                    bullet.alpha -
                    bullet.step_alpha

            end


            -- =============================================
            -- УДАЛЕНИЕ
            -- =============================================

            if bullet.alpha <= 0 then

                table.remove(
                    tracerBullets,
                    i
                )

            end

        end

    end

)


tracerFrame.HideCursor = true
tracerFrame.LockPlayer = false


-- =========================================================
-- ВЫСТРЕЛ СВОЕГО ИГРОКА
-- =========================================================

function sampev.onSendBulletSync(data)

    addTracer(data)

end


function sampev.onBulletSync(originId, data)

    addTracer(data)

end


-- =========================================================
-- /TRACERS
-- =========================================================

function cmd_tracers()

    -- Без админ-сессии команда не работает
    if not adminSession then
        return
    end


    tracersEnabled =
        not tracersEnabled


    -- Если выключили — полностью очищаем
    if not tracersEnabled then

        tracerBullets = {}

    end


    sampAddChatMessage(

        '-> Tracers enabled: ' ..
        tostring(tracersEnabled),

        CHAT_COLOR

    )

end


-- =========================================================
-- MAIN
-- =========================================================

function main()

    -- Создаём config
    createConfigFolder()


    -- Админ-сессия всегда определяется только текущей сессией.
    -- Не восстанавливаем её из CFG, чтобы WH/PINFO не работали
    -- после запуска скрипта без фактического входа в админку.
    adminSession = false


    checkEnabled =
        loadCheckState()


    -- WH также не включаем автоматически при старте.
    whEnabled = false


    -- Цветовая карта WH
    rebuildColorMap()


    -- Ждём SA-MP
    while not isSampAvailable() do
        wait(100)
    end


    -- =====================================================
    -- ЗАГРУЗКА
    -- =====================================================

    sampAddChatMessage(
        '{E37676}[Admin Helper] {FFFFFF}Скрипт загружен | Активация /at or /atools | Автор: еклипс',
        -1
    )


    -- =====================================================
    -- КОМАНДЫ
    -- =====================================================

    sampRegisterChatCommand(
        'pinfo',
        cmd_pinfo
    )


    sampRegisterChatCommand(
        'proverka',
        cmd_proverka
    )


    sampRegisterChatCommand(
        'checkon',
        cmd_checkon
    )


    sampRegisterChatCommand(
        'checkoff',
        cmd_checkoff
    )


    sampRegisterChatCommand(
        'at',
        cmd_at
    )


    sampRegisterChatCommand(
        'atools',
        cmd_at
    )


    sampRegisterChatCommand(
        'whadmin',
        cmd_whadmin
    )

    sampRegisterChatCommand(
        'tracers',
        cmd_tracers
    )


    -- =====================================================
    -- ОБНОВЛЕНИЕ СПИСКА ИГРОКОВ
    -- =====================================================

    lua_thread.create(function()

        while true do

            wait(500)


            for id = 0, 1000 do

                if sampIsPlayerConnected(id) then

                    local ok, ped =
                        sampGetCharHandleBySampPlayerId(id)


                    if ok
                        and doesCharExist(ped)
                        and ped ~= playerPed then


                        local skin =
                            getPlayerSkin(
                                id,
                                ped
                            )


                        if not players[id] then

                            players[id] = {

                                ped = ped,

                                name =
                                    sampGetPlayerNickname(id),

                                skin = skin

                            }

                        else

                            players[id].ped =
                                ped

                            players[id].skin =
                                skin

                        end

                    end

                else

                    players[id] = nil

                end

            end

        end

    end)

    -- =====================================================
    -- MAIN LOOP
    -- =====================================================

    while true do
        wait(1000)
    end

end