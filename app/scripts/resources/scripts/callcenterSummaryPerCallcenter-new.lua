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
local ONE_HOUR = 60*60;

--set the api
api = freeswitch.API();

--get the argv values

-- callcenter SR : e013c5f4-a6f2-459f-a69e-49edb9342441

-- callcenter Potsdam : fc02bca3-ce6f-4795-a332-2280e783ba0a

-- callcenter SR Offen : e8a5a39d-1582-439a-a084-fc11da86eb9b

-- generates Stats for the last 5 days of a given Callcenter 

callcenter_uuid = argv[1];
domain_name = argv[2];
evalStartEpoch = argv[3];

function filter_inplace(arr, func)
   local new_index = 1
   local size_orig = #arr
   for old_index, v in ipairs(arr) do
       if func(v, old_index) then
           arr[new_index] = v
           new_index = new_index + 1
       end
   end
   for i = new_index, size_orig do arr[i] = nil end
end

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


function getAgentIDs(agents,contactString)

   
   local start = string.find(contactString,"/")

   local stop = string.find(contactString,"@")

   local agent_id = string.sub(contactString,start+1,stop-1)

   if (callcenter_uuid == "fc02bca3-ce6f-4795-a332-2280e783ba0a") then 
      agent_id = "9"..agent_id
   end

   freeswitch.consoleLog("Info","InsertedAgend:" .. agent_id)

   table.insert(agents,#agents +1,tostring(agent_id))


end

function getAgents()

   local agents = {}

   local sqlString = "select contact from tiers t, agents a where t.queue = '"..callcenter_uuid.."' AND t.agent = a.name;"

	freeswitch.consoleLog("notice", sqlString);

		sqlite3dbh:query(sqlString, function(row)

         freeswitch.consoleLog("notice", "FoundContact: " .. row["contact"] );
         getAgentIDs(agents,row["contact"])

		end)
      
      return agents
end


function getCallsPerAgent(agents,dayTimeStamp)

   
   agentCounts = {}


   for i = 1,#agents,1 do 

      local tempAgentString = string.sub(agents[i],-3)
      local sqliteString = "select name from agents a , tiers t where a.name = t.agent AND t.queue = '"..callcenter_uuid.."' and contact like '%"..tempAgentString.."@"..domain_name.."%'"

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
   local prevAction = "";

   function func(wert,index)

      
      if prevAction == wert["action"]then

         prevAction = wert["action"]

         return false

      end
      
      prevAction = wert["action"]

      return true

   end


   filter_inplace(timesTable,func)

   freeswitch.consoleLog("INFO",dump(timesTable))

   if math.fmod(#timesTable,2) ~= 0 then
      
      local logoutTime = 0;

      if (date.wday == 2 or date.wday == 4 or date.wday == 6) then 

         logoutTime = os.time{year=date.year, month=date.month, day=date.day, hour=15, min=0}

      else

         logoutTime = os.time{year=date.year, month=date.month, day=date.day, hour=17, min=30}

      end

      
      timesTable[#timesTable+1] = {["action"]="logout",["epoch"]=logoutTime}

      freeswitch.consoleLog("notice", "Logout Added "..agent);

   end 


   freeswitch.consoleLog("notice", "HandleDay: Agent: ".. agent .. "Day: " .. os.date('%d.%m.%Y', os.time(date)) .. " timesTable: " .. dump(timesTable));


   -- calculate Online Time from timesTable 


   local onlineTime = 0

   for i = 1 ,#timesTable,2 do 

      onlineTime = onlineTime + (tonumber(timesTable[i]["epoch"]) - tonumber(timesTable[i+1]["epoch"])) * -1;

   end

   -- chnage Time to Minutes 

   onlineTime = math.ceil(onlineTime / 60)

   
   freeswitch.consoleLog("notice", "OnlineTime: ".. onlineTime );
   return onlineTime

   

   
end


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


local agents = getAgents()


local agentStatsWeek = {}


local timestamp = os.time()

-- Aktueller Tag um 20 Uhr, Script wird freitags von einem cronjob ausgeführt.

local evaluationTime; 

if (evalStartEpoch == nil or evalStartEpoch == '') then
   evaluationTime = os.time({year=os.date("%Y",timestamp), month=os.date("%m",timestamp),day=os.date("%d",timestamp),hour=20,min=00,sec=00})
else 
   evaluationTime = os.time({year=os.date("%Y",evalStartEpoch), month=os.date("%m",evalStartEpoch),day=os.date("%d",evalStartEpoch),hour=20,min=00,sec=00})
end

freeswitch.consoleLog("Info","EvaluationTime:" .. evaluationTime)



mondayTimeStamp = evaluationTime - 4*ONE_DAY - 12*ONE_HOUR
finalMonday = mondayTimeStamp;

for i=1,5,1 do 

   
   agentStatsWeek[i] = getCallsPerAgent(agents,mondayTimeStamp)
   agentStatsWeek[i]["date"] = os.date("*t",mondayTimeStamp)

   getOnlineTimePerAgentPerHour(agentStatsWeek[i],mondayTimeStamp)

   mondayTimeStamp = mondayTimeStamp + ONE_DAY
   
end 

freeswitch.consoleLog("INFO",dump(agentStatsWeek))





local callcenter_name = "";

if (callcenter_uuid == "e013c5f4-a6f2-459f-a69e-49edb9342441") then 

   callcenter_name = "SR-Berlin"

elseif (callcenter_uuid == "fc02bca3-ce6f-4795-a332-2280e783ba0a") then 

   callcenter_name = "SR-Potsdam"

elseif (callcenter_uuid == "e8a5a39d-1582-439a-a084-fc11da86eb9b") then 

   callcenter_name = "SR-Berlin-Offen"

end

local filePath;

if (evalStartEpoch == nil or evalStartEpoch == '') then
   os.execute("mkdir -p " .. "/opt/callcenterevaluation/"..os.date('%Y-%m-%d',evaluationTime))
   filePath = "/opt/callcenterevaluation/"..os.date('%Y-%m-%d',evaluationTime).."/AGENTS-"..callcenter_name .."-TIME-"..os.date('%Y-%m-%d',evaluationTime)..".csv"
else 
   os.execute("mkdir -p " .. "/opt/callcenterevaluation/redo/"..os.date('%Y-%m-%d',evaluationTime))
   filePath = "/opt/callcenterevaluation/redo/"..os.date('%Y-%m-%d',evaluationTime).."/AGENTS-"..callcenter_name .."-TIME-"..os.date('%Y-%m-%d',evaluationTime)..".csv"
end



local agent_file = assert(io.open(filePath,"w+"))

agent_file:write("Jahr,Monat,Tag,Wochentag,Agent,Angenommene Anrufe, Angemeldete Zeit\n")

for day,agentList in pairs(agentStatsWeek) do 

   for agent,agentData in pairs(agentList) do 

      if (agent ~= "date") then 

         agent_file:write(agentList["date"].year,",")
         agent_file:write(agentList["date"].month,",")
         agent_file:write(agentList["date"].day,",")
         agent_file:write(tostring(tonumber(agentList["date"].wday)-1),",")
         agent_file:write(agent,",")
         agent_file:write(agentData["count"],",")
         agent_file:write(agentData["onlineTime"],",")
         agent_file:write("\n")

      end 

      
   end 


end 

agent_file.close()

--to (mandatory) a valid email address
--from (mandatory) a valid email address
--headers (mandatory) for example "subject: you've got mail!\n"
--body (optional) your regular mail body
--file (optional) a file to attach to your mail
--convert_cmd (optional) convert file to a different format before sending
--convert_ext (optional) to replace the file's extension

-- Create Call Stats


local sqlAgents = "SELECT " 
sqlAgents =   sqlAgents  .. "DATE_PART('day', to_timestamp(min(cc_queue_joined_epoch))) as \"Tag\","
sqlAgents =   sqlAgents  .. "DATE_PART('month', to_timestamp(min(cc_queue_joined_epoch))) as \"Monat\","
sqlAgents =   sqlAgents  .. "DATE_PART('year', to_timestamp(min(cc_queue_joined_epoch))) as \"Jahr\","
sqlAgents =   sqlAgents  .. "DATE_PART('hour', to_timestamp(min(cc_queue_joined_epoch)))+2 as \"Stunde\","
sqlAgents =   sqlAgents  .. "EXTRACT(DOW FROM to_timestamp(min(cc_queue_joined_epoch))) as \"Tag der Woche\","
sqlAgents =   sqlAgents  .. "COUNT(xml_cdr_uuid) as \"Anrufe Insgesamt\","
sqlAgents =   sqlAgents  .. "SUM(CASE WHEN cc_agent_bridged = 'true' THEN 1 ELSE 0 END) as \"Angenommene Anrufe\","
sqlAgents =   sqlAgents  .. "SUM(CASE WHEN cc_cancel_reason = 'BREAK_OUT' THEN 1 ELSE 0 END) as \"Abgebrochene Anrufe\","
sqlAgents =   sqlAgents  .. "SUM(CASE WHEN cc_cancel_reason = 'EXIT_WITH_KEY' THEN 1 ELSE 0 END) as \"Anrufe auf Voicemail\","
sqlAgents =   sqlAgents  .. "SUM(CASE WHEN cc_cancel_reason = 'EXIT_WITH_KEY' AND voicemail_message = true THEN 1 ELSE 0 END) as \"Nachricht auf Voicemail\","
sqlAgents =   sqlAgents  .. "COALESCE(CEIL(AVG(CASE WHEN cc_agent_bridged = 'true' THEN COALESCE(cc_queue_terminated_epoch, end_epoch) - cc_queue_answered_epoch ELSE null END)),0) as \"Durchschnittliche Gesprächsdauer\","
sqlAgents =   sqlAgents  .. "COALESCE(CEIL(AVG(CASE WHEN  cc_agent_bridged = 'true' THEN cc_queue_answered_epoch - cc_queue_joined_epoch ELSE null END)),0) as \"Durchschnittliche Wartezeit (ohne Ansage)\""
sqlAgents =   sqlAgents  .. "FROM v_xml_cdr" 
sqlAgents =   sqlAgents  .. " WHERE cc_queue_joined_epoch > :finalMonday AND cc_queue_joined_epoch < :evaluationTime AND domain_name = :domain_name AND cc_queue = :cc_queue AND cc_side = 'member'"
sqlAgents =   sqlAgents  .. " GROUP BY " 
sqlAgents =   sqlAgents  .. "DATE_PART('year', to_timestamp(cc_queue_joined_epoch)),"
sqlAgents =   sqlAgents  .. "DATE_PART('month', to_timestamp(cc_queue_joined_epoch)),"
sqlAgents =   sqlAgents  .. "DATE_PART('day', to_timestamp(cc_queue_joined_epoch)),"
sqlAgents =   sqlAgents  .. "DATE_PART('hour', to_timestamp(cc_queue_joined_epoch))"
sqlAgents =   sqlAgents  .. " ORDER BY min(cc_queue_joined_epoch);"


local params = {finalMonday = finalMonday, cc_queue = callcenter_uuid, domain_name=domain_name,evaluationTime=evaluationTime};

local filePath2; 

if (evalStartEpoch == nil or evalStartEpoch == '') then
    filePath2 = "/opt/callcenterevaluation/"..os.date('%Y-%m-%d',evaluationTime).."/CALLS-"..callcenter_name .."-TIME-"..os.date('%Y-%m-%d',evaluationTime)..".csv"
else 
    filePath2 = "/opt/callcenterevaluation/redo/"..os.date('%Y-%m-%d',evaluationTime).."/CALLS-"..callcenter_name .."-TIME-"..os.date('%Y-%m-%d',evaluationTime)..".csv"
end

local call_file = assert(io.open(filePath2,"w+"))
call_file:write("Tag,Monat,Jahr,Stunde,Tag der Woche,Anrufe Insgesamt,Angenommene Anrufe,Abgebrochene Anrufe,Anrufe auf Voicemail,Nachricht auf Voicemail,Durchschnittliche Gesprächsdauer,Durchschnittliche Wartezeit (ohne Ansage)\n")

 callCount = 0;
 recordCount = 0;

         dbh:query(sqlAgents, params, function(row)
            -- For every Call 
            call_file:write(row["Tag"],",")
            call_file:write(row["Monat"],",")
            call_file:write(row["Jahr"],",")
            call_file:write(row["Stunde"],",")
            call_file:write(row["Tag der Woche"],",")
            call_file:write(row["Anrufe Insgesamt"],",")
            call_file:write(row["Angenommene Anrufe"],",")
            call_file:write(row["Abgebrochene Anrufe"],",")
            call_file:write(row["Anrufe auf Voicemail"],",")
            call_file:write(row["Nachricht auf Voicemail"],",")
            call_file:write(row["Durchschnittliche Gesprächsdauer"],",")
            call_file:write(row["Durchschnittliche Wartezeit (ohne Ansage)"],",")
            call_file:write("\n")
            
            callCount = callCount + tonumber(row["Angenommene Anrufe"])
         end)
         
         freeswitch.consoleLog("Info","CallCount:"..callCount)
         local sqlite3String = "select count(*) from recordApproval where epoch > " .. finalMonday .. " and epoch < ".. evaluationTime .. " and callcenter = '"..callcenter_uuid.."';"
         freeswitch.consoleLog("Info",sqlite3String)

         callcenterLogsdbh:query(sqlite3String, function(row)

               
               recordCount = row["count(*)"]

         end)

         call_file:write("\n")
         call_file:write("\n")
         call_file:write("\n")
         call_file:write("Anrufe aufgezeichnet ".. recordCount .."/" .. callCount)
call_file.close()

dbh:release()
sqlite3dbh:release()

freeswitch.consoleLog("Info","Auswertung Beendet")





