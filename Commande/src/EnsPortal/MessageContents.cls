/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

Include Ensemble

/// Utility class for displaying the contents of messages.
/// <p>
/// You should be able to pass in the following parameters: <br/>
///    HeaderClass=&lt;specific message class> (or Ens.MessageHeader if you are starting from a header)<br/>
///    SourceFile=&lt;normalised_path_to_file><br/>
///    HeaderId=&lt;ID_of_object><br/>
///    Transform=&lt;Name of transform to apply to an XML Virtual Document><br/>
///    SchemaCat=&lt;Schema category to use in constructing DocType (if needed)><br/>
/// <p>
/// The allowed values for HeaderClass are:<br/>
/// Ens.MessageHeader<br/>
/// Ens.Util.LogBase<br/>
/// Ens.Util.IOLog<br/>
/// Ens.BP.Context<br/>
/// EnsLib.EDI.XML.Document<br/>
/// EnsLib.Workflow.TaskResponse<br/>
/// any child of EnsLib.EDI.Document
Class EnsPortal.MessageContents Extends %CSP.Page [ System = 4 ]
{

Parameter DOMAIN = "Ensemble";

/// Default content type
Parameter CONTENTTYPE = "text/html";

/// Comma-separated list of additional JS include files for the page - for Event Details popup.
Parameter JSINCLUDES = "ensemble/Ensemble_Utils.js";

ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
	Do ..Initialize(.tContentType)
	Set %response.ContentType = tContentType
	Do ..GetStatus(.tType)
	If tType = "security" {
		Set %response.Status = "403 Forbidden"
	}
	Quit 1
}

