/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

Include EnsEDIX12

Class EnsLib.EDI.X12.Util.Validator [ Abstract, System = 4 ]
{

/// Use our own domain for localization
Parameter DOMAIN = "Ensemble";

/// <var>pDoc</var> is the X12 document to validate.
/// <var>pValSpec</var> is a string specifying types of Validation to perform <p>
/// Set to 1 to block documents that don't pass default validation. Default validation requires a DocType
/// and blocks messages with any other error encountered while mapping the document's 
/// sequence of segments using the X12 schema structure specified by the document's DocType. This is equivalent to 'dm'. <p/>
/// All flags relating to fields/components apply only if 's'/'c' also specified 
/// (eg. if set to 'dmslt' then the length and datatype of fields will be checked, but the length and datatype of components will not be) <p/>
/// 'd' - require DocType <br/>
/// 'm' - don't tolerate BuildMap segment mapping errors <br/>
/// 's' - enforce segment structures (number and repetition of fields) <br/>
/// 'c' - enforce composite structures (number of components) <br/>
/// 'r' - enforce required fields/components being present <br/>
/// 'u' - enforce non-use of fields/components marked 'Not Used' - Note this is not available when using a new-style only schema <br/>
/// 'l' - enforce field/component length restrictions <br/>
/// 't' - enforce correct datatypes used for field/component values <br/>
/// 'v' - enforce correct code table values used where specified in the schema - Note this is not available when using a new-style only schema <br/>
/// 'n' - perform all validation available to new style schemas.  This is equivalent to 'dmscrlt' <br/>
/// 'a' - perform all available validation. This is equivalent to 'dmscrultv' <br/>
/// 'e' - continue validating after errors are encountered - specify this to scan the entire document and report all errors <br/>
ClassMethod Validate(pDoc As EnsLib.EDI.X12.Document, pValSpec As %String = 1, pValidateChildren As %Boolean = 1) As %Status
{
	#; do validation - by default validate DocType, BuildMapStatus
	#dim tSC,tSC1 As %Status = $$$OK
	#dim tQuitOnError As %Boolean = 1
	#dim OldStyle As %Boolean = 0
	#dim i As %Integer
	#dim tSeg As EnsLib.EDI.X12.Segment
	#dim tChildDoc As EnsLib.EDI.X12.Document
	#dim DocType,tChildDocType As %String
	#dim ex As %Exception.AbstractException
	
	Try {
		Set pValSpec=$zcvt(pValSpec,"L")
		Quit:$TR(pValSpec,"e","")="" ; if no flags or just 'e' quit
		Set:pValSpec["a" pValSpec=$REPLACE(pValSpec,"a","dmscrultv")
		Set:pValSpec["n" pValSpec=$REPLACE(pValSpec,"n","dmscrlt")
		Set:pValSpec=1 pValSpec="dm"
		Set tQuitOnError = (pValSpec'["e")
		
		// first test for DocType
		If ((pDoc.DocType="") && (pValSpec["d")) {
			Set tSC=$$$ERROR($$$EnsEDIX12MissingDocType)
			Quit:tQuitOnError
		}
		Quit:(pValSpec="d")
		
		// no need for use of 'validation schema' if not doing field/component level validation
		If ($TR(pValSpec, "sc")'=pValSpec)&&(pDoc.DocType'="") {
			Set DocType = pDoc.DocType
			Set:$E(DocType)="-" DocType=$E(DocType,2,*)
			If $D($$$vaVSchemaGbl($P(DocType,":"),$P(DocType,":",2))) {
				Do pDoc.PokeDocType("-"_DocType)
				Set OldStyle = 1
			} ElseIf ($TR(pValSpec,"uv")'=pValSpec) {
				If (pValSpec["u") {
					Set tSC = $$$ADDSC(tSC,$$$ERROR($$$EnsEDIX12CannotEnforceNonUse))
					Quit:tQuitOnError
				}
				If (pValSpec["v") {
					Set tSC = $$$ADDSC(tSC,$$$ERROR($$$EnsEDIX12CannotEnforceCodeTables))
					Quit:tQuitOnError
				}
			}
		}
		Set tSC1=pDoc.BuildMap('tQuitOnError)

		If (pValSpec["m")&&$$$ISERR(tSC1) {
			Set tSC=$$$ADDSC(tSC,tSC1) 
			Quit:tQuitOnError
		}
		
		If pValSpec["s" {
			If pDoc.DocType="" || $$$StatusEquals(tSC1,$$$EnsEDIErrMapDocType) {
				Set tSC=$$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CannotValidateNoDocType))
				Quit
			}
			For i=1:1:pDoc.SegCount {
				Set tSeg=pDoc.GetSegmentAt(i,.tSC1)
				If $$$ISERR(tSC1) {
					Set tSC=$$$ADDSC(tSC,tSC1) 
					Quit:tQuitOnError
					Continue // can't do anything with segment we can't get
				}
				If tSeg.Name [ "DocsRef" {
					If pValidateChildren {
						Set tChildDoc=$$$NULLOREF
						For {
							// Get child documents and validate them
							Set tChildDoc=pDoc.NextChild(tChildDoc,i)
							Quit:'$IsObject(tChildDoc)
							If ""=tChildDoc.DocType {
								Set tChildDocType = tChildDoc.resolveChildDocType()
								Do tChildDoc.PokeDocType(tChildDocType)
							}
							Set tSC1 = ..Validate(tChildDoc,pValSpec)
							If $$$ISERR(tSC1) {
								Set tSC=$$$ADDSC(tSC,tSC1) 
								Quit:tQuitOnError
							}
						}
						Quit:$$$ISERR(tSC)&&tQuitOnError
					}
					Continue // doesn't make sense to validate the DocsRef segment because this isn't a real part of the X12 document
				}
				If OldStyle=1 {
					Set tSC1=..DoValidateVSegment(tSeg,pValSpec,i,DocType,tQuitOnError)
				} Else {
					Set tSC1=..DoValidateNewSegment(tSeg,pValSpec,i,tQuitOnError)
				}
				If $$$ISERR(tSC1) {
					Set tSC=$$$ADDSC(tSC,tSC1) 
					Quit:tQuitOnError
				}
			}
		}
	} Catch ex {
		Set tSC = $S('tQuitOnError:$$$ADDSC(ex.AsStatus(),tSC),1:ex.AsStatus())
	}
	If ($IsObject(pDoc)&&($E(pDoc.DocType)="-")) {
		// Allow proper display in Message Viewer window
		Do pDoc.PokeDocType($E(pDoc.DocType,2,*))
	}
	Quit tSC
}

ClassMethod DoValidateVSegment(pSeg As EnsLib.EDI.X12.Segment, pValSpec As %String, pSegNum As %Integer, pDocumentDocType, pQuitOnError As %Boolean = 1) As %Status [ Internal ]
{
	#dim tSC, tSC2 As %Status = $$$OK
	#dim tCategory, tDocType, tInfo, tFieldDat, tRequired, tDatatype As %String
	#dim tOrdinal, tSegCount, tFieldNum, tNumReps, tMaxUse, tMinLen, tFieldLen, tMaxLen, tCompNum As %Integer
	#dim tHasData, tIsValid As %Boolean
	#dim ex As %Exception.AbstractException
	
	Try {

		If (pSeg.DocTypeName = "") {
			Set tSC = $$$ERROR($$$EnsEDIX12CannotValidateNoSegName,pSegNum)
			Quit
		}
		If (pDocumentDocType = "") {
			Set tSC = $$$ERROR($$$EnsEDIX12CannotValidateNoCategory,pSegNum,pSeg.Name)
			Quit
		}
		
		Set tCategory = $P(pDocumentDocType,":",1)
		Set tDocType = $P(pDocumentDocType,":",2)
		Set tOrdinal = $P(pSeg.DocTypeName,"-",2)
		If '$Data($$$vaVSchemaGbl(tCategory,tDocType,"o",tOrdinal)) {
			Set tSC = $$$ERROR($$$EnsEDIX12CannotRetrieveSchema,pSegNum,pSeg.Name)
			Quit
		}

		Set tSegCount = pSeg.Count ; avoid repeated calls to CountGet()
		If (tSegCount > $O($$$vaVSchemaGbl(tCategory,tDocType,"o",tOrdinal,""),-1)) {
			Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12SegmentStructureError,pSegNum,pSeg.Name,pDocumentDocType_":"_pSeg.DocTypeName))
			Quit:pQuitOnError ; stop looking at the segment if not continuing after error
		}

		Set tFieldNum = ""
		For {
			Set tFieldNum = $O($$$vaVSchemaGbl(tCategory,tDocType,"o",tOrdinal,tFieldNum),1,tInfo)
			Quit:(tFieldNum="")||(tFieldNum > tSegCount)

			Set tFieldDat = pSeg.GetValueAt(tFieldNum, pSeg.Separators, .tSC2)
			If ($$$ISERR(tSC2)) {
				Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CannotRetrieveValue,tFieldNum,pSegNum,pSeg.Name,$System.Status.GetErrorText(tSC2)))
				Quit:pQuitOnError
				Continue ; can only continue with this field if no error in getting it
			}
			
			If (pSeg.Name="ISA")&&$Case(tFieldNum,11:1,16:1,:0) {
				If tFieldNum=11 {
					Set tNumReps = 1
					Set tHasData = (tFieldDat '= "")
				} Else {
					Set tNumReps = $Length(tFieldDat,pSeg.RS)
					Set tHasData = ($Translate(tFieldDat, pSeg.RS,"") '= "")
				}
			} Else {
				Set tNumReps = $Length(tFieldDat,pSeg.RS)
				Set tHasData = ($tr(tFieldDat, pSeg.Separators, "") '= "") ; is anything left after removing separators?
			}
			
			Set tMaxUse = $S($E(tInfo)="E":$P(tInfo,"|",7),1:$P(tInfo,"|",6))
			If ((tNumReps > tMaxUse)&&(tMaxUse'="")) {
				If tMaxUse=1 {
					Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12ForbiddenRepetition,pSegNum,pSeg.Name,tFieldNum,pDocumentDocType_":"_pSeg.DocTypeName))
				} Else {
					Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12ExcessRepetition,pSegNum,pSeg.Name,tFieldNum,tMaxUse,pDocumentDocType_":"_pSeg.DocTypeName))
				}
				Quit:pQuitOnError
			}

			If (pValSpec["r")||(pValSpec["u") {
				Set tRequired = $P(tInfo,"|",3)
				If ((pValSpec["r") && ('tHasData) && (tRequired = "M")) {
					Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12RequiredFieldMissing,pSegNum,pSeg.Name,tFieldNum,pDocumentDocType_":"_pSeg.DocTypeName))
					Quit:pQuitOnError
				} ElseIf ((pValSpec["u") && tHasData && (tRequired=".")) {
					Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldIndustryUsageError,pSegNum,pSeg.Name,tFieldNum,pDocumentDocType_":"_pSeg.DocTypeName))
					Quit:pQuitOnError
				}
			}
			
			Continue:'tHasData||($Translate(pValSpec,"ltvc")=pValSpec) ;# don't do any more work if not interested in length, datatypes, code tables, or composite structures
			
			If ($E(tInfo)="E") {
				
				If (tNumReps > 1) {
					// if care about length, do preliminary testing that applies to entire field
					If (pValSpec["l") {
						Set tDatatype = $P(tInfo,"|",4)
						Set tMinLen = $P(tInfo,"|",5)
						Set tFieldLen = $length(tFieldDat)
						Set:(("-"=$E(tFieldDat,1))&&((tDatatype ?1"N".N))) tFieldLen = (tFieldLen-1) ;# optional - sign not counted in length
						Set:(tDatatype="R") tFieldLen = $L($TR(tFieldDat,"-.")) ;# sign and decimal not counted in length
			
						If (tFieldLen < tMinLen) { ; under min length
							Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldSizeMin,pSegNum,pSeg.Name,tFieldNum,tMinLen,pDocumentDocType_":"_pSeg.DocTypeName))
							Quit:pQuitOnError
						}
					}
					For tRep=1:1:tNumReps {
						Set tValue = $P(tFieldDat,pSeg.RS, tRep)
						Set tIsValid = ..ValidateVElement(tValue,pValSpec,tInfo,pQuitOnError,pDocumentDocType,tOrdinal_":"_tFieldNum,.tErrors)
						If 'tIsValid {
							If $D(tErrors("MinLen"),tMinLen)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldSizeMinRepeating,pSegNum,pSeg.Name,tFieldNum,tRep,tMinLen,pDocumentDocType_":"_pSeg.DocTypeName))
							}
							If $D(tErrors("MaxLen"),tMaxLen)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldSizeMaxRepeating,pSegNum,pSeg.Name,tFieldNum,tRep,tMaxLen,pDocumentDocType_":"_pSeg.DocTypeName))
							}
							If $D(tErrors("Datatype"),tDatatype)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldDatatypeValRepeating,tDatatype,pSegNum,pSeg.DocTypeName,tFieldNum,tRep))
							}
							If $D(tErrors("CodeTable"))#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12InvalidFieldValRepeating,pSegNum,pSeg.DocTypeName,tFieldNum,tRep))
							}
						}
						Quit:$$$ISERR(tSC)&&pQuitOnError
					}		
						
				} Else { ; no reps
					If ($P(tInfo,"|",4)="B") {
						// for binary datatype, actual length is specified by the immediately preceding data element (B.1.1.3.1.7 of Implementation Guide)
						Set tMaxLen = pSeg.GetValueAt(tFieldNum-1, pSeg.Separators)
						Set tInfo = $P(tInfo,"|",1,5)_"|"_tMaxLen_"|"_$P(tInfo,"|",7,*)
					}
					Set tIsValid = ..ValidateVElement(tFieldDat,pValSpec,tInfo,pQuitOnError,pDocumentDocType,tOrdinal_":"_tFieldNum,.tErrors)
					If 'tIsValid {
						If $D(tErrors("MinLen"),tMinLen)#2 {
							Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldSizeMin,pSegNum,pSeg.Name,tFieldNum,tMinLen,pDocumentDocType_":"_pSeg.DocTypeName))
						}
						If $D(tErrors("MaxLen"),tMaxLen)#2 {
							Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldSizeMax,pSegNum,pSeg.Name,tFieldNum,tMaxLen,pDocumentDocType_":"_pSeg.DocTypeName))
						}
						If $D(tErrors("Datatype"),tDatatype)#2 {
							Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldDatatypeVal,tDatatype,pSegNum,pSeg.DocTypeName,tFieldNum))
						}
						If $D(tErrors("CodeTable"))#2 {
							Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12InvalidFieldVal,pSegNum,pSeg.DocTypeName,tFieldNum))
						}
					}
				}						
			}
			// Test the composite structure
			If (($E(tInfo)="C") && (pValSpec["c")) {
				Set tItemName = $P(tInfo,"|",2)
				If tNumReps > 1 {
					For tRep=1:1:tNumReps {
						Set tValue = $P(tFieldDat,pSeg.RS, tRep)
						Set tIsValid = ..ValidateVComposite(tValue,pSeg.CS,pValSpec,tInfo,pQuitOnError,pDocumentDocType,tOrdinal_":"_tFieldNum,.tErrors)
						If 'tIsValid {
							If $D(tErrors(0,"Structure"))#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompositeStructureErrRepeating,pSegNum,pSeg.DocTypeName,tFieldNum,tRep,tItemName))
							}
							Set tCompNum = 0
							For {
								Set tCompNum = $O(tErrors(tCompNum))  Quit:tCompNum=""
								If $D(tErrors(tCompNum,"Required"))#2 {
									Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12RequiredCompMissingRepeating,pSegNum,pSeg.DocTypeName,tFieldNum,tRep,tCompNum,tItemName))
								}
								If $D(tErrors(tCompNum,"Usage"))#2 {
									Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompIndustryUsageErrRepeating,pSegNum,pSeg.DocTypeName,tFieldNum,tRep,tCompNum,tItemName))
								}
								If $D(tErrors(tCompNum,"MinLen"),tMinLen)#2 {
									Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompSizeMinRepeating,pSegNum,pSeg.DocTypeName,tFieldNum,tRep,tCompNum,tMinLen,tItemName))
								}
								If $D(tErrors(tCompNum,"MaxLen"),tMaxLen)#2 {
									Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompSizeMaxRepeating,pSegNum,pSeg.DocTypeName,tFieldNum,tRep,tCompNum,tMaxLen,tItemName))
								}
								If $D(tErrors(tCompNum,"Datatype"),tDatatype)#2 {
									Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompDatatypeValRepeating,tDatatype,pSegNum,pSeg.DocTypeName,tFieldNum,tRep,tCompNum))
								}
								If $D(tErrors(tCompNum,"CodeTable"))#2 {
									Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12InvalidCompValRepeating,pSegNum,pSeg.DocTypeName,tFieldNum,tRep,tCompNum))
								}
							}
						}
						Quit:$$$ISERR(tSC)&&pQuitOnError
					}
				} Else {
					Set tIsValid = ..ValidateVComposite(tFieldDat,pSeg.CS,pValSpec,pQuitOnError,pDocumentDocType,tOrdinal_":"_tFieldNum,.tErrors)
					If 'tIsValid {
						If $D(tErrors(0,"Structure"))#2 {
							Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompositeStructureErr,pSegNum,pSeg.DocTypeName,tFieldNum,tItemName))
						}
						Set tCompNum = 0
						For {
							Set tCompNum = $O(tErrors(tCompNum))  Quit:tCompNum=""
							If $D(tErrors(tCompNum,"Required"))#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12RequiredCompMissing,pSegNum,pSeg.DocTypeName,tFieldNum,tCompNum,tItemName))
							}
							If $D(tErrors(tCompNum,"Usage"))#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompIndustryUsageErr,pSegNum,pSeg.DocTypeName,tFieldNum,tCompNum,tItemName))
							}
							If $D(tErrors(tCompNum,"MinLen"),tMinLen)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompSizeMin,pSegNum,pSeg.DocTypeName,tFieldNum,tCompNum,tMinLen,tItemName))
							}
							If $D(tErrors(tCompNum,"MaxLen"),tMaxLen)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompSizeMax,pSegNum,pSeg.DocTypeName,tFieldNum,tCompNum,tMaxLen,tItemName))
							}
							If $D(tErrors(tCompNum,"Datatype"),tDatatype)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompDatatypeVal,tDatatype,pSegNum,pSeg.DocTypeName,tFieldNum,tCompNum))
							}
							If $D(tErrors(tCompNum,"CodeTable"))#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12InvalidCompVal,pSegNum,pSeg.DocTypeName,tFieldNum,tCompNum))
							}
						}
					}
				}
			}
			Quit:($$$ISERR(tSC) && pQuitOnError)
		}
		Quit:($$$ISERR(tSC) && pQuitOnError) ; quit with error if there is one and not continuing after error
		If ((tFieldNum'="") && (pValSpec["r")) { ; fewer fields in message than in schema and we care about required fields
			If "M"=$P(tInfo,"|",3) { ; required field
				set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12RequiredFieldMissing,pSegNum,pSeg.Name,tFieldNum,pDocumentDocType_":"_pSeg.DocTypeName))
				Quit:pQuitOnError
			}
			For {
				Set tFieldNum = $O($$$vaVSchemaGbl(tCategory,tDocType,"o",tOrdinal,tFieldNum),1,tInfo)
				Quit:""=tFieldNum
				If "M"=$P(tInfo,"|",3) {
					set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12RequiredFieldMissing,pSegNum,pSeg.Name,tFieldNum,pDocumentDocType_":"_pSeg.DocTypeName))
					Quit:pQuitOnError
				}
			}
		}
	} Catch ex {
		Set tSC = $S('pQuitOnError:$$$ADDSC(ex.AsStatus(),tSC),1:ex.AsStatus())
	}
	Quit tSC
}

