-- include DGS
loadstring(exports.dgs:dgsImportFunction())()
loadstring(exports.dgs:dgsImportOOPClass(true))()



local tModal = {} -- Модальное окно добавление игроков
local tError = {} -- GUI Ошибки
local tIndexBtn = {} -- Номера страниц
local tInterface = {} -- Основное меню



local mainPanel, modalPanel, errorPanel
local current_page = 1 -- тек. страница
local maxPage = 1 -- Всего страниц 


-- DGS
local showCrud = false
local isFirstStart = true

local tLabel = {
    'Имя пользователя',
    'Фамилия пользователя',
    'Адрес проживания'
}

-- Обновление страницы ( Отправка новой страницы на сервер )
local function refreshPage( newPage )
    local nextPage = current_page + newPage

    local nextPage = nextPage <= 1 and 1 
                    or newPage >= maxPage and maxPage 
                    or nextPage

    local nextPage = nextPage < 1 and 1 or nextPage -- Если всего страниц 0 фиксим на 1
    
    if nextPage ~= current_page then -- Если это новая страница > обновляем информацию
        triggerServerEvent('crud:getServerLogs', resourceRoot, nextPage)
    end
end


local function isMainMenuVisible( )
    if not isElement( mainPanel ) then return false end 
    return dgsGetVisible( mainPanel )
end 

-- Получение послед выдл. строки
local function getSelectListRow( )
    local list = tInterface.list
    local selected, _ = dgsGridListGetSelectedItem( list )
    if selected ~= -1 then 
        local myItemData = dgsGridListGetItemData ( list, selected, 1 )
        return myItemData or false 
    end
    return false 
end 


-- Проверки 3х полей ввода
local function fillingEditbox( data )
    if not tModal or not tModal.input or not #tModal.input == 3 then return end 

    local tInput = tModal.input
    for i = 1, #tInput do 
        dgsSetText( tInput[i], tostring( data[i] ) )
    end
end 

-- Заполнение строк данными
local function setRowData( tbl )
    local dgsList = tInterface.list
    for id, data in pairs( tbl ) do
        local row = dgsGridListAddRow ( dgsList )
        dgsGridListSetItemData ( dgsList, row, 1, { data.id , data.name, data.surname, data.city } )
        dgsGridListSetItemText ( dgsList, row, 1, data.name )
        dgsGridListSetItemText ( dgsList, row, 2, data.surname )
        dgsGridListSetItemText ( dgsList, row, 3, data.city )
    end
end

