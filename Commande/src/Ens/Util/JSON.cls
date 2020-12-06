/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

Include Ensemble

Class Ens.Util.JSON [ Abstract, System = 4 ]
{

ClassMethod JSONStreamToObject(pStream, Output pObject As %RegisteredObject, pClass As %String, pIgnoreUnknownProps As %Boolean) As %Status
{
	Set tSC=##class(%ZEN.Auxiliary.jsonProvider).%ParseJSON(pStream,.pClass,.pObject,,,,.pIgnoreUnknownProps)
	Quit:$$$IsdefObject(pObject) tSC
	Set:$$$ISOK(tSC) tSC=$$$ERROR($$$EnsErrGeneral,"No object found in JSON stream "_pStream.Read(200+pStream.Rewind()))
	Quit tSC
}

ClassMethod JSONStreamToObjectArray(pStream, Output pArray, pClass As %String, pIgnoreUnknownProps As %Boolean) As %Status
{
	Kill pArray
	Set tSC = ##class(%ZEN.Auxiliary.jsonProvider).%ParseJSON(.pStream,.pClass,.tObjectList,,,,.pIgnoreUnknownProps)
	If $$$ISERR(tSC) Quit tSC
	Set pArray = tObjectList.Count()
	For i=1:1:pArray {
		Set pArray(i) = tObjectList.GetAt(i)
	}
	Quit tSC
}

ClassMethod ObjectToJSONStream(pObject As %RegisteredObject, ByRef pStream, pFormat As %String = "iw") As %Status [ CodeMode = expression ]
{
##class(%ZEN.Auxiliary.jsonProvider).%WriteJSONStreamFromObject(.pStream,.pObject,,,,pFormat)
}

}
