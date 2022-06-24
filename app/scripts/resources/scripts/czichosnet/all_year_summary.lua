--set default variables

debug["sql"] = true;

--general functions
require "resources.functions.trim";

--connect to the database
local Database = require "resources.functions.database";
dbh = Database.new('system');

sqlite3dbh = freeswitch.Dbh("sqlite://callcenter")

callcenterLogsdbh = freeswitch.Dbh("sqlite://callcenterLogs")

--include json library
local json = require "resources.functions.lunajson"

local ONE_DAY = 60*60*24;

--set the api
api = freeswitch.API();

--get the argv values

-- callcenter uuid : e013c5f4-a6f2-459f-a69e-49edb9342441

-- generates Stats for the last 5 days of a given Callcenter 

callcenter_uuid = "e013c5f4-a6f2-459f-a69e-49edb9342441";
email = argv[2];
startDate = argv[3];
local timestamp = 1647244800
domain_name = "vdk-bb-hq.realyzer.net"









function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

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

function getTimeStamps(startDate)

      local dateInformation = mysplit(startDate,"/");
      local myDay = tonumber(dateInformation[2]);
      local myMonth = tonumber(dateInformation[1]);
      local myYear = tonumber("20"..dateInformation[3]);

      local startTimestamp = os.time({year = myYear,month = myMonth,day=myDay})

      


end


function getWaitingTime(callflow)

   if  (callflow[3] == nil) then 

      return math.ceil( (tonumber(callflow[1]["times"]["bridged_time"])-tonumber(callflow[2]["times"]["transfer_time"]))/1000000) 

   end 
   

   if (callflow[2] == nil  ) then 
      freeswitch.consoleLog("Info", "CallflowWatingTime: ".. dump(callflow))
      return math.ceil( (tonumber(callflow["times"]["bridged_time"])-tonumber(callflow["times"]["transfer_time"]))/1000000) 

   end

   return math.ceil( (tonumber(callflow[2]["times"]["transfer_time"])-tonumber(callflow[3]["times"]["transfer_time"]))/1000000) 

   

end 


function getTimeTalked(callflow)


   for i=#callflow,0,-1 do 

      if tonumber(callflow[i]["times"]["bridged_time"]) ~= 0 then 

         --freeswitch.consoleLog("Info", "Test: ".. (0 or "Hello"));


         local startTime = tonumber(callflow[i]["times"]["bridged_time"])

         if (tonumber(callflow[i]["times"]["hangup_time"]) ~= 0) then 

               endTime = tonumber(callflow[i]["times"]["hangup_time"])
         else 

               endTime = tonumber(callflow[i]["times"]["transfer_time"])
         end

      
         --local endTime = tonumber(callflow[i]["times"]["hangup_time"]) ~= 0 ? tonumber(callflow[i]["times"]["hangup_time"]) : tonumber(callflow[i]["times"]["transfer_time"])

         if ((endTime-startTime)/1000000 < 0) then 

            freeswitch.consoleLog("Info", "BuggedEntry: "..dump(callflow[i]));
            

         end

         return math.ceil((endTime-startTime)/1000000)


      end 


   end 


   return 0
end

function getHour(callflow)

   local answered_time;

   if (callflow[1] == nil ) then 

      answered_time = tonumber(callflow["times"]["created_time"]/1000000)

   else

      answered_time = tonumber(callflow[1]["times"]["created_time"]/1000000)

   end 

   --freeswitch.consoleLog("Info", "Answered_Time: "..answered_time);
   --freeswitch.consoleLog("Info", "CallflowAnswereTime: ".. dump(callflow))


   return os.date("%H",math.ceil(answered_time))

end

function handleCall(calls,callflow, datetime)

   local timeWatied = getWaitingTime(callflow)
   local timeTalked = getTimeTalked(callflow)
   local parsed_datetime = os.date('*t', datetime)


   calls[parsed_datetime.hour]["talked"] = calls[parsed_datetime.hour]["talked"] + timeTalked
   calls[parsed_datetime.hour]["waited"] = calls[parsed_datetime.hour]["waited"] + timeWatied

