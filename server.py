#!/usr/bin/env python

import asyncio
import signal
import os
import json
from urllib import parse
from websockets.asyncio.server import serve
connected = []

publicAccessKey = "public"

mypath = os.path.dirname(os.path.realpath(__file__))
print(mypath)
luaFilePath = mypath+"/lua/client.lua"
luaDevFilePath = mypath+"/lua/client_dev.lua"

headlessConfig = [
	{
		"key":"internal-stargate-identity",
		"slot":-1,
		"enabled":False
	},
	{
		"key":publicAccessKey,
		"slot":-1,
		"enabled":False
	}
]
baseHeadlessConfig = headlessConfig
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
	{
		"key":"internal-stargate-identity",
		"slotListType":"blacklist",
		"slotList":[],
		"canControlExtras":False,
		"allowAddresses":[],
		"allowKeys":[],
		"keyEnabled":False,
	},
	defaultconfig,
]
baseClientConfig = clientConfig

restrictDataAccess = False
requiredSlots = []
# load user config file
try:
	configFile = open(mypath+"/config/config.json")
	config = json.loads(configFile.read())
	configFile.close()
	for gate in config["gates"]:
		if gate["enabled"] == False:
			print("Skipped loading entry for slot "+str(gate["slot"])+" because entry is disabled")
		elif gate["slot"] in requiredSlots:
			print("\033[33mDuplicate Gate Entry Detected: Slot "+str(gate["slot"])+" is defined multiple times!\033[0m")
		else:
			duplicate = False
			for entry in headlessConfig:
				if entry["key"] == gate["key"]:
					duplicate = True
			if duplicate:
				print("\033[33mDuplicate Gate Entry Detected: Slot "+str(gate["slot"])+" uses duplicate access key!\033[0m")
			else:
				print("Loaded gate entry for slot "+str(gate["slot"]))
				headlessConfig.append(gate)
				requiredSlots.append(gate["slot"])
	for key in config["keys"]:
		if key["keyEnabled"] == False:
			print("Skipped loading key \""+key["key"]+"\" because entry is disabled.")
		else:
			duplicate = False
			for entry in clientConfig:
				if entry["key"] == key["key"]:
					duplicate = True
			if duplicate:
				print("\033[33mDuplicate Client Key Entry Detected: Key \""+key["key"]+"\" is defined multiple times!\033[0m")
			else:
				clientConfig.append(key)
				print("Loaded Client Entry: \""+key["key"]+"\"")
	if "restrictDataAccess" in config:
		if config["restrictDataAccess"] == True:
			restrictDataAccess = True
			print("Blocking Data Access for denied slots")
except Exception as ex:
	print("\033[91mFailed to read config file!\033[0m")
	print(type[ex])
	print(ex.args)
	print(ex)
	print("Using default config file")
	headlessConfig = []
	clientConfig = baseClientConfig
	restrictDataAccess = False
	try: # Fall back to default config file
		configFile = open(mypath+"/config/default.json")
		config = json.loads(configFile.read())
		configFile.close()
		for gate in config["gates"]:
			if gate["enabled"] == False:
				print("Skipped loading entry for slot "+str(gate["slot"])+" because entry is disabled")
			elif gate["slot"] in requiredSlots:
				print("\033[33mDuplicate Gate Entry Detected: Slot "+str(gate["slot"])+" is defined multiple times!\033[0m")
			else:
				duplicate = False
				for entry in headlessConfig:
					if entry["key"] == gate["key"]:
						duplicate = True
				if duplicate:
					print("\033[33mDuplicate Gate Entry Detected: Slot "+str(gate["slot"])+" uses duplicate access key!\033[0m")
				else:
					print("Loaded gate entry for slot "+str(gate["slot"]))
					headlessConfig.append(gate)
					requiredSlots.append(gate["slot"])
		for key in config["keys"]:
			if key["keyEnabled"] == False:
				print("Skipped loading key \""+key["key"]+"\" because entry is disabled.")
			else:
				duplicate = False
				for entry in clientConfig:
					if entry["key"] == key["key"]:
						duplicate = True
				if duplicate:
					print("\033[33mDuplicate Client Key Entry Detected: Key \""+key["key"]+"\" is defined multiple times!\033[0m")
				else:
					clientConfig.append(key)
					print("Loaded Client Entry: \""+key["key"]+"\"")
		if "restrictDataAccess" in config:
			if config["restrictDataAccess"] == True:
				restrictDataAccess = True
				print("Blocking Data Access for denied slots")
	except Exception as ex: #If both files are broken, give up on config loading.
		print("\033[91mFailed to read default config file!\033[0m")
		print(type[ex])
		print(ex.args)
		print(ex)
		print("Skipping config file loading.")
		headlessConfig = []
		clientConfig = baseClientConfig
		restrictDataAccess = False