/// Process the incoming request and correctly initialize the data that will be 
/// used to construct the appropriate response.
ClassMethod Initialize(Output pContentType) [ ServerOnly = 1 ]
{
	Set pContentType = "text/html"
	Do ..SetStatus($$$OK)
	Try {
		Set tHeaderClass = $get(%request.Data("HeaderClass",1))
		Set tHeaderId = $get(%request.Data("HeaderId",1))
		Set tSourceFile = $get(%request.Data("SourceFile",1))
		Set tSchemaCat = $get(%request.Data("SchemaCat",1))  Set:" "=$E(tSchemaCat) $E(tSchemaCat)="+"
		Set tDocType = $get(%request.Data("DocType",1))
		If (tHeaderClass = "") || ((tHeaderId = "") && (tSourceFile = "")) {
			Do ..SetStatus($$$ERROR($$$LoadObjectNotFound, tHeaderClass, tHeaderId), "user")
			Quit
		}

		If '##class(%Dictionary.CompiledClass).%ExistsId(tHeaderClass) {
			Do ..SetStatus($$$ERROR($$$ClassDoesNotExist, tHeaderClass), "user")
			Quit
		}

		Set tStatus = ..CheckPermissions(tHeaderClass)
		If $$$ISERR(tStatus) {
			Do ..SetStatus(tStatus, "security")
			Quit
		}

		If $classmethod(tHeaderClass,"%Extends","Ens.MessageHeaderBase") {
			#dim tHeaderSQL As %String
			#dim tIsMsgBankHeader As %Boolean = 0
			Set tHeaderSQL(0)="SELECT MessageBodyClassName, MessageBodyId FROM "
			Set tHeaderSQL(1)="SELECT MessageBodyClassName, MessageBodyId, ClientBodyClassName FROM "
			Set tIsMsgBankHeader = $classmethod(tHeaderClass,"%Extends","Ens.Enterprise.MsgBank.MessageHeader")
			
			Set tStatement = ##class(%SQL.Statement).%New()
			Set tStatus = tStatement.%Prepare(tHeaderSQL(tIsMsgBankHeader)_$$$ClassSQLTable(tHeaderClass)_" WHERE ID = ?")
			If $$$ISERR(tStatus) {
				Do ..SetStatus(tStatus)
				Quit
			}
			Set tRS = tStatement.%Execute(tHeaderId)
			If 'tRS.%Next() {
				If (tRS.%SQLCODE = 100) {
					Do ..SetStatus($$$ERROR($$$LoadObjectNotFound, tHeaderClass, tHeaderId), "user")
					Quit
				}
				ElseIf tRS.%SQLCODE {
					Do ..SetStatus($$$ERROR($$$SQLCode,tRS.%SQLCode,tRS.%Message))
					Quit
				}
				Else {
					Do ..SetStatus($$$ERROR($$$EnsErrGeneral, "Unable to identify message to display"))
					Quit
				}
			}
			// can assume we got results
			Set tObjectClass = tRS.%Get("MessageBodyClassName")
			Set tObjectId = tRS.%Get("MessageBodyId")

			Set %EnsContentData("HeaderId") = tHeaderId
			Set %EnsContentData("ClassName") = tObjectClass
			Set %EnsContentData("Id") = tObjectId

			Kill %EnsContentData("ClientClassName")
			If tIsMsgBankHeader Set %EnsContentData("ClientClassName") = tRS.%Get("ClientBodyClassName")

			If tObjectClass = "" {
				Set tObject = $$$NULLOREF
			} Else {
				If '##class(%Dictionary.CompiledClass).%ExistsId(tObjectClass) {
					Do ..SetStatus($$$ERROR($$$ClassDoesNotExist,tObjectClass))
					Quit
				}
				Set tStatus = ..CheckPermissions(tObjectClass)
				If $$$ISERR(tStatus) {
					Do ..SetStatus(tStatus, "security")
					Quit
				}
				Set tObject = $classmethod(tObjectClass, "%OpenId", tObjectId, 0, .tStatus)
				If $$$ISERR(tStatus) {
					Do ..SetStatus(tStatus, "server")
					Quit
				}
			}
		}
		Else { // Not a MessageHeader, restrict options to Event Log, IO Log and BP context contents
			Set tPermitted = $select($classmethod(tHeaderClass, "%Extends", "Ens.Util.LogBase"): 1,
									 $classmethod(tHeaderClass, "%Extends", "Ens.Util.IOLog"): 3,
									 $classmethod(tHeaderClass, "%Extends", "Ens.BP.Context"): 1,
									 $classmethod(tHeaderClass, "%Extends", "EnsLib.EDI.XML.Document"): 2,
									 $classmethod(tHeaderClass, "%Extends", "EnsLib.Workflow.TaskResponse"): 1,
									 $classmethod(tHeaderClass, "%Extends", "EnsLib.EDI.Document"): 2,
									 $classmethod(tHeaderClass, "%Extends", "Ens.Util.MessageBodyMethods"): 1,
									 1: 0)
			If 'tPermitted {
				Do ..SetStatus($$$ERROR($$$AccessDenied),"security")
				Quit
			}
			If (tSourceFile '= "") && (tPermitted = 2) {
				Set tObject = $classmethod(tHeaderClass, "ImportFromFile", tSourceFile,, .tStatus)
				If $$$ISERR(tStatus) {
					Do ..SetStatus(tStatus, "server")
					Quit
				}
				Set %EnsContentData("Id") = tSourceFile
			}
			Else {
				Set tObject = $classmethod(tHeaderClass, "%OpenId", tHeaderId, 0, .tStatus)
				If $$$ISERR(tStatus) {
					Do ..SetStatus(tStatus, "server")
					Quit
				}
				Set %EnsContentData("Id") = tHeaderId
				// Special case check for IOBody parameter to see if one of the child objects has been requested
				If (tPermitted = 3) && $IsObject($get(%request)) && ($data(%request.Data("IOBody",1))#10) {
					Set tIn = +$get(%request.Data("IOBody",1))
					Set tBodyObject = $select(tIn: tObject.InObject, 1: tObject.OutObject)
					If $IsObject(tBodyObject) {
						Set tHeaderClass = $classname(tBodyObject)
						Set tIOLogObject = tObject
						Set tObject = tBodyObject
						Set %EnsContentData("Id") = tObject.%Id()
						If tIOLogObject.%Extends("Ens.Util.IOLogSegmentedObj") {
							Set tSeps = $select(tIn: tIOLogObject.InObjectSeparators, 1: tIOLogObject.OutObjectSeparators)
							If tSeps '= "" {
								Try { Set tObject.Separators = tSeps }
								Catch {}
							}
						}
					}
					Else {
						Set tErrorText = $select(tIn: $$$Text("Unable to display IO Log Input Data."), 1: $$$Text("Unable to display IO Log Output Data."))
						Do ..SetStatus($$$ERROR($$$GeneralError,tErrorText),"server")
						Quit
					}
				}
			}
			Set %EnsContentData("HeaderId") = ""
			Set %EnsContentData("ClassName") = tHeaderClass
		}
		If $$$IsdefObject(tObject) && tObject.%Extends("Ens.VDoc.Interface") && (""=tObject.DocType) {
			If (""'=tDocType) {
				Set tObject.DocType=tDocType
			} ElseIf (""'=tSchemaCat) {
				Set tSchemaClass=$P($$$GetClassParameter($classname(tObject),"SCHEMACLASS"),":",1) 
				If tSchemaClass'="" {
					If tObject.%Extends("EnsLib.EDI.X12.Document") {
						Set tImplGuide=""
						If "ST"=tObject.GetValueAt("1:0") {
							Set tImplGuide=tObject.GetValueAt("1:3")
							Set tImplGuide=$E(tImplGuide,$F(tImplGuide,"X")-1,*)
							If ""=tImplGuide {
								Set tGroup=tObject.Parent
								Set:$IsObject(tGroup) tImplGuide=tGroup.GetValueAt("1:8")
								Set tImplGuide=$E(tImplGuide,$F(tImplGuide,"X")-1,*)
								If ""=tImplGuide {
									Set tRef=tObject.FindSegment("REF")
									Set:$IsObject(tRef) tImplGuide=tRef.GetValueAt(2)
									Set tImplGuide=$E(tImplGuide,$F(tImplGuide,"X")-1,*)
								}
							}
						}
						Set tPurpose=$S("BHT"=tObject.GetValueAt("2:0"):tObject.GetValueAt("2:2"),1:"")
						Set tObject.DocType=$classmethod(tSchemaClass,"ResolveSchemaTypeToDocType",tSchemaCat,tObject.Name,,tImplGuide,tPurpose)
					} Else {
						Set tObject.DocType=$classmethod(tSchemaClass,"ResolveSchemaTypeToDocType",tSchemaCat,tObject.Name)
					}
				}
			}
		}
		// Special handling for XML VDoc where a transform has been requested
		If ($get(%EnsContentData("ClassName")) = "EnsLib.EDI.XML.Document") {
			Set tTransform = $get(%request.Data("Transform",1))
			If (tTransform '= "") {
				If '##class(%Dictionary.CompiledClass).%ExistsId(tTransform) {
					Set tStatus = $$$ERROR($$$ClassDoesNotExist,tTransform)
					Do ..SetStatus(tStatus,"user")
					Quit
				}
				If '##class(EnsPortal.Utils).IsSubclass(tTransform,"Ens.DataTransform") {
					Set tStatus = $$$ERROR($$$NotAnInstanceError,"Ens.DataTransform")
					Do ..SetStatus(tStatus,"user")
					Quit
				}
				Set tStatus = $$$OK
				Try {
					Set tStatus = $classmethod(tTransform,"Transform",tObject,.tObjectOut)
				}
				Catch ex {
					Set tStatus = ex.AsStatus()
				}
				If $$$ISERR(tStatus) {
					Do ..SetStatus(tStatus, "server")
					Quit
				}
				Set tObject = $get(tObjectOut)
			}
		}

		// Can assume tObject is defined
		Set %EnsContentData("object") = tObject

		If $IsObject(tObject) {
			If tObject.%Extends("Ens.Util.MessageBodyMethods") {
				Set pContentType = tObject.%GetContentType()
			}
			ElseIf tObject.%Extends("Ens.Util.LogBase") {
				Set pContentType = "text/html"
			}
			ElseIf tObject.%Extends("%XML.Adaptor") {
				Set pContentType = "text/xml"
			}
			ElseIf tObject.%Extends("%Stream.Object") {
				Set tContentType = ""
				If tObject.%Extends("%Library.AbstractStream") {
					Set tContentType = $get(tObject.Attributes("ContentType"))
				}
				If tContentType '= "" {
					Set pContentType = tContentType
				}
				ElseIf ($ZCVT(tObject.Read($Length("..<?xml")),"L") [ "<?xml") {
					Set pContentType = "text/xml"
				}
				Do tObject.Rewind()
				#; Check if can show the stream as text/xml for MsgBank messages
				Try {
					If ($G(%EnsContentData("ClientClassName"))'="")&&(pContentType="text/html")&&'$classmethod(%EnsContentData("ClientClassName"),"%Extends","%Stream.Object") Set pContentType="text/xml",%EnsContentData("ClientClassName")=%EnsContentData("ClientClassName")_":NotStream"
				} Catch {}
				
			}
		}
	}
	Catch ex {
		Do ..SetStatus($$$EnsSystemError)
	}
}

