SuperStrict

Import brl.objectlist
Import brl.socket

Import "packet.bmx"

Type TZClient Extends TSocketStream
	
	Field _sessionID:Short
	Field _socket:TSocket
	Field _stream:TSocketStream
	Field _port:Int
	Field _address:String
	
	Field _packetFuncPointer:TZPacket(packet:TZPacket)
	
	Field _noDelay:Byte = True
	
	' Holds anything you want
	Field Extra:Object
	
	' For receiveing packets
	Field _incomingPacketState:Byte
	Field _incomingPacket:TZPacket
	
	' For sending packets
	Field _sendQueue:TObjectList ' FIX: Make TQueue (but crashes for now)
	
	Method New(func:TZPacket(packet:TZPacket))
		
		Self._sendQueue = New TObjectList
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
				Self._stream.WriteShort(Self._sessionID)
			EndIf
		WEnd
		
		Print("My SessionID: " + Self._sessionID)
		
		'Self.Update()
		
		Return True
	EndMethod
	
	Method Connected:Int()
		If Not _stream Return False
		If Not _socket.Connected() Return False
		If Not _socket Return False
		Return True
	EndMethod
	
	rem
	Method Update()
		If Not Connected() Then Return
		
		'Handle disconnects
		For Local c:ztClientConnection = EachIn disconnects
			connections[c.sessionID] = Null
			ListRemove(disconnects, c)
		Next
		
		'Send packets in the queueue
		For Local b:TBank = EachIn packetList.Reversed()
			WriteBank(b, Self._stream, 0, BankSize(b))
			ListRemove(packetList, b)
		Next
		
		'Gets new datas
		While ReadAvail() > 0
			Select _packetStage
				
				'First stage is getting the ID for the packet
				Case 0
					If ReadAvail() >= 1 Then
						_packetID = _stream.ReadByte()
						_packetStage:+1
						downloaded:+1
						'Print("Got ID - " + _packetID)
						If _packetID = zNet_ID_SendBank Then _packetStage = 5
					EndIf
				
				'Second stage is a special client stage that tells us WHO this is from
				Case 1
					If ReadAvail() >= 2 Then
						_packetFrom = _stream.ReadShort()
						_packetStage:+1
						downloaded:+2
						'Print("Got fromClient - " + _packetFrom)
					End If
					
				'Third stage is getting the client this is for (0 = everyone)
				Case 2
					If ReadAvail() >= 2 Then
						_packetTo = _stream.ReadShort()
						_packetStage:+1
						downloaded:+2
						'Print("Got toClient - " + _packetTo)
					EndIf
				
				'Fourth stage is getting the length and preparing our bank
				Case 3
					If ReadAvail() >= 2 Then
						_packetLen = _stream.ReadShort()
						_packetStage:+1
						downloaded:+2
						'Print("Got Length - " + _packetLen)
						
						'Make our bank the correct size
						_packetBank = CreateBank(_packetLen)
					EndIf
					
				'Fifth and last is.. well everything in the actual packet!
				Case 4
					If _packetRecv < _packetLen Then
						_packetBank.PokeByte(_packetRecv, _stream.ReadByte())
						_packetRecv:+1
						downloaded:+1
						'Print("Got Data " + _packetRecv + "/" + _packetLen)
					EndIf
					
					'ACTIVATE - Packet is complete!
					If _packetRecv >= _packetLen Then
						'Print("Done")
						'Trigger our packet receiver function with a temp packet
						Local nP:ztNetPacket = New ztNetPacket
						nP.id = _packetID
						nP.data = _packetBank
						nP.fromClient = _packetFrom
						nP.toClient = _packetTo
						
						'Trigger our SPECIAL packet pointer first!
						If nP.id > 250 Then
							_specialPacket(nP)
							nP._offset = 0 'Reset offset
						EndIf
						
						'Trigger our packet pointer
						packetPointer(nP)
						
						'Remove temp packet
						nP = Null
						
						'Reset packet stuff for client to prepare the next packet!
						_packetID = Null
						_packetStage = Null
						_packetLen = Null
						_packetBank = Null
						_packetRecv = Null
						_packetTo = Null
						_packetFrom = Null
					EndIf
					
				'Sixth stage is a special BANK size stage
				Case 5
					If ReadAvail() >= 4 Then
						_packetLen = _stream.ReadInt()
						_packetStage:+1
						Print("Downloading Bank - " + (_packetLen / 1024) + "kb")
						downloaded:+_packetLen
						'Make our bank the correct size
						_packetBank = CreateBank(_packetLen)
					EndIf
					
				'Seventh stage is once again a special BANK stage where we just get the entire bank!
				Case 6
					If ReadAvail() >= 8 Then
						_packetBank.PokeLong(_packetRecv, _stream.ReadLong())
						_packetRecv:+8
					EndIf
				
					If ReadAvail() >= 4 Then
						_packetBank.PokeInt(_packetRecv, _stream.ReadInt())
						_packetRecv:+4
					EndIf
					
					If ReadAvail() >= 2 Then
						_packetBank.PokeShort(_packetRecv, _stream.ReadShort())
						_packetRecv:+2
					EndIf
					
					If ReadAvail() >= 1 Then
						_packetBank.PokeByte(_packetRecv, _stream.ReadByte())
						_packetRecv:+1
					EndIf
					
					'Print("BANK Data " + _packetRecv + "/" + _packetLen)
					
					'Entire bank is here!
					If _packetRecv >= _packetLen Then
						Print("Bank Done")
						'For Local i:Int = 0 To _packetLen
							'_packetBank.PokeByte(i, _stream.ReadByte())
						'Next
						
						'Print("Bank Saved")
						'SaveBank(_packetBank, "temp.zip")
						'Trigger our packet receiver function with a temp packet
						Local nP:ztNetPacket = New ztNetPacket
						nP.id = zNet_ID_GotBank
						nP.data = _packetBank
						nP.fromClient = 0
						nP.toClient = 0
						
						'Trigger our packet pointer
						packetPointer(nP)
						
						'Remove temp packet
						nP = Null
						
						'Reset packet stuff for client to prepare the next packet!
						_packetID = Null
						_packetStage = Null
						_packetLen = Null
						_packetBank = Null
						_packetRecv = Null
						_packetTo = Null
						_packetFrom = Null
					EndIf
				
			End Select
		Wend
	End Method
	
	Method _specialPacket:ztNetPacket(Packet:ztNetPacket)
		Select Packet.id
			Case zNet_ID_Join
				'Resize the array to fit the new connection
				'connections = connections[..Packet.fromClient + 1]
				'Add the connection
				connections[Packet.fromClient] = New ztClientConnection
				
			Case zNet_ID_Left
				'Add the connection to the disconnects list (removed at update end)
				If Not connections[Packet.fromClient] Then Return(Null)
				ListAddLast(disconnects, connections[Packet.fromClient])
		End Select
	End Method
	endrem
	
	Method ReadAvail:Int()
		Return(SocketReadAvail(Self._socket))
	EndMethod
EndType