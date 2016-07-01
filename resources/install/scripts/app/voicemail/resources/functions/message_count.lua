local log = require "resources.functions.log"["voicemail-count"]

-- Tested SQL on SQLite 3, PgSQL 9.5, MySQL 5.5 and MariaDB 10

local message_count_by_uuid_sql = [[SELECT
( SELECT count(*)
  FROM v_voicemail_messages
  WHERE voicemail_uuid = '%s' 
  AND (message_status is null or message_status = '')
) as new_messages,

( SELECT count(*)
  FROM v_voicemail_messages
  WHERE voicemail_uuid = '%s'
  AND message_status = 'saved'
) as saved_messages
]]

function message_count_by_uuid(voicemail_uuid)
	local new_messages, saved_messages = "0", "0"

	local sql = string.format(message_count_by_uuid_sql,
		voicemail_uuid, voicemail_uuid
	)

	if debug["sql"] then
		log.noticef("SQL: %s", sql)
	end

	dbh:query(sql, function(row)
		new_messages, saved_messages = row.new_messages, row.saved_messages
	end)

	if debug["info"] then
		log.noticef("mailbox uuid: %s messages: %s/%s", voicemail_uuid, new_messages, saved_messages)
	end

	return new_messages, saved_messages
end

local message_count_by_id_sql = [[SELECT
( SELECT count(*)
  FROM v_voicemail_messages as m inner join v_voicemails as v
  on v.voicemail_uuid = m.voicemail_uuid
  WHERE v.voicemail_id = '%s' AND v.domain_uuid = '%s'
  AND (m.message_status is null or m.message_status = '')
) as new_messages,

( SELECT count(*)
  FROM v_voicemail_messages as m inner join v_voicemails as v
  on v.voicemail_uuid = m.voicemail_uuid
  WHERE v.voicemail_id = '%s' AND v.domain_uuid = '%s'
  AND m.message_status = 'saved'
) as saved_messages
]]

function message_count_by_id(voicemail_id, domain_uuid)
	local new_messages, saved_messages = "0", "0"

	local sql = string.format(message_count_by_id_sql,
		voicemail_id, domain_uuid, voicemail_id, domain_uuid
	)

	if debug["sql"] then
		log.noticef("SQL: %s", sql)
	end

	dbh:query(sql, function(row)
		new_messages, saved_messages = row.new_messages, row.saved_messages
	end)

	if debug["info"] then
		log.noticef("mailbox: %s messages: %s/%s", voicemail_id, new_messages, saved_messages)
	end

	return new_messages, saved_messages
end

