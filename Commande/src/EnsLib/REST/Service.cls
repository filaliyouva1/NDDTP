/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

/// REST Service class. Can use an HTTP InboundAdapter listener, or the standard CSP Service mechanism, or both.
/// In order for the CSP mechanism to work, HTTP Services using this class must be configured with the invoking URL including ?CfgItem= giving the config item name.
/// (Configured Services exposed using the HTTP Inbound Adapter may also be invoked with this URL parameter but because
///  each configured Inbound Adapter listens on its own TCP/IP port this parameter is just a safety check for them.)
Class EnsLib.REST.Service Extends (EnsLib.HTTP.Service, %CSP.REST, Ens.Util.JSON) [ Abstract, System = 4 ]
{

Parameter ADAPTER = "EnsLib.HTTP.InboundAdapter";

/// This prefix will be removed from the beginning of the actual URL before matching it against the UrlMap.
/// If this prefix begins with '^' then the CSP Application will also be removed from the beginning of the URL if this service is being invoked via the CSP gateway.
/// If this prefix begins with '|' then the Config Name for this service will be removed from the beginning of the URL, as well as the CSP Application if this service is being invoked via the CSP gateway.
Parameter EnsServicePrefix As %String;

Parameter PREFIXCASESENSITIVE As %Boolean = 0;

ClassMethod Page(skipheader As %Boolean = 1) As %Status [ Final, ProcedureBlock = 0 ]
{
	#; We do not want the session token
	Set %response.OutputSessionToken=(''..#UseSession)

	#; For this REST service we do not want the %CSP.REST implementation of Page(); go right to the super-superclass
	Quit ##class(EnsLib.HTTP.Service).Page(skipheader)
}

/// Override OnProcessInput() this in your subclass if you want to handle dispatching yourself
Method OnProcessInput(pInput As %Library.AbstractStream, Output pOutput As %Stream.Object = {$$$NULLOREF}) As %Status
{
	#Dim tCmd, tURL, tApp, tCfg As %String = ""
	Set tCmd=$ZConvert(pInput.GetAttribute("HttpRequest"),"U")
	Set tURL=pInput.GetAttribute("URL") ; don't URL-decode because that could mess up the parse into '/' pieces
	Set tApp=pInput.GetAttribute("CSPApplication")
	Set tCfg=pInput.GetAttribute("EnsConfigName")

	Set tService=..#EnsServicePrefix, tPre1=$E(tService)
	If tPre1="^" {
		#; strip Application from URL, if any
		Set:(""'=tApp)&&$S(..#PREFIXCASESENSITIVE:(tApp=$E(tURL,1,$L(tApp))), 1:($ZCVT(tApp,"L")=$ZCVT($E(tURL,1,$L(tApp)),"L")))&&("/"=$E(tApp,*)) tURL=$E(tURL,$L(tApp),*)
		Set $E(tService,1)=""
	} ElseIf tPre1="|" {
		#; strip Application and ConfigName from URL, if any
		If ""=tApp { Set:""'=tCfg tCfg="/"_tCfg_"/" } Else { Set tCfg=$S(""=tCfg:tApp, 1:tApp_tCfg_"/") }
		Set:(""'=tCfg)&&$S(..#PREFIXCASESENSITIVE:(tCfg=$E(tURL,1,$L(tCfg))), 1:($ZCVT(tCfg,"L")=$ZCVT($E(tURL,1,$L(tCfg)),"L"))) tURL=$E(tURL,$L(tCfg),*)
		Set $E(tService,1)=""
	}
	Set:"*"=tService tService=""  Set:"/"'=$E(tService,1) tService="/"_tService  Set:"/"'=$E(tService,*) tService=tService_"/"
	Set:'..#PREFIXCASESENSITIVE tService=$ZCVT(tService,"L")
	Set tURLPrefix=$E(tURL,1,$L(tService))
	Set:'..#PREFIXCASESENSITIVE tURLPrefix=$ZCVT(tURLPrefix,"L")
	If tService'=tURLPrefix {
		Quit $$$ERROR($$$EnsErrGeneral,"Service "_tURLPrefix_" does not match supported service prefix "_tService_".")
	}
	Set $E(tURL,1,$L(tService)-1)=""

    #; Ensure that any query string is not taken into account
    Set tMatchUrl=$Piece(tURL,"?")

	#; Walk the dispatch map in collation order of definition
	For tIndex=1:1 { Set tMapEntry=..DispatchMap(tIndex)  Quit:""=tMapEntry

		#; Pick out the RegEx
		Set tRegEx=$List(tMapEntry,2)

		#; Create a matcher
		Set tMatcher=##class(%Regex.Matcher).%New(tRegEx)

		#; Test each regular expression in turn, extracting the arguments, dispatching to the named method
		If tMatcher.Match(tMatchUrl) {

			#; We have matched the resource
			Set tMatched=1

			#; Now check HTTP command/method name
			Continue:tCmd'=$List(tMapEntry,3)
			Set tTarget=$List(tMapEntry,4)

			#; Don't want multiple matches
			Quit:""'=tTarget
		}
	} ; end dispatch map loop

	If ""=$g(tTarget) {
		#; Didn't have a match for the resource, report not found
		Quit:'$g(tMatched) $$$ERROR($$$EnsErrGeneral,"Unsupported REST URL: "_tMatchUrl_" for HTTP command "_tCmd)

		#; Had a match for resource but command not matched
		Quit $$$ERROR($$$EnsErrGeneral,"Unsupported HTTP command "_tCmd_" for REST URL: "_tMatchUrl)
	}
	#; Got a match, marshall the arguments
	Set tArgs=0
	Set tArgs($I(tArgs))=pInput
	Set pOutput=##class(%GlobalBinaryStream).%New()
	Set tArgs($I(tArgs))=pOutput
	For tI=1:1:tMatcher.GroupCount Set tArgs($I(tArgs))=tMatcher.Group(tI)

	#; Dispatch; Check for optional ClassName prefix
	try {
		If tTarget'[":" {
			Set tSC=$method($this,tTarget,tArgs...)
		} Else {
			Set tClass=$classname()
			Set:tTarget[":" tClass=$Piece(tTarget,":"), tTarget=$Piece(tTarget,":",2)
			Set tSC=$classmethod(tClass,tTarget,tArgs...)
		}
	} catch {
		Set tSC=$$$SystemError
	}
	Quit tSC
}

}
