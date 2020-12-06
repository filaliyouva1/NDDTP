Class BO.Reservation Extends EnsLib.REST.Operation
{

Property Adapter As EnsLib.HTTP.OutboundAdapter;

Parameter ADAPTER = "EnsLib.HTTP.OutboundAdapter";

Parameter INVOCATION = "Queue";

Method supprimerVoiture(pRequest As msg.Reservation.supprimerVoitureDmde, Output pResponse As msg.creerVoitureRpse) As %Status
{
    set pResponse = ##class(msg.supprimerVoitureRpse).%New()

    set httpRequest = ##class(%Net.HttpRequest).%New()

    
    set ..Adapter.URL = "/api/reservation/supprimerVoiture/"

    do ..ObjectToJSONStream(pRequest, .EntityBody)

    set httpRequest.EntityBody = EntityBody

    set tsc = ..Adapter.SendFormDataArray(.httpResponse, "POST", httpRequest)

    do ..JSONStreamToObject(httpResponse.Data,.pResponse,"msg.creerVoitureRpse",1)

    Quit $$$OK
}

Method checkReservation(pRequest As msg.Reservation.checkReservationDmde, Output pResponse As msg.Reservation.checkReservationRpse) As %Status
{
    set pResponse = ##class(msg.Reservation.checkReservationRpse).%New()

    set httpRequest = ##class(%Net.HttpRequest).%New()

    
    set ..Adapter.URL = "/api/reservation/checkReservation/"

    do ..ObjectToJSONStream(pRequest, .EntityBody)

    set httpRequest.EntityBody = EntityBody

    set tsc = ..Adapter.SendFormDataArray(.httpResponse, "POST", httpRequest)

    do ..JSONStreamToObject(httpResponse.Data,.pResponse,"msg.Reservation.checkReservationRpse",1)

    Quit $$$OK
}

XData MessageMap
{
<MapItems>
    
    <MapItem MessageType="msg.Reservation.supprimerVoitureDmde">
        <Method>supprimerVoiture</Method>
    </MapItem>
    <MapItem MessageType="msg.Reservation.checkReservationDmde">
        <Method>checkReservation</Method>
    </MapItem>
   
</MapItems>
}

}
