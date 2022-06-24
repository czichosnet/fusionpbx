-- callcenter-announce-position.lua
-- Announce queue position to a member in a given mod_callcenter queue.
-- Arguments are, in order: caller uuid, queue_name, interval (in milliseconds).
api = freeswitch.API()
caller_uuid = argv[1]
queue_name = argv[2]
mseconds = argv[3]
if caller_uuid == nil or queue_name == nil or mseconds == nil then
    return
end
while (true) do
    -- Pause between announcements
    freeswitch.msleep(mseconds)
    members = api:executeString("callcenter_config queue list members "..queue_name) 
    pos = 1
    exists = false
    for line in members:gmatch("[^\r\n]+") do
        if (string.find(line, "Trying") ~= nil or string.find(line, "Waiting") ~= nil) then
            -- Members have a position when their state is Waiting or Trying
            if string.find(line, caller_uuid, 1, true) ~= nil then
                -- Member still in queue, so script must continue
                exists = true

                

                local queueCount = api:executeString("callcenter_config queue count members "..queue_name)

                position = #queueCount - pos 

                if position < 0 then 
                    position = 0
                end 

                if position > 10 then 
                    api:executeString("uuid_broadcast "..caller_uuid.." /var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/sr-ivr-callcenterPosition.wav aleg")
                    api:executeString("uuid_broadcast "..caller_uuid.." /var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/10+.wav aleg")
--                    api:executeString("uuid_broadcast "..caller_uuid.." /var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/sr-forAbPressOne.wav aleg")
		    api:executeString("uuid_broadcast "..caller_uuid.." /var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/Anzahl_ohne_AB.wav aleg")
                else
                    api:executeString("uuid_broadcast "..caller_uuid.." /var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/sr-ivr-callcenterPosition.wav aleg")
                    api:executeString("uuid_broadcast "..caller_uuid.." /var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/"..position..".wav aleg")
--                    api:executeString("uuid_broadcast "..caller_uuid.." /var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/sr-forAbPressOne.wav aleg")
		    api:executeString("uuid_broadcast "..caller_uuid.." /var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/Anzahl_ohne_AB.wav aleg")
                end 
            
                
            end
            pos = pos+1
        end
    end
    -- If member was not found in queue, or it's status is Aborted - terminate script
    if exists == false then
        return
    end
end
