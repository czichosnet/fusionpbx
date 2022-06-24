--require 'pl';
--stringx.import()

-- normiert eine Rufnummer auf E.164 mit opt. Prefix

local numberToNorm = argv[1];
local countrycode = argv[2];
local areacode = argv[3];
local normedNumberVar = argv[4];

-- optional
local prefix = argv[5] or "";

local normedNumber = "";
local start = 0;

numberToNorm = string.gsub(numberToNorm,"*","",1);

local numberLength = string.len(numberToNorm);

if (string.find(numberToNorm,"+") == 1) then
	
	normedNumber = prefix .. string.sub(numberToNorm,2);
elseif (numberToNorm == "115") then
	normedNumber =  countrycode .. numberToNorm

--elseif (string.find(numberToNorm,"49") == 1) then
--	normedNumber =  prefix .. numberToNorm

elseif (string.find(numberToNorm,"00800") == 1) then

	normedNumber =  numberToNorm
elseif (string.find(numberToNorm,"0800") == 1) then

	normedNumber =  countrycode .. string.sub(numberToNorm,2);

elseif (string.find(numberToNorm,"00"..countrycode) == 1) then
	
	normedNumber = prefix .. string.sub(numberToNorm,3);
elseif (string.find(numberToNorm,"00") == 1) then
	
	normedNumber = prefix .. string.sub(numberToNorm,3);
else
	start = string.find(numberToNorm,"[123456789]");
	
	if start == 1 then
		normedNumber = prefix .. countrycode .. areacode .. numberToNorm;
		
	elseif start == 2 then
		
		normedNumber = prefix .. countrycode .. string.sub(numberToNorm,2);
	elseif start == 3 then
		
		normedNumber = prefix .. string.sub(numberToNorm,3);
	end	
end
   
session:setVariable(normedNumberVar,normedNumber);

