SuperStrict

Import "../znet.bmx"

'Packet definer
Import "mypackets.bmx"

Local client:TZClient = New TZClient(onNetPacket)
If Not client.connect("127.0.0.1", 2472) Then
	Print("Error connecting to server")
	End
EndIf

'Send packet
'client.startpacket(zNet_ID_Test)
'client.addstring("Hello! This is a test message over the interwebs!!")
'client.addint(1234567890)
'client.addshort(1337)
'client.addbyte(128)
'client.SendPacket()

Graphics(320, 240, 0, 60, 2)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	'client.update()
Wend
End

' Packet handler
Function onNetPacket:TZPacket(packet:TZPacket)
	
	Select packet.ID()
		Case TZDefaultPackets.Join
			Print("#" + packet.FromClient() + " joined")
		
		Case TZDefaultPackets.Left
			Print("#" + packet.fromClient + " left")
		
		Case TMyPackets.Hello
			Print("Hello from #" + packet.FromClient() + ": " + Packet.ReadString())
	EndSelect
EndFunction