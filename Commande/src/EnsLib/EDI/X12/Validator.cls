/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

Include EnsEDIX12

/// Error processor, more error defs, index not in errors, 
/// This is the X12 Interchange parser
Class EnsLib.EDI.X12.Validator Extends EnsLib.EDI.X12.Scanner [ ClassType = "", ProcedureBlock, System = 4 ]
{

Parameter AllowedPunct As String = "!""&'()*+,-./:;?= %~@[]_{}\|<>^`#$";

ClassMethod IsValidSeparator(pChar As %String) [ CodeMode = expression ]
{
..#AllowedPunct[pChar||($A(pChar)<32)
}

/// This holds the base character set
Parameter AllowedChars As String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzÀÁÂÄàáâäÈÉÊèéêëÌÍÎìíîïÒÓÔÖòóôöÙÚÛÜùúûüÇçÑñ";

ClassMethod IsValidChar(pChar As %String) [ CodeMode = expression ]
{
..#AllowedChars_..#AllowedPunct_$Char(9,10,13)[pChar
}

ClassMethod GetTA1Code(pSC As %Status) As %String
{
	Quit:$$$ISERR(pSC) "999"
	Quit "000"
}

ClassMethod Get997GroupCodes(pSC As %Status) As %String
{
	#dim tCode = ""
	#; If no error or error is not at the functional group level, no error code should be sent
	If $$$ISERR(pSC) && '$System.Status.Equals(pSC,$$$EnsEDIX12AllChildrenFailedValidation,$$$EnsEDIX12ChildFailedValidation) {
		#; to-do assign proper error code values
		Set tCode = "999"
	}
	Quit tCode
}

ClassMethod Get997Codes(pSC As %Status) As %String
{
	Quit:$$$ISERR(pSC) "999"
	Quit "000"
}

ClassMethod Validate(pDoc As EnsLib.EDI.X12.Document, pValSpec As %String) As %Status
{
	Quit:pValSpec["1" pDoc.BuildMap()
	Quit $$$OK
}

/*
from: 08/26/02 15 A White Paper Describing the Recommended Solutions
 For Compliance Testing and Certification of the HIPAA transactions
Version 3.0

Recommended Types of Testing:

Type 1: EDI syntax integrity testing - Testing of the EDI file for valid segments,
segment order, element attributes, testing for numeric values in numeric data elements,
validation of X12 or NCPDP syntax, and compliance with X12 and NCPDP rules. This
will validate the basic syntactical integrity of the EDI submission.

Type 2: HIPAA syntactical requirement testing - Testing for HIPAA Implementation
Guide-specific syntax requirements, such as limits on repeat counts, used and not
used qualifiers, codes, elements and segments. Also included in this type is testing for
HIPAA required or intra-segment situational data elements, testing for non-medical
code sets as laid out in the Implementation Guide, and values and codes noted in the
Implementation Guide via an X12 code list or table.

Type 3: Balancing - Testing the transaction for balanced field totals, financial
balancing of claims or remittance advice, and balancing of summary fields, if
appropriate. An example of this includes items such as all claim line item amounts
equal the total claim amount. (See pages 19-22, Healthcare Claim Payment/Advice -
835 Implementation Guide for balancing requirements of the 835 transaction.)

Type 4: Situation testing - The testing of specific inter-segment situations described
in the HIPAA Implementation Guides, such that: If A occurs then B must be populated.
This is considered to include the validation of situational fields given values or situations
present elsewhere in the file. Example: if the claim is for an accident, the accident date
must be present.

Type 5: External code set testing - Testing for valid Implementation Guide-specific
code set values and other code sets adopted as HIPAA standards. This level of testing
will not only validate the code sets but also make sure the usage is appropriate for any
particular transaction and appropriate with the coding guidelines that apply to the
specific code set. Validates external code sets and tables such as CPT, ICD9, CDT,
NDC, status codes, adjustment reason codes, and their appropriate use for the
transaction.

Type 6: Product types or line of services: This testing type is required to ensure that
the segments/records of data that differ based on certain healthcare services are
properly created and processed into claims data formats. These specific requirements
are described in the Implementation Guides for the different product types or lines of
service. For example, ambulance, chiropractic, podiatry, home health, parenteral and
enteral nutrition, durable medical equipment, psychiatry, and other specialized services
have specific requirements in the Implementation Guide that must be tested before
putting the transaction in production. This type of testing only applies to a trading
partner candidate that conducts transactions for the specific line of business or product
type.

Type 7: Implementation Guide-Specific Trading Partners: The Implementation
Guides contain some HIPAA requirements that are specific to Medicare, Medicaid, and
Indian Health. Compliance or testing with these payer specific requirements is not
required from all trading partners. If the trading partner candidate intends to exchange
transactions with one of these Implementation Guide special payers, this type of testing
is required. When a certification service certifies a trading partner for compliance, the
certification service must indicate whether these payer specific requirements were met
during the certification process. Other payers and trading partners may have their own
specific business requirements; but, unless they are listed in the HIPAA Implementation
Guides, they are not HIPAA requirements. These non-HIPAA trading partner specific
requirements must be tested as part of the business-to-business testing.

*/
}
