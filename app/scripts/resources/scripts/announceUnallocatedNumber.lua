--
--	FusionPBX
--	Version: MPL 1.1
--
--	The contents of this file are subject to the Mozilla Public License Version
--	1.1 (the "License"); you may not use this file except in compliance with
--	the License. You may obtain a copy of the License at
--	http://www.mozilla.org/MPL/
--
--	Software distributed under the License is distributed on an "AS IS" basis,
--	WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
--	for the specific language governing rights and limitations under the
--	License.
--
--	The Original Code is FusionPBX
--
--	The Initial Developer of the Original Code is
--	Mark J Crane <markjcrane@fusionpbx.com>
--	Copyright (C) 2010-2018
--	the Initial Developer. All Rights Reserved.
--
--	Contributor(s):
--	Salvatore Caruso <salvatore.caruso@nems.it>
--	Riccardo Granchi <riccardo.granchi@nems.it>
--	Luis Daniel Lucio Quiroz <dlucio@okay.com.mx>

if (session:getVariable("originate_disposition") == "UNALLOCATED_NUMBER" ) then 

	session:answer()
	session:sleep(500)
	session:execute("playback","/usr/share/freeswitch/sounds/de/de/callie/ivr/16000/ivr-unallocated_number.wav")
	session:execute("playback","/usr/share/freeswitch/sounds/de/de/callie/ivr/16000/ivr-please_check_number_try_again.wav")
	session:hangup("UNALLOCATED_NUMBER")

end

if (session:getVariable("originate_disposition") == "INVALID_NUMBER_FORMAT" ) then 

	session:answer()
	session:sleep(500)
	session:execute("playback","/usr/share/freeswitch/sounds/de/de/callie/ivr/16000/ivr-invalid_number_format.wav")
	session:execute("playback","/usr/share/freeswitch/sounds/de/de/callie/ivr/16000/ivr-please_check_number_try_again.wav")
	session:hangup("INVALID_NUMBER_FORMAT")

end


session:hangup(session:getVariable("originate_disposition"))