maxSlotCount = 100
connnectedSlots = []
addressTable = {}
keyTable = {}

async def actuallyTransmit(message):
	slot = None
	if message.startswith("{") and message.endswith("}"): # this triggers json parse attempts
		try:
			dat = json.loads(message)
			slot = dat["slot"]
			# print("Detected Slot "+str(slot))
		except:
			slot = None
	if restrictDataAccess and slot:
		print("Fetching perms for data access! Slot "+str(slot))
	for connection in connected:
		msg = message
		try:
			if connection["key"] != "internal-stargate-identity" or msg == "-QUERY":
				if connection["key"] == "internal-stargate-identity" or msg != "-QUERY":
					if restrictDataAccess and slot != None:
						allowedSlots = await getPerms(connection["key"])
						if slot in allowedSlots:
							print("Key: "+connection["key"]+" Slot: "+str(slot))
							await connection["handle"].send(msg)
						else:
							raw = {
								"slot":slot,
								"gateStatus":-1,
								"type":"stargate"
							}
							msg = json.dumps(raw)
							await connection["handle"].send(msg)
					else:
						await connection["handle"].send(msg)
		except:
			connected.remove(connection)

async def transmit(message):
	await actuallyTransmit(message)
	for item in requiredSlots:
		if not item in connnectedSlots:
			raw = {
				"slot":item,
				"gateStatus":-1,
				"type":"stargate"
			}
			msg = json.dumps(raw)
			await actuallyTransmit(msg)

def decodeSingleVar(tbl,key):
	if key in tbl:
		tbl[key] = parse.unquote(tbl[key])
	return tbl
	

def decodeVars(tbl):
	tbl = decodeSingleVar(tbl,"timerText")
	tbl = decodeSingleVar(tbl,"idcCODE")
	tbl = decodeSingleVar(tbl,"addr")
	tbl = decodeSingleVar(tbl,"group")
	tbl = decodeSingleVar(tbl,"dialedAddr")
	tbl = decodeSingleVar(tbl,"ws-key")
	if "gateInfo"  in tbl:
		gateInfo = tbl["gateInfo"]
		gateInfo = decodeSingleVar(gateInfo,"session_name")
		gateInfo = decodeSingleVar(gateInfo,"host_name")
		gateInfo = decodeSingleVar(gateInfo,"gate_name")
		gateInfo = decodeSingleVar(gateInfo,"gate_version")
		gateInfo = decodeSingleVar(gateInfo,"dhd_version")
		gateInfo = decodeSingleVar(gateInfo,"user_name")
		gateInfo = decodeSingleVar(gateInfo,"access_level")
		tbl["gateInfo"] = gateInfo
	return tbl

