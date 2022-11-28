local Database = require "resources.functions.database";
dbh = Database.new('system');
local ONE_DAY = 60*60*24;
api = freeswitch.API();

callcenter_uuid = argv[1];
domain_name = argv[2];
email = argv[3];
mondayTimeStamp = 1656309600

 local sqlString = "SELECT" 
 sqlString = sqlString .." DATE_PART('day', to_timestamp(min(cc_queue_joined_epoch))) as \"Tag\"," 
 sqlString = sqlString ..  " DATE_PART('month', to_timestamp(min(cc_queue_joined_epoch))) as \"Monat\","
 sqlString = sqlString ..  " DATE_PART('year', to_timestamp(min(cc_queue_joined_epoch))) as \"Jahr\","
 sqlString = sqlString ..  " DATE_PART('hour', to_timestamp(min(cc_queue_joined_epoch)))+2 as \"Stunde\","
 sqlString = sqlString ..  " EXTRACT(DOW FROM to_timestamp(min(cc_queue_joined_epoch))) as \"Tag der Woche\","
 sqlString = sqlString ..  " COUNT(xml_cdr_uuid) as \"Anrufe Insgesamt\","
 sqlString = sqlString ..  " SUM(CASE WHEN cc_agent_bridged = 'true' THEN 1 ELSE 0 END) as \"Angenommene Anrufe\","
 sqlString = sqlString ..  " SUM(CASE WHEN cc_cancel_reason = 'BREAK_OUT' THEN 1 ELSE 0 END) as \"Abgebrochene Anrufe\","
 sqlString = sqlString ..  " SUM(CASE WHEN cc_cancel_reason = 'EXIT_WITH_KEY' THEN 1 ELSE 0 END) as \"Anrufe auf Voicemail\","
 sqlString = sqlString ..  " SUM(CASE WHEN cc_cancel_reason = 'EXIT_WITH_KEY' AND voicemail_message = true THEN 1 ELSE 0 END) as \"Nachricht auf Voicemail\","
 sqlString = sqlString ..  " COALESCE(CEIL(AVG(CASE WHEN cc_agent_bridged = 'true' THEN COALESCE(cc_queue_terminated_epoch, end_epoch) - cc_queue_answered_epoch ELSE null END)),0) as \"Durchschnittliche Gesprächsdauer\","
 sqlString = sqlString ..  " COALESCE(CEIL(AVG(CASE WHEN  cc_agent_bridged = 'true' THEN cc_queue_answered_epoch - cc_queue_joined_epoch ELSE null END)),0) as \"Durchschnittliche Wartezeit (ohne Ansage)\""
 sqlString = sqlString ..  " FROM v_xml_cdr "
 sqlString = sqlString ..  " WHERE cc_queue_joined_epoch > :mondayTimeStamp AND domain_name = :callcenter_uuid AND cc_queue = :callcenter_uuid AND cc_side = 'member'"
 sqlString = sqlString ..  " GROUP BY "
 sqlString = sqlString ..  " DATE_PART('year', to_timestamp(cc_queue_joined_epoch)),"
 sqlString = sqlString ..  " DATE_PART('month', to_timestamp(cc_queue_joined_epoch)),"
 sqlString = sqlString ..  " DATE_PART('day', to_timestamp(cc_queue_joined_epoch)),"
 sqlString = sqlString ..  " DATE_PART('hour', to_timestamp(cc_queue_joined_epoch))"
 sqlString = sqlString ..  " ORDER BY min(cc_queue_joined_epoch);"

 local params = {mondayTimeStamp = mondayTimeStamp, callcenter_uuid = callcenter_uuid};

 dbh:query(sqlString, params, function(row)
    -- For every Call 
    freeswitch.consoleLog("notice", "[call_center] SQL: " .. row);

 end)

 dbh:release()