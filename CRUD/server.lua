local dbConnection = false

--
local lower = utf8.lower
--

local block = {} -- Таблица флудеров
local tUsersData = {} -- БД 
local tUserOpenCRUD = {} -- Таблица у которых открыто основное окно


-- Мини антифлуд
local function isSpamer( player )
    if block[player] and getTickCount() - block[player] >= AntiFlood or not block[player] then
        block[player] = getTickCount()
        return false 
    end 
    return true
end 

local function isPlayerOpenInterface( thePlayer )
	return tUserOpenCRUD[ thePlayer ] or false
end

local function setPlayerOpenInterface( thePlayer )
	if isElement( thePlayer ) then
		tUserOpenCRUD[thePlayer] = true
	end
end

local function clearPlayerOpenInterface( thePlayer )
	if tUserOpenCRUD[thePlayer] then 
		tUserOpenCRUD[thePlayer] = nil
	end 
end

-- Сохраняем состояние окна игрока
local function setPlayerOpenStateInterface( state, thePlayer )
    local thePlayer = isElement( thePlayer ) and thePlayer or client
    if not thePlayer then return end
    if not isElement( thePlayer ) then return end 
    tUserOpenCRUD[ thePlayer ] = state and true or nil
end 

addEvent('crud:ClientOpenInterface', true)
addEventHandler('crud:ClientOpenInterface', resourceRoot , setPlayerOpenStateInterface )



