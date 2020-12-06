Class BS.ServiceVoiture Extends Ens.BusinessService
{

/// Name of the WebService
Parameter SERVICENAME = "ServiceVoiture";

Method OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject, ByRef pHint As %String) As %Status
{
    set tsc = $CASE(pHint,
        "creerVoiture":..creerVoiture(pInput,.pOutput),
        "creerReservation":..creerReservation(pInput,.pOutput),
        "checkReservation":..checkReservation(pInput,.pOutput),
        "supprimerVoiture":..supprimerVoiture(pInput,.pOutput),
	 	: $$$ERROR($$$NotImplemented)
    )
    Quit tsc
}

Method creerVoiture(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
    set tsc = ..SendRequestSync("Voiture",pInput,.pOutput)
    Quit $$$OK
}

Method creerReservation(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
     set tsc = ..SendRequestSync("Reservation",pInput,.pOutput)
    Quit $$$OK
}

Method checkReservation(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
     set tsc = ..SendRequestSync("Reservation",pInput,.pOutput)
    Quit $$$OK
}

Method supprimerVoiture(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
     set tsc = ..SendRequestSync("Voiture",pInput,.pOutput)
    Quit $$$OK
}

}
