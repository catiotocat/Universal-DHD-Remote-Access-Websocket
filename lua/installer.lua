-- This program was designed to run inside of CraftOS-PC
-- You can download CraftOS-PC from https://www.craftos-pc.cc/

if not term then --Check if the program is running inside CraftOS-PC
	print("This program was designed to run inside of CraftOS-PC")
	print("You can download CraftOS-PC from https://www.craftos-pc.cc/")
	print("Press enter to continue...")
	local a = io.read()
	return
end

-- This program is in dire need of a rewrite.
-- Said rewrite will be in-progress on the dev branch

local function readInput()
	return read()
end

-- define settings variables
settings.define("udhdRemoteAccess.accessKey",{
	description="Access Key for the webocket server", 
	default = "public", 
	type="string"
})
settings.define("udhdRemoteAccess.websocketUrl",{
	description="Websocket URL for the server",
	default = nil,
	type="string"
})
settings.define("udhdRemoteAccess.allowUpdates",{
	description="Set to false to disable automatic updates", 
	default = true, 
	type="boolean"
})
settings.define("udhdRemoteAccess.apiKey",{
	description="The API Key to use with the Stargate API. Leave blank to use the public api.", 
	default = "", 
	type="string"
})
settings.save() --save all changes to the computer settings

local colorBG = colors.black
local colorText = colors.white
local colorHeader = colors.yellow
local colorOptionBorder = colors.yellow
local colorOptionSymbol = colors.white
local colorOptionsText = colors.white
local colorOptionsDefaultIndicatorBorder = colors.yellow
local colorOptionsDefaultIndicatorText = colors.white
local colorError = colors.red
local colorPromptText = colors.lightGray
local colorPrompt = colors.yellow

local function settingPrompt(headers, current, options, prompts)
	local valid = true
	repeat
		local generatedOptionInfo = {
			default = nil
		}
		for i=1,#headers do
			term.setTextColor(headers[i].color)
			print(headers[i].text)

		end
		if current then
			term.setTextColor(current.color1)
			term.write(current.text1)
			term.setTextColor(current.color2)
			print(current.text2)
		end
		for i=1,#options do
			local character = string.upper(options[i].custom_char or tostring(i-1))
			if options[i].is_default then
				generatedOptionInfo.default = options[i]
			end
			generatedOptionInfo[character] = options[i]
			term.setTextColor(colorOptionBorder)
			term.write("[")
			term.setTextColor(colorOptionSymbol)
			term.write(character)
			term.setTextColor(colorOptionBorder)
			term.write("] ")
			term.setTextColor(colorOptionsText)
			term.write(options[i].option)
			if options[i].is_default then
				term.setTextColor(colorOptionsDefaultIndicatorBorder)
				term.write(" (")
				term.setTextColor(colorOptionsDefaultIndicatorText)
				term.write("default")
				term.setTextColor(colorOptionsDefaultIndicatorBorder)
				term.write(")")
				
			end
			print("")
		end

		-- cancel install option
		term.setTextColor(colorOptionBorder)
		term.write("[")
		term.setTextColor(colorOptionSymbol)
		term.write("X")
		term.setTextColor(colorOptionBorder)
		term.write("] ")
		term.setTextColor(colorOptionsText)
		print("Cancel Installation")

		for i=1,#prompts do
			term.setTextColor(prompts[i].color)
			print(prompts[i].text)
		end
		--prompt here

		if not valid then
			local x,y = term.getCursorPos()
			term.setCursorPos(1,y+1)
			term.setTextColor(colorError)
			print("Sorry, your response was not recognized.")
			term.setTextColor(colorText)
			print("Please try again.")
			term.setCursorPos(x,y)
		end
		valid = true

		term.setTextColor(colorPrompt)
		term.write("> ")
		-- read code will be here
		local readValue = string.upper(read())

		local optionRef
		if readValue == "" and generatedOptionInfo.default then
			optionRef = generatedOptionInfo.default
		elseif generatedOptionInfo[readValue] then
			optionRef = generatedOptionInfo[readValue]
		elseif readValue == "X" then
			optionRef = "ExitCheck"
		end
		
		if optionRef then
			if type(optionRef) == "table" then
				if optionRef.func then
					
				end
			else

			end
		else
			--not recognized
			valid = false

		end

	until valid
end

