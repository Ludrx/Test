BIND_KEY = 'L'

COLUMN_NAME = {
    "name";
    "surname";
    "city";
}

STATUS_CREATE, STATUS_UPDATE = 1, 2


RowPageSize = 20; -- Количество строк 
RenderList = 3; -- Количество страниц

AntiFlood = 500

function trim(s)
    if not s or type( s ) ~= "string" then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
 end