/// Helper method to record a status for later reuse.
ClassMethod SetStatus(pStatus As %Status, pType As %String = "server") [ Private ]
{
	Set %EnsContentData("Status") = pStatus
	If $$$ISERR(pStatus) Set %EnsContentData("ErrorType") = pType
}

/// Helper method to retrieve recorded status values/
ClassMethod GetStatus(Output pType As %String) As %Status [ Private ]
{
	Set pType = $get(%EnsContentData("ErrorType"))
	Quit $get(%EnsContentData("Status"),1)
}

/// Check whether the user is permitted to view data contained in the class specified
/// in <var>pClassName</var>. An error indicating a reason will be returned 
/// if the user is not permitted to view the contents of the class.
ClassMethod CheckPermissions(pClassName As %String = "") As %Status
{
	If $classmethod(pClassName,"%Extends","Ens.MessageHeader") {
		Set tResourcesRequired("%Ens_MessageContent") = "USE"
	}
	ElseIf $classmethod(pClassName,"%Extends","Ens.Enterprise.MsgBank.MessageHeader") {
		Set tResourcesRequired("%Ens_MsgBank_MessageContent") = "USE"
	}
	ElseIf $classmethod(pClassName,"%Extends","Ens.Util.Log") {
		Set tResourcesRequired("%Ens_EventLog") = "USE"
	}
	ElseIf $classmethod(pClassName,"%Extends","Ens.Enterprise.MsgBank.Log") {
		Set tResourcesRequired("%Ens_MsgBank_EventLog") = "USE"
	}
	Else {
		Set tResourcesRequired("%Ens_MessageContent") = "USE"
	}
	
	Set tStatus = $$$OK
	Set tResource = ""
	For {
		Set tReq = ""
		Set tResource = $order(tResourcesRequired(tResource),1,tReq)
		Quit:(tResource = "")
		If tReq = "" Set tReq = "USE"
		Set tHave = $system.Security.Check(tResource,tReq)
		If 'tHave {
			Set tStatus = $$$ERROR($$$OperationRequires1, tReq, tResource)
			Quit
		}
	}
	Quit tStatus
}

