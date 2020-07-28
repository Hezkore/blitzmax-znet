SuperStrict

Import brl.objectlist
Import brl.socketstream

Import "packet.bmx"
Import "connection.bmx"

Type TZClient Extends TZConnection
	
	Field _port:Int
	Field _address:String
	
	Field _packetFuncPointer:TZPacket(packet:TZPacket)
	
	Field _noDelay:Byte = True
	
	Method New(func:TZPacket(packet:TZPacket))
		Super.New()
		
		Self.SetPacketFunctionPointer(func)
	EndMethod
	
	Method SetPacketFunctionPointer(func:TZPacket(packet:TZPacket))
		
		Self._packetFuncPointer = func
	EndMethod
	
	Method Connect:Int(address:String, port:Int)
		
		Self._sessionID = Null
		Self._address = address
		Self._port = port
		
		Local hints:TAddrInfo = New TAddrInfo(AF_INET_, SOCK_STREAM_)
		Self._socket:TSocket = TSocket.Create(hints)
		
		If Not Self._socket Then
		    Print "Unable to create socket"
		    Return False
		EndIf
		
		Local infos:TAddrInfo[] = AddrInfo(Self._address, Self._port, hints)
		
		If Not infos Then
		    Print "Hostname could not be resolved"
		    Return False
		EndIf
		
		' We'll try the first one
		Local info:TAddrInfo = infos[0]
		
		Print "IP address of " + address + " is " + info.HostIp()
		
		If Not Self._socket.Connect(info) Then
		    Print "Error connecting to remote"
		    Return False
		EndIf
		
		Print "Socket connected to " + address + " on ip " + Self._socket.RemoteIp()
		
		Self._stream = CreateSocketStream(Self._socket)
			
		If Not Self._stream Then
		    Print "Error creating stream"
		    Return False
		EndIf
		
		' Await our session ID
		While Self._sessionID <= 0
			If ReadAvail() >= 2 Then
				Self._sessionID = _stream.ReadShort()
				Self._identified = True
				Self.WriteShort(Self._sessionID)
			EndIf
		WEnd
		
		Return True
	EndMethod
	
	Method _internalPacket(packet:TZPacket)
	EndMethod
	
	Method _triggerPacketFuncPointer(packet:TZPacket)
		
		' Call the packet function pointer
		' Anything returned will be sent
		Local returnPacket:TZPacket = ..
			Self._packetFuncPointer(packet)
		
		' Did we get a return packet?
		If returnPacket Self.QueuePacket(returnPacket)
	EndMethod
EndType