
session:consoleLog("info","BusyCheck");
domain = argv[1];
username = argv[2];
context = argv[1];

myCalls = {}
session:setAutoHangup(false)
local g_dbh = freeswitch.Dbh("sqlite://core")
local sqlString = "select count(*) as count from channels where presence_id = '".. username .."@".. domain .."'";

local result = g_dbh:query(sqlString,function(row)
    table.insert(myCalls,row); end)
session:consoleLog("info","Count = ".. myCalls[1].count);

if tonumber(myCalls[1].count) > 1 then 
    session:consoleLog("info","ACHTUNG!!!!!!!!!!!!!!!!!! BUSY CHECK ÜBERPRÜFEN");
end

if tonumber(myCalls[1].count) > 0 then 
    session:consoleLog("info","Besetzt");
    session:hangup("USER_BUSY")
end   
   
   
    