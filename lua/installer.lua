-- This program was designed to run inside of CraftOS-PC
-- You can download CraftOS-PC from https://www.craftos-pc.cc/

if not term then --Check if the program is running inside CraftOS-PC
	print("This program was designed to run inside of CraftOS-PC")
	print("You can download CraftOS-PC from https://www.craftos-pc.cc/")
	print("Press enter to continue...")
	local a = io.read()
	return
end

local args = {...}
local argIndex = 1

local function readInput()
	if argIndex <= #args then
		argIndex = argIndex + 1
		return args[argIndex-1]
	else
		return read()
	end
end

--The following few lines of code transfer the config to the new setting variables
local configStrings = {"accessKey","websocketUrl","allowUpdates"}
for i=1,#configStrings do
	local item = configStrings[i]
	settings.undefine("resoniteLink."..item)
	local value = settings.get("resoniteLink."..item)
	if value then
		settings.set("udhdRemoteAccess."..item,value)
		settings.unset("resoniteLink."..item)
	end
end
settings.define("udhdRemoteAccess.accessKey",{
	description="Access Key for the webocket server", 
	default = "public", 
	type="string"
})
settings.define("udhdRemoteAccess.websocketUrl",{
	description="Websocket URL for the server",
	default="wss://catio-api.merith.xyz/",
	type="string"
})
settings.define("udhdRemoteAccess.allowUpdates",{
	description="Set to false to disable automatic updates", 
	default = true, 
	type="boolean"
})
settings.define("udhdRemoteAccess.useDevBranch",{
	description="Set to true to use the development branch for automatic updates.", 
	default = false, 
	type="boolean"
})
settings.save() --save all changes to the computer settings

local colorBG = colors.black
local colorText = colors.white
local colorHeader = colors.yellow
local colorError = colors.red
local colorPrompt = colors.lightGray

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

term.setTextColor(colorHeader)
print("Universal DHD Remote Access Client Installer")
term.setTextColor(colorText)
print("Settings have been saved.")

print("Downloading udhdRemoteAccess.lua")
local ws,err = http.websocket(settings.get("udhdRemoteAccess.websocketUrl"))
if not ws then 
	printError("Download Failed")
	printError(err)
	print("Please try again later.")
	return
end
ws.receive()
if settings.get("udhdRemoteAccess.useDevBranch") then
	ws.send("-UPDATE_DEV")
else
	ws.send("-UPDATE")
end
local fileConts = ws.receive()
local success = false
if string.sub(fileConts,1,#"ERROR:")~="ERROR:" then
	local f = fs.open("/udhdRemoteAccess.lua","w")
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