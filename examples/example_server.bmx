SuperStrict

Framework brl.standardio
Import "../znet.bmx"

' Packet definer
Import "mypackets.bmx"

Local server:TZServer = New TZServer(onNetPacket)

' Start the server
' Use port 2472
' Max 8 user connections
If server.Start(2472, 8) Then
	
	While server.Running()
		server.Update()
	Wend
Else
	
	Print("Error starting the server")
EndIf
End

' Our packet handler
' Any client message will pass through here
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