local function inputUrl()
	term.setTextColor(colorPrompt)
	term.clearLine()
	print("Please enter the websocket URL.")
	term.setTextColor(colorHeader)
	term.clearLine()
	term.write("> ")
	term.setTextColor(colorText)
	wsURL = readInput()
end

--[[
	example options list
	{
		{
			is_default = true,
			option = "ws://localhost:8059",
			custom_char = "0",
			func = function() end,
			has_extra_prompt = false,
		}
	}

]]--


term.setBackgroundColor(colorBG)
term.setTextColor(colorText)
term.clear()
term.setCursorPos(1,1)

local wsURL
local valid = true
local reset = false
repeat
	reset = false
	term.setTextColor(colorHeader)
	print("Universal DHD Remote Access Client Installer")
	term.setTextColor(colorText)
	print("Please select a websocket URL to use.")
	term.write("Currently Set To: ")
	term.setTextColor(colorPrompt)
	print(settings.get("udhdRemoteAccess.websocketUrl"))
	term.setTextColor(colorText)
	print("0: wss://catio-api.merith.xyz/ (Default)")
	print("1: ws://localhost:8059/")
	print("C: Custom URL")
	print("L: Do Not Change")
	print("X: Cancel Installation")
	term.setTextColor(colorPrompt)
	print("Enter the letter/number of your selection and press enter.")
	print("Leave blank to use the default setting.")
	term.setTextColor(colorHeader)
	term.write("> ")
	if not valid then
		local x,y = term.getCursorPos()
		term.setCursorPos(1,y+1)
		term.setTextColor(colorError)
		print("Sorry, your response was not recognized.")
		term.setTextColor(colorText)
		print("Please try again.")
		term.setCursorPos(x,y)
	end
	valid = true
	term.setTextColor(colorText)
	local response = string.upper(readInput())
	if response == "0" or response == "" then
		wsURL = "wss://catio-api.merith.xyz/"
	elseif response == "1" then
		wsURL = "ws://localhost:8059/"
	elseif response == "C" then
		term.setTextColor(colorPrompt)
		term.clearLine()
		print("Please enter the websocket URL.")
		term.setTextColor(colorHeader)
		term.clearLine()
		term.write("> ")
		term.setTextColor(colorText)
		wsURL = readInput()
	elseif response == "L" then
	elseif response == "X" then
		reset = true
		term.clear()
		term.setCursorPos(1,1)
		term.setTextColor(colorHeader)
		print("Universal DHD Remote Access Client Installer")
		term.setTextColor(colorText)
		print("Would you like to cancel the installation?")
		term.setTextColor(colorHeader)
		term.write("y/n> ")
		term.setTextColor(colorText)
		response = readInput()
		if string.lower(response) == "y" then
			break
		else
			term.clear()
			term.setCursorPos(1,1)
		end
	else
		term.clear()
		term.setCursorPos(1,1)
		valid = false
	end
until valid and not reset
if reset then 
	printError("Exiting...")
	return
end

if wsURL then
	settings.set("udhdRemoteAccess.websocketUrl",wsURL)
	settings.save()
end

term.clear()
term.setCursorPos(1,1)

local wsKey
valid = true
repeat
	reset = false
	term.setTextColor(colorHeader)
	print("Universal DHD Remote Access Client Installer")
	term.setTextColor(colorText)
	print("Please select an access key to use.")
	term.write("Currently Set To: ")
	term.setTextColor(colorPrompt)
	print(settings.get("udhdRemoteAccess.accessKey"))
	term.setTextColor(colorText)
	print("0: public (Default)")
	print("C: Custom Access Key")
	print("L: Do Not Change")
	print("X: Cancel Installation")
	term.setTextColor(colorPrompt)
	print("Enter the letter/number of your selection and press enter.")
	print("Leave blank to use the default setting.")
	term.setTextColor(colorHeader)
	term.write("> ")
	if not valid then
		local x,y = term.getCursorPos()
		term.setCursorPos(1,y+1)
		term.setTextColor(colorError)
		print("Sorry, your response was not recognized.")
		term.setTextColor(colorText)
		print("Please try again.")
		term.setCursorPos(x,y)
	end
	valid = true
	term.setTextColor(colorText)
	local response = string.upper(readInput())
	if response == "0" or response == "" then
		wsKey = "public"
	elseif response == "C" then
		term.setTextColor(colorPrompt)
		term.clearLine()
		print("Please enter the access key.")
		term.setTextColor(colorHeader)
		term.clearLine()
		term.write("> ")
		term.setTextColor(colorText)
		wsKey = readInput()
	elseif response == "L" then
	elseif response == "X" then
		reset = true
		term.clear()
		term.setCursorPos(1,1)
		term.setTextColor(colorHeader)
		print("Universal DHD Remote Access Client Installer")
		term.setTextColor(colorText)
		print("Would you like to cancel the installation?")
		term.setTextColor(colorHeader)
		term.write("y/n> ")
		term.setTextColor(colorText)
		response = readInput()
		if string.lower(response) == "y" then
			break
		else
			term.clear()
			term.setCursorPos(1,1)
		end
	else
		term.clear()
		term.setCursorPos(1,1)
		valid = false
	end
