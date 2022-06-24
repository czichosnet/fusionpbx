inviteString = argv[1]
caller_id_number = session:getVariable("caller_id_number")
context = session:getVariable("context")




function mysplit(inputstr, sep)

    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

function inviteInternToConference(userToInvite)

    session:execute("conference_set_auto_outcall","user/" .. userToInvite[1] .."@" .. userToInvite[2])
    session:consoleLog("Info","Invited User user/" .. userToInvite[1] .."@" .. userToInvite[2]);

end 

function inviteExternToConference()


end 

 function getCallInfos(inviteString)


    session:setVariable("conference_auto_outcall_timeout","20")
    session:setVariable("conference_auto_outcall_flags", "none")
    

    local toInvite = mysplit(inviteString,",");
    local inviteIntern = {}
    local inviteExtern = {}

    for i=1,#toInvite,1 do 

        if string.find(toInvite[i],"+") == nil then 

            session:consoleLog("Info","Interner Invite");
            session:consoleLog("Info","String"..toInvite[i]);

            local inviteSplits = mysplit(toInvite[i],"/")

            
            s = session:getVariable("sip_full_from");

            
            splits = mysplit(s,'"')
            

            session:setVariable("conference_auto_outcall_caller_id_number", "Audio Konferenz")
            session:setVariable("conference_auto_outcall_caller_id_name", splits[1])

            session:consoleLog("Info","HALOLOLO Splits1"..splits[1]);

            inviteInternToConference(inviteSplits);

        else

            session:consoleLog("err","externer Invite");

        end

    end 

    session:execute("conference",caller_id_number..context.."@default")




end 










session:answer()
session:consoleLog("Info",session:getVariable("sip_full_from"));
session:consoleLog("Info",session:getVariable("sip_from_user"));
session:consoleLog("Info",session:getVariable("sip_from_uri"));
session:consoleLog("Info",session:getVariable("sip_from_host"));
session:consoleLog("Info",session:getVariable("sip_from_user_stripped"));
session:consoleLog("Info",session:getVariable("sip_from_tag"));
getCallInfos(inviteString);
session:hangup("NORMAL_CLEARING")