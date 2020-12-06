Class msg.supprimerVoitureDmde Extends Ens.Request
{

Property voiture As webObjet.wsVoiture;

Storage Default
{
<Data name="creerVoitureDmdeDefaultData">
<Subscript>"supprimerVoitureDmde"</Subscript>
<Value name="1">
<Value>voiture</Value>
</Value>
</Data>
<DefaultData>supprimerVoitureDmdeDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