local function initDxMenu()
    if isElement( mainPanel ) then return end 

    local Panel = dgsCreateWindow ( 0.25, 0.25, 0.5, 0.50, "", true, 0xFF000000, 35, nil, 0xFFf2f4f6, nil, 0xFFFFFFFF)
    dgsWindowSetMovable ( Panel, true ) -- Запрет на перемещение
    addEventHandler("onDgsWindowClose", Panel, 
        function( ) 
            if source == Panel then 
                setCRUDVisible( false )
                setModalWindowVisible( false )
                setErrorMenuVisible( false )
            end 
        end
    )
    dgsSetVisible ( Panel, false )

    local closeBtn = dgsCreateButton ( 0.97, 0.03, 0.02, 0.05, "X", true, Panel ) -- Кнопка закрытия
    local seachBtn = dgsCreateButton ( 0.92, 0.03, 0.04, 0.05, "Go", true, Panel )  -- Кнопка найти
        
    -- Поиск
    local editBox = dgsCreateEdit( 0.71, 0.03, 0.2, 0.05, "Seach", true, Panel )
    dgsSetInputMode( "no_binds_when_editing" )

    -- Сортировка по Combox
    local Combo = dgsCreateComboBox(0.53, 0.03, 0.17, 0.05, "Поиск по", true, Panel) -- Создание combox
    for _, text in pairs( tLabel ) do
        dgsComboBoxAddItem( Combo, text) -- 
    end

    -- List
    local list = dgsCreateGridList ( 0.03, 0.13, 0.94, 0.65 -0.001, true, Panel, _, 0x00FFFFFF, 0xFF000000, 0x00FFFFFF, 0xFF000000, 0xFF000000 )
    
    -- Добавление заголовков в List
    for k, text in pairs( tLabel ) do
        dgsGridListAddColumn( list, text, k == 3 and 0.5 or 0.3) -- 
    end
    
    -- -- Кнопки Prev / Next
    local tBtn = {}
    tBtn[1] = dgsCreateButton ( 0.72 , 0.80, 0.045, 0.05, ' < ' , true, Panel ) -- Кнопка Прошлой страницы
    tBtn[2] = dgsCreateButton ( 0.75 + 0.18 , 0.80, 0.05, 0.05, ' > ' , true, Panel ) -- Кнопка След страницы
    
    for i = 1, #tBtn do -- Антифлуд кнопками
        dgsSetProperty( tBtn[i], "clickCoolDown", antiFlood )
    end 

    dgsSetMultiClickInterval( 2000 ) -- Двойной клик интевар        


    local addBtn = dgsCreateButton ( 0.5, 0.80, 0.2, 0.05, "Добавить пользователя", true, Panel )
    
    -- tInterface.seachBtn
    mainPanel = Panel;
    tInterface = { 
        closeBtn = closeBtn,
        seachBtn = seachBtn,
        editBox = editBox,
        combo = Combo,
        list = list,
        page = {},
    };

    -- Обработчик кнопок

    addEventHandler ("onDgsMouseDown", Panel, 
        function( btn, x, y ) -- clickCoolDown анти-флуд
            local clickCoolDown = false
            if btn ~= "left" then return end 
            setErrorMenuVisible( false )

            local tList = tInterface.page
         
    
            for i = 1, #tBtn do -- Кнопки Prev / Next
                if tBtn[i] == source and not clickCoolDown then
                    refreshPage( i == 1 and -1 or 1 )
                    return
                end 
            end 
    
    
            for i = 1, #tList do -- Кнопки переключения страниц
                if tList[i] == source and not clickCoolDown then 
                    if tIndexBtn[source] ~= current_page then 
                        triggerServerEvent('crud:getServerLogs', resourceRoot, tIndexBtn[source])
                    end 
                    return
                end 
            end 
         
            -- Поиск по колонкам
            if seachBtn == source then
                if dgsComboBoxGetSelectedItem( Combo ) == -1 or dgsGetText( editBox ) == 'Seach' then
                    setErrorMenuVisible( true, "Ничего не выбрано/Не написано" )
                    return 
                end 
                if trim(dgsGetText( editBox )) ~= "" then 
                    triggerServerEvent( 'crud:searchColum', resourceRoot, dgsComboBoxGetSelectedItem( Combo ) or 1, trim(dgsGetText( editBox )) )
                else 
                    triggerServerEvent('crud:getServerLogs', resourceRoot, 1)
                end 
                return 
            end 
    
            -- Кнопка создания пользователя
            if source == addBtn then
                if isElement( modalPanel ) and dgsGetVisible( modalPanel ) then
                    setModalWindowVisible( false )
                    return
                end 
                setModalWindowVisible( true, STATUS_CREATE )
            end 


            if isElement( tInterface.list ) and source == tInterface.list then 
                if getSelectListRow( ) then
                    if isElement( modalPanel ) and dgsGetVisible( modalPanel ) then
                        setModalWindowVisible( false )
                        return
                    end 
                    setModalWindowVisible( true, STATUS_UPDATE )
                    local idSelectUser, nick, family, city = unpack( getSelectListRow( ))
                    fillingEditbox( { nick, family, city } ) -- Автозаполнение инфы о пользователе
                    return 
                end 
            end
        end)
    
end 

function setCRUDVisible( state )
    if state then
		if not isElement( mainPanel ) then
			initDxMenu()
		end
	end
    if not isElement( mainPanel ) then return end
	dgsSetVisible( mainPanel, state )
    triggerLatentServerEvent('crud:ClientOpenInterface', resourceRoot, state)
    showCursor( state )
end 

local function showDGSCrud( )
    showCrud = not showCrud
    setCRUDVisible( showCrud )
    triggerServerEvent( 'crud:getServerLogs', resourceRoot, current_page )
end 


addEventHandler("onClientResourceStart", resourceRoot,
    function()
        bindKey( "L", "down", showDGSCrud ) 
        outputChatBox( "[Подсказка]: Чтобы активировать CRUD нажмите L" )
    end
)


