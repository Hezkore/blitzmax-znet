SuperStrict

Import "../znet.bmx"

' Packet definer
Import "mypackets.bmx"

Global server:TZServer = New TZServer(onNetPacket)

Graphics(320, 240, 0, 60, 2)

' Start the server
' Use port 2472
' Max 8 user connections
If server.Start(2472, 8) Then
	
	While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
		server.Update()
	Wend
Else
	
	Print("Error starting the server")
EndIf
End

' Our packet handler
' Any client message will pass through here
' Return a packet to send it
' Returning a packet with 'ToClient = 0' will send it to everyone
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