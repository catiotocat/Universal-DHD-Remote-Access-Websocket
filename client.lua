-- This program was designed to run inside of CraftOS-PC
-- You can download CraftOS-PC from https://www.craftos-pc.cc/

--The following few lines of code transfer the config to the new setting variables
local configStrings = {"accessKey","websocketUrl","allowUpdates"}
for i=1,#configStrings do
	item = configStrings[i]
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
	default="wss://catio.merith.xyz/ws/",
	type="string"
})
settings.define("udhdRemoteAccess.allowUpdates",{
    description="Set to false to disable automatic updates", 
    default = true, 
    type="boolean"
})
settings.save() --save all changes to the computer settings

local args = {...}
local parsed = {}
local argLoop = false
local argUpdate = false
local argNoUpdate = false
myArgs = ""
local argKey = nil
local argUrl = nil
local argHelp = false
local argDebug = false

local wasKeyword = nil

local sgURL = "https://api.rxserver.net/stargates/"

if not settings.get("udhdRemoteAccess.allowUpdates") then
    argNoUpdate = true
end

for _, arg in pairs(args) do
    if wasKeyword then
        if wasKeyword == "K" then
            argKey = arg
		elseif wasKeyword == "W" then
			argUrl = arg
		end
        wasKeyword = nil
    elseif arg == "-K" then
        wasKeyword = "K"
	elseif arg == "-W" then
		wasKeyword = "W"
    elseif arg == "-U" then
        argUpdate = true
    elseif arg == "-N" then
        argNoUpdate = true
    elseif arg == "-L" then
        argLoop = true
    elseif arg == "-D" then
        argDebug = true
    elseif arg == "-H" then
        argHelp = true
    end
end

if argHelp then
    print("VALID ARGUMENTS LIST")
    print("-K <key> - sets the access key the program will use for authentication")
    print("-U - updates the program")
	print("-W <ws url> sets the websocket url to use.")
    print("-N - disables the automatic update check")
    print("-L - runs the program in a loop.")
    print("-D - enable debugging messages")
    print("-H - show this information")
    return
end

local wsURL = argUrl or settings.get("udhdRemoteAccess.websocketUrl")

