local api = freeswitch.API()
local queueCount = api:executeString("callcenter_config queue count members e8a5a39d-1582-439a-a084-fc11da86eb9b")


if tonumber(queueCount) > 8 then 
    session:answer();
    session:sleep("1000");
    session:read(0,0,"/var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/offeneSprechstundeVoll.wav",200, "#");
    session:hangup("USER_BUSY");
end



