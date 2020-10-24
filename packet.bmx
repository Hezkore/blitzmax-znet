SuperStrict

Import brl.bank
Import brl.stringbuilder

' Default internal packets
Type TNetworkDefaultPackets
	Global Ping:Byte = 255
	Global Left:Byte = 254
	Global Join:Byte = 253
	Global Bank:Byte = 252
EndType

' Packet type
Type TNetworkPacket
	Global WriteBufferSize:Int = 32
	
	Field _id:Byte
	Field _data:TBank
	Field _fromClient:Short
	Field _toClient:Short
	
	Field _offset:Short
	Field _realSize:Short
	
	Method New(id:Byte)
		Self._id = id
		Self._data = CreateBank(Self.WriteBufferSize)
	EndMethod
	
	Method ID:Byte()
		Return Self._id
	EndMethod
	
	Method FromClient:Short()
		Return Self._fromClient
	EndMethod
	
	Method SetFromClient(id:Short)
		Self._fromClient = id
	EndMethod
	
	Method ToClient:Short()
		Return Self._toClient
	EndMethod
	
	Method SetToClient(id:Short)
		Self._toClient = id
	EndMethod
	
	Method Size:Short(withBuffer:Byte = False)
		If withBuffer Return Int(Self._data.Size())
		Return Self._realSize
	EndMethod
	
	Method SetSize(size:Short)
		Self._data.Resize(size)
	EndMethod
	
	Method Offset:Short()
		Return Self._offset
	EndMethod
	
	Method EOF:Byte()
		If Self._offset < Self._realSize Return False
		Return True
	EndMethod
	
	Method ToBank:TBank(includeFromUser:Byte)
		
		Local tmpBank:TBank = CreateBank(Self.Size(True))
		Local tmpOffset:Int
		
		tmpBank.PokeByte(tmpOffset, Self.ID()) ; tmpOffset:+1
		tmpBank.PokeShort(tmpOffset, Self.ToClient()) ; tmpOffset:+2
		If includeFromUser ..
			tmpBank.PokeShort(tmpOffset, Self.FromClient()) ; tmpOffset:+2
		tmpBank.PokeShort(tmpOffset, Self.Size()) ; tmpOffset:+2
		
		' FIX: Add multiple bytes instead of one by one
		For Local i:Int = 0 Until Self.Size(False)
			tmpBank.PokeByte(Self.ReadByte(), tmpOffset)
			tmpOffset:+1
		Next
		
		Return tmpBank
	EndMethod
	
	Method _resizeToFitOffset:Int()
		' Do we need a resize?
		If Self._offset > Self._data.Size() Then
			Local diff:Int = Self._offset - Self._data.Size()
			Self._data.Resize(Self._data.Size() + Self.WriteBufferSize)
			Return diff 
		EndIf
		
		' Are we actually at the end of the known size?
		If Self._offset > Self._realSize ..
			Return Self._offset - Self._realSize
		
		' We're not expanding anything
		Return 0
	EndMethod
	
	Method Seek(offset:Int)
		Self._offset = offset
	EndMethod
	
	Method WriteByte(value:Byte)
		Self._offset:+1
		Self._realSize:+Self._resizeToFitOffset()
		Self._data.PokeByte(Self._offset - 1, value)
	EndMethod
	
	Method WriteShort(value:Short)
		Self._offset:+2
		Self._realSize:+Self._resizeToFitOffset()
		Self._data.PokeShort(Self._offset - 2, value)
	EndMethod
	
	Method WriteInt(value:Int)
		Self._offset:+4
		Self._realSize:+Self._resizeToFitOffset()
		Self._data.PokeInt(Self._offset - 4, value)
	EndMethod
	
	Method WriteLong(value:Long)
		Self._offset:+8
		Self._realSize:+Self._resizeToFitOffset()
		Self._data.PokeLong(Self._offset - 8, value)
	EndMethod
	
	Method WriteDouble(value:Double)
		Self._offset:+8
		Self._realSize:+Self._resizeToFitOffset()
		Self._data.PokeDouble(Self._offset - 8, value)
	EndMethod
	
	Method WriteFloat(value:Float)
		Self._offset:+4
		Self._realSize:+Self._resizeToFitOffset()
		Self._data.PokeFloat(Self._offset - 4, value)
	EndMethod
	
	Method WriteString(text:String)
		For Local i:Int = 0 Until text.Length
			Self.WriteByte(Byte(text[i]))
		Next
		Self.WriteByte(0)
	EndMethod
	
	Method ReadByte:Byte()
		Self._offset:+1
		Return Self._data.PeekByte(Self._offset - 1)
	EndMethod
	
	Method ReadShort:Short()
		Self._offset:+2
		Return Self._data.PeekShort(Self._offset - 2)
	EndMethod
	
	Method ReadInt:Int()
		Self._offset:+4
		Return Self._data.PeekInt(Self._offset - 4)
	EndMethod
	
	Method ReadLong:Long()
		Self._offset:+8
		Return Self._data.PeekLong(Self._offset - 8)
	EndMethod
	
	Method ReadFloat:Float()
		Self._offset:+4
		Return Self._data.PeekFloat(Self._offset - 4)
	EndMethod
	
	Method ReadDouble:Double()
		Self._offset:+8
		Return Self._data.PeekDouble(Self._offset - 8)
	EndMethod
	
	Method ReadString:String()
		Local text:TStringBuilder = New TStringBuilder
		Local char:Byte
		Repeat
			char = Self.ReadByte()
			If char = 0 Return text.ToString()
			text.AppendChar(char)
		Forever
	EndMethod
EndType