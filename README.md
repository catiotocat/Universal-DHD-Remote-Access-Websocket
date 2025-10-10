# Universal DHD Remote Access Websocket

 Remote Control System for Ancients of Resonite Stargate System

# Client Program

The client program (client.lua) is designed to be run through CraftOS-PC.  
You can download CraftOS-PC from https://www.craftos-pc.cc/  
An installer script is now available to help with setting up the program.
Simply drag and drop installer.lua from file explorer onto the CraftOS-PC window then type `installer.lua` to run it.
Once the installer is finished, you can type `client.lua` to run the program.
To change settings later on you can either use the built-in `set` command or re-run the installer.  

# Server Program

The server program was designed to run in Python 3.13 and relies on the `websockets` library.  
The server will default to running at the following url: `ws://localhost:8059/`  
The installer has this url available as a preset.

More documentation will be written in the future.
