#!/usr/bin/env python

import asyncio
import os
import json
from urllib import parse
from datetime import datetime
from websockets.asyncio.server import serve

publicAccessKey = "public"

mypath = os.path.dirname(os.path.realpath(__file__))
print(mypath)
luaFilePath = mypath+"/lua/client.lua"
luaDevFilePath = mypath+"/lua/client_dev.lua"

defaultconfig = {
		"key":publicAccessKey,
		"slotListType":"whitelist",
		"slotList":[],
		"canControlExtras":False,
		"allowAddresses":[],
		"allowKeys":[],
		"keyEnabled":True,
	}
clientConfig = [
	defaultconfig,
]

adminKeys = []
connectedStargates = []
connectedClients = []
maxSlotCount = 100

global restrictDataAccess
restrictDataAccess = False
# load user config file

def loadConfig(config):
	global restrictDataAccess
	for key in config["adminKeys"]:
		duplicate = False
		invalid = False
		for entry in clientConfig:
			if key == entry:
				duplicate = True
			if key == publicAccessKey:
				invalid = True
		if duplicate:
			print("\033[33mDuplicate Admin Key Detected: Key \""+key+"\" is defined multiple times!\033[0m")
		elif invalid:
			print("\033[33mInvalid Admin Key Detected: Key \""+key+"\" is the public access key!\033[0m")
		else:
			adminKeys.append(key)
			print("Loaded Admin Key: \""+key+"\"")
	if "restrictDataAccess" in config:
		if config["restrictDataAccess"] == True:
			restrictDataAccess = True
			print("Blocking Data Access for denied slots")

try:
	configFile = open(mypath+"/config/config.json")
	config = json.loads(configFile.read())
	configFile.close()
	loadConfig(config)
except Exception as ex:
	print("\033[91mFailed to read config file!\033[0m")
	print(type[ex])
	print(ex.args)
	print(ex)
	print("Using default config file")
	adminKeys = []
	restrictDataAccess = False
	try: # Fall back to default config file
		configFile = open(mypath+"/config/default.json")
		config = json.loads(configFile.read())
		configFile.close()
		loadConfig(config)
	except Exception as ex: #If both files are broken, give up on config loading.
		print("\033[91mFailed to read default config file!\033[0m")
		print(type[ex])
		print(ex.args)
		print(ex)
		print("Skipping config file loading.")
		adminKeys = ["admin"]
		restrictDataAccess = False


def tryConvertGateData(gateData):
	convertedData = {
		"access_key":gateData["ws-key"],
		"gate_status":gateData["gateStatus"],
		"control_state":gateData["controlState"],
		"gate_info":{
			"address":gateData["addr"],
			"type_code":gateData["group"],
			"open":gateData["open"],
			"iris_present":gateData["irisPresent"],
			"iris_closed":gateData["irisClose"],
			"name":gateData["gateInfo"]["gate_name"],
			"version":gateData["gateInfo"]["gate_version"],
			"dialed_address":gateData["dialedAddr"],
			"remote_iris":gateData["remoteIris"],
			"cs_enabled":gateData["gateInfo"]["gate_cs_en"],
			"cs_visible":gateData["gateInfo"]["gate_cs_vis"]
		},
		"udhd_info":{
			"version":gateData["gateInfo"]["dhd_version"]+" [COMPAT]",
			"idc_enabled":gateData["idcEN"],
			"idc_present":gateData["idcPresent"],
			"idc_code":gateData["idcCODE"],
			"websocket_user":gateData["gateInfo"]["user_name"],
			"timer_text":"TIMER: ",
			"timer_enabled":False,
			"timer_seconds":0,
			"timer_minutes":0
		},
		"session_info":{
			"world_name":gateData["gateInfo"]["session_name"],
			"host_user":gateData["gateInfo"]["host_name"],
			"user_count":gateData["playerCount"],
			"user_limit":gateData["playerMax"],
			"is_headless":False,
			"is_hidden":False,
			"access_level":0
		},
		"gate_list":[],
	}

	if "timerText" in gateData:
		convertedData["udhd_info"]["timer_text"] = gateData["timerText"]
	if "sec" in gateData and "min" in gateData:
		convertedData["udhd_info"]["timer_enabled"] = True
		convertedData["udhd_info"]["timer_minutes"] = gateData["min"]
		convertedData["udhd_info"]["timer_seconds"] = gateData["sec"]
	accessLV = gateData["gateInfo"]["access_level"]
	if accessLV.startswith("Hidden"):
		convertedData["session_info"]["is_hidden"] = True
	if accessLV.endswith("Private"):
		convertedData["session_info"]["access_level"] = 0
	elif accessLV.endswith("LAN"):
		convertedData["session_info"]["access_level"] = 1
	elif accessLV.endswith("Contacts"):
		convertedData["session_info"]["access_level"] = 2
	elif accessLV.endswith("ContactsPlus"):
		convertedData["session_info"]["access_level"] = 3
	elif accessLV.endswith("RegisteredUsers"):
		convertedData["session_info"]["access_level"] = 4
	elif accessLV.endswith("Anyone"):
		convertedData["session_info"]["access_level"] = 5

	return convertedData

