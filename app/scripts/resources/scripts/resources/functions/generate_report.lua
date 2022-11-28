function generateFaxReport(body,faxRequest,density,outputPath)

--body.variable_fax_result_text = "Super"
--body.variable_current_application_response ="Response"
--body.variable_answer_stamp = 1655470137
--body["Event-Date-Local"] = 1655470137
--body.variable_billmsec = 12987
--body.variable_fax_document_transferred_pages = 17
--body["Caller-Orig-Caller-ID-Number"] = "015117963423"
--body["Caller-Destination-Number"] = "015117963423"
--faxRequest.totalPages = 17
--faxRequest.faxPath = "/var/lib/freeswitch/storage/fax/vdk-de-hq.realyzer.net/1405/temp/0d8e35c7-99ec-48be-909f-6c9d0b1ef179.pdf"
logoPath = "/var/www/fusionpbx/app/fax/resources/images/czichosnet-email.png"
--outputPath ="/tmp/reportTest2.pdf"

density = density or 300

pxWidth = 8.27 * density;
pxHeight = 11.69 * density;

weight = 300;
gravity = "northwest";
pointsize = 14;

topPerc = 0.2;
botPerc = 0.35;
headspace = 0.02;
indent = 0.02;
lineindent = 0.07;
fpHeadspace = 0.04;

emptyPDF = "/var/www/fusionpbx/app/fax/resources/images/empty.pdf"

function drawLine(x1,y1,x2,y2) 
command = command .. "-draw \"line " .. x1 .. "," .. y1 .. " " .. x2 .. "," .. y2 .. "\" "
end

function drawText(text, x,y) 
command = command .. "-weight " .. weight .. " -gravity " .. gravity .. " -pointsize " .. pointsize .. " -draw \"text " .. x .. "," .. y .. " '" .. text .. "'\" "
end

function drawImage(operator, x,y, width, height, filename) 
command = command .. "-fill none -draw \"image " .. operator .. " " .. x .. "," .. y .. " " .. math.ceil(width) .. "," .. math.ceil(height) .. " '" .. filename .. "'\" -fill black ";
end

function drawRectangle(x1,y1,x2,y2,fill) 

fill = fill or "none" 
command = command .. "-fill " .. fill .. " -stroke black -strokewidth " .. math.floor(density / 100) .. " -draw \"rectangle " .. x1 .. "," .. y1 .. " " .. x2 .. "," .. y2 .. "\" -fill black -strokewidth 1 -stroke none ";
end



function convertDate(msecs) 
local secs = math.ceil(msecs / 1000);
local minutes = math.floor(secs / 60);
local restSec = secs % 60;
return minutes .. "\\'" .. string.format("%02d",restSec) .. "\\'\\'";
end 

command = "convert -density " .. density .. " " .. emptyPDF .. " -type Grayscale -compress Zip "

drawLine(
pxWidth * indent, pxHeight * topPerc,pxWidth * (1 - indent), pxHeight * topPerc
);
drawLine(
pxWidth * indent, pxHeight * botPerc,
pxWidth * (1 - indent), pxHeight * botPerc
);

sectionHeight = pxHeight * (botPerc - topPerc);
lineHeight = (sectionHeight * 1) / 9;

drawText(
"Resultat: " .. (body.variable_fax_result_text or body.variable_current_application_response),pxWidth * (indent + lineindent),pxHeight * topPerc + lineHeight * 2

);
drawText(
"Datum: " .. body.variable_answer_stamp or body["Event-Date-Local"],pxWidth * (indent + lineindent),pxHeight * topPerc + lineHeight * 4
);
drawText(
"Übertragungsdauer: " .. convertDate(body.variable_billmsec),pxWidth * (indent + lineindent),pxHeight * topPerc + lineHeight * 6
)

if (body.variable_fax_document_transferred_pages ~= nil) then

drawText("Seiten: " .. body.variable_fax_document_transferred_pages .. "/" .. faxRequest.totalPages,pxWidth * (1 - (indent + (1 - 2 * indent) / 2 - lineindent)),pxHeight * topPerc + lineHeight * 2);
else

drawText("Seiten: -",pxWidth * (1 - (indent + (1 - 2 * indent) / 2 - lineindent)),pxHeight * topPerc + lineHeight * 2);
end


drawText(
"Sender: "..body.caller_orig_caller_id_number,
    pxWidth * (1 - (indent + (1 - 2 * indent) / 2 - lineindent)),
    pxHeight * topPerc + lineHeight * 4
)
drawText(
"Empfänger: +"..body.caller_destination_number,
    pxWidth * (1 - (indent + (1 - 2 * indent) / 2 - lineindent)),
    pxHeight * topPerc + lineHeight * 6
);

imageHeight = 40;
imageWidth = 350;
scale = density / 100;

fpScale = 1 - botPerc - fpHeadspace - headspace;

drawImage(
"over",
    pxWidth * (1 - indent) - scale * imageWidth,
    pxHeight * headspace,
scale * imageWidth,
scale * imageHeight,
logoPath
)


drawRectangle(

    (pxWidth * (1 - fpScale)) / 2 + 1,
    pxHeight * (botPerc + fpHeadspace) + 1,
    (pxWidth * (1 + fpScale)) / 2 + 1,
    pxHeight * (botPerc + fpHeadspace + fpScale) + 1
);
drawImage(
"atop",
(pxWidth * (1 - fpScale)) / 2,
pxHeight * (botPerc + fpHeadspace),
pxWidth * fpScale,
pxHeight * fpScale,
faxRequest.faxPath

);

pointsize = 30;
weight = 700;
gravity = "north";

drawText(
"Faxbericht",
0,
imageHeight * scale + pxHeight * 3 * headspace
);

weight = 100;
pointsize = 8;


command = command .. outputPath;
freeswitch.consoleLog("Info","Command: "..command);

os.execute(command)

end

return generateFaxReport
