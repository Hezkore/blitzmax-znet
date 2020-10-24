SuperStrict

Framework brl.standardio
Import hez.network

' Packet definer
Import "mypackets.bmx"

Local server:TNetworkServer = New TNetworkServer(OnNetPacket)

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
Function OnNetPacket:TNetworkPacket(packet:TNetworkPacket)
	Print "Got Packet #" + packet.ID(	)
	
	Select packet.ID()
		Case TNetworkDefaultPackets.Join
			Print("#" + packet.FromClient() + " joined")
		
		Case TNetworkDefaultPackets.Left
			Print("#" + packet.fromClient + " left")
		
		Case TMyPackets.Hello
			Print("Hello from #" + packet.FromClient() + ": " + Packet.ReadString())
	EndSelect
EndFunction