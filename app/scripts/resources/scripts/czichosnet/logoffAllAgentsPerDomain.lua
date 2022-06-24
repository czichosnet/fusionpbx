--set default variables

debug["sql"] = true;

--general functions
require "resources.functions.trim";

--connect to the database
local Database = require "resources.functions.database";
dbh = Database.new('system');

--include json library
local json
if (debug["sql"]) then
    json = require "resources.functions.lunajson"
end

local presence_in = require "resources.functions.presence_in"

--set the api
api = freeswitch.API();

--get the argv values

domain_uuid = argv[1];
domain_name = argv[2];
context = argv[2];

agent_authorized = 'true';

function LogOffAgent(agent_id,user_uuid,agent_uuid,agent_name)
    action = "logout";
    status = 'Logged Out';
                
        --send a login or logout to mod_callcenter
            cmd = "sched_api +5 none callcenter_config agent set status "..agent_uuid.." '"..status.."'";
            freeswitch.consoleLog("notice", "[user status][login] "..cmd.."\n");
            result = api:executeString(cmd);

        --update the user status
            if (user_uuid ~= nil and user_uuid ~= '') then
                local sql = "SELECT user_status FROM v_users ";
                sql = sql .. "WHERE user_uuid = :user_uuid ";
                sql = sql .. "AND domain_uuid = :domain_uuid ";
                local params = {user_uuid = user_uuid, domain_uuid = domain_uuid};
                if (debug["sql"]) then
                    freeswitch.consoleLog("notice", "[call_center] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
                end
                dbh:query(sql, params, function(row)

                    --set the user_status in the users table
                        local sql = "UPDATE v_users SET ";
                        sql = sql .. "user_status = :status ";
                        sql = sql .. "WHERE user_uuid = :user_uuid ";
                        local params = {status = status, user_uuid = user_uuid};
                        if (debug["sql"]) then
                            freeswitch.consoleLog("notice", "[call_center] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
                        end
                        dbh:query(sql, params);
                end);
            end

        --set the presence to terminated - turn the lamp off:
            
            event = freeswitch.Event("PRESENCE_IN");
            event:addHeader("proto", "sip");
            event:addHeader("event_type", "presence");
            event:addHeader("alt_event_type", "dialog");
            event:addHeader("Presence-Call-Direction", "outbound");
            event:addHeader("state", "Active (1 waiting)");
            event:addHeader("from", agent_name.."@"..domain_name);
            event:addHeader("login", agent_name.."@"..domain_name);
            event:addHeader("unique-id", agent_uuid);
            event:addHeader("answer-state", "terminated");
            event:fire();

            if (action == "login") then 
                blf_status = "false"
            end
            if string.find(agent_name, 'agent+', nil, true) ~= 1 then
                presence_in.turn_lamp( blf_status,
                    'agent+'..agent_name.."@"..domain_name
                );
            end			

    --send the status to the display
    --if (status ~= nil) then
    --    reply = api:executeString("uuid_display "..uuid.." '"..status.."'");
    --end

    
end



--get all Agents of the Domain
local params = {domain_uuid = domain_uuid, agent_id = agent_id}
local sql = "SELECT * FROM v_call_center_agents ";
sql = sql .. "WHERE domain_uuid = :domain_uuid ";

if (debug["sql"]) then
    freeswitch.consoleLog("notice", "[user status] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
end

dbh:query(sql, params, function(row)
    --Logg each Agent Off
        LogOffAgent(row.agent_id,row.user_uuid,row.call_center_agent_uuid,row.agent_name)    
end);

