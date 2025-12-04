-- This program was designed to run inside of CraftOS-PC
-- You can download CraftOS-PC from https://www.craftos-pc.cc/
local programVersion = "2.2.0"

if not term then --Check if the program is running inside CraftOS-PC
	print("This program was designed to run inside of CraftOS-PC")
	print("You can download CraftOS-PC from https://www.craftos-pc.cc/")
	print("Press enter to continue...")
	local a = io.read()
	return
end
if not shell then --If the shell api isn't present, return the program version for update check.
	return programVersion
end

settings.define("udhdRemoteAccess.accessKey",{
	description="Access Key(s) for the webocket server. Use \";\" to seperate keys.", 
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

local arguments = {...}
local baseTerm = term.current()
local windows = {}
local data = {
	apiList = {},
	wsList = {},
	genList = {},
	wsListCondensed = {},
	perms = {
		allowed = {},
		online = {}
	}
} 
local programVars = {
	slotListOffset = 0,
	gateListOffset = 0,
	mainMouseMapping = {},
	isRunning = true,
	exitMessage = "missingno",
	noResetTerminal = false,
	activeSlot = 0,
	apiTimer = 0,
	timeoutTimer = 0,
	targetAddress = "",
	dialogState = {
		type = "text",
		enabled = false,
		source = "gatelist",
		target = "address",
		textContent = "",
		cursorPos = 1
	},
	borderColor = colors.lightGray,
	debugMessage = {
		active = false,
		message = "",
		timer = 0,
		queue = {}
	}
}
local lastMouseEvent = {
	"mouse_up",
	1, 1, 1
}
local gateStatusPalette = {
	colors.cyan,
	colors.white,
	colors.blue,
	colors.purple,
	colors.orange,
	colors.lightGray
}
local config =  {
	wsURL = settings.get("udhdRemoteAccess.websocketUrl"),
	apiURL = "https://api.rxserver.net/stargates/",
	accessKey = settings.get("udhdRemoteAccess.accessKey"),
	allowUpdates = settings.get("udhdRemoteAccess.allowUpdates"),
	useDevBranch = settings.get("udhdRemoteAccess.useDevBranch")
}
local argStates = {
	update = false,
	noUpdate = false,
	debug = false,
	version = false,
	help = false
}
local colorPalette = {
	colors={colors.lime,colors.red,colors.yellow,colors.black,colors.blue,colors.white,colors.lightBlue},
	codes= {0x00FF00,   0xFF0000,  0xFFFF00,     0x000000,    0x00A0FF,   0xffffff,    0x00eeee}
}

local function init()
	local wasKeyword = nil
	for _, arg in pairs(arguments) do
		if wasKeyword then
			if wasKeyword == "K" then
				config.accessKey = arg
			elseif wasKeyword == "W" then
				config.wsURL = arg
			end
			wasKeyword = nil
		elseif arg == "-K" then
			wasKeyword = "K"
		elseif arg == "-W" then
			wasKeyword = "W"
		elseif arg == "-U" then
			argStates.update = true
			argStates.noupdate = false
			config.allowUpdates = true
		elseif arg == "-V" then
			argStates.version = true
		elseif arg == "-N" then
			argStates.noupdate = true
			argStates.update = false
			config.allowUpdates = false
		elseif arg == "-D" then
		    argStates.debug = true
		elseif arg == "-H" then
			argStates.help = true
		end
	end

	if argStates.version then
		print("udhdRemoteAccess.lua v"..programVersion)
		programVars.isRunning = false
		programVars.noResetTerminal = true
		return
	end

	if argStates.help then
		print("VALID ARGUMENTS LIST")
		print("-K <key> - sets the access key the program will use for authentication")
		print("-U - updates the program then exits")
		print("-W <ws url> - sets the websocket url to use.")
		print("-N - disables the automatic update check")
		print("-D - enable debugging messages")
		print("-H - show this information and exit")
		print("-V - print the program version and exit.")
		programVars.isRunning = false
		programVars.noResetTerminal = true
		return
	end

	if config.allowUpdates then
		--new update function
		print("Checking for Updates...")
		local ws,err = http.websocket(config.wsURL)
		if not ws then
			printError("Update Failed")
			printError(err)
			if argStates.update then
				programVars.isRunning = false
				programVars.noResetTerminal = true
			end
			return
		end
		ws.receive()
		if config.useDevBranch then
			ws.send("-UPDATE_DEV")
		else
			ws.send("-UPDATE")
		end
		local fileConts = ws.receive()
		local success = false
		if string.sub(fileConts,1,#"ERROR:")~="ERROR:" then
			--parse file
			local start1,start2 = string.find(fileConts,"local programVersion = \"")
			local end1,end2 = string.find(fileConts,"\"\n",start2)
			local readVersion = string.sub(fileConts,start2+1,end1-1)
			local validChars = "0123456789."
			local fileValid = true
			for i=1,#readVersion do
				if not string.find(validChars,string.sub(readVersion,i,i)) then
					fileValid = false
				end
			end
			if not fileValid then
				printError("Update Failed")
				printError("Bad program file from server")
			elseif readVersion == programVersion then
				print("Already Up To Date!")
				print("Version: "..programVersion)
			else
				local f = fs.open(shell.getRunningProgram(),"w")
				f.write(fileConts)
				f.close()
				print("Update Completed")
				print("Old Version: "..programVersion)
				print("New Version: "..readVersion)
				success = true
			end
			-- sleep(5)
		else
			printError(fileConts)
			if argStates.update then
				programVars.isRunning = false
				programVars.noResetTerminal = true
			end
		end
		print("Waiting for connection to close...")
		os.pullEvent("websocket_closed")
		if success then
			programVars.isRunning = false
			programVars.noResetTerminal = true
			print()
			print("Please re-run the program.")
			return
		end

	end

	if not term.isColor() then
		programVars.isRunning = false
		programVars.noResetTerminal = true
		print("This program requires an advanced computer or monitor.")
		print("Press enter to continue...")
		read()
		return
	end

	--Convert access key list to json
	local keys = {}
	for key in string.gmatch(config.accessKey, "[^;]+") do
		table.insert(keys,textutils.urlEncode(key))
	end
	config.accessKey = textutils.serialiseJSON(keys)
	
end

local function debugWrite(message)
	if programVars.debugMessage.active then
		table.insert(programVars.debugMessage.queue,message)
	else
		programVars.debugMessage.active = true
		programVars.debugMessage.message = message
		programVars.debugMessage.timer = os.startTimer(3)
	end
end

local function fetchAPI()
	http.request(config.apiURL)
end

local function setBorderColor(color,gate)
	programVars.borderColor = color
	windows.topWindow.setVisible(false)
	local xsize,ysize = windows.topWindow.getSize()
	windows.topWindow.setCursorPos(1,1)
	windows.topWindow.setBackgroundColor(color)
	windows.topWindow.setTextColor(colors.black)
	windows.topWindow.clear()
	windows.topWindow.write("Universal DHD Remote Access v"..programVersion)
	if gate.gateStatus ~= -1 then
		windows.topWindow.setCursorPos(xsize-5,1)
		windows.topWindow.write(" i ")
	end
	windows.topWindow.setCursorPos(xsize-2,1)
	windows.topWindow.setBackgroundColor(colors.red)
	windows.topWindow.setTextColor(colors.white)
	windows.topWindow.write(" X ")
	windows.topWindow.setVisible(true)

	windows.botWindow.setBackgroundColor(color)
	windows.botWindow.clear()
	windows.botWindow.setCursorPos(1,1)
	windows.botWindow.setTextColor(colors.black)
	if argStates.debug and programVars.debugMessage.active then
		windows.botWindow.write(#programVars.debugMessage.queue)
		windows.botWindow.write(" "..programVars.debugMessage.message)
	end
	windows.botWindow.setVisible(true)

	for i=1,4 do
		windows["vertBorder"..i].setVisible(false)
		windows["vertBorder"..i].setBackgroundColor(color)
		windows["vertBorder"..i].clear()
	end
	windows.vertBorder1.setVisible(true)
	if not (programVars.dialogState.enabled and programVars.dialogState.type == "info" and programVars.dialogState.source == "websocket") then
		windows.vertBorder2.setVisible(true)
		windows.vertBorder3.setVisible(true)
	end
	windows.vertBorder4.setVisible(true)
end

local function setupWindows()
	local xsize,ysize = term.getSize()
	windows.dialog.setVisible(false)
	if programVars.dialogState.enabled then
		if programVars.dialogState.type == "info" then
			if programVars.dialogState.source == "gatelist" then
				windows.main.reposition(13,8,xsize-24,ysize-8)
				windows.dialog.reposition(13,2,xsize-24,6)
			else
				windows.dialog.reposition(2,2,xsize-2,ysize-2)
			end
		elseif programVars.dialogState.type == "text" then
			windows.main.reposition(13,2,xsize-24,ysize-7)
			windows.dialog.reposition(13,ysize-5,xsize-24,5)
		else -- exit dialog
			windows.main.reposition(13,6,xsize-24,ysize-6)
			windows.dialog.reposition(13,2,xsize-24,4)
		end
	else
		windows.main.reposition(13,2,xsize-24,ysize-2)
	end
end

local function drawMain()
	local function drawLine(y,isHeader,text,textColor,bgColor,mouseEvent)
		windows.main.setCursorPos(1,y)
		if isHeader then
			windows.main.setBackgroundColor(colors.white)
			windows.main.setTextColor(colors.black)
		else
			windows.main.setBackgroundColor(colors.black)
			windows.main.setTextColor(colors.white)
		end
		windows.main.clearLine()
			if not (textColor and bgColor) then
				windows.main.write(text)
			else
				windows.main.blit(text,textColor,bgColor)
			end
		if mouseEvent then
			programVars.mainMouseMapping[y] = mouseEvent
		end
		return y+1
	end
	windows.main.setVisible(false)
	windows.main.setBackgroundColor(colors.black)
	windows.main.clear()
	local gateData = data.wsList[programVars.activeSlot+1] or {gate_status = -1}
	local gateStatus = gateData.gate_status
	if gateStatus == 0 then 
		gateStatus = 4 
	end
	setBorderColor(gateStatusPalette[gateStatus+2],gateData)
	local allowed = false
	for i, item in pairs(data.perms.allowed) do
		if item == (gateData.slot or -1) then
			allowed = true
		end
	end
	local windx,windy = windows.main.getSize()
	local useSmallForm = windx < 22
	local ypos = 1
	programVars.mainMouseMapping = {}
	if gateStatus == -1 then -- No Data
		ypos = drawLine(ypos,false,"NO DATA","1111111","fffffff")
	else
		if gateData.gate_info.iris_present then --Iris Controls
			ypos = drawLine(ypos,true,"Iris Controls")
			if gateData.udhd_info.idc_present then -- idc data
				local textStr = "Auto Mode: "
				local col1Str = "00000000000"
				local col2Str = "fffffffffff"
				if useSmallForm then
					textStr = "Auto: "
					col1Str = "000000"
					col2Str = "ffffff"
				end
				if gateData.udhd_info.idc_enabled then
					textStr = textStr.."TRUE"
					if allowed then
						col1Str = col1Str.."ffff"
						col2Str = col2Str.."5555"
					else 
						col1Str = col1Str.."5555"
						col2Str = col2Str.."ffff"
					end
				else
					textStr = textStr.."FALSE"
					if allowed then
						col1Str = col1Str.."00000"
						col2Str = col2Str.."eeeee"
					else 
						col1Str = col1Str.."eeeee"
						col2Str = col2Str.."fffff"
					end
				end
				ypos = drawLine(ypos,false,textStr,col1Str,col2Str,{event="idc_toggle",bound1=1,bound2=#textStr})
				local textStr = "Iris Code: "
				if useSmallForm then
					textStr = "Code: "
				end
				ypos = drawLine(ypos,false,textStr..gateData.udhd_info.idc_code,nil,nil,{event="idc_code",bound1=1,bound2=windx})
			end
			local textStr = "Iris State: "
			local col1Str = "000000000000"
			local col2Str = "ffffffffffff"
			if useSmallForm then
				textStr = "State: "
				col1Str = "0000000"
				col2Str = "fffffff"
			end
			if gateData.gate_info.iris_closed then
				textStr = textStr.."CLOSED"
				if allowed then
					col1Str = col1Str.."000000"
					col2Str = col2Str.."eeeeee"
				else 
					col1Str = col1Str.."eeeeee"
					col2Str = col2Str.."ffffff"
				end
			else
				textStr = textStr.."OPEN"
				if allowed then
					col1Str = col1Str.."ffff"
					col2Str = col2Str.."5555"
				else 
					col1Str = col1Str.."5555"
					col2Str = col2Str.."ffff"
				end
			end
			ypos = drawLine(ypos,false,textStr,col1Str,col2Str,{event="iris_toggle",bound1=1,bound2=#textStr})
		end
		if allowed then
			if gateData.control_state == 0 then --main
				ypos = drawLine(ypos,true,"Stargate Dialing")
				
				local textStr = "Target Addr: "..string.sub(programVars.targetAddress.."--------",1,8)
				local col1Str = string.sub("000000000000000000033",1,#textStr)
				local col2Str = string.sub("fffffffffffffffffffff",1,#textStr)
				if useSmallForm then
					textStr = "Target: "..string.sub(programVars.targetAddress.."--------",1,8)
					col1Str = string.sub("0000000000000033",1,#textStr)
					col2Str = string.sub("ffffffffffffffff",1,#textStr)
				end
				ypos = drawLine(ypos,false,textStr,col1Str,col2Str,{event="dial_address",bound1=1,bound2=21})
				ypos = drawLine(ypos,false,"Dial Normally",nil,nil,{event="dial_normal",bound1=1,bound2=13})
				ypos = drawLine(ypos,false,"Dial Instantly",nil,nil,{event="dial_instant",bound1=1,bound2=14})
			elseif gateData.control_state == 1 then --dialing
				ypos = drawLine(ypos,true,"Dialing in Progress")
				ypos = drawLine(ypos,false,"Cancel Dial",nil,nil,{event="cancel",bound1=1,bound2=11})
			elseif gateData.control_state == 2 then --open
				ypos = drawLine(ypos,true,"Wormhole is Open")
				ypos = drawLine(ypos,false,"Close Wormhole",nil,nil,{event="close",bound1=1,bound2=14})
				local textStr, col1Str, col2Str
				if gateData.gate_info.remote_iris then
					textStr = "Remote Iris Detected"
					col1Str = "00000000000000000000"
					col2Str = "eeeeeeeeeeeeeeeeeeee"
				else
					textStr = "No Action Needed"
					col1Str = "ffffffffffffffff"
					col2Str = "5555555555555555"
				end
				ypos = drawLine(ypos,true,textStr,col1Str,col2Str)
				ypos = drawLine(ypos,false,"Send IDC Code",nil,nil,{event="gdo",bound1=1,bound2=13})
			elseif gateData.control_state == 3 then --incoming
				ypos = drawLine(ypos,true,"Incoming Wormhole")
				ypos = drawLine(ypos,false,"Please Wait...")
			elseif gateData.control_state == 4 then --sequence complete
				ypos = drawLine(ypos,true,"Sequence Complete")
				ypos = drawLine(ypos,false,"Please Wait...")
			elseif gateData.control_state == 5 then --closing
				ypos = drawLine(ypos,true,"Closing Wormhole")
				ypos = drawLine(ypos,false,"Please Wait...")
			end
		end
		ypos = drawLine(ypos,true,"Stargate Info")

		local textStr = "Gate Address: "..string.sub(gateData.gate_info.address..gateData.gate_info.type_code,1,8)
		local col1Str = string.sub("0000000000000000000033",1,#textStr)
		local col2Str = string.sub("ffffffffffffffffffffff",1,#textStr)
		if useSmallForm then
			textStr = "Address: "..string.sub(gateData.gate_info.address..gateData.gate_info.type_code,1,8)
			col1Str = string.sub("00000000000000033",1,#textStr)
			col2Str = string.sub("fffffffffffffffff",1,#textStr)
		end
		ypos = drawLine(ypos,false,textStr,col1Str,col2Str)
		
		local textStr = "Dialing Addr: "..string.sub(gateData.gate_info.dialed_address.."--------",1,8)
		local col1Str = string.sub("0000000000000000000033",1,#textStr)
		local col2Str = string.sub("ffffffffffffffffffffff",1,#textStr)
		if useSmallForm then
			textStr = "Dialing: "..string.sub(gateData.gate_info.dialed_address.."--------",1,8)
			col1Str = string.sub("00000000000000033",1,#textStr)
			col2Str = string.sub("fffffffffffffffff",1,#textStr)
		end
		ypos = drawLine(ypos,false,textStr,col1Str,col2Str)


		local textStr = "Cross-Session: "
		local col1Str = "000000000000000"
		local col2Str = "fffffffffffffff"
		if useSmallForm then
			textStr = "CS: "
			col1Str = "0000"
			col2Str = "ffff"
		end
		if gateData.gate_info.cs_enabled then
			textStr = textStr.."TRUE"
			col1Str = col1Str.."5555"
			col2Str = col2Str.."ffff"
		else
			textStr = textStr.."FALSE"
			col1Str = col1Str.."eeeee"
			col2Str = col2Str.."fffff"
		end
		ypos = drawLine(ypos,false,textStr,col1Str,col2Str)
		local textStr = "Gate Ver: "
		if useSmallForm then
			textStr = "Gate: "
		end
		ypos = drawLine(ypos,false,textStr..gateData.gate_info.version)
		local textStr = "UDHD Ver: "
		if useSmallForm then
			textStr = "UDHD: "
		end
		ypos = drawLine(ypos,false,textStr..gateData.udhd_info.version)
		
		ypos = drawLine(ypos,true,"Session Info")
		local textStr = "User Count: "
		if useSmallForm then
			textStr = "Users: "
		end
		ypos = drawLine(ypos,false,textStr..gateData.session_info.user_count.."/"..gateData.session_info.user_limit)
		if gateData.udhd_info.timer_enabled then
			local secStr = tostring(gateData.udhd_info.timer_seconds)
			if #secStr == 1 then
				secStr = "0"..secStr
			end
			local minStr = tostring(gateData.udhd_info.timer_minutes)
			if #minStr == 1 then
				minStr = "0"..minStr
			end
			local tmrStr = gateData.udhd_info.timer_text or "Timer: "
			ypos = drawLine(ypos,false,tmrStr..minStr..":"..secStr)
		end
	end
	if not (programVars.dialogState.enabled and programVars.dialogState.type == "info" and programVars.dialogState.source == "websocket") then
		windows.main.setVisible(true)
	end
end

local function drawGateList()
	local myWindow = windows.gateList
	local xsize,ysize = myWindow.getSize()
	local function drawEntry(ypos,address,code,status,gtype)
		myWindow.setCursorPos(1,ypos)
		myWindow.setBackgroundColor(colors.black)
		myWindow.setTextColor(colors.white)
		myWindow.write(string.sub(address.."------",1,6))
		if gtype == 1 then
			myWindow.setTextColor(colors.lime)
		elseif gtype == 2 then
			myWindow.setTextColor(colors.lightBlue)
		else
			myWindow.setTextColor(colors.red)
		end
		myWindow.write(string.sub(code.."--",1,2))
		if status == 1 then
			myWindow.setTextColor(colors.black)
			myWindow.setBackgroundColor(colors.lime)
		elseif status == 2 then
			myWindow.setTextColor(colors.white)
			myWindow.setBackgroundColor(colors.red)
		else
			myWindow.setTextColor(colors.white)
		end
		myWindow.write("i")
	end
	myWindow.setVisible(false)
	myWindow.setBackgroundColor(colors.black)
	myWindow.setTextColor(colors.white)
	myWindow.clear()
	myWindow.setCursorPos(1,1)
	myWindow.write("Gate List")
	data.genList = {}
	local tempList = {}
	local currentGate = data.wsList[programVars.activeSlot+1] or {gate_list = {}, gate_info = {cs_enabled = false}}

	for i=1,#currentGate.gate_list do
		local temp = currentGate.gate_list[i]
		if temp.gate_open then
			temp.gate_status = "OPEN"
		else
			temp.gate_status = "IDLE"
		end
		temp.session_name = temp.gate_name
		temp.in_session = true
		table.insert(tempList,temp)
	end
	if currentGate.gate_info.cs_enabled then
		for i=1,#data.apiList do
			table.insert(tempList,data.apiList[i])
		end
	end

	for i=1,#tempList do
		local isdupe = false
		for j=i+1,#tempList do
			if tempList[i].gate_address == tempList[j].gate_address then
				isdupe = true
			end
		end
		if not isdupe then
			table.insert(data.genList,tempList[i])
		end
	end

	while ysize+programVars.gateListOffset-2 >= #data.genList and not (programVars.gateListOffset <= 0) do
		programVars.gateListOffset = programVars.gateListOffset - 1
	end
	if programVars.gateListOffset < 0 then
		programVars.gateListOffset = 0
	end
	if programVars.gateListOffset ~= 0 then
		myWindow.write("\x18")
	else
		myWindow.write("|")
	end
	for i=2,ysize do
		local index = i+programVars.gateListOffset-1
		local gate = data.genList[index]
		if gate then
			local status = 0
			if gate.gate_status == "OPEN" then
				if gate.iris_state then
					status = 2
				else
					status = 1
				end
			end
			local gtype = 0
			if gate.is_headless then
				gtype = 1
			end
			if gate.in_session then
				gtype = 2
			end
			drawEntry(i,gate.gate_address,gate.gate_code,status,gtype)
		else
			myWindow.setCursorPos(xsize,i)
			myWindow.clearLine()
		end
		local drawArrow = data.genList[index+1] and i == ysize
		myWindow.setTextColor(colors.white)
		myWindow.setBackgroundColor(colors.black)
		if drawArrow then
			myWindow.write("\x19")
		else
			myWindow.write("|")
		end
	end
	if not (programVars.dialogState.enabled and programVars.dialogState.type == "info" and programVars.dialogState.source == "websocket") then
		myWindow.setVisible(true)
	end
end

local function drawSlotList()
	local myWindow = windows.slotList
	local xsize,ysize = myWindow.getSize()
	local function drawEntry(ypos,address,code,status,gtype,gStatus)
		myWindow.setCursorPos(1,ypos)
		myWindow.setBackgroundColor(colors.black)
		myWindow.setTextColor(gateStatusPalette[gStatus+2])
		myWindow.write(string.sub(address.."------",1,6))
		if gtype then
			myWindow.setTextColor(colors.lime)
		else
			myWindow.setTextColor(colors.red)
		end
		myWindow.write(string.sub(code.."--",1,2))
		if status == 1 then
			myWindow.setTextColor(colors.black)
			myWindow.setBackgroundColor(colors.lime)
		elseif status == 2 then
			myWindow.setTextColor(colors.white)
			myWindow.setBackgroundColor(colors.red)
		else
			myWindow.setTextColor(colors.white)
		end
		myWindow.write("i")
	end
	myWindow.setVisible(false)
	myWindow.setBackgroundColor(colors.black)
	myWindow.setTextColor(colors.white)
	myWindow.clear()
	myWindow.setCursorPos(1,1)
	myWindow.write("Slot List")

	while ysize+programVars.slotListOffset-2 >= #data.wsListCondensed and not (programVars.slotListOffset <= 0) do
		programVars.slotListOffset = programVars.slotListOffset - 1
	end
	if programVars.slotListOffset < 0 then
		programVars.slotListOffset = 0
	end
	if programVars.slotListOffset ~= 0 then
		myWindow.write("\x18")
	else
		myWindow.write("|")
	end
	for i=2,ysize do
		local index = i+programVars.slotListOffset-1
		local gate = data.wsListCondensed[index]
		if gate then
			local status = 0
			if gate.gate_info.open then
				if gate.gate_info.iris_closed then
					status = 2
				else
					status = 1
				end
			end
			local perms = false
			for j=1,#data.perms.allowed do
				if data.perms.allowed[j] == gate.slot then
					perms = true
				end
			end
			drawEntry(i,gate.gate_info.address,gate.gate_info.type_code,status,perms,gate.gate_status)
		else
			myWindow.setCursorPos(xsize,i)
			myWindow.clearLine()
		end
		local drawArrow = data.wsListCondensed[index+1] and i == ysize
		myWindow.setTextColor(colors.white)
		myWindow.setBackgroundColor(colors.black)
		if drawArrow then
			myWindow.write("\x19")
		else
			myWindow.write("|")
		end
	end
	if not (programVars.dialogState.enabled and programVars.dialogState.type == "info" and programVars.dialogState.source == "websocket") then
		myWindow.setVisible(true)
	end
end

local function drawDialog()
	local xsize,ysize = term.getSize()
	local dialog = windows.dialog
	if programVars.dialogState.type ~= "text" or not programVars.dialogState.enabled then
		dialog.setCursorBlink(false)
	end
	if programVars.dialogState.enabled then
		if programVars.dialogState.type == "info" then
			if programVars.dialogState.source == "gatelist" then
				dialog.setBackgroundColor(colors.black)
				dialog.clear()
				dialog.setBackgroundColor(programVars.borderColor)
				dialog.setCursorPos(1,6)
				dialog.clearLine()
				dialog.setBackgroundColor(colors.white)
				dialog.setCursorPos(1,1)
				dialog.clearLine()
				dialog.setBackgroundColor(colors.red)
				dialog.setTextColor(colors.white)
				local windx,windy = dialog.getSize()
				dialog.setCursorPos(windx-2,1)
				dialog.write(" X ")
				dialog.setCursorPos(1,1)
				dialog.setBackgroundColor(colors.white)
				dialog.setTextColor(colors.black)
				dialog.write("Gate Info")
				local gate
				for i, sg in pairs(data.genList) do
					if sg.gate_address == programVars.dialogState.target then
						gate = sg
					end
				end
				if not gate then 
					programVars.dialogState.enabled = false
					os.queueEvent("refresh")
					return 
				end
				dialog.setCursorPos(1,2)
				dialog.setBackgroundColor(colors.black)
				dialog.setTextColor(colors.white)
				dialog.write("Address: "..gate.gate_address)
				if gate.is_headless then -- Note: implement in-session code when new data structure is released
					dialog.setTextColor(colors.lime)
				else
					dialog.setTextColor(colors.red)
				end
				if gate.in_session then
					dialog.setTextColor(colors.lightBlue)
				end
				dialog.write(gate.gate_code)
				dialog.setTextColor(colors.white)
				dialog.setCursorPos(1,3)
				dialog.write("Name: "..gate.session_name)
				if gate.in_session then
					dialog.setCursorPos(1,4)
					dialog.write("In-Session GateList Item")
					dialog.setCursorPos(1,5)
					dialog.write("Some Data Not Available")
				else
					dialog.setCursorPos(1,4)
					dialog.write("Host: "..gate.owner_name)
					dialog.setCursorPos(1,5)
					dialog.write("Users: "..gate.active_users.."/"..gate.max_users)
				end
			else
				dialog.setBackgroundColor(colors.black)
				dialog.clear()
				dialog.setBackgroundColor(colors.white)
				dialog.setCursorPos(1,1)
				dialog.clearLine()
				dialog.setBackgroundColor(colors.red)
				dialog.setTextColor(colors.white)
				local windx,windy = dialog.getSize()
				dialog.setCursorPos(windx-2,1)
				dialog.write(" X ")
				dialog.setCursorPos(1,1)
				dialog.setBackgroundColor(colors.white)
				dialog.setTextColor(colors.black)
				dialog.write("Slot Info")
				local gate = data.wsList[programVars.dialogState.target]
				if not gate then 
					programVars.dialogState.enabled = false
					os.queueEvent("refresh")
					return 
				end
				dialog.setTextColor(colors.white)
				dialog.setBackgroundColor(colors.black)
				dialog.setCursorPos(1,2)
				dialog.write("Slot Number: "..gate.slot)
				dialog.setCursorPos(1,3)
				dialog.write("Address: "..gate.gate_info.address)
				local allowed = false
				for i=1,#data.perms.allowed do
					if data.perms.allowed[i] == gate.slot then
						allowed = true
					end
				end
				if allowed then
					dialog.setTextColor(colors.lime)
				else
					dialog.setTextColor(colors.red)
				end
				dialog.write(gate.gate_info.type_code)
				dialog.setTextColor(colors.white)
				dialog.setCursorPos(1,4)
				dialog.write("World Name: "..gate.session_info.world_name)
				dialog.setCursorPos(1,5)
				dialog.write("Gate Name: "..gate.gate_info.name)
				dialog.setCursorPos(1,6)
				dialog.write("Host: "..gate.session_info.host_user)
				dialog.setCursorPos(1,7)
				dialog.write("Users: "..gate.session_info.user_count .."/"..gate.session_info.user_limit)
				dialog.setCursorPos(1,8)
				dialog.write("CS Enabled: ")
				if gate.gate_info.cs_enabled then
					dialog.setTextColor(colors.lime)
					dialog.write("TRUE")
				else
					dialog.setTextColor(colors.red)
					dialog.write("FALSE")
				end
				dialog.setCursorPos(1,9)
				dialog.setTextColor(colors.white)
				dialog.write("CS Visible: ")
				if gate.gate_info.cs_visible then
					dialog.setTextColor(colors.lime)
					dialog.write("TRUE")
				else
					dialog.setTextColor(colors.red)
					dialog.write("FALSE")
				end
				dialog.setTextColor(colors.white)
				dialog.setCursorPos(1,10)
				local accessLevelString = ""
				if gate.session_info.is_hidden then
					accessLevelString = "Hidden, "
				end
				if gate.session_info.access_level == 0 then
					accessLevelString = accessLevelString.."Private (invite only)"
				elseif gate.session_info.access_level == 1 then
					accessLevelString = accessLevelString.."LAN"
				elseif gate.session_info.access_level == 2 then
					accessLevelString = accessLevelString.."Contacts"
				elseif gate.session_info.access_level == 3 then
					accessLevelString = accessLevelString.."Contacts+"
				elseif gate.session_info.access_level == 4 then
					accessLevelString = accessLevelString.."Registered Users"
				else
					accessLevelString = accessLevelString.."Anyone"
				end
				dialog.write("Access Level: "..accessLevelString)
				dialog.setCursorPos(1,11)
				dialog.write("Websocket User: "..gate.udhd_info.websocket_user)
				dialog.setCursorPos(1,12)
				dialog.write("Gate Version: "..gate.gate_info.version)
				dialog.setCursorPos(1,13)
				dialog.write("UDHD Version: "..gate.udhd_info.version)
				if gate.udhd_info.timer_enabled then
					local secStr = tostring(gate.udhd_info.timer_seconds)
					if #secStr == 1 then
						secStr = "0"..secStr
					end
					local minStr = tostring(gate.udhd_info.timer_minutes)
					if #minStr == 1 then
						minStr = "0"..minStr
					end
					local tmrStr = gate.udhd_info.timer_text or "Timer: "
					dialog.setCursorPos(1,14)
					dialog.write(tmrStr..minStr..":"..secStr)
				end
			end
		elseif programVars.dialogState.type == "text" then
			dialog.setBackgroundColor(colors.black)
			dialog.clear()
			dialog.setBackgroundColor(programVars.borderColor)
			dialog.setCursorPos(1,1)
			dialog.clearLine()
			dialog.setBackgroundColor(colors.white)
			dialog.setCursorPos(1,2)
			dialog.clearLine()
			dialog.setBackgroundColor(colors.red)
			dialog.setTextColor(colors.white)
			local windx,windy = dialog.getSize()
			dialog.setCursorPos(windx-2,2)
			dialog.write(" X ")
			dialog.setCursorPos(1,2)
			dialog.setBackgroundColor(colors.white)
			dialog.setTextColor(colors.black)
			local gate = data.wsList[programVars.activeSlot+1]
			local allowed = false
			if not gate and programVars.dialogState.target ~= "address" then
				programVars.dialogState.enabled = false
				os.queueEvent("refresh")
				return
			elseif gate then
				for i,slot in pairs(data.perms.allowed) do
					if slot == gate.slot then
						allowed = true
					end
				end
			end
			if programVars.dialogState.target == "address" then
				dialog.write("Address Input")
				dialog.setCursorPos(1,3)
				dialog.setBackgroundColor(colors.black)
				dialog.setTextColor(colors.white)
				dialog.write("Enter New Target Address")
			elseif programVars.dialogState.target == "idc" then
				if not (gate.gate_info.iris_present and gate.udhd_info.idc_present and allowed) then
					programVars.dialogState.enabled = false
					os.queueEvent("refresh")
					return
				end
				dialog.write("IDC Input - "..string.sub(gate.gate_info.address.."------",1,6))
				dialog.setBackgroundColor(colors.lightBlue)
				dialog.write(string.sub(gate.gate_info.type_code.."--",1,2))
				dialog.setCursorPos(1,3)
				dialog.setBackgroundColor(colors.black)
				dialog.setTextColor(colors.white)
				dialog.write("Enter New IDC Code")
			else
				if gate.control_state ~= 2 or not allowed then
					programVars.dialogState.enabled = false
					os.queueEvent("refresh")
					return
				end
				local addr = string.sub(gate.gate_info.dialed_address,1,6)
				local group = string.sub(gate.gate_info.dialed_address,7,8)
				dialog.write("GDO Input - "..string.sub(addr.."------",1,6))
				dialog.setBackgroundColor(colors.lightBlue)
				dialog.write(string.sub(group.."--",1,2))
				dialog.setCursorPos(1,3)
				dialog.setBackgroundColor(colors.black)
				dialog.setTextColor(colors.white)
				dialog.write("Enter IDC Code to send")
			end
			dialog.setCursorPos(3,5)
			dialog.write("Confirm")
			dialog.setCursorPos(windx-7,5)
			dialog.write("Cancel")
			dialog.setCursorPos(1,4)
			if programVars.dialogState.target == "address" then
				local fullCont = string.sub(programVars.dialogState.content.."--------",1,8)
				dialog.write(string.sub(fullCont,1,6))
				dialog.setTextColor(colors.lightBlue)
				dialog.write(string.sub(fullCont,7,8))
				local cursorPos = #programVars.dialogState.content+1
				dialog.setCursorPos(cursorPos,4)
				dialog.setCursorBlink(cursorPos < 9)
				if cursorPos < 7 then
					dialog.setTextColor(colors.white)
				end
			else
				if #programVars.dialogState.content >= windx then
					dialog.write("\171")
					dialog.write(string.sub(programVars.dialogState.content,-(windx-2)))
				else
					dialog.write(programVars.dialogState.content)
				end
				dialog.setCursorBlink(true)
			end
		else --Exit Dialog
			dialog.setBackgroundColor(colors.black)
			dialog.clear()
			dialog.setBackgroundColor(programVars.borderColor)
			dialog.setCursorPos(1,4)
			dialog.clearLine()
			dialog.setBackgroundColor(colors.white)
			dialog.setCursorPos(1,1)
			dialog.clearLine()
			dialog.setBackgroundColor(colors.red)
			dialog.setTextColor(colors.white)
			local windx,windy = dialog.getSize()
			dialog.setCursorPos(windx-2,1)
			dialog.write(" X ")
			dialog.setCursorPos(1,1)
			dialog.setBackgroundColor(colors.white)
			dialog.setTextColor(colors.black)
			dialog.write("Confirm Action")
			dialog.setCursorPos(1,2)
			dialog.setBackgroundColor(colors.black)
			dialog.setTextColor(colors.white)
			dialog.write("Exit Program?")
			dialog.setCursorPos(3,3)
			dialog.write("Confirm")
			dialog.setCursorPos(windx-7,3)
			dialog.write("Cancel")
		end
		dialog.setVisible(true)
	end
end

local function defineWindows()
	local xsize,ysize = term.getSize()
	for i=1,#colorPalette.colors do
		term.setPaletteColor(colorPalette.colors[i],colorPalette.codes[i])
	end
	--Header Bar
	windows.topWindow = window.create(baseTerm,1,1,xsize,1,false)

	--Footer bar
	windows.botWindow = window.create(baseTerm,1,ysize,xsize,1,false)

	-- Vertical Borders
	local vertBorderY1 = 2
	local vertBorderYh = ysize-2
	windows.vertBorder1 = window.create(baseTerm,1,vertBorderY1,1,vertBorderYh,false)
	windows.vertBorder2 = window.create(baseTerm,12,vertBorderY1,1,vertBorderYh,false)
	windows.vertBorder3 = window.create(baseTerm,xsize-11,vertBorderY1,1,vertBorderYh,false)
	windows.vertBorder4 = window.create(baseTerm,xsize,vertBorderY1,1,vertBorderYh,false)

	--Dialog Window (most versatile)
	windows.dialog = window.create(baseTerm,1,1,1,1,false) -- basic init - will be configured later by setupWindows()
	--GateList Window
	windows.gateList = window.create(baseTerm,2,2,10,ysize-2,false)
	drawGateList()

	--SlotList Window
	windows.slotList = window.create(baseTerm,xsize-10,2,10,ysize-2,false)
	drawSlotList()

	--Main Window
	windows.main = window.create(baseTerm,13,2,xsize-24,ysize-2,false)
	drawMain()
end

local function wsHandler(event)
	if event[3] == "INPUT USER" then
		programVars.ws.send(config.accessKey)
	else
		local packet, err = textutils.unserializeJSON(event[3])
		if packet.type == "perms" then
			data.perms = packet
			for i, slot in pairs(data.wsList) do
				local found = false
				for j=1,#packet.online do
					if packet.online[j] == i-1 then
						found = true
					end
				end
				if not found then
					data.wsList[i] = nil
				end
			end
		elseif packet.type == "stargate" then
			if packet.gateStatus == -1 then
				local slotNo = packet.slot
				data.wsList[slotNo+1] = nil
			else
				local slotNo = packet.slot
				data.wsList[slotNo+1] = packet
			end
		end
		data.wsListCondensed = {}
		for i, slot in pairs(data.wsList) do
			table.insert(data.wsListCondensed,slot)
		end
	end
end


local function sendCommand(command,parameter)
	if parameter then
		command = command..parameter
	end
	local slotStr = tostring(programVars.activeSlot)
	if #slotStr == 1 then
		slotStr = "0"..slotStr
	end
	debugWrite("Sent: "..slotStr..command)
	programVars.ws.send(slotStr..command)
end


local function keyHandler(event)
	local validGlyphs = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@*"
	if not (programVars.dialogState.enabled and programVars.dialogState.type == "text") then
		return
	end
	if event[1] == "char" then
		if programVars.dialogState.target == "address" then
			if #programVars.dialogState.content >= 8 then 
				return 
			end
			local raw = string.upper(event[2])
			local currText = programVars.dialogState.content
			if string.find(currText,raw,1,true) or not string.find(validGlyphs,raw,1,true) then
				return
			end
			programVars.dialogState.content = programVars.dialogState.content..raw
		else
			programVars.dialogState.content = programVars.dialogState.content..event[2]
		end
	else --key
		if event[2] == keys.enter then
			--confirm dialog
			if programVars.dialogState.target == "address" then
				programVars.targetAddress = programVars.dialogState.content
			elseif programVars.dialogState.target == "idc" then
				sendCommand(7,programVars.dialogState.content)
			elseif programVars.dialogState.target == "gdo" then
				sendCommand(8,programVars.dialogState.content)
			end
			programVars.dialogState.enabled = false
		elseif event[2] == keys.backspace then
			--backspace
			if #programVars.dialogState.content > 0 then
				programVars.dialogState.content = string.sub(programVars.dialogState.content,1,-2)
			end
		end
	end
end

local function mouseHandler(event)
	local function spawnAddressDialog()
		programVars.dialogState.enabled = true
		programVars.dialogState.type = "text"
		programVars.dialogState.target = "address"
		programVars.dialogState.content = programVars.targetAddress
		programVars.dialogState.cursorPos = #programVars.dialogState.content+1
	end
	local function dialNormal()
		sendCommand(1,programVars.targetAddress)
	end
	local function dialInstant()
		sendCommand(2,programVars.targetAddress)
	end
	local function spawnIDCDialog()
		programVars.dialogState.enabled = true
		programVars.dialogState.type = "text"
		programVars.dialogState.target = "idc"
		local gate = data.wsList[programVars.activeSlot+1]
		programVars.dialogState.content = gate.udhd_info.idc_code
		programVars.dialogState.cursorPos = #programVars.dialogState.content+1
	end
	local function spawnGDODialog()
		programVars.dialogState.enabled = true
		programVars.dialogState.type = "text"
		programVars.dialogState.target = "gdo"
		programVars.dialogState.content = ""
		programVars.dialogState.cursorPos = 1
	end
	local eventList = {
		dial_address = spawnAddressDialog,
		dial_normal = dialNormal,
		dial_instant = dialInstant,
		cancel = 3,
		close = 4,
		iris_toggle = 5,
		idc_toggle = 6,
		idc_code = spawnIDCDialog,
		gdo = spawnGDODialog
	}
	local mx,my = event[3],event[4]
	local wind
	local windName = ""
	local function checkBounds(wind,mx,my)
		local x1,y1 = wind.getPosition()
		local x2,y2 = wind.getSize()
		x2,y2 = x2+x1-1,y2+y1-1
		return (mx >= x1 and mx <= x2 and my >= y1 and my <= y2 and wind.isVisible())
	end
	local function adjustBounds(wind,mx,my)
		local x1,y1 = wind.getPosition()
		return mx-x1+1,my-y1+1
	end
	if checkBounds(windows.main,mx,my) then -- Main Window
		wind = windows.main
		windName = "main"
	elseif checkBounds(windows.gateList,mx,my) then
		wind = windows.gateList
		windName = "gateList"
	elseif checkBounds(windows.slotList,mx,my) then
		wind = windows.slotList
		windName = "slotList"
	elseif checkBounds(windows.topWindow,mx,my) then
		wind = windows.topWindow
		windName = "top"
	elseif checkBounds(windows.dialog,mx,my) then
		wind = windows.dialog
		windName = "dialog"
	end
	if wind then
		mx,my = adjustBounds(wind,mx,my)
		if event[1] == "mouse_scroll" then
			if windName == "slotList" then
				programVars.slotListOffset = programVars.slotListOffset + event[2]
			elseif windName == "gateList" then
				programVars.gateListOffset = programVars.gateListOffset + event[2]
			end
		elseif event[1] == "mouse_up" and lastMouseEvent[1] == "mouse_click" then
			local windx,windy = wind.getSize()
			if windName == "slotList" then
				 if mx == windx then --Arrow Buttons
					if my == 1 then
						programVars.slotListOffset = programVars.slotListOffset - 1
					elseif my == windy then
						programVars.slotListOffset = programVars.slotListOffset + 1
					end
				elseif my ~= 1 then
					local gate = data.wsListCondensed[my+programVars.slotListOffset-1]
					if gate then
						if mx >= windx-1 then
							programVars.dialogState.enabled = true
							programVars.dialogState.type = "info"
							programVars.dialogState.source = "websocket"
							programVars.dialogState.target = (gate.slot or 0) + 1
						else
							programVars.activeSlot = gate.slot or 0
						end
					end
				else
					programVars.ws.send("-QUERY")
				end
			elseif windName == "gateList" then
				if mx == windx then --Arrow Buttons
					if my == 1 then
						programVars.gateListOffset = programVars.gateListOffset - 1
					elseif my == windy then
						programVars.gateListOffset = programVars.gateListOffset + 1
					end
				elseif my ~= 1 then
					local gate = data.genList[my+programVars.gateListOffset-1]
					if gate then
						if mx == windx-1 then
							programVars.dialogState.enabled = true
							programVars.dialogState.type = "info"
							programVars.dialogState.source = "gatelist"
							programVars.dialogState.target = gate.gate_address
						else
							programVars.targetAddress = gate.gate_address..gate.gate_code
							if programVars.dialogState.enabled and programVars.dialogState.type == "text" and programVars.dialogState.target == "address" then
								programVars.dialogState.content = gate.gate_address..gate.gate_code
							end
						end
					end
				else
					fetchAPI()
				end
			elseif windName == "top" then
				if mx > windx-3 then
					--EXIT
					if programVars.dialogState.enabled and programVars.dialogState.type == "exit" then
						programVars.isRunning = false
						programVars.exitMessage = "Program Closed by User"
					else
						programVars.dialogState.enabled = true
						programVars.dialogState.type = "exit"
					end
				elseif mx > windx-6 then
					local index = programVars.activeSlot+1
					if data.wsList[index] then
						programVars.dialogState.enabled = true
						programVars.dialogState.type = "info"
						programVars.dialogState.source = "websocket"
						programVars.dialogState.target = index
					end
				end
			elseif windName == "dialog" then
				if programVars.dialogState.type == "text" then
					my = my - 1
				end
				windy = windy-1
				if mx > windx-3 and my == 1 then
					programVars.dialogState.enabled = false
				end
				if programVars.dialogState.type ~= "info" and my == windy then
					-- bottom buttons
					if mx >= 3 and mx <= 9 then
						-- confirm action
						if programVars.dialogState.type == "exit" then
							programVars.isRunning = false
							programVars.exitMessage = "Program Closed by User"
						else
							--text dialog
							if programVars.dialogState.target == "address" then
								programVars.targetAddress = programVars.dialogState.content
							elseif programVars.dialogState.target == "idc" then
								sendCommand(7,programVars.dialogState.content)
							elseif programVars.dialogState.target == "gdo" then
								sendCommand(8,programVars.dialogState.content)
							end
						end
						programVars.dialogState.enabled = false
					elseif mx >= windx-7 and mx <= windx-2 then
						--cancel action
						programVars.dialogState.enabled = false
					end
				end
			elseif windName == "main" then
				local line = programVars.mainMouseMapping[my]
				if line then
					if mx >= line.bound1 and mx <= line.bound2 then
						if type(eventList[line.event]) == "function" then
							eventList[line.event]()
						else
							sendCommand(eventList[line.event])
						end
					end
				end
			end
		elseif event[1] == "mouse_drag" then
			local amnt = lastMouseEvent[4] - event[4]
			if windName == "slotList" then
				programVars.slotListOffset = programVars.slotListOffset + amnt
			elseif windName == "gateList" then
				programVars.gateListOffset = programVars.gateListOffset + amnt
			else
				if lastMouseEvent[1] == "mouse_click" then
					event[1] = "mouse_scroll" -- hacky way of ignoring the drag event
				end
			end
		end
	end
	if event[1] ~= "mouse_scroll" then
		lastMouseEvent = event
	end
end


local function apiHandler(event)
	data.apiList = {}
	if event[1] == "http_success" then
		local success, err = textutils.unserializeJSON(event[3].readAll())
		if success then
			data.apiList = success
		else
			debugWrite("API Fail: "..tostring(err))
		end
	else
		debugWrite("API Fail: "..tostring(event[3]))
	end
end


local function main()
	init()
	if programVars.isRunning then
		print("Connecting...")
		local ws,err = http.websocket(config.wsURL)
		programVars.ws = ws
		if programVars.ws then
			programVars.isRunning = true
			programVars.apiTimer = os.startTimer(30)
			programVars.timeoutTimer = os.startTimer(40)
			fetchAPI()
			defineWindows()
		else
			programVars.exitMessage = err
			programVars.isRunning = false
		end
	end
	while programVars.isRunning do
		setupWindows()
		drawMain()
		drawGateList()
		drawSlotList()
		drawDialog()
		local event = {os.pullEventRaw()}
		if event[1] == "websocket_message" then
			os.cancelTimer(programVars.timeoutTimer)
			programVars.timeoutTimer = os.startTimer(40)
			wsHandler(event)
		elseif event[1] == "mouse_click" then
			mouseHandler(event)
		elseif event[1] == "mouse_drag" then
			mouseHandler(event)
		elseif event[1] == "mouse_up" then
			mouseHandler(event)
		elseif event[1] == "mouse_scroll" then
			mouseHandler(event)
		elseif event[1] == "char" then
			keyHandler(event)
		elseif event[1] == "key" then
			keyHandler(event)
		elseif event[1] == "websocket_closed" then
			--connection closed
			programVars.isRunning = false
			programVars.exitMessage = "Connection Closed"
		elseif event[1] == "terminate" then
			programVars.isRunning = false
			programVars.exitMessage = "Terminated"
		elseif event[1] == "timer" then
			if event[2] == programVars.timeoutTimer then
				programVars.isRunning = false
				programVars.exitMessage = "Connection Timed Out"
			elseif event[2] == programVars.apiTimer then
				fetchAPI()
				programVars.apiTimer = os.startTimer(30)
			elseif event[2] == programVars.debugMessage.timer then
				if #programVars.debugMessage.queue > 0 then
					local newQueue = {}
					local isFirstIteration = true
					for _,item in pairs(programVars.debugMessage.queue) do
						if isFirstIteration then
							programVars.debugMessage.message = item
							isFirstIteration = false
						else
							table.insert(newQueue,item)
						end
					end
					programVars.debugMessage.queue = newQueue
					programVars.debugMessage.timer = os.startTimer(3)
				else
					programVars.debugMessage.active = false
				end
			end
		elseif event[1] == "http_success" then
			apiHandler(event)
		elseif event[1] == "http_failure" then
			apiHandler(event)
		elseif event[1] == "term_resize" then
			defineWindows()
		end
	end
end

local success, err = pcall(main)

for i=1,#colorPalette.colors do
	term.setPaletteColor(colorPalette.colors[i],term.nativePaletteColor(colorPalette.colors[i]))
end

if programVars.ws then
	pcall(programVars.ws.close)
end
if not success then
	programVars.exitMessage = err
	programVars.noResetTerminal = false
end
if not programVars.noResetTerminal then
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.setCursorPos(1,1)
	term.clear()
	printError(programVars.exitMessage)
end