function update()
    print("Checking for Updates...")
    local ws,err = http.websocket(wsURL)
    if not ws then 
        printError("Update Failed")
        printError(err)
        return
    end
	ws.receive()
    ws.send("-UPDATE")
    local fileConts = ws.receive()
	local success = false
	if string.sub(fileConts,1,#"ERROR:")~="ERROR:" then
		local f = fs.open(shell.getRunningProgram(),"r")
		local og = f.readAll()
		f.close()
		if og ~= fileConts then
			local f = fs.open(shell.getRunningProgram(),"w")
			f.write(fileConts)
			f.close()
			print("Update Completed")
			success = true
		else
			print("Already Up To Date")
		end
	else
		printError(fileConts)
	end
	print("Waiting for connection to close...")
    os.pullEvent("websocket_closed")
	return success
end

if argUpdate then
    argNoUpdate = false
    argLoop = false
    update()
    return
end

if argKey then
	myArgs = myArgs.." -K "..argKey
end
if argLoop then
	myArgs = myArgs.." -L"
end
if argDebug then
    myArgs = myArgs.." -D"
end
if argUrl then
	myArgs = myArgs.." -W "..argUrl
end
local loopEnd = false
if argLoop then
    repeat
        local layeredArgs = " -N "
        if not argNoUpdate then
            if update() then
				shell.run(shell.getRunningProgram()..myArgs)
				loopEnd = true
				break
			end
        end
		if not loopEnd then
			if argKey then
				layeredArgs = layeredArgs.."-K "..argKey.." "
			end
			if argUrl then
				layeredArgs = layeredArgs.."-W "..argUrl.." "
			end
			if argDebug then
				layeredArgs = layeredArgs.."-D "
			end
			print("Running...")
			sleep(1)
			shell.run(shell.getRunningProgram()..layeredArgs)
			sleep(5)
		end
    until loopEnd
    return
end

if not argNoUpdate then
	if update() then
		shell.run(shell.getRunningProgram()..myArgs)
		return
	end
end

activeSlot = 0
local accessKey = argKey or settings.get("udhdRemoteAccess.accessKey")

isRunning = true
xsize,ysize = term.getSize()
local apiList = {} -- Stores raw api data as a table
local apiTbl = {} --Stores api data as tables keyed by gate address
local wsTbl = {} --Stores ws data as tables keyed by slot (strings)
dialogState = {active=false,type="txt",id=1,text="",importantCoords={{type=0,x1=1,x2=1,y=1}},corner={x=1,y=1}}
local buttonPOS = {}
local wsColors = {colors.lightGray,colors.lightGray,colors.white,colors.lightBlue,colors.blue,colors.yellow,colors.red}
local gateColor = colors.white
exitMessage = "missingno" --message shown on program exit
local slotListMode = false -- WS List is shown when true
local maxSlot = 0
pageNumber = 1
local pageCount = 0
print("Connecting...")
ws,err = http.websocket(wsURL)
if not ws then printError(err) return end
local tmr = 0
local clearDialog = 0
local wsRemap = {}
local permsObtained = false
local apiPage = {}
local wsPage = {}
targetAddress = ""
term.setPaletteColor(colors.lime,0x00FF00)
term.setPaletteColor(colors.red,0xFF0000)
term.setPaletteColor(colors.yellow,0xFFFF00)
term.setPaletteColor(colors.black,0x000000)
term.setPaletteColor(colors.blue,0x00A0FF)
term.setPaletteColor(colors.white,0xe5e5e5)
term.setPaletteColor(colors.lightBlue,0x00ffff)
local timeoutTimer = os.startTimer(40)
local callChain = {{"init"}}
debugDialogState = {visible = false,timerid = 0, text = "missingno"}

local function dumpState()
    local dumpTbl = {}
    local dataTbl = {
        apiList = apiList,
        wsTbl = wsTbl
    }
    dumpTbl.pageInfo = {
        count=pageCount,
        active=pageNumber,
        ws=wsPage,
        api=apiPage,
        mode=slotListMode
    }
    dumpTbl.misc = {
        maxSlot=maxSlot,
        permsObtained=permsObtained,
        wsRemap=wsRemap,
        activeSlot=activeSlot,
        color=gateColor,
        buttonPOS = buttonPOS,
        dialogState=dialogState,
        termSize =  {x=xsize,y=ysize},
        targetAddress = targetAddress
    }
    dumpTbl.runtime = {
        running=isRunning,
        args=args,
        exitMsg=exitMessage,
        accessKey=accessKey,
        callChain=callChain
    }
    return dumpTbl,dataTbl
end

function saveDump()
    local dumped,data = dumpState()
    local f = fs.open("/client.dump","w")
    local str = textutils.serialize(dumped,{allow_repetitions=true})
    f.write(str)
    f.close()
    local f = fs.open("/client.data","w")
    local str = textutils.serialize(data,{allow_repetitions=true})
    f.write(str)
    f.close()
end

local function drawDebugDialog()
    table.insert(callChain,{"drawDebugDialog"})
    local x,y = 1,1
    if debugDialogState.visible then
        term.setCursorPos(1,ysize)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.gray)
        term.write(debugDialogState.text)
        x,y = term.getCursorPos()
	    paintutils.drawLine(x,ysize,xsize,ysize,colors.gray)
    else
	    paintutils.drawLine(1,ysize,xsize-11,ysize,colors.black)
    end
    table.remove(callChain,#callChain)
end

function writeDebugDialog(text)
    table.insert(callChain,{"writeDebugDialog",text})
    if argDebug then
        debugDialogState.visible = true
        debugDialogState.text = text
        debugDialogState.timer = os.startTimer(5)
        drawDebugDialog()
    end
    table.remove(callChain,#callChain)
end

local function drawDialog() --Handles Dialog Box Display
    table.insert(callChain,{"drawDialog"})
    if dialogState.active == false then
		term.setCursorBlink(false)
        table.remove(callChain,#callChain)
        return
    end
	if dialogState.type == "exit" then
        term.setCursorPos(1,2)
		local windSize = 22
		local wind = window.create(term.current(),1,2,windSize,3)
		dialogState.corner.x = windSize
		dialogState.corner.y = 6
		wind.setBackgroundColor(colors.gray)
        wind.setTextColor(colors.white)
		wind.clear()
		wind.setCursorPos(1,1)
		wind.write("CONFIRM ACTION")
		wind.setCursorPos(1,2)
		wind.write("EXIT PROGRAM?")
		wind.setCursorPos(1,3)
		wind.write(" CONFIRM       CANCEL")
		wind.setBackgroundColor(colors.red)
		wind.setCursorPos(windSize-2,1)
		wind.write(" X ")
		wind.setBackgroundColor(colors.gray)
		dialogState.importantCoords = {
			{type=0,y=2,x1=windSize-2,x2=windSize},
			{type=1,y=4,x1=2,x2=8},
			{type=0,y=4,x1=windSize-6,x2=windSize-1}
		}
        wind.setCursorPos(1,4)
		if dialogState.id == 1 then
			wind.write(string.sub(dialogState.text,1,6))
			wind.setTextColor(colors.lime)
			wind.write(string.sub(dialogState.text,7,8))
			if #dialogState.text < 6 then
			    wind.setTextColor(colors.white)
			end   
			if #dialogState.text < 8 then
				wind.setCursorBlink(true)
			end
		else
		    if #dialogState.text > windSize-1 then
		        wind.write("\171")
		        wind.write(string.sub(dialogState.text,-(windSize-2)))
		    else
			    wind.write(dialogState.text)
			end
			wind.setCursorBlink(true)
		end
	elseif dialogState.type == "sg" then
        local dataSet = apiTbl[tostring(dialogState.id)]
        term.setCursorPos(1,2)
		local str0 = "ADDR: "..dialogState.id
		local str1 = "NAME: Gate Offline"
		local str2 = "HOST: nil"
		local str3 = "USERS: -/-"
        if dataSet then
            str1 = "NAME: "..dataSet.session_name
			str2 = "HOST: "..dataSet.owner_name
			str3 = "USERS: "..tostring(dataSet.active_users).."/"..tostring(dataSet.max_users)
        end
		local windSize = 18
		if #str1 > windSize then
			windSize = #str1
		end
		if #str2 > windSize then
			windSize = #str2
		end
		if windSize > xsize - 11 then windSize = xsize - 11 end
		local wind = window.create(term.current(),1,2,windSize,5)
		dialogState.corner.x = windSize
		dialogState.corner.y = 6
		wind.setBackgroundColor(colors.gray)
        wind.setTextColor(colors.white)
		wind.clear()
		wind.setCursorPos(1,1)
		wind.write("API GATE INFO")
		wind.setCursorPos(1,2)
		wind.write(str0)
		wind.setTextColor(colors.red)
		if dataSet then
			if dataSet.is_headless then
				wind.setTextColor(colors.lime)
			end
			wind.write(dataSet.gate_code)
		else
			wind.setTextColor(colors.white)
			wind.write("--")
		end
		wind.setTextColor(colors.white)
		wind.setCursorPos(1,3)
		wind.write(str1)
		wind.setCursorPos(1,4)
		wind.write(str2)
		wind.setCursorPos(1,5)
		wind.write(str3)
		wind.setBackgroundColor(colors.red)
		wind.setCursorPos(windSize-2,1)
		wind.write(" X ")
		wind.setBackgroundColor(colors.black)
		dialogState.importantCoords = {{type=0,y=2,x1=windSize-2,x2=windSize}}
		if windSize ~= xsize - 11 then
			for i=2,6 do
				paintutils.drawLine(dialogState.corner.x+1,i,xsize-11,i,colors.black)
			end
		end
	elseif dialogState.type == "wsg" then
		local dataSet = wsTbl[tostring(dialogState.id)]
		if not dataSet then
			writeDebugDialog("DrawDialog: wsg - dataset is nil")
			dialogState.active = false
			os.queueEvent("REDRAWSCREEN")
			table.remove(callChain,#callChain)
			return
		end
		if not dataSet.gateInfo then
			writeDebugDialog("DrawDialog: wsg - gateInfo missing")
			dialogState.active = false
			os.queueEvent("REDRAWSCREEN")
			table.remove(callChain,#callChain)
			return
		end
		if not dataSet.gateInfo.session_name then
			writeDebugDialog("DrawDialog: wsg - SOMETHING HAS GONE SERIOUSLY WRONG! dump made")
			if argDebug then
				saveDump()
			end
			dialogState.active = false
			os.queueEvent("REDRAWSCREEN")
			table.remove(callChain,#callChain)
			return
		end
		if dialogState.id > maxSlot then
			writeDebugDialog("DrawDialog: wsg - invalid slot")
			dialogState.active = false
			os.queueEvent("REDRAWSCREEN")
			table.remove(callChain,#callChain)
			return
		end
        term.setCursorPos(1,2)
		if dataSet.addr == "" then dataSet.addr = "------" end
		if dataSet.group == "" then dataSet.group = "--" end
		local str0 = "ADDR: "..dataSet.addr
        local str1 = "NAME: "..dataSet.gateInfo.session_name
		local str2 = "HOST: "..dataSet.gateInfo.host_name
		local str3 = "USERS: "..tostring(dataSet.playerCount).."/"..tostring(dataSet.playerMax)
		local str4 = "CS ENABLE: "..tostring(dataSet.gateInfo.gate_cs_en)
		local str5 = "CS NAME: nil"
		local str6 = "CS VISIBLE: "..tostring(dataSet.gateInfo.gate_cs_vis)
		local str7 = "ACCESS LVL: "..dataSet.gateInfo.access_level
		if dataSet.gateInfo.gate_name then
			str5 = "CS NAME: "..dataSet.gateInfo.gate_name
		end
		local windSize = 21
		local windYSize, str8,str9,str10
		if #str1 > windSize then
			windSize = #str1
		end
		if #str2 > windSize then
			windSize = #str2
		end
		if #str3 > windSize then
			windSize = #str3
		end
		if #str4 > windSize then
			windSize = #str4
		end
		if #str5 > windSize then
			windSize = #str5
		end
		if #str6 > windSize then
			windSize = #str6
		end
		if #str7 > windSize then
			windSize = #str7
		end
		if dataSet.gateInfo.dhd_version then
			windYSize = 12
			str8 = "WS USER: "..dataSet.gateInfo.user_name
			str9 = "GATE VER: "..dataSet.gateInfo.gate_version
			str10 = "UDHD VER: "..dataSet.gateInfo.dhd_version
			if #str8 > windSize then
				windSize = #str8
			end
			if #str9 > windSize then
				windSize = #str9
			end
			if #str10 > windSize then
				windSize = #str10
			end
		else
			windYSize = 9
		end
		if windSize > xsize - 11 then windSize = xsize - 11 end
		local wind = window.create(term.current(),1,2,windSize,windYSize)
		dialogState.corner.x = windSize
		dialogState.corner.y = windYSize+1
		wind.setBackgroundColor(colors.gray)
        wind.setTextColor(colors.white)
		wind.clear()
		wind.setCursorPos(1,1)
		local slotString = tostring(dialogState.id)
		if #slotString == 1 then slotString = "0"..slotString end
		wind.write("STARGATE SLOT "..slotString)
		wind.setCursorPos(1,2)
		wind.write(str0)
		wind.setTextColor(colors.red)
		local allowed = false
		for i=1,#wsRemap do
		    if dataSet.slot == wsRemap[i] then
		        allowed = true
		    end
		end
		if allowed then
			wind.setTextColor(colors.lime)
		end
		wind.write(dataSet.group)
		wind.setTextColor(colors.white)
		wind.setCursorPos(1,3)
		wind.write(str1)
		wind.setCursorPos(1,4)
		wind.write(str2)
		wind.setCursorPos(1,5)
		wind.write(str3)
		wind.setCursorPos(1,6)
		wind.write(str4)
		wind.setCursorPos(1,7)
		wind.write(str5)
		wind.setCursorPos(1,8)
		wind.write(str6)
		wind.setCursorPos(1,9)
		wind.write(str7)
		if dataSet.gateInfo.dhd_version then
			wind.setCursorPos(1,10)
			wind.write(str8)
			wind.setCursorPos(1,11)
			wind.write(str9)
			wind.setCursorPos(1,12)
			wind.write(str10)
		end
		wind.setBackgroundColor(colors.red)
		wind.setCursorPos(windSize-2,1)
		wind.write(" X ")
		wind.setBackgroundColor(colors.black)
		dialogState.importantCoords = {{type=0,y=2,x1=windSize-2,x2=windSize}}
		if windSize ~= xsize - 11 then
			for i=2,windYSize+1 do
				paintutils.drawLine(dialogState.corner.x+1,i,xsize-11,i,colors.black)
			end
		end
    elseif dialogState.type == "txt" then
		local dataSet = wsTbl[tostring(activeSlot)]
		if not dataSet then 
		    dialogState.active = false
			os.queueEvent("REDRAWSCREEN")
            table.remove(callChain,#callChain)
		    return 
		end
		if dataSet.gateStatus == -1 then
			dialogState.active = false
			os.queueEvent("REDRAWSCREEN")
			table.remove(callChain,#callChain)
			return
		end
		if not dataSet.irisPresent and dialogState.id == 2 then 
		    dialogState.active = false 
			os.queueEvent("REDRAWSCREEN")
            table.remove(callChain,#callChain)
		    return 
		end
		if not dataSet.open and dialogState.id == 3 then
		    dialogState.active = false 
			os.queueEvent("REDRAWSCREEN")
            table.remove(callChain,#callChain)
		    return 
		end
        term.setCursorPos(1,2)
		local str0 = "ADDR: "..dialogState.id
		local windSize = 22
		local wind = window.create(term.current(),1,2,windSize,4)
		dialogState.corner.x = windSize
		dialogState.corner.y = 5
		wind.setBackgroundColor(colors.gray)
        wind.setTextColor(colors.white)
		wind.clear()
		wind.setCursorPos(1,1)
		wind.write("TEXT ENTRY DIALOG")
		wind.setCursorPos(1,2)
		if dialogState.id == 1 then
			wind.write("TARGET ADDRESS ENTRY")
		elseif dialogState.id == 2 then
			wind.write("IDC CODE ENTRY")
		elseif dialogState.id == 3 then
			wind.write("SEND IDC CODE ")
		end
		wind.setCursorPos(1,4)
		wind.write(" CONFIRM       CANCEL")
		wind.setBackgroundColor(colors.red)
		wind.setCursorPos(windSize-2,1)
		wind.write(" X ")
		wind.setBackgroundColor(colors.gray)
		dialogState.importantCoords = {
			{type=0,y=2,x1=windSize-2,x2=windSize},
			{type=1,y=5,x1=2,x2=8},
			{type=0,y=5,x1=windSize-6,x2=windSize-1}
		}
        wind.setCursorPos(1,3)
		if dialogState.id == 1 then
			wind.write(string.sub(dialogState.text,1,6))
			wind.setTextColor(colors.lime)
			wind.write(string.sub(dialogState.text,7,8))
			if #dialogState.text < 6 then
			    wind.setTextColor(colors.white)
			end   
			if #dialogState.text < 8 then
				wind.setCursorBlink(true)
			end
		else
		    if #dialogState.text > windSize-1 then
		        wind.write("\171")
		        wind.write(string.sub(dialogState.text,-(windSize-2)))
		    else
			    wind.write(dialogState.text)
			end
			wind.setCursorBlink(true)
		end
    end
    table.remove(callChain,#callChain)
end

local function drawAddress(id,start)
    table.insert(callChain,{"drawAddress",id,start})
	local activeData = wsTbl[tostring(activeSlot)] or {gateStatus = -1}
	local activeDataaddr = activeData.addr
	if activeData.gateStatus == -1 then
		activeDataaddr = "nil"
	end
	if slotListMode then
		term.setCursorPos(xsize-10,id+4-start)
		local requested = wsTbl[tostring(id)] or {gateStatus = -1}
		local addr,group = requested.addr,requested.group
		if requested.gateStatus == -1 then
			addr = "------"
			group = "--"
		end
		term.setBackgroundColor(colors.lime)
		term.setTextColor(colors.black)
		if (id) == activeSlot then
			-- term.setBackgroundColor(colors.yellow)
			term.write("\x07")
		else
			term.write(" ")
		end
		term.setBackgroundColor(colors.black)
		term.setTextColor(wsColors[requested.gateStatus + 3])
		if addr == "" then addr = "------" end
		if group == "" then group = "--" end
		term.write(addr or "------")
		local allowed = false
		for i=1,#wsRemap do
		    if requested.slot == wsRemap[i] then
		        allowed = true
		    end
		end
		if allowed then
		    term.setTextColor(colors.lime)
		else
		    term.setTextColor(colors.red)
		end
		term.write(group or "--")
		term.setTextColor(colors.white)
		if requested.open then
			term.setBackgroundColor(colors.lime)
			term.setTextColor(colors.black)
			if requested.irisClose then
				term.setBackgroundColor(colors.red)
				term.setTextColor(colors.white)
			end
		end
		if requested.gateInfo then
			term.write("i")
		else
			term.write(" ")
		end
		term.setTextColor(colors.white)
		term.setBackgroundColor(colors.black)
	else
		term.setCursorPos(xsize-10,id+4-start)
		local requested = apiList[id]
		term.setBackgroundColor(colors.lime)
		term.setTextColor(colors.black)
		if requested.gate_address == activeDataaddr then
			-- term.setBackgroundColor(colors.yellow)
			term.write("\x07")
		else
			term.write(" ")
		end
		term.setBackgroundColor(colors.black)
		term.setTextColor(gateColor)
		term.write(requested.gate_address)
		term.setTextColor(colors.red)
		if requested.is_headless then
			term.setTextColor(colors.lime)
		end
		term.write(requested.gate_code)
		term.setTextColor(gateColor)
		term.setBackgroundColor(colors.black)
		if requested.gate_status == "OPEN" then
			term.setBackgroundColor(colors.lime)
			term.setTextColor(colors.black)
			if requested.iris_state then
				term.setBackgroundColor(colors.red)
				term.setTextColor(colors.white)
			end
		end
		term.write("i")
		term.setTextColor(gateColor)
		term.setBackgroundColor(colors.black)
	end
    table.remove(callChain,#callChain)
end

local function drawSide()
    table.insert(callChain,{"drawSide"})
	term.setCursorPos(xsize-10,2)
	term.setBackgroundColor(colors.black)
	term.setTextColor(gateColor)
	term.setBackgroundColor(gateColor)
	for i=2,ysize do
		term.setCursorPos(xsize,i)
		write(" ")
	end 
	addrBK = {}
	term.setCursorPos(xsize-10,2)
	term.setBackgroundColor(colors.black)
	if slotListMode then --lists stargates on my websocket
		wsPage = {}
		term.write("SLOT LIST ")
		term.setCursorPos(xsize-10,ysize-2)
		term.write("LIST TYPE ")
		term.setCursorPos(xsize-10,ysize-1)
		-- term.setBackgroundColor(colors.lime)
		term.setBackgroundColor(colors.black)
		write(" ")
		write("GATES    ")
		if not debugDialogState.visible then
    		term.setCursorPos(xsize-10,ysize)
    		-- term.setBackgroundColor(colors.lime)
			-- term.setTextColor(colors.black)
			write("\x07")
			-- term.setTextColor(gateColor)
    		-- term.setBackgroundColor(colors.black)
    		write("SLOTS    ")
    	end
		local a = ysize-6
		local listMax = maxSlot
		-- if #wsRemap > 0 and false then
		--     listMax = #wsRemap - 1
		-- end
		local availableSpace = ysize-6
		pageCount = math.ceil((listMax+1) / availableSpace)
		local firstSlot = ((pageNumber-1) * availableSpace)
		local lastSlot = firstSlot+availableSpace-1
		if lastSlot > listMax then lastSlot = listMax end
		for i=firstSlot,lastSlot do
			table.insert(wsPage,i)
			drawAddress(i,firstSlot)
		end
		local drawnItems = lastSlot-firstSlot+1
		if drawnItems < 0 then drawnItems = 0 end
		-- if drawnItems > availableSpace then drawnItems = availableSpace end
		-- writeDebugDialog(tostring(drawnItems).." "..tostring(ysize))
		if drawnItems ~= availableSpace then
			paintutils.drawFilledBox(xsize-10,drawnItems+4,xsize-1,ysize-3,colors.black)
		end
		-- if lastSlot-firstSlot+4 < ysize-2 and lastSlot-firstSlot+3 > 0 then
		-- 	paintutils.drawFilledBox(xsize-10,lastSlot-firstSlot+4,xsize-1,ysize-3,colors.black)
		-- elseif lastSlot-firstSlot+4 < ysize-2 then
		-- 	paintutils.drawFilledBox(xsize-10,3,xsize-1,ysize-3,colors.black)
		-- end
		term.setTextColor(gateColor)
		term.setBackgroundColor(colors.black)
		term.setCursorPos(xsize-10,3)
		term.write("<-PG ")
		term.write(tostring(pageNumber))
		term.write("/")
		term.write(tostring(pageCount))
		term.write("->")
	else --lists stargates from stargate api
		apiPage = {}
		local a = ysize-6
		local availableSpace = ysize-6
		pageCount = math.ceil(#apiList / availableSpace)
		local firstitem = ((pageNumber-1) * availableSpace)+1
		local lastItem = firstitem+availableSpace-1
		if lastItem > #apiList then lastItem = #apiList end
		for i=firstitem,lastItem do
			drawAddress(i,firstitem)
			table.insert(apiPage,i)
		end
		local drawnItems = lastItem-firstitem+1
		if drawnItems < 0 then drawnItems = 0 end
		-- writeDebugDialog(tostring(drawnItems).." "..tostring(ysize))
		term.setCursorPos(xsize-10,2)
		term.setBackgroundColor(colors.black)
		term.write("GATE LIST ")
		term.setCursorPos(xsize-10,ysize-2)
		term.write("LIST TYPE ")
		term.setCursorPos(xsize-10,ysize-1)
		-- term.setBackgroundColor(colors.lime)
		-- term.setTextColor(colors.black)
		-- term.setTextColor(gateColor)
		term.setBackgroundColor(colors.black)
    	write("\x07")
		write("GATES    ")
		if not debugDialogState.visible then
    		term.setCursorPos(xsize-10,ysize)
    		-- term.setBackgroundColor(colors.lime)
    		write(" ")
    		term.setBackgroundColor(colors.black)
    		write("SLOTS    ")
	    end
		if drawnItems ~= availableSpace then
			paintutils.drawFilledBox(xsize-10,drawnItems+4,xsize-1,ysize-3,colors.black)
		end
		-- if lastItem-firstitem+4 < ysize-2 and lastItem-firstitem+3 > 1 then
		-- 	paintutils.drawFilledBox(xsize-10,lastItem-firstitem+4,xsize-1,ysize-3,colors.black)
		-- elseif lastItem-firstitem+4 < ysize-2 then
		-- 	paintutils.drawFilledBox(xsize-10,3,xsize-1,ysize-3,colors.black)
		-- end
		term.setTextColor(gateColor)
		term.setBackgroundColor(colors.black)
		term.setCursorPos(xsize-10,3)
		term.write("<-PG ")
		term.write(tostring(pageNumber))
		term.write("/")
		term.write(tostring(pageCount))
		term.write("->")
	end
    table.remove(callChain,#callChain)
end

local function drawLine(currenty,text,mode,value,action)
    table.insert(callChain,{"drawLine",currenty,text,mode,value,action})
	if action then
		buttonPOS[currenty] = action
	end
	if not mode then
		mode = 1
	end
	term.setCursorPos(1,currenty)
	if not (dialogState.active and currenty <= dialogState.corner.y) then
		if mode == 1 then --Header
			term.setTextColor(colors.black)
			term.setBackgroundColor(gateColor)
			term.write(text)
		elseif mode == 2 then --Normal Text
			term.setTextColor(gateColor)
			term.setBackgroundColor(colors.black)
			term.write(text)
		elseif mode == 3 then --Display Value
			term.setTextColor(gateColor)
			term.setBackgroundColor(colors.black)
			term.write(text)
			term.write(value)
		elseif mode == 4 then --Display Address
			term.setTextColor(gateColor)
			term.setBackgroundColor(colors.black)
			term.write(text)
			term.write(string.sub(value,1,6))
			term.setTextColor(colors.lime)
			term.write(string.sub(value,7,8))
		elseif mode == 5 then --Display Boolean
			term.setTextColor(gateColor)
			term.setBackgroundColor(colors.black)
			term.write(text)
			if value then
				term.setBackgroundColor(colors.lime)
			else
				term.setBackgroundColor(colors.red)
			end
			term.write(" ")
		end
		local x,y = term.getCursorPos()
		paintutils.drawLine(x,currenty,xsize-11,currenty,colors.black)
	else
		if dialogState.corner.x ~= xsize-11 then
			paintutils.drawLine(dialogState.corner.x+1,currenty,xsize-11,currenty,colors.black)
		end
	end
	term.setTextColor(gateColor)
	term.setBackgroundColor(colors.black)
    table.remove(callChain,#callChain)
	return currenty+1
end

local function drawHeader(printSlot,gateData)
    table.insert(callChain,{"drawHeader",printSlot,gateData})
	term.setCursorPos(1,1)
	term.setBackgroundColor(gateColor)
	term.setTextColor(colors.black)
	if gateData.gateStatus ~= -1 then
		term.write("STARGATE SLOT "..printSlot..": ")
		local allowed = false
		for i=1,#wsRemap do
			if wsRemap[i] == activeSlot then
				allowed = true
			end
		end
		if gateData.addr == "" then gateData.addr = "------" end
		term.write(gateData.addr or "------")
		if allowed then
			term.setBackgroundColor(colors.lime)
			term.setTextColor(colors.black)
		else
			term.setBackgroundColor(colors.red)
			term.setTextColor(colors.white)
		end
		if gateData.group == "" then gateData.group = nil end
		term.write(gateData.group or "--")
		term.setBackgroundColor(gateColor)
		term.setTextColor(colors.black)
		term.write(" ")
		term.write(tostring(gateData.chevrons or " "))
		if gateData.incoming then
			term.write("!")
		elseif gateData.locked then
			term.write("?")
		else
			term.write(" ")
		end
		if gateData.open then
			term.write("O")
		else
			term.write(" ")
		end
	else
		term.write("STARGATE SLOT "..printSlot)
	end
	local cursorx,cursory = term.getCursorPos()
	local xsize,ysize = term.getSize()
	paintutils.drawFilledBox(cursorx,1,xsize-7,1,gateColor)
	term.setBackgroundColor(gateColor)
	term.setTextColor(colors.black)
	if gateData.gateInfo then
		term.write(" i ")
	else
		term.write("   ")
	end
	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.red)
	term.write(" X ")
	term.setBackgroundColor(gateColor)
	term.write(" ")
    table.remove(callChain,#callChain)
end

function drawMain()
    table.insert(callChain,{"drawMain"})
	term.setCursorBlink(false)
	buttonPOS = {}
	local x = wsTbl[tostring(activeSlot)] or {gateStatus = -1}
	local currenty = 2
	local printSlot = tostring(activeSlot)
	if activeSlot < 10 then
	    printSlot = "0"..printSlot
	end
	if x.gateStatus == -1 then
		gateColor = colors.orange
		-- currenty = drawLine(currenty,"SLOT NUMBER ",3,printSlot,"QUERY")
		-- currenty = drawLine(currenty,"STATUS CODE -1",2,nil,"QUERY")
		currenty = drawLine(currenty,"NO DATA",2,nil,"QUERY")
		gateColor = colors.cyan
	else
	    gateColor = wsColors[x.gateStatus+3]
		if x.irisPresent then
			currenty = drawLine(currenty,"IRIS CONTROLS",1,nil,"QUERY")
			if x.idcPresent then
				currenty = drawLine(currenty,"IDC ENABLE ",5,x.idcEN,"idcEN")
				currenty = drawLine(currenty,"CODE: ",3,x.idcCODE,"idcCODE")
			end
			currenty = drawLine(currenty,"TOGGLE IRIS ",5,not x.irisClose,"IRIS")
		end
		if x.controlState == 0 then
			currenty = drawLine(currenty,"STARGATE DIALING",1,nil,"QUERY")
			currenty = drawLine(currenty,"TARGET ADDR: ",4,targetAddress,"ADDR")
			currenty = drawLine(currenty,"DIAL NORMALLY",2,nil,"DIALNORM")
			currenty = drawLine(currenty,"DIAL INSTANTLY",2,nil,"DIALINST")
		elseif x.controlState == 2 then
			currenty = drawLine(currenty,"WORMHOLE IS OPEN",1,nil,"QUERY")
			currenty = drawLine(currenty,"CLOSE WORMHOLE",2,nil,"CLOSE")
			if x.remoteIris then
				currenty = drawLine(currenty,"REMOTE IRIS DETECTED",1,nil,"QUERY")
			else
				currenty = drawLine(currenty,"NO ACTION NEEDED",1,nil,"QUERY")
			end
			currenty = drawLine(currenty,"SEND IDC CODE",2,nil,"GDO")
		elseif x.controlState == 1 then
			currenty = drawLine(currenty,"DIALING IN PROGRESS",1,nil,"QUERY")
			currenty = drawLine(currenty,"CANCEL DIAL",2,nil,"CANCEL")
		elseif x.controlState == 3 then
			currenty = drawLine(currenty,"INCOMING WORMHOLE",1,nil,"QUERY")
			currenty = drawLine(currenty,"PLEASE WAIT",2,nil,"QUERY")
		end
		currenty = drawLine(currenty,"GATE INFORMATION",1,nil,"QUERY")
		if x.addr == "" then x.addr = "------" end
		if x.group == "" then x.group = "--" end
		currenty = drawLine(currenty,"GATE ADDRESS: ",4,(x.addr or "------")..(x.group or "--"),nil)
		if x.dialedAddr ~= "" then
			currenty = drawLine(currenty,"DIALED ADDR: ",4,x.dialedAddr,nil)
		end
		currenty = drawLine(currenty,"SESSION STATUS",1,nil,"QUERY")
		currenty = drawLine(currenty,"CURRENT USERS: ",3,tostring(x.playerCount).."/"..tostring(x.playerMax),nil)
		
		if x.min then
			local lastSave = tostring(x.sec)
			if #lastSave == 1 then
				lastSave = "0"..lastSave
			end
			lastSave = tostring(x.min)..":"..lastSave
			if #lastSave == 4 then
				lastSave = "0"..lastSave
			end
			currenty = drawLine(currenty,x.timerText or "TIMER: ",3,lastSave,nil)
		end
	end
	if currenty <= dialogState.corner.y and dialogState.active then
	    currenty = dialogState.corner.y + 1
	end
	if currenty <= ysize then
		paintutils.drawFilledBox(1,currenty,xsize-11,ysize-1,colors.black)
	end
	drawHeader(printSlot,x)
	drawDebugDialog()
	drawSide()
	drawDialog()
    table.remove(callChain,#callChain)
end

local function parseAPI(json)
    table.insert(callChain,{"parseAPI",json})
    local x = textutils.unserializeJSON(json)
    if not x then 
        table.remove(callChain,#callChain)
        return
    end
    apiList = x
    apiTbl = {}
    for i=1,#x do
    	apiTbl[x[i].gate_address] = x[i]
    end
    drawMain()
    table.remove(callChain,#callChain)
end

function query()
    table.insert(callChain,{"query"})
	ws.send("-QUERY")
	table.remove(callChain,#callChain)
end

function getAPI()
    table.insert(callChain,{"getAPI"})
	http.request(sgURL)
    table.remove(callChain,#callChain)
end


function modeChange(newM)
    table.insert(callChain,{"modeChange",newM})
	slotListMode = newM
	if slotListMode then
		query()
	else
		getAPI()
	end
	drawMain()
    table.remove(callChain,#callChain)
end

function sendCommand(commandstr,argument)
    table.insert(callChain,{"sendCommand",commandstr,argument})
	if not argument then argument = "" end
	local activeSlotStr = tostring(activeSlot)
	if activeSlot < 10 then
		activeSlotStr = "0"..tostring(activeSlot)
	end
	ws.send(activeSlotStr..commandstr..argument)
	writeDebugDialog("send: "..activeSlotStr..commandstr..argument)
    table.remove(callChain,#callChain)
end

function spawnInfoDialog(addr)
    table.insert(callChain,{"spawnInfoDialog",addr})
	dialogState.id = addr
	dialogState.type = "sg"
	dialogState.active = true
	drawMain()
    table.remove(callChain,#callChain)
end

function spawnExitDialog()
	table.insert(callChain,{"spawnExitDialog"})
	dialogState.type = "exit"
	dialogState.active = true
	drawMain()
	table.remove(callChain,#callChain)
end

function spawnWSInfoDialog(index)
    table.insert(callChain,{"spawnWSInfoDialog",index})
	dialogState.id = index
	dialogState.type = "wsg"
	dialogState.active = true
	drawMain()
    table.remove(callChain,#callChain)
end

function spawnAddressDialog()
    table.insert(callChain,{"spawnAddressDialog"})
	dialogState.text = targetAddress
	dialogState.id = 1
	dialogState.type = "txt"
	dialogState.active = true
	drawMain()
    table.remove(callChain,#callChain)
end

function spawnIDCDialog()
    table.insert(callChain,{"spawnIDCDialog"})
	dialogState.text = wsTbl[tostring(activeSlot)].idcCODE
	dialogState.id = 2
	dialogState.type = "txt"
	dialogState.active = true
	drawMain()
    table.remove(callChain,#callChain)
end

function spawnGDODialog()
    table.insert(callChain,{"spawnGDODialog"})
	dialogState.text = ""
	dialogState.id = 3
	dialogState.type = "txt"
	dialogState.active = true
	drawMain()
    table.remove(callChain,#callChain)
end

local function parseWS(json)
    table.insert(callChain,{"parseWS",json})
	if json == "INPUT USER" then
		ws.send(accessKey)
		getAPI()
		tmr = os.startTimer(30)
        table.remove(callChain,#callChain)
		return
	elseif json == "-PING" then
        table.remove(callChain,#callChain)
		return
	end
    local x, err = textutils.unserializeJSON(json)
    if not x then 
        table.remove(callChain,#callChain)
        return 
    end	
    if x.type == "perms" then
        writeDebugDialog("perms obtained from server")
		for i=1,#x.defined do
			if not wsTbl[tostring(x.defined[i])] then
				wsTbl[tostring(x.defined[i])] = {gateStatus = -1}
			end
		end
		wsRemap = x.allowed
		permsObtained = true
        local highestSlot = 0
        for i=1,#x.defined do
            if x.defined[i] > highestSlot then
                highestSlot = x.defined[i]
            end
        end
        for i=1,#x.online do
            if x.online[i] > highestSlot then
                highestSlot = x.online[i]
            end
        end
        for i=0,highestSlot do
            local exists = false
            for j=1,#x.online do
                if i == x.online[j] then
                    exists = true
                end
            end
            if not exists then
                wsTbl[tostring(i)] = {slot=i,gateStatus=-1}
            end
        end
        maxSlot = highestSlot
        if activeSlot > highestSlot then
            activeSlot = highestSlot
        end
		drawMain()
	elseif x.type == "stargate" then
		if x.slot > maxSlot then
			maxSlot = x.slot
		end
		local allowed = false
		for i=1,#wsRemap do
		    if x.slot == wsRemap[i] then
		        allowed = true
		    end
		end
		if not allowed then
		    x.controlState = -1
		    x.irisPresent = false
		end
		wsTbl[tostring(x.slot)] = x
		drawMain()
	-- elseif not x.type then
	-- 	parseAPI(json)
	-- 	writeDebugDialog("parsing api data from websocket")
	end
    table.remove(callChain,#callChain)
end

local function dialAddress()
    table.insert(callChain,{"dialAddress"})
	sendCommand("1",targetAddress)
	table.remove(callChain,#callChain)
end

local function dialNox()
    table.insert(callChain,{"dialNox"})
	sendCommand("2",targetAddress)
	table.remove(callChain,#callChain)
end

local function textDialogConfirmHandler()
    table.insert(callChain,{"textDialogConfirmHandler"})
    dialogState.active = false
	if dialogState.id == 1 then
		targetAddress = dialogState.text
	elseif dialogState.id == 2 then
		sendCommand("7",dialogState.text)
	elseif dialogState.id == 3 then
		sendCommand("8",dialogState.text)
	end
	table.remove(callChain,#callChain)
end

local commandIndex = { --button action keywords
	QUERY = query,
	idcEN = 6,
	IRIS = 5,
	idcCODE = spawnIDCDialog,
	ADDR = spawnAddressDialog,
	GDO = spawnGDODialog,
	DIALNORM = dialAddress,
	DIALINST = dialNox,
	CLOSE = 4,
	CANCEL = 3,
}
local function mouseHandler(x,y)
    table.insert(callChain,{"mouseHandler",x,y})
	-- if dialogState.type == "weakalert" and dialogState.active then
    --     dialogState.active = false
    --     if y <= dialogState.corner.y and (x <= dialogState.corner.y or x < xsize-10) then
    --         table.remove(callChain,#callChain)
    --         return
    --     end
    -- end
	if dialogState.active then
		local coords = dialogState.importantCoords
		for i=1,#coords do
			if coords[i].x1 <= x and x <= coords[i].x2 and y == coords[i].y then
				if coords[i].type == 0 then
					dialogState.active = false
					-- if dialogState.type == "alert" then
					-- 	os.cancelTimer(clearDialog)
					-- end
				elseif coords[i].type == 1 then
	                if dialogState.type == "txt" then
					    textDialogConfirmHandler()
					elseif dialogState.type == "exit" then
						isRunning = false
						exitMessage = "Program Closed by User"
					else
					    dialogState.active = false
					end
				end
				drawMain()
			end
		end
	else
		if x < xsize-10 then -- main
			if buttonPOS[y] then
				if type(commandIndex[buttonPOS[y]]) == "number" then
					sendCommand(commandIndex[buttonPOS[y]])
				elseif commandIndex[buttonPOS[y]] then
					commandIndex[buttonPOS[y]]()
				end
			end
		else -- side
			if y == 1 then
				if x > xsize-4 and x < xsize then
					spawnExitDialog()
				elseif x > xsize-7 and x < xsize-3 then
					spawnWSInfoDialog(activeSlot)
				end
			elseif y == 2 then
				getAPI()
			elseif y == 3 then
				if x <= xsize-9 then
					if pageNumber > 1 then
						pageNumber = pageNumber - 1
						drawMain()
					end
				elseif x >= xsize-2 then
					if pageNumber < 9 then
						pageNumber = pageNumber + 1
						drawMain()
					end
				end
			elseif y == ysize - 2 then
				query()
			elseif y == ysize - 1 then
				modeChange(false)
				drawMain()
			elseif y == ysize then
				modeChange(true)
				drawMain()
			else
				local correctedIndex = y-3
				if slotListMode then
				    local wsIndex = wsPage[correctedIndex]
				    if wsIndex then
    					if (wsTbl[tostring(wsIndex)] or wsIndex <= maxSlot) and x < xsize-1 then
    						activeSlot = wsIndex
    						drawMain()
						elseif x >= xsize-1 then
							if wsTbl[tostring(wsIndex)] then
								if wsTbl[tostring(wsIndex)].gateInfo then
									spawnWSInfoDialog(wsIndex)
								end
							end
						end
    				end
				else
					if apiList[apiPage[correctedIndex]] then
					 	if wsTbl[tostring(activeSlot)] and x < xsize-1 then
							if wsTbl[tostring(activeSlot)].gateStatus >= 0 then
								addr = apiList[apiPage[correctedIndex]].gate_address
								if wsTbl[tostring(activeSlot)].group ~= apiList[apiPage[correctedIndex]].gate_code then
									addr = addr..string.sub(apiList[apiPage[correctedIndex]].gate_code,1,1)
								end
								targetAddress = addr
							end
						elseif x >= xsize-1 then
							spawnInfoDialog(apiList[apiPage[correctedIndex]].gate_address)
						end
					end
				end
			end
		end
	end
	table.remove(callChain,#callChain)
end

local function keyHandler(key) --handle keys not handled in charHandler
    table.insert(callChain,{"keyHandler",key})
    if key == keys.tab then
        saveDump()
        writeDebugDialog("saved variable dumps")
    end
	if dialogState.type ~= "txt" then 
        table.remove(callChain,#callChain)
	    return 
	end
	if not dialogState.active then 
        table.remove(callChain,#callChain)
	    return 
	end
	if key == keys.enter then
		textDialogConfirmHandler()
	elseif key == keys.backspace then
		if #dialogState.text > 0 then
			dialogState.text = string.sub(dialogState.text,1,-2)
		end
	end
	drawMain()
    table.remove(callChain,#callChain)
end

local validGlyphs = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@*"
local function charHandler(key) --Handle text input
    table.insert(callChain,{"charHandler",key})
	if dialogState.type ~= "txt" then 
        table.remove(callChain,#callChain)
	    return 
	end
	if not dialogState.active then 
        table.remove(callChain,#callChain)
	    return 
	end
    if dialogState.id == 1 then
        raw = string.upper(key)
        if #dialogState.text >= 8 then 
            table.remove(callChain,#callChain)
            return 
        end
		if raw == "%" or raw == "." or raw == "[" or raw == "(" then 
            table.remove(callChain,#callChain)
		    return 
		end
        if string.find(dialogState.text,raw) or not string.find(validGlyphs,raw) then 
            table.remove(callChain,#callChain)
            return 
        end
        dialogState.text = dialogState.text..raw
    else
        dialogState.text = dialogState.text..key
    end
    drawMain()
    table.remove(callChain,#callChain)
end

local function main()
    table.insert(callChain,{"main"})
    while isRunning do
    	local event = {os.pullEventRaw()}
    	if event[1] == "terminate" or (event[1] == "websocket_closed" and event[2]==wsURL) then
    		isRunning = false
    		if event[1]=="terminate" then
    			exitMessage = "Terminated"
    		else
    			exitMessage = "Connection Closed"
    		end
    	elseif event[1] == "websocket_message" then
			timeoutTimer = os.startTimer(40)
    		parseWS(event[3])
    	elseif event[1] == "timer" then
    		if event[2] == tmr then
				if not slotListMode then
    				getAPI()
				end
    			tmr = os.startTimer(30)
    		-- elseif event[2] == clearDialog and (dialogState.type == "alert" or dialogState.type=="weakalert") then
    		-- 	dialogState.active = false
    		elseif event[2] == debugDialogState.timer then
    		    debugDialogState.visible = false
    		    drawMain()
			elseif event[2] == timeoutTimer then
				exitMessage = "Connection Timed Out"
				isRunning = false
    		end
    	elseif event[1] == "term_resize" then
    		xsize,ysize = term.getSize()
    		dialogState.active = false
    		term.setPaletteColor(colors.lime,0x00FF00)
    		term.setPaletteColor(colors.red,0xFF0000)
    		term.setPaletteColor(colors.yellow,0xFFFF00)
    		term.setPaletteColor(colors.black,0x000000)
    		term.setPaletteColor(colors.blue,0x00A0ff)
    		term.setPaletteColor(colors.white,0xe5e5e5)
    		term.setPaletteColor(colors.lightBlue,0x00ffff)
    		writeDebugDialog("term resize detected")
    		drawMain()
    	elseif event[1] == "http_success" and event[2] == sgURL then
    		parseAPI(event[3].readAll())
    		writeDebugDialog("api fetch success.")
    	elseif event[1] == "http_failure" and event[2] == sgURL then
    	    writeDebugDialog("api fetch failure.")
    	    -- ws.send("-API")
    	elseif event[1] == "mouse_click" then
    		mouseHandler(event[3],event[4])
    	elseif event[1] == "key" then
    		keyHandler(event[2])
    	elseif event[1] == "char" then
    		charHandler(event[2])
		elseif event[1] == "REDRAWSCREEN" then
			drawMain()
    	end
    end
    table.remove(callChain,#callChain)
end

local success,msg = pcall(main)
pcall(ws.close)
term.setPaletteColor(colors.lime,term.nativePaletteColor(colors.lime))
term.setPaletteColor(colors.red,term.nativePaletteColor(colors.red))
term.setPaletteColor(colors.yellow,term.nativePaletteColor(colors.yellow))
term.setPaletteColor(colors.black,term.nativePaletteColor(colors.black))
term.setPaletteColor(colors.white,term.nativePaletteColor(colors.white))
term.setPaletteColor(colors.lightBlue,term.nativePaletteColor(colors.lightBlue))
term.setPaletteColor(colors.blue,term.nativePaletteColor(colors.blue))
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)
if not success then
    printError("An Error has Occurred!")
    exitMessage = msg
end
printError(exitMessage)
if not success then
    local dumped, msg = pcall(saveDump)
    if dumped then
        print("Dumps Saved to \"/client.dump\" and \"/client.data\"")
        print("Please DM these files to catiotocat on Discord if possible.")
        printError("WARNING: DO NOT SHARE THESE FILES WITH ANYONE ELSE")
		print("If you are running this in CraftOS-PC on Windows, the files can be located in the directory below:")
		print("%appdata%/CraftOS-PC/computer/"..os.getComputerID())
    else
        printError("Variable Dump Failed")
        print("Please DM the error message printed above to catiotocat on Discord")
    end
end

--[[
Command Info
Format: XXYZ
XX = Slot Number
Y = Command ID
Z = Parameter (Varied Length)
Command List:

]]