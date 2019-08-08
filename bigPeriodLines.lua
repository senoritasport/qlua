--Для включения логирования надо раскомментировать строку
--local logFile = io.open(getWorkingFolder().."\\LuaIndicators\\bigPeriodLines.txt", "w")

--[[
    nick-h@yandex.ru
    https://github.com/nick-nh/qlua

    Индикатор вывода линий индикатора большего диапазона на меньший одного тикера.
    Для примера, вывести с дневного графика на часовой и т.д.
    Ограничений комбинаций интервалов нет.
    Индикатор сам находит интервал старшего графика и производит пересчет значений.
    Необходимо задать Идентификатор indTag графика с котрого будут взяты значения линий.
    Также необходимо задать номера линий для вывода showLines через ";"
    Можно задавать произвольные комбинации линий 1;2;3 или 1;3 или 2;3 и т.д.
    Если у старшего индикатора есть сдвиг его можно задать через indOffset
    По умолчанию вывод линий произволится лесенкой, если задать параметр smoothLines,
    то будет произведено сглаживание линий для меньшего тайм-фрейма
]]

Settings= {
        Name                = "*BigPeriodLines",
        indTag              = 'testChart',
        indOffset           = 0,
        showLines           = '1;2;3',
        smoothLines         = 0,
        smoothLastRegion    = 1
}

local linesSettings = {
        {
            Color = RGB(255, 128, 128),
            Type = TYPE_LINE,
            Width = 2
        },
        {
            Color = RGB(128, 0, 0),
            Type = TYPE_LINE,
            Width = 2
        },
        {
            Color = RGB(0, 128, 128),
            Type = TYPE_LINE,
            Width = 2
        },
        {
            Color = RGB(128, 128, 255),
            Type = TYPE_LINE,
            Width = 2
        },
        {
            Color = RGB(128, 128, 128),
            Type = TYPE_LINE,
            Width = 2
        }
}

local floor = math.floor
local ceil  = math.ceil
local abs   = math.abs
local min   = math.min
local max   = math.max

local function allWords(str, sep)
    return function()
        if str == '' then return nil end
        local pos = string.find(str,sep)
        while pos do
            local word = string.sub(str,1,pos-1)
            str = string.sub(str,pos+1)
            pos = string.find(str,sep)
            return word
        end
        local word = str
        str = string.gsub(str,word,'')
        return word
    end
end

local function round(num, idp)
    if num then
        local mult = 10^(idp or 0)
        if num >= 0 then
            return floor(num * mult + 0.5) / mult
        else
            return ceil(num * mult - 0.5) / mult
        end
    else
        return num
    end
end

local function toYYYYMMDDHHMMSS(datetime)
     if type(datetime) ~= "table" then
        return ""
     else
        local Res = tostring(datetime.year)
        if #Res == 1 then Res = "000"..Res end
        Res = Res.."."
        local month = tostring(datetime.month)
        if #month == 1 then Res = Res.."0"..month else Res = Res..month end
        Res = Res.."."
        local day = tostring(datetime.day)
        if #day == 1 then Res = Res.."0"..day else Res = Res..day end
        Res = Res.." "
        local hour = tostring(datetime.hour)
        if #hour == 1 then Res = Res.."0"..hour else Res = Res..hour end
        Res = Res..":"
        local minute = tostring(datetime.min)
        if #minute == 1 then Res = Res.."0"..minute else Res = Res..minute end
        Res = Res..":"
        local sec = tostring(datetime.sec);
        if #sec == 1 then Res = Res.."0"..sec else Res = Res..sec end
        return Res
     end
end --toYYYYMMDDHHMMSS

local function myLog(text)
    if logFile==nil then return end
    logFile:write(tostring(os.date("%c",os.time())).." "..text.."\n");
    logFile:flush();
end