end 





       
function getCallStats(dayTimeStamp)

   calls = {}

   for i=0,23 do
      calls[i] = {}
      calls[i].count = 0
      calls[i].talked = 0
      calls[i].waited = 0
      calls[i].avgTalked = 0
      calls[i].avgWaited = 0
   end 

   local callflow;

   local sql = "SELECT json, start_epoch FROM v_xml_cdr ";
      sql = sql .. "WHERE domain_name = :domain_name ";
      --sql = sql .. "AND caller_destination = :caller_destination ";
      sql = sql .. "AND bridge_uuid is not null AND start_epoch > :timestamp AND start_epoch < :timestampNextDay AND cc_queue = :cc_queue AND cc_agent IS NOT NULL "
      sql = sql .. "ORDER BY start_epoch "
      local params = {domain_name = "vdk-bb-hq.realyzer.net", cc_queue = callcenter_uuid, timestamp = dayTimeStamp, timestampNextDay = dayTimeStamp+ONE_DAY};
   
      freeswitch.consoleLog("notice", "[call_center] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");

      

      dbh:query(sql, params, function(row)
         -- For every Call 
         callflow = json.decode(row["json"])["callflow"]


         handleCall(calls,callflow, row['start_epoch'])
      end)

      dayTimeStamp = dayTimeStamp
      for i = 0,23,1 do 

         local hour = math.fmod(8+i,24)

         
         calls[hour]["answeredCalls"] = getAnsweredCallCount(dayTimeStamp)
         calls[hour]["abondesCakks"] = getAbondetCallCount(dayTimeStamp)
         calls[hour]["callsSendToVoicemail"] = getCallsOnVoicemail(dayTimeStamp)
         calls[hour]["callsLeftVoicemail"] = getCallsLeftVoicemail(dayTimeStamp)
         if calls[hour]["answeredCalls"] ~= 0 then 
   
            calls[hour].avgTalked = calls[hour].talked / calls[hour]['answeredCalls']
            calls[hour].avgWaited = calls[hour].waited / calls[hour]['answeredCalls']
   
         end


         dayTimeStamp = dayTimeStamp + 60 * 60
      end 

      return calls


end

function getAnsweredCallCount(dayTimeStamp)

   count = 0


   local sql = "SELECT count(*) FROM v_xml_cdr ";
   sql = sql .. "WHERE domain_name = :domain_name ";
   --sql = sql .. "AND caller_destination = :caller_destination ";
   sql = sql .. "AND bridge_uuid is not null AND cc_queue = :cc_queue  AND start_epoch > :timestamp AND start_epoch < :timestampnextday AND cc_agent IS NOT NULL"
   local params = {domain_name = "vdk-bb-hq.realyzer.net", cc_queue = callcenter_uuid, timestamp = dayTimeStamp, timestampnextday = dayTimeStamp+60*60};

   freeswitch.consoleLog("notice", "[call_center] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");

   

   dbh:query(sql, params, function(row)
      -- For every Call 
      count = row["count"]
   end)

   return count

end 

function getAbondetCallCount(dayTimeStamp)

   count = 0


   local sql = "SELECT count(*) FROM v_xml_cdr ";
   sql = sql .. "WHERE domain_name = :domain_name ";
   --sql = sql .. "AND caller_destination = :caller_destination ";
   sql = sql .. "AND cc_queue_joined_epoch is not null AND start_epoch > :timestamp AND start_epoch < :timestampnextday AND cc_queue = :cc_queue AND caller_destination IS NOT NULL AND bridge_uuid IS NULL AND cc_cancel_reason = 'BREAK_OUT'"

   local params = {domain_name = "vdk-bb-hq.realyzer.net", cc_queue = callcenter_uuid, timestamp = timestamp, timestamp = dayTimeStamp, timestampnextday = dayTimeStamp+3600};

   freeswitch.consoleLog("notice", "[call_center] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");

   

   dbh:query(sql, params, function(row)
      -- For every Call 
      count = row["count"]
   end)

   return count

end 

function getCallsOnVoicemail(dayTimeStamp)

   count = 0


   local sql = "SELECT count(*) FROM v_xml_cdr ";
   sql = sql .. "WHERE domain_name = :domain_name ";
   --sql = sql .. "AND caller_destination = :caller_destination ";
   sql = sql .. "AND cc_queue_joined_epoch is not null AND start_epoch > :timestamp AND start_epoch < :timestampnextday AND cc_queue = :cc_queue AND caller_destination IS NOT NULL AND bridge_uuid IS NULL AND cc_cancel_reason = 'EXIT_WITH_KEY'"

   local params = {domain_name = "vdk-bb-hq.realyzer.net", cc_queue = callcenter_uuid, timestamp = timestamp, timestamp = dayTimeStamp, timestampnextday = dayTimeStamp+3600};

   freeswitch.consoleLog("notice", "[call_center] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");

   

   dbh:query(sql, params, function(row)
      -- For every Call 
      count = row["count"]
   end)

   return count