-- Создание карусели страниц
local function generatePage( AllPage )
    if not isElement( mainPanel ) then return end 
    local tList = tInterface.page
    -- Очистка старых
    for index = 1, #tList do
        tIndexBtn[tList[index]] = nil
        destroyElement( tList[index] )
        tList[index] = nil
    end 
    -- Создание новых
    for index = current_page, current_page + RenderList > AllPage and AllPage or current_page + RenderList do
        tList[#tList + 1] = dgsCreateButton ( 0.733 + ( (#tList + 1) * 4 / 100) , 0.80, 0.03, 0.05, index , true, mainPanel ) -- Кнопки страниц
        dgsSetProperty( tList[#tList], "clickCoolDown", antiFlood ) -- Кд на жмяк
        tIndexBtn[tList[#tList]] = index
    end 
end 


-- Ответ от сервера с логами
addEvent('crud:sendClientLogs', true)
addEventHandler('crud:sendClientLogs', resourceRoot, 
    function( table, AllPages, selectedPage )
        if not isElement( mainPanel ) then return end 
        if not isElement( tInterface.list ) then return end

        setModalWindowVisible( false )
        current_page = selectedPage -- Выбранная страница
        maxPage = AllPages -- Всего страниц

        generatePage( AllPages )

        dgsGridListClear( tInterface.list );
        if next( table ) then 
            setRowData( table, tInterface.list )
        end 

    end
)

-- Проверки 3х полей ввода
local function checkValidInput( )
    if not tModal or not tModal.input or not #tModal.input == 3 then return end 
    local tInput = tModal.input
    local sendData = {}
    for i = 1, #tInput do 
        local dgsInput = trim( dgsGetText( tInput[i] ) )
        if #dgsInput < 1 then
            return false 
        end 
        sendData[#sendData + 1] = dgsInput
    end
    if #sendData == 3 then
        return true, sendData
    else
        return false 
    end 
end 



function isModalMenuVisible( )
    if not isElement( modalPanel ) then return false end 
    return dgsGetVisible( modalPanel )
end 


local function initModalWindow( )
    if isElement( modalPanel ) then return end 

    local Panel = dgsCreateWindow ( 0.38, 0.33, 0.3, 0.50, "Настройки пользователей", true, 0xFF70747b, 35, nil, 0xFF202225, nil, 0xFF36393f )
    -- dgsWindowSetMovable ( Panel, false ) -- Запрет на перемещение
    addEventHandler("onDgsWindowClose", Panel, 
        function( ) 
            if source == Panel then 
                setModalWindowVisible( false )
                setCRUDVisible ( true )
                setErrorMenuVisible( false )
            end 
        end
    )
    dgsSetVisible ( Panel, false )

    local tInput = {}
    local text = dgsCreateLabel( 0.1, 0.1, 0.5, 0.1, "Имя", true, Panel )
    tInput[1] = dgsCreateEdit( 0.1, 0.15, 0.5, 0.1, "", true, Panel )
    
    local text = dgsCreateLabel( 0.1, 0.3, 0.2, 0.1, "Фамилия", true, Panel)
    tInput[2] = dgsCreateEdit( 0.1, 0.35, 0.5, 0.1, "" , true, Panel )
    
    local text = dgsCreateLabel( 0.1, 0.5, 0.6, 0.05, "Адрес проживания", true, Panel )
    tInput[3] = dgsCreateEdit( 0.1, 0.55, 0.5, 0.1, "", true, Panel )
    dgsSetInputMode( "no_binds_when_editing" ) -- Отключение всего чтоб ничего не мешало печатать ;)

    local btnAccept = dgsCreateButton ( 0.1, 0.75, 0.3, 0.1, " Добавить пользователя ", true, Panel )
    dgsSetProperty( btnAccept, "clickCoolDown", antiFlood ) -- Кд на жмяк

    local btnDelete = dgsCreateButton ( 0.6, 0.75, 0.3, 0.1, " Удалить ", true, Panel )
    dgsSetProperty( btnAccept, "clickCoolDown", antiFlood ) -- Кд на жмяк

    --tModal.status
    modalPanel = Panel;
    tModal = { 
        accBtn = btnAccept,
        accDel = btnDelete,
        input = tInput,
        status = STATUS_CREATE,
        idUser = -1,
    };

    -- Обработчик кнопок
    addEventHandler ("onDgsMouseClickUp", Panel, 
        function( btn, _,_,_, clickCoolDown ) -- clickCoolDown анти-флуд
        if btn ~= "left" then return end 
        
        if source == btnAccept then
            if checkValidInput( ) then
                local bool, tNewData = checkValidInput( )
                if tModal.status == STATUS_UPDATE and isElement( tInterface.list ) and getSelectListRow( ) then
                    local oldNick, oldFmily, oldCity = unpack( tNewData )
                    local idSelectUser, nick, family, city = unpack( getSelectListRow( ))
                    if oldNick == nick and oldFmily == family and oldCity == city then
                        setErrorMenuVisible( true, 'Вы ничего не поменяли' )
                        return
                    end 
                    triggerServerEvent( 'crud:updateUser', resourceRoot, tNewData, tonumber( idSelectUser ) )
                    setModalWindowVisible( false )
                    setErrorMenuVisible( false )
                elseif tModal.status == STATUS_CREATE then
                    triggerServerEvent( 'crud:addNewUser', resourceRoot, tNewData )  
                    setModalWindowVisible( false )
                    setErrorMenuVisible( false )
                end 
            end 
        elseif source == btnDelete and getSelectListRow( ) then
            local idSelectUser = unpack( getSelectListRow( ))
            setErrorMenuVisible( true, " Вы действительно желаете удалить пользователя?", 
                function( bool ) 
                    if bool then 
                        triggerServerEvent( 'crud:DeleteUser', resourceRoot, tonumber( idSelectUser ) )
                        setErrorMenuVisible( false )
                    end 
                end
            )
        end 
    end)
end 

-- Вкл/Выкл модального окна настройки 
function setModalWindowVisible( state, status )
    if state then
		if not isElement( modalPanel ) then
			initModalWindow()
		end
	end
    if not isElement( modalPanel ) then return end
    local isMainVisible = isMainMenuVisible( )

    showCursor( isMainVisible and true 
                or ( not state and isMainVisible and true ) 
                or ( not state and not isMainVisible and false ) 
                or state and true 
                or false )

    
    tModal.status = status
    local newText = status == STATUS_CREATE and ' Добавить пользователя ' or ' Сохранить '

    if status == STATUS_CREATE then -- Если это создание > прячем кнопку удалить
        dgsSetVisible( tModal.accDel, false )
    else
        dgsSetVisible( tModal.accDel, true )
    end 
    dgsBringToFront( modalPanel ) 
    dgsSetText( tModal.accBtn, newText )
	dgsSetVisible( modalPanel, state )
end 


-- Окно ошибки
local function initErrorMenu( text, callback )
    if isElement( errorPanel ) then return end 
    local Panel = dgsCreateWindow( 0.38, 0.33, 0.25, 0.3, "Уведомление", true)
    errorPanel = Panel

    addEventHandler("onDgsWindowClose", Panel, 
        function( ) 
            if source == Panel then 
                if callback then 
                    callback( false )
                end     
            end 
        end
    )
    local label = dgsCreateLabel( 0.05, 0.1, 0.95, 0.5, text, true, Panel )
    dgsSetProperty( label, "alignment", {"center","top"} )
    dgsSetProperty( label, "wordBreak", true) 
    
    local accept = false 

    if callback then     
        accept = dgsCreateButton ( 0.2, 0.65, 0.6, 0.2, "Подтверждаю", true, label )
    end 

    local cancel = dgsCreateButton ( 0.2, 0.89, 0.6, 0.2, "Закрыть", true, label )
    

    addEventHandler ("onDgsMouseDown", Panel, 
        function( btn ) 
            if btn ~= "left" then return end 
            if source == cancel or source == accept then
                if callback then 
                    callback( source == accept and true or false )
                end
                setErrorMenuVisible( false )
            end 
        end
    )
end



function setErrorMenuVisible( state, text, callback )
    if isMainMenuVisible() then 
        if isElement( errorPanel ) then
            destroyElement( errorPanel )
        end 
        if state then
	    	if not isElement( errorPanel ) then
	    		initErrorMenu( text, callback )
	    	end
	    end
        if not isElement( errorPanel ) then return end
        dgsBringToFront( errorPanel )
	    dgsSetVisible( errorPanel, state )
        showCursor( state )
    end
end 

addEvent( "crud:setVisibleWarning", true )
addEventHandler( "crud:setVisibleWarning", localPlayer, setErrorMenuVisible )