/// Render the actual content the user will see.
ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
	Set tStatus = ..GetStatus(.tType)
	If $$$ISERR(tStatus) {
		Set tError("user") = $$$Text("Client Error")
		Set tError("security") = $$$Text("Security Error")
		Set tError("server") = $$$Text("Server Error")
		Set tErrorTitle = $get(tError(tType), $$$Text("Server Error"))
		Set tErrorMessage = $zcvt($system.Status.GetErrorText(tStatus),"O","HTML")
		If tType = "security" {
			Set tErrorMessage = "<span style=""color: black;"">"_$$$Text("Not permitted to view message contents")_"</span><br/>"_tErrorMessage
		}
		&html<
		<html><head><title>#(tErrorTitle)#</title>>
		Do ..DrawAutoLogout()
		&html<</head>
>
		// This style makes error messages consistent with EDI Document Viewer page, per ProdLog 90739
		&html<<body style="color: darkred; font-family: Arial,sans-serif; font-size: 0.8em;"><div>#(tErrorTitle)#: #(tErrorMessage)#</div></body>>
		Kill %EnsContentData
		Quit $$$OK
	}
	
	Set tObject = $get(%EnsContentData("object"))
	Set tId = $get(%EnsContentData("Id"))
	Set tHeaderId = $get(%EnsContentData("HeaderId"))
	Set tClass = $get(%EnsContentData("ClassName"))
	
	#dim tClientClass As %String
	#dim tClientClassNotStream As %Boolean
	
	Set tClientClass = $P($get(%EnsContentData("ClientClassName")),":")
	Set tClientClassNotStream=($P($get(%EnsContentData("ClientClassName")),":",2)="NotStream")
	
	Set tSource = $$$Text("Message Browser")
	#; Allow RAW mode for EDI documents except for XML VDocs
	Set tShowRaw = (+$get(%request.Data("RAW",1))) && $IsObject(tObject) && tObject.%Extends("EnsLib.EDI.Document") && 'tObject.%Extends("EnsLib.EDI.XML.Document")
	Set tAudit = $case(tClass,
						"Ens.AlarmRequest": 0,
						"Ens.AlarmResponse": 0,
						: 1)
	If tAudit {
		Do $$$AuditViewMessage(tSource,tHeaderId,tClass,tId)
	}
	Set tBrowserStyle = $get(%request.Data("BrowserStyle",1))
	If %response.ContentType = "text/xml" {
		If tObject.%Extends("%XML.Adaptor") {
			&html<<?xml version="1.0" ?>>
			If 'tBrowserStyle &html<<?xml-stylesheet href="ensemble/Ensemble_XMLDisplay.xsl" type="text/xsl" ?>>
			&html<<!-- type: #($zcvt($classname(tObject),"O","XML"))#  id: #($zcvt(tObject.%Id(),"O","XML"))# -->>
  			Set tSC = ..writewithoutNonXMLChars(.tWriter,tObject,.tControlChars)
			If $$$ISERR(tSC) {
				Write "<!-- "_$$$TextHTML("Error trying to display message contents:")_..EscapeHTML($$$StatusDisplayString(tSC))_" -->"
				Do ..SetStatus(tSC)
			} ElseIf tControlChars {
				Write "<!-- "_$$$TextHTML("Characters that could not be shown were removed for viewing purposes only")_" -->"
			}
		}
		ElseIf tObject.%Extends("%Stream.Object") {
			Set tHaveXMLDec = 0
			Set tStartPos = $Length("..<?xml ")
			Set tXMLDec = tObject.Read(.tStartPos)
			While ('tHaveXMLDec) && ('tObject.AtEnd) {
				Set tReadLen = 1
				Set tXMLDec = tXMLDec _ tObject.Read(.tReadLen)
				Set tStartPos = tStartPos + tReadLen
				If $extract(tXMLDec, *-1, *) = "?>" {
					Set tHaveXMLDec = 1
					Quit
				}
				If $length(tXMLDec)>50 Quit
			}
			If tHaveXMLDec {
				Write tXMLDec
			}
			Else {
				&html<<?xml version="1.0" ?>>
			}
			Write !
			If 'tBrowserStyle &html<<?xml-stylesheet href="ensemble/Ensemble_XMLDisplay.xsl" type="text/xsl" ?>>
			&html<<!-- type: #($classname(tObject))#  id: #($ZCVT($ZSTRIP(tObject.%Id(),"*C"),"O","XML"))# #($S(tClientClass'="":"[Client class: "_tClientClass_"]",1:""))# -->>
			Set tControlChars = 0
			If 'tHaveXMLDec {
				Set tIn = tXMLDec
				Set tOut = $ZStrip(tIn,"*C",,$C(9,10,13,133))
    			Set:(tIn'=tOut) tControlChars = 1
    			Write tOut
			}
			If tClientClassNotStream {
				While 'tObject.AtEnd {
    				Set tIn = tObject.Read(4000)
    				Set tOut = $ZStrip(tIn,"*C",,$C(9,10,13,133))
    				Set:(tIn'=tOut) tControlChars = 1
    				Write tOut
				}
			} Else {
				// Note that argument is required otherwise Rewind() is called on the Stream
				Do tObject.OutputToDevice(tObject.Size - tStartPos)
			}
			If tControlChars Write "<!-- "_$$$TextHTML("Characters that could not be shown were removed for viewing purposes only")_" -->"
		}
		Else {
			Do tObject.%ShowContents(1)
		}
		Quit $$$OK
	}

	/// Display HTML
	&html<<html>
		<head>
		<title>#($$$TextHTML("Message Content Viewer"))#</title>
		<style type="text/css">
			body {
				font-family: Arial,sans-serif;
				font-size: 1.0em;
				font-weight: regular;
			}
			.portalTitleLink {
				cursor: pointer;
				color: #3B84BC;
				font-weight: regular;
				text-decoration: none;
			}
		</style>
	>
	Do ..DrawAutoLogout()
			
	If $IsObject(tObject) {
		If tObject.%Extends("Ens.Util.MessageBodyMethods") || tObject.%Extends("Ens.Util.IOLog") {
			If ('tShowRaw) Do tObject.%ShowContentsHead(1)
		}
		ElseIf tObject.%Extends("Ens.Util.LogBase") {
			Do ##class(EnsPortal.Utils).DrawEventInfoStyle()
		}
	}
	&html<</head>
		<body>>
	If '$IsObject(tObject) {
		&html<<div>#($$$TextHTML("There is no message body associated with this message."))#</div>>
	}
	ElseIf tObject.%Extends("Ens.Util.MessageBodyMethods") || tObject.%Extends("Ens.Util.IOLog") {
		If tShowRaw {
			&html<<pre style="padding: 5px;">>
			Set currIO = $$$GETIO
			try {
				$$$SETIO("HTML")
				If 'tObject.%Extends("EnsLib.EDI.Segmented") {
					Do tObject.OutputToDevice()
				} Else {
					Set tSeg=tObject.GetSegmentAt(1)
					Set tSeparators=$S($IsObject(tSeg):tSeg.Separators,1:"")
					Set:$E(tObject.Separators,1,$L(tSeparators))'=$E(tSeparators,1,$L(tObject.Separators)) tSeparators=$E(tObject.Separators,1,$L(tSeparators))_$E(tSeparators,1+$L(tObject.Separators),*)
					Set:tObject.%Extends("EnsLib.EDI.X12.Document")||tObject.%Extends("EnsLib.EDI.EDIFACT.Document") tSeparators=tSeparators_tObject.SegmentTerminator
					Set:$C(10)'=$E(tSeparators,*) tSeparators=tSeparators_$C(10)
					Set:$C(13)'=$E(tSeparators,*-1) tSeparators=$E(tSeparators,1,*-1)_$C(13,10)
					If tObject.%Extends("EnsLib.HL7.Message") {
						Do tObject.OutputToDevice(,tSeparators)
					} Else {
						Do tObject.OutputToDevice(tSeparators)
					}
				}
			} catch { }
			$$$SETIO(currIO)
			&html<</pre>>
		}
		Else {
			Do tObject.%ShowContents(1)
		}
	}
	ElseIf tObject.%Extends("Ens.Util.LogBase") {
		Do ##class(EnsPortal.Utils).DrawEventInfo(tObject.%Id(), 0,0, tObject.%IsA("Ens.Enterprise.MsgBank.Log"))
	}
	ElseIf tObject.%Extends("%Stream.Object") {
		&html<<div>>
		While 'tObject.AtEnd {
			Set tChunk=tObject.Read(4000)
			Quit:(""=tChunk)
			Write $$replace^EnsUtil($Replace($ZCVT(tChunk,"O","HTML"),$C(13,10),$C(13)),$C(13),"<br/>",$C(10),"<br/>")
		}
		&html<</div>>
	}
	Else {
		&html<<div>#($$$TextHTML("There is no content viewer defined for this message type."))#</div>>
	}
	&html<</body></html>>
	Quit $$$OK
}

