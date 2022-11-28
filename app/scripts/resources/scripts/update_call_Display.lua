api = freeswitch.API();
api:executeString("uuid_display "..session:get_uuid().." AUFNAHME");