Class webObjet.wsReservation Extends (%SerialObject, %XML.Adaptor, %JSON.Adaptor)
{

Property voiture As data.Voiture;

Property datDeb As %TimeStamp;

Property datFin As %TimeStamp;

Storage Default
{
<Data name="wsReservationState">
<Value name="1">
<Value>voiture</Value>
</Value>
<Value name="2">
<Value>datDeb</Value>
</Value>
<Value name="3">
<Value>datFin</Value>
</Value>
</Data>
<State>wsReservationState</State>
<StreamLocation>^webObjet.wsReservationS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
