SuperStrict

Import brl.objectlist
Import brl.socket

Import "packet.bmx"

Type TZServer
	Field _clientsMax:Short
	Field _clientCount:Short
	
	Field _noDelay:Byte = True
	Field _port:Int
	Field _socket:TSocket
	Field _packetFuncPointer:TZPacket(packet:TZPacket)
	Field _connections:TServerConnection[]	'All our "players" are stored here
	
	Field _hints:TAddrInfo
	
	Method New(func:TZPacket(packet:TZPacket))
		
		Self.SetPacketFunctionPointer(func)
	EndMethod
	
	Method SetPacketFunctionPointer(func:TZPacket(packet:TZPacket))
		
		Self._packetFuncPointer = func
	EndMethod
	
	Method Start:Byte(port:Int, clientsMax:Short = 16)
		
		' Sanity checks
		If clientsMax <= 0 Then
			Print("Max client count is too low!")
			Return False
		EndIf
		Self._clientsMax = clientsMax
		Self._port = port
		
		' Resize the connections array so that it fits all clients
		Self._connections = New TServerConnection[Self._clientsMax]
		
		' Prepare the socket
		Self._socket = CreateTCPSocket()
				If Not Self._socket Then
		    Print "Unable to create socket"
		    Return False
		EndIf
		
		If Not BindSocket(Self._socket, Self._port) Or Not SocketListen(Self._socket)
			CloseSocket(Self._socket)
			Print("Unable to create server at port #" + Self._port)
			Return False
		EndIf
		
		Self._socket.SetTCPNoDelay(Self._noDelay)
		
		Print("New server at port #" + Self._port)
		
		Return True
	EndMethod
	
	Method Close()
		
		CloseSocket(Self._socket)
	EndMethod
	
	Method _checkDisconnects()
		For Local c:TServerConnection = EachIn Self._connections
			If Not c.Connected() Then
				
				If c._state = 1
					' This was an identified connection
					' Report its departure via a packet
					Local leavePacket:TZPacket = New TZPacket(TZDefaultPackets.Left)
					leavePacket.SetFromClient(c._sessionID)
					
					Self._triggerPacketFuncPointer(leavePacket)
				EndIf
				
				Self._connections[c._sessionID] = Null
				Self._clientCount:-1
			EndIf
		Next
	EndMethod
	
	Method _checkNewConnections:TServerConnection()
		
		' Accept the new socket if there is one
		Local accepted_socket:TSocket = SocketAccept(Self._socket)
		If Not accepted_socket Return Null ' Return null if there was no new connection
		
		' Check if we're inside the max client limit
		If Self._clientCount < Self._clientsMax Then
			' We're good, continue
			Self._clientCount:+1
			
			Local client:TServerConnection = New TServerConnection
			client._socket = accepted_socket
			client._stream = CreateSocketStream(client._socket)
			
			client._sessionID = Self._findFreeSessionID()
			Self._connections[client._sessionID] = client
			
			' Send the client his ID
			'client.WriteShort(client._sessionID)
			client.WriteShort(client._sessionID)
			
			'Print("New client: " + client.sessionID)
			Return client
		Else
			' No free client slots, close connection
			accepted_socket.Close()
			
			Print("Client overflow (" + Self._clientCount + "/" + Self._clientsMax + ")")
			Return Null
		EndIf
	EndMethod
	
	Method _receiveAndSendData()
		
		' Send packets in the queue
		Local packet:TZPacket
		For Local c:TServerConnection = EachIn Self._connections
			' FIX: Send as one huge bank, not one bank per packet
			For packet = EachIn c._sendQueue.Reversed() ' FIX: Once it's a queue we don't need to reverse this!
				c._stream.WriteBytes(packet.ToBank(True), packet.Size())
			Next
			c._sendQueue.Clear()
		Next
		
		' Receive packets
		Local canReceiveMorePackets:Byte
		For Local c:TServerConnection = EachIn Self._connections
			
			' Only handle a certain amount of packets per client
			canReceiveMorePackets = 5
			
			' WHILE there's stuff to read
			While c.ReadAvail() > 0
				
				' Is this client identified?
				If c._state = 0 Then ' nope
					If c.ReadAvail() >= 2 Then
						
						' Client needs to identify by sending correct session ID
						If c.ReadShort() = c._sessionID Then
							'Print("Client #" + c.sessionID + " identified")
							c._state = 1
							' Annouce via packet
							Local joinPacket:TZPacket = New TZPacket(TZDefaultPackets.Join)
							joinPacket.SetFromClient(c._sessionID)
							Self._triggerPacketFuncPointer(joinPacket)
						Else
							Print("Client #" + c._sessionID + " failed to ident!")
							c.Close()
						EndIf
					EndIf
				EndIf
				
				If c._state = 1 Then ' yep
					Select c._incomingPacketState
						
						' First stage is getting the ID for the packet
						Case 0
							If c.ReadAvail() >= 1 Then
								If Not c._incomingPacket..
									c._incomingPacket = New TZPacket(Byte(c.ReadByte()))
								c._incomingPacketState:+1
							EndIf
						
						' Second stage is getting destination
						Case 1
							If c.ReadAvail() >= 2 Then
								c._incomingPacket.SetToClient(Short(c.ReadShort()))
								c._incomingPacket.SetFromClient(c._sessionID)
								c._incomingPacketState:+1
							Else
								Exit
							EndIf
						
						' Third stage is getting the length and preparing our bank
						Case 2
							If c.ReadAvail() >= 2 Then
								c._incomingPacket.SetSize(Short(c.ReadShort()))
								c._incomingPacketState:+1
							Else
								Exit
							EndIf
						
						' Fourth is the actual packet
						Case 3
							' FIX: Instead of adding one byte we could add many
							If Not c._incomingPacket.EOF() Then
								c._incomingPacket.WriteByte(Byte(c.ReadByte()))
							EndIf
							
							' Packet is complete!
							If c._incomingPacket.EOF() Then						
								canReceiveMorePackets:-1
								c._incomingPacketState = 0
								
								' Is this an internal packet?
								If c._incomingPacket.ID() <= 250 Then
									Self._triggerPacketFuncPointer(c._incomingPacket)
								Else
									Self._internalPacket(c._incomingPacket)
								EndIf
							EndIf
					EndSelect
				EndIf
				
				If canReceiveMorePackets < 0 Exit
			Wend
		Next
	EndMethod
	
	Method _internalPacket(packet:TZPacket)
	EndMethod
	
	Method _triggerPacketFuncPointer(packet:TZPacket)
		
		' Call the packet function pointer
		' Anything returned will be sent
		Local returnPacket:TZPacket = ..
			Self._packetFuncPointer(packet)
		
		' Did we get a return packet?
		If returnPacket Then
			
			' For everyone
			If returnPacket.ToClient() = 0 Then
				
				For Local c:TServerConnection = EachIn Self._connections
					c.QueuePacket(returnPacket)
				Next
			Else
				
				If Self.GetConnection(returnPacket.ToClient()) ..
					Self.GetConnection(returnPacket.ToClient()).QueuePacket(returnPacket)
			EndIf
		EndIf
	EndMethod
	
	Method Update()
		
		' Look for disconnects
		Self._checkDisconnects()
		
		' Look for new connections
		Self._checkNewConnections()
		
		' Receive data
		Self._receiveAndSendData()
	EndMethod
	
	Method _findFreeSessionID:Int()
		
		' Find the first empty space in our connections array
		For Local i:Int = 1 Until Self._connections.Length
			If Not Self._connections[i] Return i
		Next
	EndMethod
	
	Method GetConnection:TServerConnection(sessionID:Short)
		If Self._connections[sessionID] ..
			Return(Self._connections[sessionID])
	EndMethod
