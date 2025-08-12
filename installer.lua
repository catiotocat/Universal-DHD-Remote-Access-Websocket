-- This program was designed to run inside of CraftOS-PC
-- You can download CraftOS-PC from https://www.craftos-pc.cc/

settings.define("resoniteLink.accessKey",{
    description="Access Key for the webocket server", 
    default = "public", 
    type="string"
})
settings.define("resoniteLink.websocketUrl",{
	description="Websocket URL for the server",
	default="wss://catio.merith.xyz/ws/",
	type="string"
})
settings.define("resoniteLink.allowUpdates",{
    description="Set to false to disable automatic updates", 
    default = true, 
    type="boolean"
})
settings.save()

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
repeat
    term.setTextColor(colorHeader)
    print("Universal DHD Remote Access Client Installer")
    term.setTextColor(colorText)
    print("Please select a websocket URL to use.")
    term.setTextColor(colorText)
    print("0: wss://catio.merith.xyz/ws/ (Default)")
    print("1: ws://localhost:8059/")
    print("2: Custom URL")
    print("3: Do Not Change")
    term.setTextColor(colorPrompt)
    print("Enter the number of your selection and press enter.")
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
    local response = read()
    if response == "0" then
        wsURL = "wss://catio.merith.xyz/ws/"
    elseif response == "1" then
        wsURL = "ws://localhost:8059/"
    elseif response == "2" then
        term.setTextColor(colorPrompt)
        print("Please enter the websocket URL.")
        term.setTextColor(colorHeader)
        term.write("> ")
        term.setTextColor(colorText)
        wsURL = read()
    elseif response == "3" then
    else
        term.clear()
        term.setCursorPos(1,1)
        valid = false
    end
until valid
if wsURL then
    settings.set("resoniteLink.websocketUrl",wsURL)
    settings.save()
end

term.clear()
term.setCursorPos(1,1)

local wsKey
local valid = true
repeat
    term.setTextColor(colorHeader)
    print("Universal DHD Remote Access Client Installer")
    term.setTextColor(colorText)
    print("Please select an access key to use.")
    term.setTextColor(colorText)
    print("0: public (Default)")
    print("1: Custom Access Key")
    print("2: Do Not Change")
    term.setTextColor(colorPrompt)
    print("Enter the number of your selection and press enter.")
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
    local response = read()
    if response == "0" then
        wsKey = "public"
    elseif response == "1" then
        term.setTextColor(colorPrompt)
        print("Please enter the access key.")
        term.setTextColor(colorHeader)
        term.write("> ")
        term.setTextColor(colorText)
        wsKey = read()
    elseif response == "2" then
    else
        term.clear()
        term.setCursorPos(1,1)
        valid = false
    end
until valid
if wsKey then
    settings.set("resoniteLink.accessKey",wsKey)
    settings.save()
end

term.clear()
term.setCursorPos(1,1)

term.setTextColor(colorHeader)
print("Universal DHD Remote Access Client Installer")
term.setTextColor(colorText)
print("Settings have been saved.")

print("Downloading client.lua")
local ws,err = http.websocket(wsURL)
if not ws then 
    printError("Download Failed")
    printError(err)
    print("Please try again later.")
    return
end
ws.receive()
ws.send("-UPDATE")
local fileConts = ws.receive()
local success = false
if string.sub(fileConts,1,#"ERROR:")~="ERROR:" then
    local f = fs.open("/client.lua","w")
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