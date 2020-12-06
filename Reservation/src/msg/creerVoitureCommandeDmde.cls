Class msg.creerVoitureCommandeDmde Extends (Ens.Request, %JSON.Adaptor)
{

Property categorie As webObjet.wsVoitureCommande;

Storage Default
{
<Data name="creerVoitureCommandeDmdeDefaultData">
<Subscript>"creerVoitureCommandeDmde"</Subscript>
<Value name="1">
<Value>voiture</Value>
</Value>
<Value name="2">
<Value>categorie</Value>
</Value>
</Data>
<DefaultData>creerVoitureCommandeDmdeDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
