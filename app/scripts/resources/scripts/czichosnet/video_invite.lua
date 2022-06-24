local sms = argv[1] or 'all';

freeswitch.consoleLog("info", message:serialize());

function mysplit (inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

local body = message:getBody();
local split = mysplit(body, "\n");
local conf = table.remove(split, 1);


for k, v in pairs(split) do
    local who = mysplit(v, "@"); 
    local e = freeswitch.Event("NOTIFY");
    e:addHeader("profile", "internal");
    e:addHeader("content-type", "application/simple-message-summary");
    e:addHeader("event-string", "conference.invite");
    e:addHeader("user", who[1]);
    e:addHeader("host", who[2]);
    e:addBody(message:getHeader("from") .. "#$#" .. conf);
    freeswitch.consoleLog("info", e:serialize());
    e:fire();
end


