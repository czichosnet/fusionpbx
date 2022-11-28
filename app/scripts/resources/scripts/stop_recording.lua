
coredbh = freeswitch.Dbh("sqlite://core")
callcenterdbh = freeswitch.Dbh("sqlite://callcenter")


local path = session:getVariable("record_path")
callcenter_uuid = argv[1]

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

function contains(list, x)
	for _, v in pairs(list) do
		if v == x then return true end
	end
	return false
end

 
function checkAgent(extension)
 
    local sqlString = "select uuid from tiers t, agents a where t.queue = '"..callcenter_uuid.."' AND t.agent = a.name AND contact like '%user/"..extension.."%';"
    local agentIsOkay = false
 
     freeswitch.consoleLog("notice", sqlString);
 
        callcenterdbh:query(sqlString, function(row)
 
                freeswitch.consoleLog("INFO", row.uuid);
                agentIsOkay = row ~= nil
               
         end)

    return agentIsOkay
 end

function stopRecording() 
local transfer_history = session:getVariable("transfer_history")

session:consoleLog("Info","transfer_history: "..transfer_history)

local transfers = mysplit(transfer_history,"|")

local lastTransfer = transfers[#transfers]

local _, _, channel_uuid = string.find(lastTransfer, 'uuid_br:([%x\\-]+)')

if (channel_uuid == nil) then 

    session:consoleLog("Info","No Channel ID")

    return

end




session:consoleLog("Info","Cannel_uuid"..channel_uuid)



local sqlString = "select uuid,callee_num from channels where uuid = '"..channel_uuid.."';"

	freeswitch.consoleLog("notice", sqlString);

        coredbh:query(sqlString, function(row)

            session:consoleLog("Info",row.callee_num)

            if (checkAgent(row.callee_num) == false) then

                session:consoleLog("Info","EndRecording")
                session:execute("stop_record_session",path)
                session:setVariable("effective_caller_id_name",session:getVariable("effective_caller_id_number"))

            end

		end)
end

function startRecording()

    callcenterLogsdbh = freeswitch.Dbh("sqlite://callcenterLogs")

    local caller_id_number = session:getVariable("sip_from_user")
    local epoch = tostring(os.time())
    local date = os.date("%Y",tonumber(epoch)).."-"..os.date("%m",tonumber(epoch)).."-"..os.date("%d",tonumber(epoch))..":"..os.date("%H",tonumber(epoch)).."-"..os.date("%M",tonumber(epoch));
    local target_callcenter = session:getVariable("target_callcenter");

    session:consoleLog("Info","caller_id_number"..caller_id_number)
    session:consoleLog("Info","epoch"..epoch)
    session:consoleLog("Info","date"..date)
    session:consoleLog("Info","target_callcenter"..target_callcenter)

    local sqlite3String = "INSERT INTO recordApproval(caller_id_number,epoch,date,callcenter) VALUES ('+"..caller_id_number.."','"..epoch.."','"..date.."','"..target_callcenter.."');"

    callcenterLogsdbh:query(sqlite3String, function(row)

    end)

    local record_path = "/var/lib/freeswitch/recordings/vdk-bb-hq.realyzer.net/"..session:getVariable("sip_from_user").."-Epoch-"..os.time()..".wav"
    --session:setVariable("recording_follow_transfer", "true");
    --session:setVariable("email_recordings_to", "jens.hoernke@vdk.de");
    --session:setVariable("email_recordings_subject", "Neue Aufnahme eines Calls von Anrufer:+" .. session:getVariable("caller_id_name") .." Zeit: " ..session:getVariable(strftime(%Y-%m-%d-%H-%M-%S)))
    --session:setVariable("email_recordings_delete_after", "true");
    session:setVariable("record_post_process_exec_app", "lua:email_recordings.lua "..record_path);
    session:setVariable("record_in_progress", "true");
    session:setVariable("record_start",os.time());
    session:setVariable("record_path",record_path)
    session:execute("record_session", record_path)

    callcenterLogsdbh:release()



end

local isRecording = session:getVariable("record_in_progress")
session:consoleLog("Info",isRecording)

if (isRecording == "true") then 

    stopRecording()

else


    startRecording()

end

--session:consoleLog("Info","Heheh")


--session:execute("send_display","Hello World")
coredbh:release()
callcenterdbh:release()
