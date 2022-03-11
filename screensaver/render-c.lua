math.randomseed(getTickCount())
local xScreen,yScreen = guiGetScreenSize()


local function setRandomColor()
    return tocolor( math.random(1, 255), math.random(1, 255), math.random(1, 255) )
end

-- Рандомная точка в указанном пространстве
local function randomPoint( x, y, w, h, size)
    math.randomseed( getTickCount()  )
    if not ( x + size[1] <  w - size[1]) 
    or not (y + size[2] < h - size[2]) then
        error('Неправильно заданы размеры для размещения DVD (Размеры картинки больше зоны рендера)')
        return false 
    end 
    return math.random( x + size[1], w - size[1] ), math.random( y + size[2], h - size[2] )
end 

local function checkInvalidParams( i, tbl, needArg )
    assert( type( tbl ) == 'table', string.format('function DVD argument %d is not table', i or 1)  )
    assert( #tbl == 4, string.format('function DVD argument %d, the table must contain %d arguments', i or 1, needArg)  )
    for k, v in pairs( tbl ) do
        assert( type( v ) == 'number', string.format('function DVD is not number = argument %d tbl[%s] = %s ', i or 1, k, tostring(v))  )
    end
    return true
end 

-- Размеры зоны, размеры фотки, скорость
local function createScreensaver( arenaLimit, size, texture, speed )
    local speed = speed or 10
    local params = { arenaLimit, size, speed }
    -- или #params
    assert(select('#', unpack(params)) >= 2, 'function DVD accepts at least 2 parameters' )

    --=========================== Проверка на ошибки ======================================================
    for i = 1, #params do
        checkInvalidParams( i, arenaLimit, i == 1 and 4 or 2 )
    end 

    --================================================================================================== 
	local data = {
        arenaLimit = arenaLimit, -- Лимиты зоны отрисовки
	    pos = { randomPoint( arenaLimit[1], arenaLimit[2], arenaLimit[3], arenaLimit[4], size) }; -- Рандомная позиция лого
        imgSize = size, -- размер image;
        vectorSpeed = { 
            x = math.random(0, 1) > 0 and -speed or speed, -- Рандом направление по вектору X
            y = math.random(0, 1) > 0 and -speed or speed,  -- Рандом направление по вектору Y
        },
        color = setRandomColor(), -- Рандом цвет
        texture = assert(dxCreateTexture( texture, "dxt5", true, "wrap" ), 'error create image'),
	}


    function data:updatePosition()
        self.pos[1] = self.pos[1] + self.vectorSpeed.x
        self.pos[2] = self.pos[2] + self.vectorSpeed.y
            
         --  Ограничения по X
        if (self.pos[1] + (self.imgSize[1])) >= self.arenaLimit[3] 
        or self.pos[1] <= self.arenaLimit[1] then
            self.color = setRandomColor()
            self.vectorSpeed.x = -self.vectorSpeed.x  
        end 
        --  Ограничения по Y
        if self.pos[2] + self.imgSize[2] >= self.arenaLimit[4] 
        or self.pos[2] <= self.arenaLimit[2] then
            self.color = setRandomColor()
            self.vectorSpeed.y = -self.vectorSpeed.y 
        end
    end 

    function data:drawLogo()                 
        dxDrawImage( self.pos[1], self.pos[2], self.imgSize[1], self.imgSize[2], self.texture, 0, 0, 0, self.color )
	end

    function data:termite()
        if self.texture and isElement( self.texture ) then 
            destroyElement( self.texture ) 
            self.texture = nil
        end 
    end 
    
  return data
end




local cache = {
    [1] = createScreensaver(
        {0, 0, xScreen/2, yScreen}, -- Размеры зоны
        { 400, 200 },  -- Размеры картинки
        "img/dvd.dds",
        1 -- Скорость по двум осям
    ); 
    [2] = createScreensaver(
        { xScreen/2, 0, xScreen, yScreen },
        { 400, 200 },
        "img/dvd.dds",
        1
    )
}


local function render()
    if cache and type( cache ) == 'table'  then 
        for k,v in pairs( cache ) do
            v:drawLogo()
            v:updatePosition()
        end
    end
end 

addEventHandler( "onClientResourceStart", resourceRoot,
    function ( )
        addEventHandler( "onClientRender", root, render)
    end
);



addEventHandler( "onClientResourceStop", resourceRoot,
    function( )
        removeEventHandler( "onClientRender", root, render)
        if cache and type( cache ) == 'table'  then 
            for k,v in pairs( cache ) do
                v:termite()
            end
        end
        cache = nil
    end
)





