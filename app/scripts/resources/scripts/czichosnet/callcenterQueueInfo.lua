local api = freeswitch.API()
local queueCount = api:executeString("callcenter_config queue count members e013c5f4-a6f2-459f-a69e-49edb9342441")
session:answer();


session:consoleLog("info", "QueCount:" .. queueCount..".");

session:sleep("1000");

if tonumber(queueCount) > 10 then 
    session:read(0,0,"/var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/10+",200, "#");
else
    session:read(0,0,"/var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/" .. tonumber(queueCount) .. ".wav",200, "#");
end


session:hangup("NORMAL_CLEARING");