until valid and not reset
if reset then 
	printError("Exiting...")
	return
end

if wsKey then
	settings.set("udhdRemoteAccess.accessKey",wsKey)
	settings.save()
end

term.clear()
term.setCursorPos(1,1)


local fname
valid = true
repeat
	reset = false
	term.setTextColor(colorHeader)
	print("Universal DHD Remote Access Client Installer")
	term.setTextColor(colorText)
	print("Please select a filename to use.")
	print("Filenames must have the \".lua\" file extension.")
	term.setTextColor(colorText)
	print("0: udhdRemoteAccess.lua (default)")
	print("1: client.lua")
	print("C: Custom File Name")
	print("X: Cancel Installation")
	term.setTextColor(colorPrompt)
	print("Enter the letter/number of your selection and press enter.")
	print("Leave blank to use the default setting.")
	term.setTextColor(colorHeader)
	term.write("> ")
	if not valid then
		local x,y = term.getCursorPos()
		term.setCursorPos(1,y+1)
		term.setTextColor(colorError)
		print("Sorry, your response was not recognized.")
		term.setTextColor(colorText)
		print("Please try again.")
		term.setCursorPos(x,y)
	end
	valid = true
	term.setTextColor(colorText)
	local response = string.upper(readInput())
	if response == "0" or response == "" then
		fname = "udhdRemoteAccess.lua"
	elseif response == "1" then
		fname = "client.lua"
	elseif response == "C" then
		local valid = true
		repeat
			term.setTextColor(colorPrompt)
			term.clearLine()
			if valid then
				print("Please enter the file name.")
			else
				valid = true
			end
			term.setTextColor(colorHeader)
			term.clearLine()
			term.write("> ")
			term.setTextColor(colorText)
			fname = readInput()
			if string.sub(fname,-4,-1) ~= ".lua" then
				term.setTextColor(colorPrompt)
				print("The filename must have the \".lua\" file extension.")
				print("Please try again.")
				valid = false
			end
		until valid
	elseif response == "X" then
		reset = true
		term.clear()
		term.setCursorPos(1,1)
		term.setTextColor(colorHeader)
		print("Universal DHD Remote Access Client Installer")
		term.setTextColor(colorText)
		print("Would you like to cancel the installation?")
		term.setTextColor(colorHeader)
		term.write("y/n> ")
		term.setTextColor(colorText)
		response = readInput()
		if string.lower(response) == "y" then
			break
		else
			term.clear()
			term.setCursorPos(1,1)
		end
	else
		term.clear()
		term.setCursorPos(1,1)
		valid = false
	end
until valid and not reset
if reset then 
	printError("Exiting...")
	return
end



term.setTextColor(colorHeader)
print("Universal DHD Remote Access Client Installer")
term.setTextColor(colorText)
print("Settings have been saved.")

print("Downloading "..fname)
local ws,err = http.websocket(settings.get("udhdRemoteAccess.websocketUrl"))
if not ws then 
	printError("Download Failed")
	printError(err)
	print("Please try again later.")
	return
end
ws.receive(1)
ws.send("-UPDATE")
local fileConts, fail = ws.receive(5)
local success = false
if not fileConts then
	printError(fail)
	print("Please try again later.")
	return
elseif string.sub(fileConts,1,#"ERROR:")~="ERROR:" then
	local f = fs.open(fname,"w")
	f.write(fileConts)
	f.close()
	print("Download Completed")
	success = true
else
	printError(fileConts)
	print("Please try again later.")
	return
end
print("Waiting for connection to close...")
os.pullEvent("websocket_closed")
print("Program is now ready to use!")
