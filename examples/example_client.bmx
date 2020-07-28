SuperStrict

Framework brl.standardio
Import "../znet.bmx"

'Packet definer
Import "mypackets.bmx"

Local client:TZClient = New TZClient(onNetPacket)


If client.connect("127.0.0.1", 2472) Then
	
	While client.Connected()
		client.update()
	Wend
Else
	
	Print("Error connecting to server")
EndIf
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