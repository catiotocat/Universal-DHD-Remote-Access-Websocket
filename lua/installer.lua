-- This program was designed to run inside of CraftOS-PC
-- You can download CraftOS-PC from https://www.craftos-pc.cc/

if not term then --Check if the program is running inside CraftOS-PC
	print("This program was designed to run inside of CraftOS-PC")
	print("You can download CraftOS-PC from https://www.craftos-pc.cc/")
	print("Press enter to continue...")
	local a = io.read()
	return
end

-- define settings variables
settings.define("udhdRemoteAccess.accessKey",{
	description="Access Key for the webocket server. Use ';' to specify multiple keys.", 
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
settings.define("udhdRemoteAccess.installPath",{
    description="The filepath at which the program was last installed. This is set automatically when downloading the program from the server.",
    default = nil,
    type="string"
})
settings.save() --save all changes to the computer settings

-- Settings:
-- Websocket Server URL
-- Access Key
-- Stargate Network API Key
-- Program Install Path

local strings = {
    ws = {
        title = "Setting Websocket URL",
        null = "Not Set",
        description = "This is the url of the Universal DHD Remote Access Server. The client program and the Universal DHD must be connected to the same server in order to communicate."
    },
    key = {
        title = "Setting Access Key(s)",
        null = "public",
        description = "In order for you to be able to access a Universal DHD, you must have it's access key set here. If you want to set multiple keys for the client program, use ';' to separate entries."
    },
    api = {
        title = "Setting Stargate Network API Key",
        null = "Not Set",
        description = "This is an optional setting that allows a gate network admin to provide an API key to view hidden Stargates in the Cross-Session list. If you are not an admin, you do not need to set this value."
    },
    path = {
        title = "Setting Install Path",
        null = "Not Set",
        description = "This is where the client program will be downloaded on the computer. This can be anywhere, so long as it isn't read-only. It is recommended that you use \".lua\" as the file extension."
    }
}

local programState = {
    page = "main",
    text = "",
    cursorPos = 0
}

local function drawPage()
    term.setCursorPos(1,1)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.yellow)
    local xsize,ysize = term.getSize()
    print("Universal DHD Remote Access Client Installer")
    term.setTextColor(colors.white)
    if programState.page == "main" then
        term.setCursorBlink(false)
        local installReady = true
        term.setTextColor(colors.lightGray)
        print("Use the arrow keys and the ENTER key to navigate.")

        term.setCursorPos(1,4)
        term.setTextColor(colors.white)
        print("Websocket URL")
        if programState.cursorPos == 0 then
            term.setBackgroundColor(colors.white)
        else
            term.setBackgroundColor(colors.lightGray)
        end
        term.clearLine()
        term.setTextColor(colors.black)
        local text = settings.get("udhdRemoteAccess.websocketUrl", "") or ""
        if text == "" then
            term.setTextColor(colors.gray)
            text = "Not Set"
            installReady = false
        end
        if #text > xsize then
            text = string.sub(text,1,xsize-1).."\187"
        end
        term.write(text)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)

        term.setCursorPos(1,7)
        term.setTextColor(colors.white)
        print("Access Key(s)")
        if programState.cursorPos == 1 then
            term.setBackgroundColor(colors.white)
        else
            term.setBackgroundColor(colors.lightGray)
        end
        term.clearLine()
        term.setTextColor(colors.black)
        local text = settings.get("udhdRemoteAccess.accessKey", "") or ""
        if text == "" then
            term.setTextColor(colors.gray)
            text = "public"
        end
        if #text > xsize then
            text = string.sub(text,1,xsize-1).."\187"
        end
        term.write(text)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
        
        term.setCursorPos(1,10)
        term.setTextColor(colors.white)
        print("Stargate Network API Key (Optional)")
        if programState.cursorPos == 2 then
            term.setBackgroundColor(colors.white)
        else
            term.setBackgroundColor(colors.lightGray)
        end
        term.clearLine()
        term.setTextColor(colors.black)
        local text = settings.get("udhdRemoteAccess.apiKey", "") or ""
        if text == "" then
            term.setTextColor(colors.gray)
            text = "Not Set"
        end
        if #text > xsize then
            text = string.sub(text,1,xsize-1).."\187"
        end
        term.write(text)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
        
        term.setCursorPos(1,13)
        term.setTextColor(colors.white)
        print("Install Path")
        if programState.cursorPos == 3 then
            term.setBackgroundColor(colors.white)
        else
            term.setBackgroundColor(colors.lightGray)
        end
        term.clearLine()
        term.setTextColor(colors.black)
        local text = settings.get("udhdRemoteAccess.installPath", "") or ""
        if text == "" then
            term.setTextColor(colors.gray)
            text = "Not Set"
            installReady = false
        end
        if #text > xsize then
            text = string.sub(text,1,xsize-1).."\187"
        end
        term.write(text)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)

        term.setCursorPos(2,16)
        term.setBackgroundColor(colors.lightGray)
        term.setTextColor(colors.black)
        local text = " Install "
        if installReady then
            term.setBackgroundColor(colors.green)
            term.setTextColor(colors.white)
        end
        if programState.cursorPos == 4 then
            text = ">Install<"
        end
        term.write(text)

        term.setCursorPos(2,18)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.black)
        local text = " Exit "
        if programState.cursorPos == 5 then
            text = ">Exit<"
        end
        term.write(text)
        
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
    else
        -- all other pages go here since they all work the same way

        term.setCursorPos(1,3)
        term.setTextColor(colors.white)
        print(strings[programState.page].title)

        term.setTextColor(colors.lightGray)
        term.setCursorPos(1,4)
        print("Press ENTER when finished")

        term.setCursorPos(1,6)
        term.setTextColor(colors.lightGray)
        print(strings[programState.page].description)

        term.setCursorPos(1,5)
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
        term.clearLine()
        if programState.text == "" then
            term.setTextColor(colors.gray)
            term.write(strings[programState.page].null)
            term.setCursorPos(1,5)
            term.setTextColor(colors.black)
            term.setCursorBlink(true)
        else
            if #programState.text >= xsize then
				term.write("\171")
				term.write(string.sub(programState.text,-(xsize-2)))
			else
				term.write(programState.text)
			end
			term.setCursorBlink(true)
        end
    end