--Расчет интервала индикатора, первого бара
local function CalcBigInd(settings, interval)

    local status,res1,res2 = pcall(function()

        local last_bar  = getNumCandles(settings.indTag) - settings.indOffset
        local line      = getCandlesByIndex(settings.indTag, 0, 0, last_bar)

        if line and line[#line] then

            local big_interval  = round((os.time(line[#line].datetime) - os.time(line[#line-1].datetime))/60)

            myLog('Индикатор большого периода: last_bar: '..tostring(last_bar)..', Size: '..tostring(Size())..', interval: '..tostring(interval)..', big_interval: '..tostring(big_interval)..', line 0: '..tostring(line[#line].close)..' - '..toYYYYMMDDHHMMSS(line[#line].datetime))

            if big_interval == 0 then
                myLog("Не определен интервал графика")
                return 0,0
            end

            if (interval or 0)~=0 then

                local first_index       = max(last_bar - floor(Size()*interval/big_interval), 0)
                --myLog('first_index: '..tostring(first_index)..' - '..toYYYYMMDDHHMMSS(line[first_index].datetime))
                myLog('first_index: '..tostring(first_index))
                local cur_index_time    = os.time(T(1))
                local index_time        = os.time(line[first_index].datetime)
                if cur_index_time > index_time then
                    while cur_index_time > (index_time + big_interval*60) do
                        first_index = first_index+1
                        index_time  = os.time(line[first_index].datetime)
                    end
                elseif cur_index_time < index_time then
                    while cur_index_time < index_time and first_index>0 do
                        first_index = first_index-1
                        index_time  = os.time(line[first_index].datetime)
                    end
                end

                myLog('Первый индекс: '..toYYYYMMDDHHMMSS(T(1))..', first_index: '..tostring(first_index)..' - '..toYYYYMMDDHHMMSS(line[first_index].datetime))

                return big_interval, first_index
            end
            return 0,0

        else
            message("Не удалось получить данные по индикатору: "..tostring(settings.indTag), 3)
            myLog("Не удалось получить данные по индикатору: "..tostring(settings.indTag))
        end

        return 0,0
    end)
    if not status then
        myLog('Error CalcInterval: '..res1)
        return 0,0
    end
    return res1,res2

end

local function GetNextBigIndex(index, big_index, big_interval, settings)
    local status,res = pcall(function()
        local line = getCandlesByIndex(settings.indTag, 0, big_index - settings.indOffset, 1)
        if index == Size() then myLog('GetNextBigIndex  index: '..tostring(index)..' - '..toYYYYMMDDHHMMSS(T(index))..', big_index: '..tostring(big_index)..' - '..toYYYYMMDDHHMMSS(line[#line].datetime)) end
        while os.time(T(index)) >= os.time(line[#line].datetime)+big_interval*60 do
            big_index = min(big_index+1, getNumCandles(settings.indTag) - settings.indOffset)
            line      = getCandlesByIndex(settings.indTag, 0, big_index - settings.indOffset, 1)
            if index == Size() then myLog('new big_index: '..tostring(big_index)) end
        end
        return big_index
    end)
    if not status then
        myLog('Error GetNextBigIndex: '..res)
        return 0
    end
    return res
end

local function GetBigLine(big_index, line_index, settings)
    local status,res = pcall(function()
        local line = getCandlesByIndex(settings.indTag, line_index, big_index - settings.indOffset, 1)
        if type(line) == 'table' and line[#line] then
            return line[#line].close
        else
            myLog('GetBigLine ошибка получения значения индикатора big_index: '..tostring(big_index)..', line: '..tostring(line_index))
        end
        return 0
    end)
    if not status then
        myLog('Error GetBigLine: '..res)
        return 0
    end
    return res
end

local function CalcFunc(settings)

    local scale             = 0
    local interval          = 0
    local big_interval      = 0
    local big_index         = 0
    local interval          = 0
    local last_index        = 0
    local last_prev_index   = 0
    local big_lines         = {}

    myLog('-------------------------------------------------------')
    myLog('Settings:')
    for k,v in pairs(settings) do
        if type(p)~='function'then
            myLog(k..': '..tostring(v))
        end
    end
    myLog('Show lines:')
    for k,v in pairs(settings.big_line) do
        myLog(k..' line '..tostring(v))
    end

    return function(index)

        local status,res = pcall(function()

            if index == 1 then
                local ds_info               = getDataSourceInfo()
                scale                       = getSecurityInfo(ds_info.class_code, ds_info.sec_code).scale or 0
                myLog(toYYYYMMDDHHMMSS(T(Size()))..' - '..toYYYYMMDDHHMMSS(T(Size()-1)))
                interval                    = round((os.time(T(Size())) - os.time(T(Size()-1)))/60)
                big_interval, big_index     = CalcBigInd(settings, interval)
                myLog('-------------------------------------------------------')
                big_lines[index]            = {}
                for i=1,#settings.line do
                    big_lines[index][i]     = C(index)
                end
                last_index                  = 1
                return nil
            end

            if big_interval == 0 then return nil end

            big_lines[index] = {}

            local new_big_index = GetNextBigIndex(index, big_index, big_interval, settings)
            local bars          = index - last_index

            for i=1,#settings.line do
                local new_val_line      = GetBigLine(new_big_index, settings.big_line[i], settings)
                if index == Size() and new_val_line == 0 then
                    myLog('Не получен бар старшего интервала')
                    return nil
                end
                big_lines[index][i] = new_val_line == 0 and big_lines[index-1][i] or new_val_line
                if index >= Size() - 50 then myLog('index: '..tostring(index)..' - '..toYYYYMMDDHHMMSS(T(index))..', line: '..tostring(i)..', big_lines: '..tostring(big_lines[index][i])..', last_prev_index: '..tostring(last_prev_index)..', last_index: '..tostring(last_index)) end
                if index == Size() or (settings.smoothLines == 1 and new_big_index~=big_index) then
                    local val_line = new_val_line
                    if new_big_index~=big_index then
                        if index >= Size() - 50 then myLog('new_big_index: '..tostring(new_big_index)..', last_index: '..tostring(last_index)..', last_prev_index: '..tostring(last_prev_index)..', index: '..tostring(index))  end
                        val_line            = GetBigLine(big_index, settings.big_line[i], settings) or big_lines[index-1][i]
                        local delta_range   = 0
                        if settings.smoothLines == 1 and last_prev_index~=0 then
                            local prev_val_line = GetBigLine(big_index-1, settings.big_line[i], settings) or big_lines[index-1][i]
                            bars                = last_index - last_prev_index
                            delta_range         = (val_line - prev_val_line)
                            if index >= Size() - 50 then myLog('val_line: '..tostring(val_line)..', delta: '..tostring(delta_range)..', bars: '..tostring(bars)) end
                            local sum = 0
                            for ind = 0, bars, 1 do
                                sum = sum + (ind == 0 and 0 or (delta_range-sum)/(bars-ind+1))
                                big_lines[last_index - bars+ind][i] = prev_val_line+sum
                                SetValue(last_index - bars+ind, i, prev_val_line+sum)
                                if index >= Size() - 50 then myLog('Set index : '..tostring(last_index - bars+ind)..' - '..toYYYYMMDDHHMMSS(T(last_index - bars+ind))..' val = '..tostring(prev_val_line+sum)) end
                            end
                        end
                    end
                    local delta_range   = 0
                    bars                = index - last_index
                    if settings.smoothLines == 1 and last_index~=0 then
                        val_line        = GetBigLine(((new_big_index~=big_index or settings.smoothLastRegion == 0) and big_index or big_index-1), settings.big_line[i], settings) or big_lines[index-1][i]
                        delta_range         = (new_val_line - val_line)
                        bars                = index - ((new_big_index~=big_index or settings.smoothLastRegion == 0) and last_index or last_prev_index)
                    end
                    if index >= Size() - 50 then myLog('new_val_line: '..tostring(new_val_line)..', delta: '..tostring(delta_range)..', bars: '..tostring(bars)) end
                    local sum = 0
                    for ind = 0, bars, 1 do
                        sum = sum + (ind == 0 and 0 or (delta_range-sum)/(bars-ind+1))
                        big_lines[index - bars+ind][i] = val_line+sum
                        SetValue(index - bars+ind, i, val_line+sum)
                        if index >= Size() - 50 then myLog('Set index : '..tostring(index - bars+ind)..' - '..toYYYYMMDDHHMMSS(T(index - bars+ind))..' val = '..tostring(val_line+sum)) end
                    end
                end
            end

            if new_big_index~=big_index then
                big_index       = new_big_index
                last_prev_index = last_index
                last_index      = index
            end

        end)
        if not status then
            myLog('Error CalcFunc: '..res)
            return nil
        end

        return unpack(big_lines[index] or {})

    end
end

function Init()

    Settings.line       = {}
    Settings.big_line   = {}
    local i             = 1
    for line in allWords(Settings.showLines,';') do
        Settings.line[i] = {}
        Settings.line[i] = linesSettings[i] or {Color = RGB(0, 0, 0), Type = TYPE_LINE, Width = 2}
        Settings.big_line[i] = tonumber(line)-1
        i = i + 1
    end

    PlotLines = CalcFunc(Settings)

    return #Settings.line
end

function OnChangeSettings()
    Init()
end

function OnCalculate(index)
    return PlotLines(index)
end
