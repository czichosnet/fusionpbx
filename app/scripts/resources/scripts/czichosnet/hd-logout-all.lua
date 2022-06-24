--	Part of FusionPBX
--	Copyright (C) 2015-2018 Mark J Crane <markjcrane@fusionpbx.com>
--	All rights reserved.
--
--	Redistribution and use in source and binary forms, with or without
--	modification, are permitted provided that the following conditions are met:
--
--	1. Redistributions of source code must retain the above copyright notice,
--	  this list of conditions and the following disclaimer.
--
--	2. Redistributions in binary form must reproduce the above copyright
--	  notice, this list of conditions and the following disclaimer in the
--	  documentation and/or other materials provided with the distribution.
--
--	THIS SOFTWARE IS PROVIDED ''AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
--	INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
--	AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
--	AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
--	OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
--	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
--	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
--	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
--	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--	POSSIBILITY OF SUCH DAMAGE.

function logoffDevice(uuid,username,domain)

    --remove the previous alternate device uuid
    local sql = "UPDATE v_devices SET device_uuid_alternate = null WHERE device_uuid_alternate = '"..uuid.."'";	
	freeswitch.consoleLog("NOTICE", "[SQL] SQL: ".. sql );
	dbh:query(sql, params);


--get the sip profile
    api = freeswitch.API();
    local sofia_contact = trim(api:executeString("sofia_contact */"..username.."@"..domain));
    array = explode("/", sofia_contact);
    profile = "internal";
    freeswitch.consoleLog("NOTICE", "[provision] profile: ".. profile .. "\n");
--send a sync command to the previous device
    --create the event notify object
        local event = freeswitch.Event('NOTIFY');
    --add the headers
        event:addHeader('profile', profile);
        event:addHeader('user', username);
        event:addHeader('host', domain);
        event:addHeader('content-type', 'application/simple-message-summary');
    --check sync
        event:addHeader('event-string', 'check-sync;reboot='..reboot);
        --event:addHeader('event-string', 'resync');
    --send the event
        event:fire();
    end

freeswitch.consoleLog("NOTICE", "[SQL] SQL:HALLO");

--set the debug options
debug["sql"] = false;

--define the explode function
	require "resources.functions.explode";
	require "resources.functions.trim";
    json = require "resources.functions.lunajson"

--connect to the database
	local Database = require "resources.functions.database";
	dbh = Database.new('system');

--include json library
	local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson"
	end

--set defaults
	if (not reboot) then reboot = 'false'; end

--get the user and domain name from the user argv user@domain
	
	domain = argv[1];
    

    --get device_uuid

    local sqlString = "SELECT device_uuid_alternate FROM v_devices WHERE device_uuid_alternate IS NOT NULL"

    freeswitch.consoleLog("NOTICE", "[SQL] SQL: ".. sqlString);

    dbh:query(sqlString, params, function(row)
        freeswitch.consoleLog("NOTICE", "[SQL] SQL: ".. sqlString);
        
            local sqlString2 = "SELECT device_label from v_devices WHERE device_uuid = '"..row.device_uuid_alternate.."'"
            freeswitch.consoleLog("NOTICE", "[SQL] SQL: ".. sqlString2);
            dbh:query(sqlString2, params, function(value)
                username = value.device_label
                logoffDevice(row.device_uuid_alternate,username,domain)
            end);
            
        
    end);

    