ClassMethod ValidateVComposite(pValue, pSep, pValSpec, pQuitOnError, pDocType, pOrdinal, pErrors) As %Boolean
{
	#dim tIsOkay,tIsOkayElem As %Boolean = 1
	#dim tCompCount,tCompNum As %Integer
	#dim tHasData As %Boolean
	#dim tInfo,tCompDat,tRequired As %String
	Kill pErrors
	
	Do {
		
		Set tCompCount = $L(pValue,pSep)
		#; first check don't have too many components
		If (tCompCount > $O($$$vaVSchemaGbl($P(pDocType,":"),$P(pDocType,":",2),"o",$P(pOrdinal,":"),$P(pOrdinal,":",2),""),-1)) {
			Set tIsOkay=0
			Set pErrors(0,"Structure")=""
			Quit:pQuitOnError ; stop looking at the field if not continuing after error
		}
		Set tCompNum = ""
		For {
			Set tCompNum = $O($$$vaVSchemaGbl($P(pDocType,":"),$P(pDocType,":",2),"o",$P(pOrdinal,":"),$P(pOrdinal,":",2),tCompNum),1,tInfo)
			Quit:((tCompNum="")||(tCompNum>tCompCount))
			Set tCompDat = $P(pValue,pSep,tCompNum)
			
			Set tHasData = (tCompDat'= "")
			If (pValSpec["r")||(pValSpec["u") {
				Set tRequired = $P(tInfo,"|",3)
				If ((pValSpec["r") && ('tHasData) && (tRequired = "M")) {
					Set tIsOkay = 0
					Set pErrors(tCompNum,"Required")=""
					Quit:pQuitOnError
				} ElseIf ((pValSpec["u") && tHasData && (tRequired=".")) {
					Set tIsOkay = 0
					Set pErrors(tCompNum,"Usage")=""
					Quit:pQuitOnError
				}
			}
		
			Continue:'tHasData||($Translate(pValSpec,"ltv")=pValSpec) ;# don't do any more work if not interested in length, datatypes, code tables
			Set tIsOkayElem = ..ValidateVElement(tCompDat,pValSpec,tInfo,pQuitOnError,pDocType,pOrdinal_":"_tCompNum,.tErrors)
			Set tIsOkay = (tIsOkay && tIsOkayElem)
			Merge pErrors(tCompNum) = tErrors
			Quit:('tIsOkay && pQuitOnError)
		}
			
		If ((tCompNum'="") && (pValSpec["r")) { ; fewer components in message than in schema and we care about required fields
			If "M"=$P(tInfo,"|",3) { ; required field
				Set tIsOkay = 0
				Set pErrors(tCompNum,"Required")=""
				Quit:pQuitOnError
			}
			For {
				Set tCompNum = $O($$$vaVSchemaGbl($P(pDocType,":"),$P(pDocType,":",2),"o",$P(pOrdinal,":"),$P(pOrdinal,":",2),tCompNum),1,tInfo)
				Quit:""=tCompNum
				If "M"=$P(tInfo,"|",3) {
					Set tIsOkay = 0
					Set pErrors(tCompNum,"Required")=""
					Quit:pQuitOnError
				}
			}
		}

	} While 0
	
	Quit tIsOkay
}

ClassMethod ValidateVElement(pValue, pValSpec, pInfo, pQuitOnError, pDocType, pOrdinal, pErrors) As %Boolean
{
	#dim tIsOkay As %Boolean = 1
	#dim tDatatype,tItemName As %String
	#dim tMinLen, tMaxLen,tLength, tCodeIndex As %String
	#dim tMatches As %Boolean
	Kill pErrors
	
	Do {
					
		Set tDatatype = $P(pInfo,"|",4)
		// if care about length, do preliminary testing that applies to entire field whether repeating or not
		If (pValSpec["l") {
			Set tMinLen = $P(pInfo,"|",5)
			Set tMaxLen = $P(pInfo,"|",6)
			Set tLength = $length(pValue)
			Set:(("-"=$E(pValue,1))&&((tDatatype ?1"N".N))) tLength = (tLength-1) ;# optional - sign not counted in length
			Set:(tDatatype="R") tLength = $L($TR(pValue,"-.")) ;# sign and decimal not counted in length
	
			If (tLength < tMinLen) { ; under min length
				Set tIsOkay = 0
				Set pErrors("MinLen") = tMinLen
				Quit:pQuitOnError
			} ElseIf ((tLength > tMaxLen)&&(tMaxLen'="")) { ; over the length restriction
				Set tIsOkay = 0
				Set pErrors("MaxLen") = tMaxLen
				Quit:pQuitOnError
			}
		}
		#; datatype test
		If (pValSpec["t") {
			Set tMatches = ..CheckDatatype(pValue,tDatatype)
			If 'tMatches {
				Set tIsOkay = 0
				Set pErrors("Datatype") = tDatatype
				Quit:pQuitOnError
			}
		}
		#; code table tests
		If ((pValSpec["v") || ((pValSpec["t") && (tDatatype="ID"))) {
			Set tItemName = $P(pInfo,"|",2)
			If $L(pOrdinal,":")>2 {
				Set tCodeIndex = $G($$$vaVSchemaGbl($P(pDocType,":"),$P(pDocType,":",2),"c",tItemName,"l",$P(pOrdinal,":"),$P(pOrdinal,":",2),$P(pOrdinal,":",3))) // get the index for fetching values if defined
			} Else {
				Set tCodeIndex = $G($$$vaVSchemaGbl($P(pDocType,":"),$P(pDocType,":",2),"c",tItemName,"l",$P(pOrdinal,":"),$P(pOrdinal,":",2))) // get the index for fetching values if defined
			}
			If ""'=tCodeIndex {
				#; test to see if value is among those allowed for this element
				If '$D($$$vaVSchemaGbl($P(pDocType,":"),$P(pDocType,":",2),"c",tItemName,"c",tCodeIndex,pValue)) {
					Set tIsOkay = 0
					Set pErrors("CodeTable")=""
					Quit:pQuitOnError
				}
			}
		}
	} While 0
	
	Quit tIsOkay
}

ClassMethod DoValidateNewSegment(pSeg As EnsLib.EDI.X12.Segment, pValSpec As %String, pSegNum As %Integer, pQuitOnError As %Boolean = 1) As %Status [ Internal ]
{
	#dim tSC, tSC2 As %Status = $$$OK
	#dim tCategory, tDocType, tInfo, tFieldDat, tRequired, tDatatype As %String
	#dim tSegCount, tFieldNum, tNumReps, tMaxUse, tMinLen, tFieldLen, tMaxLen, tCompNum As %Integer
	#dim tSegFound, tHasData, tIsValid As %Boolean
	#dim ex As %Exception.AbstractException
	
	Try {

		If (pSeg.Name = "") {
			Set tSC = $$$ERROR($$$EnsEDIX12CannotValidateNoSegName,pSegNum)
			Quit
		}
		If (pSeg.DocTypeCategory = "") {
			Set tSC = $$$ERROR($$$EnsEDIX12CannotValidateNoCategory,pSegNum,pSeg.Name)
			Quit
		}
		
		Set tCategory = pSeg.DocTypeCategory
		Set tDocType = pSeg.Name
		Set tSegFound = 0
		For {
			If $D($$$vaSchemaGbl(tCategory,"SS",tDocType),tSegData)#2 {
				Set tSegFound = 1
				Quit
			} ElseIf '$D($$$vaSchemaGbl(tCategory,"base"),tCategory) {
				Quit
			}
		}
		If 'tSegFound {
			Set tSC = $$$ERROR($$$EnsEDIX12CannotRetrieveSchema,pSegNum,pSeg.Name)
			Quit
		}

		Set tSegCount = pSeg.Count ; avoid repeated calls to CountGet()
		If (tSegCount > $ListLength(tSegData)) {
			Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12SegmentStructureError,pSegNum,pSeg.Name,pSeg.DocType))
			Quit:pQuitOnError ; stop looking at the segment if not continuing after error
		}

		Set tFieldNum = ""
		For tFieldNum=1:1:$ListLength(tSegData) {
			Quit:(tFieldNum > tSegCount)
			Set tInfo = $LG(tSegData,tFieldNum)

			Set tFieldDat = pSeg.GetValueAt(tFieldNum, pSeg.Separators, .tSC2)
			If ($$$ISERR(tSC2)) {
				Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CannotRetrieveValue,tFieldNum,pSegNum,pSeg.Name,$System.Status.GetErrorText(tSC2)))
				Quit:pQuitOnError
				Continue ; can only continue with this field if no error in getting it
			}
			
			If (pSeg.Name="ISA")&&$Case(tFieldNum,11:1,16:1,:0) {
				If tFieldNum=11 {
					Set tNumReps = 1
					Set tHasData = (tFieldDat '= "")
				} Else {
					Set tNumReps = $Length(tFieldDat,pSeg.RS)
					Set tHasData = ($Translate(tFieldDat, pSeg.RS,"") '= "")
				}
			} Else {
				Set tNumReps = $Length(tFieldDat,pSeg.RS)
				Set tHasData = ($tr(tFieldDat, pSeg.Separators, "") '= "") ; is anything left after removing separators?
			}
			
			Set tMaxUse = $LG(tInfo,3)
			If ((tNumReps > tMaxUse) && (tMaxUse'="")) {
				If tMaxUse=1 {
					Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12ForbiddenRepetition,pSegNum,pSeg.Name,tFieldNum,pSeg.DocType))
				} Else {
					Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12ExcessRepetition,pSegNum,pSeg.Name,tFieldNum,tMaxUse,pSeg.DocType))
				}
				Quit:pQuitOnError
			}

			If (pValSpec["r") {
				Set tRequired = $LG(tInfo,5)
				If (('tHasData) && (tRequired = "M")) {
					Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12RequiredFieldMissing,pSegNum,pSeg.Name,tFieldNum,pSeg.DocType))
					Quit:pQuitOnError
				}
			}
			
			Continue:'tHasData||($Translate(pValSpec,"ltc")=pValSpec) ;# don't do any more work if not interested in length, datatypes, or composite structures
			
			Set tDatatype = $LG(tInfo,1)
			
			If (tDatatype'[":") {
				// Simple element - not composite
				Set tDatatype = $E(tDatatype,2,*-1)
				If (tNumReps > 1) {
					// if care about length, do preliminary testing that applies to entire field
					If (pValSpec["l") {
						Set tMinLen = $LG(tInfo,2)
						Set tFieldLen = $length(tFieldDat)
						Set:(("-"=$E(tFieldDat,1))&&((tDatatype ?1"N".N))) tFieldLen = (tFieldLen-1) ;# optional - sign not counted in length
						Set:(tDatatype="R") tFieldLen = $L($TR(tFieldDat,"-.")) ;# sign and decimal not counted in length
			
						If (tFieldLen < tMinLen) { ; under min length
							Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldSizeMin,pSegNum,pSeg.Name,tFieldNum,tMinLen,pSeg.DocType))
							Quit:pQuitOnError
						}
					}
					For tRep=1:1:tNumReps {
						Set tValue = $P(tFieldDat,pSeg.RS, tRep)
						Set tIsValid = ..ValidateNewElement(tValue,pValSpec,tInfo,pQuitOnError,.tErrors)
						If 'tIsValid {
							If $D(tErrors("MinLen"),tMinLen)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldSizeMinRepeating,pSegNum,pSeg.Name,tFieldNum,tRep,tMinLen,pSeg.DocType))
							}
							If $D(tErrors("MaxLen"),tMaxLen)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldSizeMaxRepeating,pSegNum,pSeg.Name,tFieldNum,tRep,tMaxLen,pSeg.DocType))
							}
							If $D(tErrors("Datatype"),tDatatype)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldDatatypeValRepeating,tDatatype,pSegNum,pSeg.Name,tFieldNum,tRep))
							}
						}
						Quit:$$$ISERR(tSC)&&pQuitOnError
					}		
						
				} Else { ; no reps
					If (tDatatype="B") {
						// for binary datatype, actual length is specified by the immediately preceding data element (B.1.1.3.1.7 of Implementation Guide)
						Set $List(tInfo,4) = pSeg.GetValueAt(tFieldNum-1, pSeg.Separators)
					}
					Set tIsValid = ..ValidateNewElement(tFieldDat,pValSpec,tInfo,pQuitOnError,.tErrors)
					If 'tIsValid {
						If $D(tErrors("MinLen"),tMinLen)#2 {
							Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldSizeMin,pSegNum,pSeg.Name,tFieldNum,tMinLen,pSeg.DocType))
						}
						If $D(tErrors("MaxLen"),tMaxLen)#2 {
							Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldSizeMax,pSegNum,pSeg.Name,tFieldNum,tMaxLen,pSeg.DocType))
						}
						If $D(tErrors("Datatype"),tDatatype)#2 {
							Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12FieldDatatypeVal,tDatatype,pSegNum,pSeg.Name,tFieldNum))
						}
					}
				}						
			} Elseif (pValSpec["c") {
				
				Set tItemName = tDatatype
				If '$D($$$vaSchemaGbl($P(tItemName,":"),"CS",$P(tItemName,":",2)),tCompStruct) {
					Set tSC = $$$ERROR($$$EnsEDIX12CannotRetrieveSchema,tDatatype,pSegNum,pSeg.Name,tFieldNum)
					Quit
				}
				// Test the composite structure
				If tNumReps > 1 {
					For tRep=1:1:tNumReps {
						Set tValue = $P(tFieldDat,pSeg.RS, tRep)
						Set tIsValid = ..ValidateNewComposite(tValue,pSeg.CS,pValSpec,tInfo,pQuitOnError,tCompStruct,.tErrors)
						If 'tIsValid {
							If $D(tErrors(0,"Structure"))#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompositeStructureErrRepeating,pSegNum,pSeg.Name,tFieldNum,tRep,tItemName))
							}
							Set tCompNum = 0
							For {
								Set tCompNum = $O(tErrors(tCompNum))  Quit:tCompNum=""
								If $D(tErrors(tCompNum,"Required"))#2 {
									Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12RequiredCompMissingRepeating,pSegNum,pSeg.Name,tFieldNum,tRep,tCompNum,tItemName))
								}
								If $D(tErrors(tCompNum,"MinLen"),tMinLen)#2 {
									Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompSizeMinRepeating,pSegNum,pSeg.Name,tFieldNum,tRep,tCompNum,tMinLen,tItemName))
								}
								If $D(tErrors(tCompNum,"MaxLen"),tMaxLen)#2 {
									Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompSizeMaxRepeating,pSegNum,pSeg.Name,tFieldNum,tRep,tCompNum,tMaxLen,tItemName))
								}
								If $D(tErrors(tCompNum,"Datatype"),tDatatype)#2 {
									Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompDatatypeValRepeating,tDatatype,pSegNum,pSeg.Name,tFieldNum,tRep,tCompNum))
								}
							}
						}
						Quit:$$$ISERR(tSC)&&pQuitOnError
					}
				} Else {
					Set tIsValid = ..ValidateNewComposite(tFieldDat,pSeg.CS,pValSpec,pQuitOnError,tCompStruct,.tErrors)
					If 'tIsValid {
						If $D(tErrors(0,"Structure"))#2 {
							Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompositeStructureErr,pSegNum,pSeg.Name,tFieldNum,tItemName))
						}
						Set tCompNum = 0
						For {
							Set tCompNum = $O(tErrors(tCompNum))  Quit:tCompNum=""
							If $D(tErrors(tCompNum,"Required"))#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12RequiredCompMissing,pSegNum,pSeg.Name,tFieldNum,tCompNum,tItemName))
							}
							If $D(tErrors(tCompNum,"MinLen"),tMinLen)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompSizeMin,pSegNum,pSeg.Name,tFieldNum,tCompNum,tMinLen,tItemName))
							}
							If $D(tErrors(tCompNum,"MaxLen"),tMaxLen)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompSizeMax,pSegNum,pSeg.Name,tFieldNum,tCompNum,tMaxLen,tItemName))
							}
							If $D(tErrors(tCompNum,"Datatype"),tDatatype)#2 {
								Set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsEDIX12CompDatatypeVal,tDatatype,pSegNum,pSeg.Name,tFieldNum,tCompNum))
							}

						}
					}
				}
			}
			Quit:($$$ISERR(tSC) && pQuitOnError)
		}
		Quit:($$$ISERR(tSC) && pQuitOnError) ; quit with error if there is one and not continuing after error
		If ((tSegCount<$LL(tSegData)) && (pValSpec["r")) { ; fewer fields in message than in schema and we care about required fields
			Set tInfo = $LG(tSegData,tFieldNum)
			If "M"=$LG(tInfo,5) { ; required field
				set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsErrGeneral, $$$FormatText($$$Text("Required field missing in segment %1: %2.  Missing field %3 which is required in segment structure %4."),pSegNum,pSeg.Name,tFieldNum,pSeg.DocType)))
				Quit:pQuitOnError
			}
			For {
				Quit:$I(tFieldNum)>$LL(tSegData)
				Set tInfo = $LG(tSegData,tFieldNum)
				If "M"=$L(tInfo,5) {
					set tSC = $$$ADDSC(tSC, $$$ERROR($$$EnsErrGeneral, $$$FormatText($$$Text("Required field missing in segment %1: %2.  Missing field %3 which is required in segment structure %4."),pSegNum,pSeg.Name,tFieldNum,pSeg.DocType)))
					Quit:pQuitOnError
				}
			}
		}
	} Catch ex {
		Set tSC = $S('pQuitOnError:$$$ADDSC(ex.AsStatus(),tSC),1:ex.AsStatus())
	}
	Quit tSC
}

