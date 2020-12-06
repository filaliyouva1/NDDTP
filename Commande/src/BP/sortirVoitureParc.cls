/// 
Class BP.sortirVoitureParc Extends Ens.BusinessProcessBPL
{

/// BPL Definition
XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript' request='msg.sortirVoitureParcDmde' response='msg.sortirVoitureParcRpse' height='2000' width='2000' >
<sequence xend='200' yend='800' >
<call name='checkReservation' target='Reservation' async='0' xpos='200' ypos='250' >
<request type='msg.Reservation.checkReservationDmde' >
<assign property="callrequest.plaque" value="request.plaque" action="set" />
</request>
<response type='msg.Reservation.checkReservationRpse' >
<assign property="response.codeRetour" value="callresponse.codeRetour" action="set" />
</response>
</call>
<if condition='response.codeRetour = "OK"' xpos='200' ypos='350' xend='200' yend='700' >
<true>
<call name='sortirVoitureParc' target='Reservation' async='0' xpos='335' ypos='500' >
<request type='msg.Reservation.supprimerVoitureDmde' >
<assign property="callrequest.plaque" value="request.plaque" action="set" />
</request>
<response type='msg.supprimerVoitureRpse' >
<assign property="response.codeRetour" value="callresponse.codeRetour" action="set" />
</response>
</call>
<call name='supprimerVoiture' target='Voiture' async='0' xpos='335' ypos='600' >
<request type='msg.supprimerVoitureDmde' >
<assign property="callrequest.plaque" value="request.plaque" action="set" />
</request>
<response type='msg.supprimerVoitureRpse' >
<assign property="response.codeRetour" value="callresponse.codeRetour" action="set" />
</response>
</call>
</true>
</if>
</sequence>
</process>
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