end

drawPage()
-- read()

local running = true
local exitType = 0
while running do
    local event = {os.pullEventRaw()} --will switch to raw once terminate is implemented properly
    if event[1] == "key" then
        if programState.page == "main" then
            if event[2] == keys.up then
                if programState.cursorPos > 0 then
                    programState.cursorPos = programState.cursorPos - 1
                end
            elseif event[2] == keys.down then
                if programState.cursorPos < 5 then
                    programState.cursorPos = programState.cursorPos + 1
                end
            elseif event[2] == keys.enter then
                if programState.cursorPos == 0 then
                    programState.page = "ws"
                    programState.text = settings.get("udhdRemoteAccess.websocketUrl", "") or ""
                elseif programState.cursorPos == 1 then
                    programState.page = "key"
                    programState.text = settings.get("udhdRemoteAccess.accessKey", "") or ""
                elseif programState.cursorPos == 2 then
                    programState.page = "api"
                    programState.text = settings.get("udhdRemoteAccess.apiKey", "") or ""
                elseif programState.cursorPos == 3 then
                    programState.page = "path"
                    programState.text = settings.get("udhdRemoteAccess.installPath", "") or ""
                elseif programState.cursorPos == 4 then
                    local url = settings.get("udhdRemoteAccess.websocketUrl") or ""
                    local path = settings.get("udhdRemoteAccess.installPath") or ""
                    if url ~= "" and path ~= "" then
                        running = false
                        exitType = 1 --run install
                    end
                elseif programState.cursorPos == 5 then
                    running = false
                end
            end
        else
            --all other pages run here.
            if event[2] == keys.backspace then
                programState.text = string.sub(programState.text,1,-2)
            elseif event[2] == keys.enter then
                if programState.page == "ws" then
                    if programState.text == "" then
                        settings.unset("udhdRemoteAccess.websocketUrl")
                    else
                        settings.set("udhdRemoteAccess.websocketUrl", programState.text)
                    end
                elseif programState.page == "key" then
                    if programState.text == "" then
                        settings.unset("udhdRemoteAccess.accessKey")
                    else
                        settings.set("udhdRemoteAccess.accessKey", programState.text)
                    end
                elseif programState.page == "api" then
                    if programState.text == "" then
                        settings.unset("udhdRemoteAccess.apiKey")
                    else
                        settings.set("udhdRemoteAccess.apiKey", programState.text)
                    end
                elseif programState.page == "path" then
                    if programState.text == "" then
                        settings.unset("udhdRemoteAccess.installPath")
                    else
                        settings.set("udhdRemoteAccess.installPath", programState.text)
                    end
                end
                settings.save()
                programState.page = "main"
            end
        end
    elseif event[1] == "char" or event[1] == "paste" then
        if programState.page ~= "main" then
            programState.text = programState.text..event[2]
        end
    elseif event[1] == "terminate" then
        running = false
        exitType = -1
    end
    drawPage()

end

term.setTextColor(colors.white)
term.setBackgroundColor(colors.black)
term.setCursorPos(1,1)
term.clear()
if exitType == -1 then
    printError("Terminated")
elseif exitType == 1 then
    local fname = settings.get("udhdRemoteAccess.installPath")
    if string.sub(fname,1,1) ~= "/" then
        fname = "/"..fname
    end
    if fs.isReadOnly(fname) then
        printError("Cannot download to "..fname)
        printError("Path is Read Only")
        return
    end
    print("Downloading "..fname)

    local url = settings.get("udhdRemoteAccess.websocketUrl")
    if string.sub(url,-1,-1) ~= "/" then
        url = url.."/"
    end
    if string.sub(url,1,3) == "ws:" then
        url = "http://"..string.sub(url,6,-1)
    else
        url = "https://"..string.sub(url,7,-1)
    end
    url = url.."client.lua"
    local response,err = http.get(url)
		
    if not response then 
        printError("Download Failed")
        printError(err)
        print("Please try again later.")
        return
    end
    local fileConts = response.readAll()
    response.close()
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
            print("Please try again later.")
        else
            local f = fs.open(fname,"w")
            f.write(fileConts)
            f.close()
            print("Download Completed")
            print("Version: "..readVersion)
            success = true
        end
    else
        printError(fileConts)
        print("Please try again later.")
    end
    if success then
        print()
        print("Program is now ready to use!")
    end

end