async def getPerms(accessKey):
	auth = defaultconfig
	for item in clientConfig:
		if item["key"] == accessKey:
			auth = item
	allowedSlots = []
	if auth["slotListType"] == "blacklist":
		for s in requiredSlots:
			if not s in auth["slotList"]:
				allowedSlots.append(s)
	else:
		for s in auth["slotList"]:
			allowedSlots.append(s)
	if auth["canControlExtras"]:
		for s in connnectedSlots:
			allow = False
			if not s in requiredSlots:
				allow = True
			if allow:
				allowedSlots.append(s)
	else:
		for s in connnectedSlots:
			allow = False
			if not s in requiredSlots:
				if str(s) in addressTable:
					for addr in auth["allowAddresses"]:
						if addr == addressTable[str(s)]:
							allow = True
			if allow:
				allowedSlots.append(s)
	for s in connnectedSlots:
			allow = False
			if not s in requiredSlots:
				if not s in allowedSlots:
					if str(s) in keyTable:
						if keyTable[str(s)] == accessKey or keyTable[str(s)]==publicAccessKey:
							allow = True
			if allow:
				allowedSlots.append(s)
	print("\033[96mgetPerms: "+accessKey+" Perms: "+json.dumps(allowedSlots)+"\033[0m")
	return allowedSlots

async def broadcastPerms():
	print("Fetching perms for broadcast!")
	for client in connected:
		if client["key"] != "internal-stargate-identity":
			allowedSlots = await getPerms(client["key"])
			raw = {
				"defined":requiredSlots,
				"allowed":allowedSlots,
				"online":connnectedSlots,
				"type":"perms"
			}
			await client["handle"].send(json.dumps(raw))
			print("\033[96mClient: "+client["key"]+" Perms: "+json.dumps(raw)+"\033[0m")