-- Получаем общее количество страниц
local function totalPages( table )
    return math.ceil( ( #table or 1 ) / ( RowPageSize or 20) ) 
end 

-- Получие списка пользователей исходя из страницы
local function getUsersSelectPage( page )
    local tSendData = { }
    local totalPage = totalPages( tUsersData )
    local size = RowPageSize * page
    local startSize = ( page - 1 ) < 1 and 1 or RowPageSize * ( page - 1)
    for i = startSize, size > #tUsersData and #tUsersData or size do
        if not tUsersData[i] then break end 
        tSendData[#tSendData + 1] = tUsersData[i]
    end 
    return tSendData
end 



-- Вызыв окна ошибки
local function sendErrorClient( thePlayer, text )
    if isPlayerOpenInterface( thePlayer ) then
        triggerClientEvent( thePlayer, "crud:setVisibleWarning", thePlayer, true, text )
    end 
end 

--// CallBack-функция обновления данных
local function fillCacheData( queryHandler )
	local queryResult = dbPoll( queryHandler, -1 )
    if queryResult and next( queryResult ) then
        for id, data in pairs( queryResult ) do
            local accID = data.id or false
            if accID then
                tUsersData[#tUsersData + 1] = data
                -- tUsersData[id] = data
            end 
        end
    end
    -- Если есть инфа и есть игроки у которых открыто окно
    if #tUsersData > 0 and next( tUserOpenCRUD ) then
        local tSend = {}
        for thePlayer, isOpen in pairs( tUserOpenCRUD ) do 
            if isOpen then
                tSend[#tSend + 1] = thePlayer
            end 
        end 
        triggerClientEvent( tSend, 'crud:sendClientLogs', resourceRoot, getUsersSelectPage( 1 ), totalPages( tUsersData ), 1 )
    end 
end


local function refreshServerData( )
    dbQuery ( fillCacheData, dbConnection, "SELECT * FROM task")  
end

-- Подключение к базе данных
local function CreateConnection()
    dbConnection = dbConnect( "mysql", "dbname=quest; host=127.0.0.1;", "root", "", "share=1")
    if dbConnection then 
        refreshServerData( )      
    else
        setTimer( CreateConnection, 8888, 1 )
        print("Нет подключения, повторная попытка")
    end
end
addEventHandler("onResourceStart", resourceRoot, CreateConnection)




-- Подготвка данных для отправки данных клиенту
local function getUserData( page )
    local client = isElement( client ) and client or false 
    if not client then return end
    if isSpamer( client ) then return end 
    
    local page = tonumber( page ) and page or false 
    if not page then
        page = 1
    end 

    local tData = getUsersSelectPage( page )
    triggerClientEvent( client, 'crud:sendClientLogs', resourceRoot, tData, totalPages( tUsersData ), page )
end 

addEvent('crud:getServerLogs', true)
addEventHandler('crud:getServerLogs', resourceRoot , getUserData)

-- Отправка клиенту то что он просил
local function seachCrud( query, player )
	local result = dbPoll( query, 0 )
	if not result then return end
    if not next( result ) then return end
    triggerClientEvent( player, 'crud:sendClientLogs', resourceRoot, result, totalPages( result ), 1 )
end 

--  Поиск пользователя указанного в INPUT ( Столбик, введенная строка)
function SearchUser( colum, str )
    if not client then return end
    if isSpamer( client ) then return end 
    if not colum or type( colum ) ~= 'number' then return end 

    local tData = {}
    local str = trim( str )

    -- Если указанное поле пустое
    if str == "" then 
        local tDatad = getUsersSelectPage( 1 )
        if #tDatad > 0 then 
            triggerClientEvent( client, 'crud:sendClientLogs', resourceRoot, tDatad, totalPages( tUsersData ), page )
        end 
        return 
    end 
    
    if not COLUMN_NAME[colum] then return end
    -- fast =)
    dbQuery( seachCrud, { client }, dbConnection, string.format( "SELECT * FROM task WHERE %s LIKE '%%%s%%'", COLUMN_NAME[colum], str))
    -- for k, v in pairs( tUsersData ) do 
    --     if COLUMN_NAME[colum] and v[COLUMN_NAME[colum]]:find( str ) then -- Если есть такая колонка и информация в ней
    --         table.insert( tData, v )   
    --     end 
    -- end
    -- if #tData > 0 then
    --     triggerClientEvent( client, 'crud:sendClientLogs', resourceRoot, tData, totalPages( tData ), 1 )
    -- end 
end
addEvent( "crud:searchColum", true )
addEventHandler( "crud:searchColum", resourceRoot , SearchUser )



----------------------------------------------
-- Добавление игрока в БД
local function addNewUser( data )
    if not client then return end 
    if type( data ) ~= 'table' then return end 
    if not next( data ) then return end 
    if isSpamer( client ) then return end 


    local nick, family, city = unpack( data )
    lowNick, lowFamily, lowCity = lower( nick ), lower( family ), lower( city )

    for i = 1, #tUsersData do
        local data = tUsersData[i]
        if data and lower( data.name ) == lowNick and lower( data.surname ) == lowFamily and lower( data.city ) == lowCity then
            sendErrorClient( client, "Такой пользователь уже есть, пш")
            return false 
        end 
    end
    local post = dbPrepareString( dbConnection, "INSERT INTO `task` (`name`, `surname`, `city`) VALUES (?, ?, ?)" , nick, family, city )
    dbExec( dbConnection, post)
    sendErrorClient( client, "Вы успешно добавили пользователя")
    outputChatBox( "Вы успешно добавили пользователя", client)
    refreshServerData( )
end 

addEvent( "crud:addNewUser", true)
addEventHandler( "crud:addNewUser", resourceRoot , addNewUser )


----------------------------------------------
-- Обновление пользователя в БД
local function updateUserDB( data, accID )
    if not client then return end 
    if type( data ) ~= 'table' then return end 
    if not next( data ) then return end 
    if isSpamer( client ) then return end 
    
    local accID = tonumber( accID ) or false  
    if not accID then return end 
    

    local nick, family, city = unpack( data )   

    for i = 1, #tUsersData do
        local tUserInfo = tUsersData[i]
        local id, _name, _surname, _city = tUserInfo.id, tUserInfo.name, tUserInfo.surname, tUserInfo.city
        if tUserInfo.id == tonumber( accID ) then
            if not ( name == nick and _surname == family and _city == city ) then
                local post = dbPrepareString( dbConnection, "UPDATE `task` SET `name` = ?, `surname` = ?, `city` = ? WHERE `id` = ?" , nick, family, city, accID )
                dbExec( dbConnection, post )
                tUsersData[i] = { id = accID, name = nick, surname = family, city = city } -- На момент обновления
                refreshServerData( )
                outputChatBox( "Вы успешно обновили пользователя", client)
            else
                sendErrorClient( client, "Вы ничего не поменяли")
            end 
            return
        end 
    end 
end 
addEvent( "crud:updateUser", true)
addEventHandler( "crud:updateUser", resourceRoot , updateUserDB )

----------------------------------------------
-- удаление пользователя из БД
local function deleteUserBD( userID )

    if not client then return end 
    local userID = tonumber( userID ) or false 
    if not userID then return end 
    if isSpamer( client ) then return end 

    
    for i = 1, #tUsersData do
        local tUserInfo = tUsersData[i]
        if tUserInfo.id == userID then
            local post = dbPrepareString( dbConnection, "DELETE FROM `task` WHERE `id` = ?", userID )
            dbExec( dbConnection, post)
            table.remove( tUsersData, i )
            refreshServerData( )
            outputChatBox( "Вы успешно удалили пользователя", client)
            return
        end 
    end
    sendErrorClient( client, "Нет указанного пользователя для удаления")
end
addEvent( "crud:DeleteUser", true)
addEventHandler( "crud:DeleteUser", resourceRoot , deleteUserBD )



-- Очиска
local function Clear()
    if block[source] then
        block[source] = nil
    end
    clearPlayerOpenInterface( source )
end
addEventHandler( "onPlayerQuit", root, Clear)
addEventHandler( "onPlayerLogout", root, Clear )
    
    