async def sendGateInfo(message,gate):
	# if restrictDataAccess:
		# print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | "+"Fetching perms for data access! Slot "+str(gate["Slot"]))
	for client in connectedClients:
		msg = message
		try:
			if restrictDataAccess:
				allowedSlots = await getPerms(client["KeyList"],True)
				if gate["Slot"] in allowedSlots:
					await client["Websocket"].send(msg)
				else:
					raw = {
						"slot":gate["Slot"],
						"gate_status":-1,
						"type":"stargate"
					}
					msg = json.dumps(raw)
					await client["Websocket"].send(msg)
			else:
				await client["Websocket"].send(msg)
		except:
			pass

async def query():
	for gate in connectedStargates:
		try:
			await gate["Websocket"].send("-QUERY")
		except:
			pass

def decodeSingleVar(tbl,key):
	if key in tbl:
		tbl[key] = parse.unquote_plus(tbl[key])
	return tbl

def decodeVars(tbl):
	tbl = decodeSingleVar(tbl,"access_key")
	if "gate_info" in tbl:
		gateInfo = tbl["gate_info"]
		gateInfo = decodeSingleVar(gateInfo,"address")
		gateInfo = decodeSingleVar(gateInfo,"type_code")
		gateInfo = decodeSingleVar(gateInfo,"dialed_address")
		gateInfo = decodeSingleVar(gateInfo,"version")
		gateInfo = decodeSingleVar(gateInfo,"name")
		tbl["gate_info"] = gateInfo
	if "udhd_info" in tbl:
		gateInfo = tbl["udhd_info"]
		gateInfo = decodeSingleVar(gateInfo,"idc_code")
		gateInfo = decodeSingleVar(gateInfo,"timer_text")
		gateInfo = decodeSingleVar(gateInfo,"websocket_user")
		gateInfo = decodeSingleVar(gateInfo,"version")
	if "session_info" in tbl:
		gateInfo = tbl["session_info"]
		gateInfo = decodeSingleVar(gateInfo,"world_name")
		gateInfo = decodeSingleVar(gateInfo,"host_user")
		tbl["session_info"] = gateInfo
	if "gate_list" in tbl:
		newlist = []
		for item in tbl["gate_list"]:
			item = decodeSingleVar(item,"gate_address")
			item = decodeSingleVar(item,"gate_code")
			item = decodeSingleVar(item,"gate_name")
			newlist.append(item)
		tbl["gate_list"] = newlist
	return tbl

def generateKeyString(keys):
	keyStr = ""
	firstLoop = True
	for key in keys:
		if firstLoop:
			keyStr = key
		else:
			keyStr = keyStr+", "+key
		firstLoop = False
	return keyStr

