#!/usr/bin/env python

import asyncio
import aiohttp
import signal
import os
import json
from websockets.asyncio.server import serve
global apiRequested
apiRequested = False
connected = []

fileDir = "./files/"
luaFileDirectory = "./files/lua/"


headlessConfig = []
defaultconfig = {
		"key":"ws-dev-public",
		"slotListType":"whitelist",
		"slotList":[],
		"allowJSON":False,
		"canControlExtras":False,
		"allowAddresses":[],
		"keyEnabled":True,
	}
clientConfig = [
	{
		"key":"internal-stargate-identity",
		"slotListType":"blacklist",
		"slotList":[],
		"allowJSON":False,
		"canControlExtras":False,
		"allowAddresses":[],
		"keyEnabled":False,
	},
	{
		"key":"ws-dev-public",
		"slotListType":"whitelist",
		"slotList":[],
		"allowJSON":False,
		"canControlExtras":False,
		"allowAddresses":[],
		"keyEnabled":True,
	},
]

requiredSlots = []
# requiredSlots = [0]
maxSlotCount = 100
connnectedSlots = []
pingedSlots = []
pongedSlots = []
addressTable = {}
keyTable = {}

async def pingPong():
	while True:
		await asyncio.sleep(30)
		# ping
		pingedSlots = connnectedSlots
		pongedSlots = []
		for item in connected:
			try:
				if item["slot"] > -1:
					await item["handle"].send("-PING")
			except:
				connected.remove(item)
		await asyncio.sleep(30)
		for slot in pingedSlots:
			if not slot in pongedSlots:
				for x in connected:
					if x["slot"]==slot:
						try:
							await x["handle"].close()
						except:
							connected.remove(x)
		# kill

async def apiFunc():
	async with aiohttp.ClientSession() as session:
		global apiRequested
		while True:
			await asyncio.sleep(5)
			if apiRequested:
				apiRequested = False
				try:
					async with session.get("https://api.rxserver.net/stargates/") as response:
						await transmit(await response.text())
				except:
					apiRequested = True

async def actuallyTransmit(message):
	slot = None
	if message.startswith("{") and message.endswith("}"): # this triggers json parse attempts
		try:
			dat = json.loads(message)
			slot = dat["slot"]
			# print("Detected Slot "+str(slot))
		except:
			slot = None
	for connection in connected:
		msg = message
		try:
			if connection["key"] != "internal-stargate-identity" or msg == "-QUERY":
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

async def broadcastPerms():
	for client in connected:
		if client["key"] != "internal-stargate-identity":
			auth = defaultconfig
			for item in clientConfig:
				if item["key"] == client["key"]:
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
								if keyTable[str(s)] == client["key"] or keyTable[str(s)]=="ws-dev-public":
									allow = True
					if allow:
						allowedSlots.append(s)
			raw = {
				"defined":requiredSlots,
				"allowed":allowedSlots,
				"online":connnectedSlots,
				"type":"perms"
			}
			await client["handle"].send(json.dumps(raw))

async def handler(websocket):
	await websocket.send("INPUT USER")
	user = await websocket.recv()
	if user == "ws-dev-user":
		await websocket.send("INPUT KEY")
		key = await websocket.recv()
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
			connected.append(identity) #add the client to the list
			await transmit("-QUERY") #this tells the headless instances to report all stargate data
			while True:
				try:
					try:
						async with asyncio.timeout(30):
							msg = await websocket.recv()
						await websocket.send('{"type":"keepalive"}')
						if msg.startswith("{") and msg.endswith("}") and auth["allowJSON"] == False:
							print("JSON Perms Denied: "+key)
						elif msg.startswith("{") and msg.endswith("}"):
							await transmit(msg)
						elif msg == "-API":
							global apiRequested
							apiRequested = True
						elif msg == "-SLOTS":
							await broadcastPerms()
						elif msg == "-QUERY":
							await transmit("-QUERY")
						else:
							try:
								slotNo = int(msg[0:2])
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
												if keyTable[str(s)] == key or keyTable[str(s)]=="ws-dev-public":
													allow = True
									if allow:
										allowedSlots.append(s)
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
		else: #if the access key was wrong, close the connection
			await websocket.close()
	elif user == "ws-dev-get":
		while True: 
			await websocket.send("INPUT FILE PATH")
			fp = await websocket.recv()
			if fp == "-LOGOUT":
				await websocket.send("Logging out...")
				await asyncio.sleep(1)
				await websocket.close()
				break
			elif ".." in fp:
				await websocket.send("Access Denied.")
			else:
				try:
					file = open(fileDir+fp)
					await websocket.send(file.read())
					file.close()
				except:
					await websocket.send("File not Found")
	elif user.startswith("{") and user.endswith("}"):
		try:
			x = json.loads(user)
			slot = -1
			for i in range(len(headlessConfig)):
				check = headlessConfig[i]
				if check.get("key") == x.get("ws-key"):
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
			print("Stargate Auth Processing")
			print("Key: "+x["ws-key"])
			print("Slot: "+str(item))
			if item != -1:
				connnectedSlots.append(item)
				identity = {"handle":websocket,"key":"internal-stargate-identity","slot":item}
				connected.append(identity)
				print("Stargate Authentication Completed")
				print("Key: "+x["ws-key"])
				print("Slot: "+str(item))
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
						if msg == "-PONG":
							pongedSlots.append(item)
						else:
							x = json.loads(msg)
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
					except TimeoutError:
						try:
							await websocket.send("CLOSING DUE TO INACTIVITY")
						except:
							pass
						print("Stargate timed out!")
						break
					except Exception as ex:
						print("\033[91mException in stargate handler loop\033[0m")
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
				await transmit("-QUERY")
				await broadcastPerms()
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
	else: #if the supplied user was invalid, close the connection
		await websocket.close()


async def main():
	apiTask = asyncio.create_task(apiFunc())
	# pingTask = asyncio.create_task(pingPong())
	loop = asyncio.get_running_loop()
	stop = loop.create_future()
	# loop.add_signal_handler(signal.SIGTERM, stop.set_result, None)
	port = int(os.environ.get("PORT","8059"))
	async with serve(handler,"",port):
		await stop

if __name__=="__main__":
	asyncio.run(main())
