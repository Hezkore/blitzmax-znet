SuperStrict

Framework brl.standardio
Import hez.network

' Packet definer
Import "mypackets.bmx"

Local client:TNetworkClient = New TNetworkClient(OnNetPacket)

Delay(500)
If client.connect("127.0.0.1", 2472) Then
	
	While client.Connected()
		client.update()
		
		' Send hello
		Local myPacket:TNetworkPacket = New TNetworkPacket(TMyPackets.Hello)
		myPacket.WriteByte(1)
		client.QueuePacket(myPacket)
	Wend
Else
	
	Print("Error connecting to server")
EndIf
End

' Packet handler
Function OnNetPacket:TNetworkPacket(packet:TNetworkPacket)
	
	Select packet.ID()
		Case TNetworkDefaultPackets.Join
			Print("#" + packet.FromClient() + " joined")
			
		Case TNetworkDefaultPackets.Left
			Print("#" + packet.fromClient + " left")
			
		Case TMyPackets.Hello
			'Print("Hello from #" + packet.FromClient() + ": " + Packet.ReadString())
	EndSelect
EndFunction