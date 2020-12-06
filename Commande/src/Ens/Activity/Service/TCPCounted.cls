/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

Class Ens.Activity.Service.TCPCounted Extends Ens.BusinessService [ ProcedureBlock, System = 4 ]
{

Parameter ADAPTER = "EnsLib.TCP.CountedInboundAdapter";

Method OnProcessInput(pInput As %Stream.Object, pOutput As %RegisteredObject) As %Status
{
	#dim tSC As %Status = $$$OK
	#dim e As %Exception.AbstractException
	
	#dim tActivityList As %String 
	
	Try {
		Set tActivityList = pInput.Read()
		Set tSC = ##class(Ens.Activity.Utils).AddActivityList(tActivityList)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Set pOutput=##Class(%IO.StringStream).%New($S($$$ISOK(tSC):1,1:tSC))
	Quit tSC
}

Method OnInit() As %Status
{
	Set ..Adapter.Charset = "Binary"
	Quit ##super()
}

}