/// Helper method to draw the autologout logic for this page.
/// This code should be called from within the HTML head tag.
ClassMethod DrawAutoLogout() [ Private ]
{
	&html<
	<script type="text/javascript" src="ensemble/Ensemble_Utils.js"></script>
	 <script type="text/javascript">
		try {
			handleZenAutoLogout(#((%session.AppTimeout+15)*1000)#);
		}
		catch (ex) {}
	</script>>
	Quit
}

ClassMethod GetMessages(messages As %ZEN.proxyObject) As %ZEN.proxyObject
{
	Set tLocal = ##class(%ZEN.proxyObject).%New()
	If $IsObject($get(messages)) {
		Set tLoc("noNamespace") = $$$Text("NOTE: XML namespace information not available in your browser. XML namespace declarations will not be displayed in output.")
		Set tLoc("expandAll") = $$$Text("Expand All")
		Set tLoc("defaultBrowser") = $$$Text("Default Browser Style")
		Set tLoc("showDefaultBrowser") = $$$Text("Show default browser display")

		Do messages.%CopyToArray(.tRequested)
		Set tMsg = ""
		For {
			Set tMsg = $order(tRequested(tMsg))
			Quit:(tMsg = "")
			If $data(tLoc(tMsg))#10 {
				Set tRequested(tMsg) = tLoc(tMsg)
			}
		}
		Do tLocal.%CopyFromArray(.tRequested)
	}
	Quit tLocal
}