async def handler(websocket):
	await websocket.send("INPUT USER")
	user = await websocket.recv()
	if user == "-UPDATE":
		await asyncio.sleep(1)
		try:
			file = open(luaFilePath)
			await websocket.send(file.read())
			file.close()
		except:
			await websocket.send("ERROR: EXCEPTION OCCURRED")
		await asyncio.sleep(1)
		await websocket.close()
	elif user == "-UPDATE_DEV":
		await asyncio.sleep(1)
		try:
			file = open(luaDevFilePath)
			await websocket.send(file.read())
			file.close()
		except:
			await websocket.send("ERROR: EXCEPTION OCCURRED")
		await asyncio.sleep(1)
		await websocket.close()
	elif user.startswith("{") and user.endswith("}"):
		try:
			x = json.loads(user)
			x = decodeVars(x)
			slot = -1
			for i in range(len(headlessConfig)):
				check = headlessConfig[i]
				if check.get("key") == x.get("ws-key") and check.get("enabled"):
					# await transmit(json.dumps({"lua":"print(\""+check.get("user")+"\",\""+check.get("key")+"\")"}))
					# await asyncio.sleep(2)
					slot = i
					break
			item = 0
			if slot == -1:
				# assign a slot
				for i in range(maxSlotCount):
					if not i in requiredSlots and not i in connnectedSlots and slot == -1:
						slot = i
				item = slot
			else:
				item = headlessConfig[slot].get("slot")
				if item in connnectedSlots:
					item = -1
			print("Stargate Auth Processing")
			print("Key: "+x["ws-key"])
			print("Slot: "+str(item))
			if item != -1:
				connnectedSlots.append(item)
				identity = {"handle":websocket,"key":"internal-stargate-identity","slot":item}
				connected.append(identity)
				# print("Stargate Authentication Completed")
				# print("Key: "+x["ws-key"])
				# print("Slot: "+str(item))
				keyTable[str(item)] = x["ws-key"]
				del x["ws-key"]
				x["slot"] = item
				x["type"] = "stargate"
				addressTable[str(item)] = x["addr"]
				await broadcastPerms()
				await transmit(json.dumps(x))
				await transmit("-QUERY")
				# await transmit(json.dumps({"lua":"print(\"loop start\")"}))
				while True:
					try:
						async with asyncio.timeout(40):
							msg = await websocket.recv()
						x = json.loads(msg)
						x = decodeVars(x)
						if "ws-key" in x:
							del x["ws-key"]
						x["slot"] = item
						x["type"] = "stargate"
						reSendPerms = False
						if addressTable[str(item)] != x["addr"]:
							reSendPerms = True
						addressTable[str(item)] = x["addr"]
						if reSendPerms:
							await broadcastPerms()
							await transmit(json.dumps(x))
							await transmit("-QUERY")
						else:
							await transmit(json.dumps(x))
					except TimeoutError:
						try:
							await websocket.send("CLOSING DUE TO INACTIVITY")
						except:
							pass
						print("Stargate timed out!")
						print("Slot: "+str(item))
						break
					except Exception as ex:
						print("\033[91mException in stargate handler loop\033[0m")
						print("Stargate Slot "+str(item))
						print(type[ex])
						print(ex.args)
						print(ex)
						break
				connnectedSlots.remove(item)
				connected.remove(identity)
				if str(item) in addressTable:
					del addressTable[str(item)]
				if str(item) in keyTable:
					del keyTable[str(item)]
				await broadcastPerms()
				await transmit("-QUERY")
				# await transmit(json.dumps({"lua":"print(\"death\")"}))
				await websocket.close()
			else:
				await websocket.close()
		# except:
		# 	print("something went wrong during stargate handling")
		except Exception as ex:
			print("\033[91mException in stargate handler\033[0m")
			print(type[ex])
			print(ex.args)
			print(ex)
			# await transmit(json.dumps({"lua":"print(\"exception\")"}))
			await websocket.close()
	else:
		key = user
		print("Authenticating user: "+key)
		auth = defaultconfig
		for item in clientConfig:
			if item["key"] == key:
				auth = item
		if auth["keyEnabled"]==True:
			identity = {
				"handle":websocket,
				"key":key,
				"slot":-1
			}
			print("Auth competed! User: "+key)
			connected.append(identity) #add the client to the list
			await broadcastPerms()
			await transmit("-QUERY") #this tells the headless instances to report all stargate data
			while True:
				try:
					try:
						async with asyncio.timeout(30):
							msg = await websocket.recv()
						await websocket.send('{"type":"keepalive"}')
						if msg.startswith("{") and msg.endswith("}"):
							print("Blocked JSON From Client: "+key)
						elif msg == "-SLOTS":
							print("Perm Request from "+key)
							allowedSlots = await getPerms(key)
							raw = {
								"defined":requiredSlots,
								"allowed":allowedSlots,
								"online":connnectedSlots,
								"type":"perms"
							}
							await websocket.send(json.dumps(raw))
							print("\033[96mClient: "+key+" Perms: "+json.dumps(raw)+"\033[0m")
						elif msg == "-QUERY":
							await transmit("-QUERY")
						else:
							try:
								slotNo = int(msg[0:2])
								allowedSlots = await getPerms(key)
								if slotNo in allowedSlots:
									for item in connected:
										if item["slot"] != -1:
											if item["slot"] == slotNo:
												msg = msg[2:]
												await item["handle"].send(msg)
							except Exception as ex:
								print("Exception in command send function!")
								print(type[ex])
								print(ex.args)
								print(ex)
					except TimeoutError:
						await websocket.send('{"type":"keepalive"}')
				except:
					try:
						connected.remove(identity)
					except:
						pass
					break
		else: #if the access key was presend but disabled, close the connection
			await websocket.close() #This blocks use of the internal stargate identity


async def main():
	# apiTask = asyncio.create_task(apiFunc())
	loop = asyncio.get_running_loop()
	stop = loop.create_future()
	# loop.add_signal_handler(signal.SIGTERM, stop.set_result, None)
	port = int(os.environ.get("PORT","8059"))
	print("Starting server on port "+str(port))
	async with serve(handler,"",port):
		await stop

if __name__=="__main__":
	asyncio.run(main())
