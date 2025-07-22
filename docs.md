# Universal DHD Remote Access Documentation

> The URL for the websocket is `wss://catio.merith.xyz/ws/`

The Universal DHD uses a websocket server to handle remote access functionality.

## Auth Flow

Upon accepting a connection the server will send `INPUT USER`.

In order to use remote access, the client must respond with `ws-dev-user`.

The server will respond with another prompt: `INPUT KEY`.

The client should respond with the access key to be used for authentication. This key will determine what stargates are available for the client to control. All stargate data will be provided regardless of access key.

Once the server recieves the access key, it will immediatly begin sending data to the client and will listen for further messages.

## Message Structure (Client -> Server)

All messages sent by a client to the server should be in plain text.

There are 3 special commands that can be sent by any client at any time.

- `-API` - Tells the server to make a stargate api request. Results in a Stargate API Data message being sent to all clients.
- `-SLOTS` - Tells the server to immediatly send out Permission Information messages to all clients.
- `-QUERY` - Tells the server to query information from all connected stargates. Results in many Stargate Slot Information messages being sent to all clients.

In addition to the special commands, there are multiple commands that are desinged to target a specific stargate.

These commands will be blocked if the client does not have permission to control the provided slot number.

### Command List

> Command Format: `XXYZ`  
`XX` = 2 digit slot number to target  
`Y` = 1 character command ID  
`Z` (optional) = variable length parameter for commands that require it.

`0`: Tells the Universal DHD to immediatly send a Stargate Slot Information message.  
`1`\*: Triggers a `Dial` dynamic impulse on the stargate using the parameter as the dialing address.  
`2`\*: Triggers a Nox Dial event on the stargate using the parameter as the dialing address.  
`3`: Triggers a `Fail` impulse on the stargate with value `400`.  
`4`: Triggers a `CloseWormhole` impulse on the stargate.  
`5`: Toggles the state of the iris on the stargate (If Present)  
`6`: Toggles the state of Auto Iris Mode on the Universal DHD (If Iris is Present)  
`7`\*: Sets the iris code on the Universal DHD to the parameter value (If Iris is Present)  
`8`\*: Sends the parameter as an IDC Impulse to the dialed stargate.  
`9`\*: Allows use of DHD Impulses. Set the parameter to `?` to fire DHDLock and `#` to fire DHDOpen. Anything else will be sent as a DHDEncode impulse. Only works if both the Stargate and the Universal DHD support it. (Requires Universal DHD Version `1.0.0` or later)

\*Marks commands that require a parameter

## Message Structure (Server -> Client)

The server will send only JSON Formatted messages to the client.

These messages can be split into 4 categories:

- KeepAlive Message
- Stargate Slot Information
- Permission Information
- Stargate API Data

### KeepAlive Message Structure

This message type does not require any response and is sent at least once every 30 seconds.

|Key|Type|Description|Notes|
|-|-|-|-|
|`type`|string|The type of message|Will be set to `keepalive` for this message type.|

### Stargate Slot Information Message Structure

|Key|Type|Description|Notes|
|-|-|-|-|
|`type`|string|The type of message|Will be set to `stargate` for this message type.|
|`slot`|int|Provides the slot number that can be used to send commands to the stargate.||
|`gateStatus`|int|The status of the stargate. See documentation below for more information.|If value is `-1`, Assume only `type`, `slot` and `gateStatus` are provided|
|`controlState`|int|The control state on the Universal DHD. See documentation below for more information.||
|`addr`|string|The address of the stargate, not including the type code||
|`group`|string|The type code of the stargate.||
|`irisPresent`|bool|If true, an iris exists on the stargate||
|`idcPresent`|bool|If true, IDC is available on the Universal DHD|If `irisPresent` is `false`, treat this value as `false` too.|
|`irisClose`|bool|True if the stargate's iris is closed||
|`idcEN`|bool|The state of the IDC system on the Universal DHD|Might not be provided if `idcPresent` is `false`|
|`idcCODE`|string|The IDC Code set on the Universal DHD|Might not be provided if `idcPresent` is `false`|
|`dialedAddr`|string|The currently encoded address on the stargate||
|`chevrons`|int|The number of currently encoded chevrons||
|`locked`|bool|True if the gate's point of origin is locked||
|`open`|bool|True if the stargate is open||
|`incoming`|bool|True if the stargate is on incoming||
|`remoteIris`|bool|True if the dialed stargate has an active iris||
|`playerCount`|int|The number of users in the session||
|`playerMax`|int|The session user limit||
|`timerText`|string|The text to be displayed before the timer data|This field is optional and is often not present|
|`min`|int|The minutes value for the timer|This field is optional and is often not present|
|`sec`|int|The seconds value for the timer|This field is optional and is often not present|
|`gateInfo`|table|Contains extra information about the world, the Stargate, and the Universal DHD. See documentation below for more information.|This field is optional and might not be present.|

#### `gateStatus` Value Information

|Value|Meaning|
|-|-|
|`-1`|This Slot is Currently Offline|
|`0`|Stargate is idle|
|`1`|Stargate is active, but the chevron is not locked|
|`2`|Stargate is active and the chevron is locked|
|`3`|Stargate is on incoming|

#### `controlState` Value Information

|Value|Meaning|
|-|-|
|`-1`|No Controls Available, Setup is Open|
|`0`|Dialing Controls are available|
|`1`|Cancel Dial Button is available|
|`2`|Close Wormhole and GDO Functionality are availabe|
|`3`|No Controls Available, Incoming Wormhole|

#### `gateInfo` Table Structure

|Key|Type|Description|Notes|
|-|-|-|-|
|`session_name`|string|The name of the world||
|`host_name`|string|The Host User's Username|This is the host of the session, not the user running the websocket connection|
|`gate_cs_en`|bool|Value of `Stargate/Internal_CrossSession`||
|`gate_name`|string|Value of `Stargate/Internal_CrossSessionName`|This field is optional and might be missing|
|`gate_cs_vis`|bool|Value of `Stargate/Internal_CrossSessionVisible`||
|`access_level`|string|The access level of the session||
|`user_name`|string|The username of the user running the websocket connection.|Requires Universal DHD Version `1.0.0` or later|
|`gate_version`|string|The stargate's version number|Requires Universal DHD Version `1.0.0` or later|
|`dhd_version`|string|The Universal DHD version number|Requires Universal DHD Version `1.0.0` or later|

### Permission Information Message Structure

>Note: The arrays provided in this message type are not guarenteed to be sorted

|Key|Type|Description|Notes|
|-|-|-|-|
|`type`|string|The type of message|Will be set to `perms` for this message type.|
|`defined`|int array|List of all pre-registered slots in the server config|Use this alongside `online` to form a full list of existing slots|
|`allowed`|int array|List of all slot IDs the client is currently allowed to send commands to||
|`online`|int array|List of all currently online slots|Use this alongside `defined` to form a full list of existing slots|

### Stargate API Data Message Structure

>This message type does not provide a `type` field.  
It instead directly provides the data from a Stargate API Query.

See [Stargate API Documentation](https://docs.rxserver.net/universe/public_api/stargate/stargates)