end 

function getCallsLeftVoicemail(dayTimeStamp)

   count = 0


   local sql = "SELECT count(*) FROM v_xml_cdr ";
   sql = sql .. "WHERE domain_name = :domain_name ";
   --sql = sql .. "AND caller_destination = :caller_destination ";
   sql = sql .. "AND cc_queue_joined_epoch is not null AND start_epoch > :timestamp AND start_epoch < :timestampnextday AND cc_queue = :cc_queue AND caller_destination IS NOT NULL AND bridge_uuid IS NULL AND cc_cancel_reason = 'EXIT_WITH_KEY' AND voicemail_message = true"

   local params = {domain_name = "vdk-bb-hq.realyzer.net", cc_queue = callcenter_uuid, timestamp = timestamp, timestamp = dayTimeStamp, timestampnextday = dayTimeStamp+3600};

   freeswitch.consoleLog("notice", "[call_center] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");

   

   dbh:query(sql, params, function(row)
      -- For every Call 
      count = row["count"]
   end)

   return count

end 

function getAgentIDs(agents,contactString)

   
   local start = string.find(contactString,"/")

   local stop = string.find(contactString,"@")

   local agent_id = string.sub(contactString,start+1,stop-1)

   table.insert(agents,#agents +1,tostring(agent_id))


end

function getAgents()

   local agents = {}

   local sqlString = "select contact from tiers t, agents a where t.queue = '"..callcenter_uuid.."' AND t.agent = a.name;"

	freeswitch.consoleLog("notice", sqlString);

		sqlite3dbh:query(sqlString, function(row)

         --freeswitch.consoleLog("notice", "FoundContact: " .. row["contact"] );
         getAgentIDs(agents,row["contact"])

		end)
      
      return agents
end


function getCallsPerAgent(agents,dayTimeStamp)

   
   agentCounts = {}


   for i = 1,#agents,1 do 


      local sqliteString = "select name from agents a , tiers t where a.name = t.agent AND t.queue = '"..callcenter_uuid.."' and contact like '%"..agents[i].."@"..domain_name.."%'"

      sqlite3dbh:query(sqliteString, function(row)

         local agentName = row["name"]

         --freeswitch.consoleLog("notice", "FoundName: " .. agentName );
         
         local sql = "SELECT count(*) FROM v_xml_cdr ";
         sql = sql .. "WHERE domain_name = :domain_name AND cc_agent = :cc_agent AND cc_queue =:cc_queue AND start_epoch > :timestamp AND start_epoch < :timestampnextday AND bridge_uuid IS NOT NULL";
        
         local params = {domain_name = "vdk-bb-hq.realyzer.net", cc_queue = callcenter_uuid, timestamp = dayTimeStamp, timestampnextday = dayTimeStamp+ONE_DAY, cc_agent = agentName};

         --freeswitch.consoleLog("notice", "[call_center] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");


         dbh:query(sql, params, function(row)
            -- For every Call 
            count = row["count"]
            freeswitch.consoleLog("notice", "Agent: " .. agents[i] .. " Calls: " .. count);
            agentCounts[agents[i]] = {}
            agentCounts[agents[i]]["count"] = count
            agentCounts[agents[i]]["onlineTime"] = 0
            

         end)



      end)

   end 

   return agentCounts


end



function calculateOnlineTimePerDay(agent,date,timesTable)

   -- Add Logout Time at end of the Shift if needed.



   freeswitch.consoleLog("INFO",dump(timesTable))

   if math.fmod(#timesTable,2) ~= 0 then
      
      local logoutTime = 0;

      if (date.wday == 2 or date.wday == 4 or date.wday == 6) then 

         logoutTime = os.time{year=date.year, month=date.month, day=date.day, hour=15, min=0}

      else

         logoutTime = os.time{year=date.year, month=date.month, day=date.day, hour=17, min=30}

      end

      
      timesTable[#timesTable+1] = {["action"]="logout",["epoch"]=logoutTime}

      freeswitch.consoleLog("notice", "Logout Added");

   end 


   freeswitch.consoleLog("notice", "HandleDay: Agent: ".. agent .. "Day: " .. os.date('%d.%m.%Y', os.time(date)) .. " timesTable: " .. dump(timesTable));


   -- calculate Online Time from timesTable 


   local onlineTime = 0

   for i = 1 ,#timesTable/2,2 do 

      onlineTime = onlineTime + (tonumber(timesTable[i]["epoch"]) - tonumber(timesTable[i+1]["epoch"])) * -1;

   end

   -- chnage Time to Minutes 

   onlineTime = math.ceil(onlineTime / 60)

   
   freeswitch.consoleLog("notice", "OnlineTime: ".. onlineTime );
   return onlineTime

   

   
end

--function calculateTimesPerDay(agentData,agentTimes)

  

--      for day,actionList in pairs(dayList) do 

         
--         calculateOnlineTimePerDay(statsCurrentDay[agent],agent,day,actionList);

--      end 

--   end 

   
--end 


function handleTimeEntry(rowElement,agentTimes)


   local date = os.date("%x",rowElement["epoch"]) 

   --freeswitch.consoleLog("notice", "RowElement: ".. dump(rowElement));

   if agent ~= startAgent then 

      startAgent = agent

      agentTimes[agent] = {}

      

      startDate = date

      agentTimes[agent][date] = {}
          
      

      table.insert(agentTimes[agent][date],{action = rowElement["action"],epoch = rowElement["epoch"] })
      

   else

      if date ~= startDate then 

         startDate = date

         agentTimes[agent][date] = {} 
         
      end
      
      table.insert(agentTimes[agent][date],{action = rowElement["action"],epoch = rowElement["epoch"] })
      
      
   end 



end



function getOnlineTimePerAgentPerHour(statsCurrentDay,dayTimeStamp)

   local timestampNextDay = dayTimeStamp + ONE_DAY
   
   
   for agent, data in pairs(statsCurrentDay) do 
      
      if (agent ~= 'date') then
         local agentTimes = {}

         -- gather agent times per day per agent
         local sqlite3String = "select agent_id, epoch, action from statusChanges where epoch > "..dayTimeStamp .." AND epoch < ".. timestampNextDay .." AND agent_id = '"..agent .."'"

         callcenterLogsdbh:query(sqlite3String, function(row)

            table.insert(agentTimes, {action = row['action'], epoch = row['epoch']})

         end)
            
         data['onlineTime'] = calculateOnlineTimePerDay(agent, statsCurrentDay['date'], agentTimes)
      end
   end 

end 

function getHourlyStats(dayTimeStamp)
 
   count = 0


   local sql = "SELECT count(*) FROM v_xml_cdr ";
   sql = sql .. "WHERE domain_name = :domain_name ";
   --sql = sql .. "AND caller_destination = :caller_destination ";
   sql = sql .. "AND cc_queue_joined_epoch is not null AND start_epoch > :timestamp AND start_epoch < :timestampnextday AND cc_queue = :cc_queue AND caller_destination IS NOT NULL AND bridge_uuid IS NULL AND cc_cancel_reason = 'EXIT_WITH_KEY' AND voicemail_message = true"
   sql = sql .. "GROUP BY DATEPART(hour,epoch) ";
   local params = {domain_name = "vdk-bb-hq.realyzer.net", cc_queue = callcenter_uuid, timestamp = timestamp, timestamp = dayTimeStamp, timestampnextday = dayTimeStamp+ONE_DAY};

   freeswitch.consoleLog("notice", "[call_center] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");

   

   dbh:query(sql, params, function(row)
      -- For every Call 
      count = row["count"]
   end)

   return count



end 

local agents = getAgents()

local callStatsWeek = {}
local agentStatsWeek = {}

local systemTime = os.date("*t",os.time())

systemTime.hour = 8
systemTime.minute = 0
systemTime.second = 0

local mondayTimeStamp = os.time(systemTime)

mondayTimeStamp = mondayTimeStamp - ((systemTime.wday-2)%7) * ONE_DAY

-- this overrides default behaviour
mondayTimeStamp = 1649656800

for i=1,5,1 do 

   -- getCallStatsPerWeekAndDay
   callStatsWeek[i] = {}
   callStatsWeek[i]["stats"] = getCallStats(mondayTimeStamp)
   --callStatsWeek[i]["answeredCalls"] = getAnsweredCallCount(mondayTimeStamp)
   --callStatsWeek[i]["abondesCakks"] = getAbondetCallCount(mondayTimeStamp)
   --callStatsWeek[i]["callsSendToVoicemail"] = getCallsOnVoicemail(mondayTimeStamp)
   --callStatsWeek[i]["callsLeftVoicemail"] = getCallsLeftVoicemail(mondayTimeStamp)
   callStatsWeek[i]["date"] = os.date("*t",mondayTimeStamp)
   
   agentStatsWeek[i] = getCallsPerAgent(agents,mondayTimeStamp)
   agentStatsWeek[i]["date"] = os.date("*t",mondayTimeStamp)

   getOnlineTimePerAgentPerHour(agentStatsWeek[i],mondayTimeStamp)

   --getAgentsOnlineTime(agents,mondayTimeStamp)

   mondayTimeStamp = mondayTimeStamp + ONE_DAY
   
end 

freeswitch.consoleLog("INFO",dump(agentStatsWeek))
freeswitch.consoleLog("INFO",dump(callStatsWeek))

local evaluationTime = os.time()

-- this overrides default behaviour
evaluationTime = 1650045600

local file = assert(io.open("/opt/callcenterevaluation/CALLS-"..callcenter_uuid .."-TIME-" .. os.date('%d.%m.%Y',evaluationTime) ..".csv","w+"))


file:write("Jahr,Monat,Tag,Stunde,Durchschittliche Wartezeit,Durchschnittliche Gesprächsdauer,Anzahl Anrufe,Angenommene Anrufe,Nachrichten auf Voicemail,Anrufer aufgelegt,Anrufe zur Voicemail gesendet\n")
for day,data in pairs(callStatsWeek) do 

   for hour,hourDate in pairs(data["stats"]) do 

      file:write(data["date"].year,",")
      file:write(data["date"].month,",")
      file:write(data["date"].day,",")
      file:write(hour,",")
      file:write(math.ceil(hourDate["avgWaited"]),",")
      file:write(math.ceil(hourDate["avgTalked"]),",")
      file:write(hourDate["answeredCalls"]+hourDate["abondesCakks"]+hourDate["callsSendToVoicemail"],",")
      --file:write(hourDate['count'],',')
      file:write(hourDate["answeredCalls"],",")
      file:write(hourDate["callsLeftVoicemail"],",")
      file:write(hourDate["abondesCakks"],",")
      file:write(hourDate["callsSendToVoicemail"],",")
      file:write("\n")
   end 


end 

file.close()


local file2 = assert(io.open("/opt/callcenterevaluation/AGENTS-"..callcenter_uuid .."-TIME-" ..  os.date('%d.%m.%Y',evaluationTime) ..".csv","w+"))

file2:write("Jahr,Monat,Tag,Agent,Angenommene Anrufe, Angemeldete Zeit\n")

for day,agentList in pairs(agentStatsWeek) do 

   for agent,agentData in pairs(agentList) do 

      if (agent ~= "date") then 

      file2:write(agentList["date"].year,",")
      file2:write(agentList["date"].month,",")
      file2:write(agentList["date"].day,",")
      file2:write(agent,",")
      file2:write(agentData["count"],",")
      file2:write(agentData["onlineTime"],",")
      file2:write("\n")

      end 

      
   end 


end 

file2.close()






--freeswitch.consoleLog("Info", dump(callStatsWeek[1]));





--freeswitch.consoleLog("Info", dump(getCallStats(timestamp)));

-- Callcenter Stats
 --getCallStats()
 --freeswitch.consoleLog("notice", "Answered Calls: "..answeredCalls);
 --freeswitch.consoleLog("notice", "Abondet Calls: "..abondetCalls);
 --freeswitch.consoleLog("notice", "CallsOnVoicemailWithoutVoicemail: "..callsSendToVoicemail-callsLeftVoicemail);
 --freeswitch.consoleLog("notice", "VoicemailsLeft: "..callsLeftVoicemail);
 --freeswitch.consoleLog("Info", dump(calls));

-- Agent Stats
-- CallCount

--getAgentsOnlineTime()
--freeswitch.consoleLog("notice", "agents: ".. dump(agentTimes));
--getCallsPerAgent()
--freeswitch.consoleLog("notice", dump(agentCounts))
--freeswitch.consoleLog("notice", getOnlineTimePerAgentPerHour(agents))
--freeswitch.consoleLog("notice", dump(callStatsWeek))


dbh:release()
sqlite3dbh:release()







-- DB Query
--local params = {domain_uuid = domain_uuid, agent_id = agent_id}
--local sql = "SELECT * FROM v_call_center_agents ";
--sql = sql .. "WHERE domain_uuid = :domain_uuid ";

--if (debug["sql"]) then
--    freeswitch.consoleLog("notice", "[user status] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
--end

-- Execute fs_cli command
--cmd = "sched_api +5 none callcenter_config agent set status "..agent_uuid.." '"..status.."'";
--freeswitch.consoleLog("notice", "[user status][login] "..cmd.."\n");
--result = api:executeString(cmd);