/// Used to strip non XML characters from XML object when writing to current device.
ClassMethod writewithoutNonXMLChars(pWriter As %XML.Writer, pObject As %XML.Adaptor, Output pWasChanged As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		If '$IsObject($G(pWriter)) {
			Set pWriter = ##class(%XML.Writer).%New()
			Set pWriter.NoXMLDeclaration = 1
			Do pWriter.AddInstanceNamespace()
			Do pWriter.AddSchemaNamespace()	
		} Else {
			If pWriter.OutputDestination'="device" {Set tSC = $$$ERROR($$$EnsErrGeneral, "XML Writer output destination needs to be 'device'") Quit}
		}		
		Set tOutputStream = ##class(%Stream.TmpBinary).%New()
		Set tSC = ##class(Ens.Util.IO).Redirect(.tIO,,tOutputStream)
		If $$$ISERR(tSC){Do:$IsObject($G(tIO)) tIO.StopRedirect()  Quit}
		Set tSC = pWriter.RootObject(pObject)
		Set tSC1 = tIO.StopRedirect()
		Quit:($$$ISERR(tSC)||$$$ISERR(tSC1))
		Quit:'tOutputStream.Size
		Do tOutputStream.Rewind()
		While 'tOutputStream.AtEnd {
    		Set tIn = tOutputStream.Read(4000)
    		Set tOut = $ZStrip(tIn,"*C",,$C(9,10,13,133))
    		Set:(tIn'=tOut) pWasChanged = 1
    		Write tOut
  		}
	} Catch {
		Set tSC = $$$SystemError	
	}
	Quit tSC
}

}