async def getPerms(keys,isDataCheck):
	admin = False
	for item in adminKeys:
		for key in keys:
			if item == key:
				admin = True
	allowedSlots = []
	if admin:
		for s in connectedStargates:
			allowedSlots.append(s["Slot"])
	else:
		for s in connectedStargates:
			allow = False
			if s["Key"] == publicAccessKey:
				allow = True
			for key in keys:
				if s["Key"] == key:
					allow = True
			if allow:
				allowedSlots.append(s["Slot"])
	if not isDataCheck:
		print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | "+"\033[96mgetPerms: "+generateKeyString(keys)+" Perms: "+json.dumps(allowedSlots)+"\033[0m")
	return allowedSlots

async def broadcastPerms():
	print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ","Fetching perms for broadcast!")
	for client in connectedClients:
		allowedSlots = await getPerms(client["KeyList"],False)
		connectedSlots = []
		for gate in connectedStargates:
			connectedSlots.append(gate["Slot"])
		raw = {
			"allowed":allowedSlots,
			"online":connectedSlots,
			"type":"perms"
		}
		await client["Websocket"].send(json.dumps(raw))

async def serveUpdate(websocket,useDevBranch):
	await asyncio.sleep(1)
	try:
		if useDevBranch:
			file = open(luaDevFilePath)
		else:
			file = open(luaFilePath)
		await websocket.send(file.read())
		file.close()
	except:
		await websocket.send("ERROR: EXCEPTION OCCURRED")
	await asyncio.sleep(1)
	await websocket.close()

async def handleStargate(websocket,initialMessage):
	try:
		x = json.loads(initialMessage)
		if "ws-key" in x:
			x = tryConvertGateData(x)
		x = decodeVars(x)
		slot = -1
		for i in range(maxSlotCount):
			if slot == -1:
				freeSlot = True
				for gate in connectedStargates:
					if i == gate["Slot"]:
						freeSlot = False
				if freeSlot:
					slot = i
					# print("Slot Set")
		item = slot
		print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ","Stargate Connected")
		print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ","Key: "+x["access_key"])
		print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ","Slot: "+str(item))
		if item != -1:
			identity = {"Websocket":websocket,"Key":x["access_key"],"Slot":item}
			connectedStargates.append(identity)
			del x["access_key"]
			x["slot"] = item
			x["type"] = "stargate"
			await broadcastPerms()
			await sendGateInfo(json.dumps(x),identity)
			await query()
			while True:
				try:
					async with asyncio.timeout(40):
						msg = await websocket.recv()
					x = json.loads(msg)
					if "ws-key" in x:
						x = tryConvertGateData(x)
					x = decodeVars(x)
					if "access_key" in x:
						del x["access_key"]
					x["slot"] = item
					x["type"] = "stargate"
					await sendGateInfo(json.dumps(x),identity)
				except TimeoutError:
					try:
						await websocket.send("CLOSING DUE TO INACTIVITY")
					except:
						pass
					print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ","Stargate timed out!")
					print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ","Slot: "+str(item))
					break
				except Exception as ex:
					print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ","\033[91mException in stargate handler loop\033[0m")
					print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ","Stargate Slot "+str(item))
					print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ",type[ex])
					print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ",ex.args)
					print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ",ex)
					break
			connectedStargates.remove(identity)
			await broadcastPerms()
			await query()
			await websocket.close()
		else:
			await websocket.close()
	except Exception as ex:
		print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ","\033[91mException in stargate handler\033[0m")
		print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ",type[ex])
		print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ",ex.args)
		print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ",ex)
		await websocket.close()

async def handleClient(websocket,initialMessage):
	if initialMessage.startswith("[") and initialMessage.endswith("]"):
		#json array
		raw = json.loads(initialMessage)
		keys = []
		for key in raw:
			keys.append(parse.unquote_plus(key))
		identity = {
			"Websocket":websocket,
			"KeyList":keys
		}
	else:
		#normal key
		identity = {
			"Websocket":websocket,
			"KeyList":[initialMessage]
		}
	keyStr = generateKeyString(identity["KeyList"])
	print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | Client Connected: "+keyStr)
	connectedClients.append(identity) #add the client to the list
	await broadcastPerms()
	await query() #this tells the headless instances to report all stargate data
	while True:
		try:
			try:
				async with asyncio.timeout(30):
					msg = await websocket.recv()
				await websocket.send('{"type":"keepalive"}')
				if msg == "-SLOTS":
					print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | Perm Request from "+keyStr)
					allowedSlots = await getPerms(identity["KeyList"],False)
					connectedSlots = []
					for gate in connectedStargates:
						connectedSlots.append(gate["Slot"])
					raw = {
						"allowed":allowedSlots,
						"online":connectedSlots,
						"type":"perms"
					}
					await identity["Websocket"].send(json.dumps(raw))
				elif msg == "-QUERY":
					await query()
				else:
					try:
						slotNo = int(msg[0:2])
						allowedSlots = await getPerms(identity["KeyList"],False)
						if slotNo in allowedSlots:
							for gate in connectedStargates:
								if gate["Slot"] == slotNo:
									msg = msg[2:]
									await gate["Websocket"].send(msg)
					except Exception as ex:
						print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | Exception in command send function!")
						print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ",type[ex])
						print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ",ex.args)
						print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ",ex)
			except TimeoutError:
				await websocket.send('{"type":"keepalive"}')
		except:
			try:
				connectedClients.remove(identity)
			except:
				pass
			break

async def handler(websocket):
	await websocket.send("INPUT USER")
	user = await websocket.recv()
	if user == "-UPDATE":
		await serveUpdate(websocket,False)
	elif user == "-UPDATE_DEV":
		await serveUpdate(websocket,True)
	elif user.startswith("{") and user.endswith("}"): #Stargate
		await handleStargate(websocket,user)
	elif user.startswith("[") and user.endswith("]"): #Client
		await handleClient(websocket,user)
	else:
		websocket.close()


async def main():
	loop = asyncio.get_running_loop()
	stop = loop.create_future()
	port = int(os.environ.get("PORT","8059"))
	print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" | ","Starting server on port "+str(port))
	async with serve(handler,"",port):
		await stop

if __name__=="__main__":
	asyncio.run(main())
