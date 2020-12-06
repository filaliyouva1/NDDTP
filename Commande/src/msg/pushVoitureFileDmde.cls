You sent Aujourd’hui, à 09:45
Class BO.File Extends Ens.BusinessOperation
{

Property Adapter As EnsLib.File.OutboundAdapter;

Parameter ADAPTER = "EnsLib.File.OutboundAdapter";

Parameter INVOCATION = "Queue";

Method pushVoitureFile(pRequest As msg.pushVoitureFileDmde, Output pResponse As msg.pushVoitureFileRpse) As %Status
{
    set pResponse = ##class(msg.pushVoitureFileRpse).%New()

    set file = ##class(%Library.FileBinaryStream).%New()

    do file.Write(pRequest.voiture.marque_";"pRequest.voiture.modele";"pRequest.voiture.categorie";"pRequest.voiture.plaque";"pRequest.voiture.couleur";"pRequest.voiture.nbPlaces)

    set tsc = ..Adapter.PutStream("fichierVoiture"$TR($TR($ZDT($ZDTH($ZTS,-3),3,9),":/-","")," ","")".csv",file)
    
    if tsc {
        set pResponse.codeRetour = "OK"
    }
    else{
        set pResponse.codeRetour = "KO"
    }
    Quit $$$OK
}

XData MessageMap
{
<MapItems>
    <MapItem MessageType="msg.pushVoitureFileDmde">
        <Method>pushVoitureFile</Method>
    </MapItem>
</MapItems>
}

}