ClassMethod ValidateNewComposite(pValue, pSep, pValSpec, pQuitOnError, pStructure, pErrors) As %Boolean
{
	#dim tIsOkay,tIsOkayElem As %Boolean = 1
	#dim tCompCount,tCompNum As %Integer
	#dim tHasData As %Boolean
	#dim tInfo,tCompDat,tRequired As %String
	Kill pErrors
	
	Do {
		
		Set tCompCount = $L(pValue,pSep)
		#; first check don't have too many components
		If (tCompCount > $LL(pStructure)) {
			Set tIsOkay=0
			Set pErrors(0,"Structure")=""
			Quit:pQuitOnError ; stop looking at the field if not continuing after error
		}
		Set tCompNum = ""
		For tCompNum=1:1:$LL(pStructure) {
			Quit:(tCompNum>tCompCount)
			Set tInfo = $LG(pStructure,tCompNum)
			Set tCompDat = $P(pValue,pSep,tCompNum)
			
			Set tHasData = (tCompDat'= "")
			If (pValSpec["r") {
				Set tRequired = $LG(tInfo,5)
				If (('tHasData) && (tRequired = "M")) {
					Set tIsOkay = 0
					Set pErrors(tCompNum,"Required")=""
					Quit:pQuitOnError
				} 
			}
		
			Continue:'tHasData||($Translate(pValSpec,"ltv")=pValSpec) ;# don't do any more work if not interested in length, datatypes, code tables
			Set tIsOkayElem = ..ValidateNewElement(tCompDat,pValSpec,tInfo,pQuitOnError,.tErrors)
			Set tIsOkay = (tIsOkay && tIsOkayElem)
			Merge pErrors(tCompNum) = tErrors
			Quit:('tIsOkay && pQuitOnError)
		}
			
		If ((tCompCount<$LL(pStructure)) && (pValSpec["r")) { ; fewer components in message than in schema and we care about required fields
			Set tInfo = $LG(pStructure,tCompNum)
			If "M"=$LG(tInfo,5) { ; required field
				Set tIsOkay = 0
				Set pErrors(tCompNum,"Required")=""
				Quit:pQuitOnError
			}
			For {
				Quit:$I(tCompNum)>$LL(pStructure)
				Set tInfo = $LG(pStructure,tCompNum)
				If "M"=$LG(tInfo,5) {
					Set tIsOkay = 0
					Set pErrors(tCompNum,"Required")=""
					Quit:pQuitOnError
				}
			}
		}

	} While 0
	
	Quit tIsOkay
}

ClassMethod ValidateNewElement(pValue, pValSpec, pInfo, pQuitOnError, pErrors) As %Boolean
{
	#dim tIsOkay As %Boolean = 1
	#dim tDatatype As %String
	#dim tMinLen, tMaxLen, tLength As %Integer
	#dim tMatches As %Boolean
	Kill pErrors
	
	Do {
					
		Set tDatatype = $E($LG(pInfo,1),2,*-1)
		// if care about length, do preliminary testing that applies to entire field whether repeating or not
		If (pValSpec["l") {
			Set tMinLen = $LG(pInfo,2)
			Set tMaxLen = $LG(pInfo,4)
			Set tLength = $length(pValue)
			Set:(("-"=$E(pValue,1))&&((tDatatype ?1"N".N))) tLength = (tLength-1) ;# optional - sign not counted in length
			Set:(tDatatype="R") tLength = $L($TR(pValue,"-.")) ;# sign and decimal not counted in length
	
			If (tLength < tMinLen) { ; under min length
				Set tIsOkay = 0
				Set pErrors("MinLen") = tMinLen
				Quit:pQuitOnError
			} ElseIf ((tLength > tMaxLen)&&(tMaxLen'="")) { ; over the length restriction
				Set tIsOkay = 0
				Set pErrors("MaxLen") = tMaxLen
				Quit:pQuitOnError
			}
		}
		#; datatype test
		If (pValSpec["t") {
			Set tMatches = ..CheckDatatype(pValue,tDatatype)
			If 'tMatches {
				Set tIsOkay = 0
				Set pErrors("Datatype") = tDatatype
				Quit:pQuitOnError
			}
		}
	} While 0
	
	Quit tIsOkay
}

ClassMethod CheckDatatype(pValue, pDatatype) As %Boolean
{
	#dim tMatches As %Boolean = 1
	#dim tMonth As %Integer
	
	If pDatatype = "R" {
		// Decimal
		#; "numeric values that have a varying number of decimal positions"
		Set tMatches = (pValue ? 0.1"-"0.N0.1".".N)
	} ElseIf pDatatype = "ID" {
		// Identifier
		#; "An identified data element always contains a value from a predefined list of codes"
		#; will need to code table check - don't yet know if it meets criteria
		Set tMatches = 1 ; we don't yet have evidence to the contrary
	} ElseIf pDatatype = "AN" {
		// String
		#; "... must contains at least on non-space character"
		Set tMatches = ($L($TR(pValue," ")) > 0)
	} ElseIf pDatatype = "DT" {
		// Date
		#; YYMMDD or CCYYMMDD
		If $zstrip(pValue,"*N")'="" {
			Set tMatches = 0
		} Else {
			Set tMonth = $E(pValue,*-3,*-2)
			If (tMonth < 1) || (tMonth > 12) {
				Set tMatches = 0
			} ElseIf (($E(pValue,*-1,*) < 1) || ($E(pValue,*-1,*)>$Case(tMonth,2:29,4:30,6:30,9:30,11:30,:31))) {
				Set tMatches = 0
			}
		}
	} ElseIf pDatatype = "TM" {
		// Time
		#; HHMMSSd...d
		If $zstrip(pValue,"*N")'="" {
			Set tMatches = 0
		} ElseIf (($E(pValue,1,2) < 0) || ($E(pValue,1,2) > 23)) {
			Set tMatches = 0
		} ElseIf (($L(pValue) > 2) && ($E(pValue,3,4) < 0) || ($E(pValue,3,4) > 59)) {
			Set tMatches = 0
		} ElseIf (($L(pValue) > 4) && ($E(pValue,5,6) < 0) || ($E(pValue,5,6) > 59)) {
			Set tMatches = 0
		}
	} ElseIf pDatatype = "B" {
	} ElseIf pDatatype ? 1"N".N {
		// Numeric
		#; "A numeric data element is represented by one or more digits with an optional leading sign... The plus sign must not be transmitted"
		Set tMatches = (pValue ? 0.1"-"1.N)
	}
	Quit tMatches
}

}
