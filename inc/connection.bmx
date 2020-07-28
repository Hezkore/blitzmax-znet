SuperStrict

Import brl.objectlist
Import brl.socketstream

Import "packet.bmx"

Type TZConnection
	
	Field _socket:TSocket
	Field _stream:TSocketStream
	
	Field _sessionID:Short
	Field _identified:Byte
	
	' Holds anything you want
	Field Extra:Object
	
	' For receiveing packets
	Field _incomingPacketState:Byte
	Field _incomingPacket:TZPacket
	
	Field _packetFuncPointer:TZPacket(packet:TZPacket)
	
	' For sending packets
	Field _sendQueue:TObjectList ' FIX: Make TQueue (but crashes for now)
	Field _includeFromUser:Byte = False
	Field _canReceiveMorePackets:Byte
	
	Method New()
		Self._sendQueue = New TObjectList
	EndMethod
	
	Method Connected:Byte()
		If Not Self._stream Return False
		If Not Self._socket Return False
		Return Self._socket.Connected()
	EndMethod
	
	Method QueuePacket(packet:TZPacket)
		Self._sendQueue.AddLast(packet)
	EndMethod
	
	Method SetPacketFunctionPointer(func:TZPacket(packet:TZPacket))
		
		Self._packetFuncPointer = func
	EndMethod
	
	Method _triggerPacketFuncPointer(packet:TZPacket)
		
		' Call the packet function pointer
		' Anything returned will be queued
		Local returnPacket:TZPacket = ..
			Self._packetFuncPointer(packet)
		
		' Did we get a return packet?
		If returnPacket Self.QueuePacket(returnPacket)
	EndMethod
	
	Method Update()
		
		' Receive data
		Self._receiveAndSendData()
	EndMethod
	
	Method _receiveAndSendData()
		
		' Send packets in the queue
		Local packet:TZPacket
		' FIX: Send as one huge bank, not one bank per packet
		For packet = EachIn Self._sendQueue.Reversed() ' FIX: Once it's a queue we don't need to reverse this!
			Self._stream.WriteBytes(packet.ToBank(Self._includeFromUser), packet.Size())
		Next
		Self._sendQueue.Clear()
		
		' Receive packets
		
		' Only handle a certain amount of packets
		Self._canReceiveMorePackets = 5
		
		' WHILE there's stuff to read
		' Remember to exit the loop whenever possible!
		While Self.ReadAvail() > 0
			
			' Is this connection identified?
			If Not Self._identified Then ' nope
				' This part is only used by the server
				If Self.ReadAvail() >= 2 Then
					
					' Connection needs to identify by sending correct session ID
					If Self.ReadShort() = Self._sessionID Then
						
						Self._identified = 1
						
						' Annouce via packet
						Local joinPacket:TZPacket = New TZPacket(TZDefaultPackets.Join)
						joinPacket.SetFromClient(Self._sessionID)
						Self._triggerPacketFuncPointer(joinPacket)
					Else
						Print("Connection #" + Self._sessionID + " failed to ident!")
						Self.Close()
					EndIf
				EndIf
			EndIf
			
			If Self._identified Then ' yep
				' Used by both the server and client
				Select Self._incomingPacketState
					
					' First stage is getting the ID for the packet
					Case 0
						If Self.ReadAvail() >= 1 Then
							If Not Self._incomingPacket ..
								Self._incomingPacket = New TZPacket(Byte(Self.ReadByte()))
							Self._incomingPacketState:+1
						Else
							Exit
						EndIf
					
					' Second stage is getting destination
					Case 1
						If Self.ReadAvail() >= 2 Then
							Self._incomingPacket.SetToClient(Short(Self.ReadShort()))
							Self._incomingPacket.SetFromClient(Self._sessionID)
							Self._incomingPacketState:+1
						Else
							Exit
						EndIf
					
					' Third stage is getting the length and preparing our bank
					Case 2
						If Self.ReadAvail() >= 2 Then
							Self._incomingPacket.SetSize(Short(Self.ReadShort()))
							Self._incomingPacketState:+1
						Else
							Exit
						EndIf
					
					' Fourth is the actual packet
					Case 3
						' FIX: Instead of adding one byte we could add a bunch
						If Not Self._incomingPacket.EOF() Then
							Self._incomingPacket.WriteByte(Byte(Self.ReadByte()))
							If Not Self._incomingPacket.EOF() Exit
						EndIf
						
						' Packet is complete!
						If Self._incomingPacket.EOF() Then
							Self._canReceiveMorePackets:-1
							Self._incomingPacketState = 0
							
							' Is this an internal packet?
							If Self._incomingPacket.ID() <= 250 Then
								'Self._triggerPacketFuncPointer(Self._incomingPacket)
							Else
								'Self._internalPacket(Self._incomingPacket)
							EndIf
						EndIf
				EndSelect
			EndIf
			
			If Self._canReceiveMorePackets < 0 Exit
		Wend
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