EndType

Type TServerConnection
	
	Field _socket:TSocket
	Field _stream:TSocketStream
	
	Field _sessionID:Short
	Field _state:Byte
	
	' Holds anything you want
	Field Extra:Object
	
	' For receiveing packets
	Field _incomingPacketState:Byte
	Field _incomingPacket:TZPacket
	
	' For sending packets
	Field _sendQueue:TObjectList ' FIX: Make TQueue (but crashes for now)
	
	Method New()
		Self._sendQueue = New TObjectList
	EndMethod
	
	Method Connected:Int()
		If Not _socket Return False
		If Not _socket.Connected() Return False
		Return True
	EndMethod
	
	Method QueuePacket(packet:TZPacket)
		Self._sendQueue.AddLast(packet)
	EndMethod
	
	Method Close()
		CloseSocket(Self._socket)
	EndMethod
	
	Method ReadByte:Byte()
		Return Byte(Self._stream.ReadByte())
	EndMethod
	
	Method ReadShort:Short()
		Return Short(Self._stream.ReadShort())
	EndMethod
	
	Method ReadInt:Int()
		Return Self._stream.ReadInt()
	EndMethod
	
	Method ReadLong:Long()
		Return Self._stream.ReadLong()
	EndMethod
	
	Method ReadFloat:Float()
		Return Self._stream.ReadFloat()
	EndMethod
	
	Method ReadDouble:Double()
		Return Self._stream.ReadDouble()
	EndMethod
	
	Method WriteByte(value:Byte)
		Self._stream.WriteByte(value)
	EndMethod
	
	Method WriteShort(value:Short)
		Self._stream.WriteShort(value)
	EndMethod
	
	Method WriteInt(value:Int)
		Self._stream.WriteInt(value)
	EndMethod
	
	Method WriteLong(value:Long)
		Self._stream.WriteLong(value)
	EndMethod
	
	Method WriteDouble(value:Double)
		Self._stream.WriteDouble(value)
	EndMethod
	
	Method ReadAvail:Int()
		Return SocketReadAvail(Self._socket)
	EndMethod
EndType