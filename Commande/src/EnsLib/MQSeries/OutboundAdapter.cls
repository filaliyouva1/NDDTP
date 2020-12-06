/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

/// This adapter is for connecting to IBM WebSphere MQ.
Class EnsLib.MQSeries.OutboundAdapter Extends Ens.OutboundAdapter [ ClassType = "", ProcedureBlock, System = 4 ]
{

/// If you omit this setting, the system uses the default queue manager, as configured in IBM WebSphere MQ. 
/// Or, if IBM WebSphere MQ has been the configured so that the queue manager is determined by the queue name, 
/// the system uses the queue manager that is appropriate for the given queue name. 
Property QueueManager As %String(MAXLEN = 256);

/// The specification for the channel, in the following form: "channel_name/transport/host_name(port)". 
/// Transport can be one of the following: TCP, LU62, NETBIOS, SPX 
/// <p>If you omit this setting, the system uses the default channel specification, as configured in 
/// IBM WebSphere MQ. 
/// Or, if the system has been the configured so that the channel is determined by the queue name, the system
/// uses the channel that is appropriate for the given queue name.
Property Channel As %String(MAXLEN = 256);

/// (Required) Specifies the queue name; this should be a valid queue for the specified queue manager. 
/// Also, you must have permission to use this queue. 
Property QueueName As %String(MAXLEN = 256);

/// Specifies the log file to write error messages to. 
/// <p>If you omit this setting, no logging occurs.
Property ErrorFile As %String(MAXLEN = 1023);

/// This setting specifies the IBM Coded Character Set Id that the messages are already in; no conversion is done based 
/// on this selection
Property CharSet As %Integer;

Parameter SETTINGS = "QueueManager:Basic,Channel:Basic,QueueName:Basic,CharSet,ErrorFile:Dev";

Property %Queue As %Net.MQSend [ Internal ];

/// Temp storage for %PutStream
Property %tempStream As %Stream.FileCharacter;

/// This is set if the queue needs to be initialized again after the job has started.
/// Default is 0 since OnInit() calls initialize and the job will not start if not successful.
Property %initQueueNeeded As %Boolean [ InitialExpression = 0 ];

/// This user callback method is called just after %OnNew()
Method OnInit() As %Status
{
	Set tSC = ..InitQueue()
	If $$$ISERR(tSC) {
		Set ..%initQueueNeeded = 1
		$$$LOGWARNING($$$StatusDisplayString(tSC))
	}
	#; Do not prevent job starting if cannot initialise on connection
	#; If still error initialising when have message to send it will be reported in the event log and available for Alert on Error
	Quit $$$OK
}

/// This user callback method is called before first message is sent and after if reconnect is needed
Method InitQueue() As %Status
{
	Set tSC=$$$OK
	try {
		$$$sysTRACE("InitQueue: Initializing with "_..QueueManager_" on "_..Channel)
		Set:$$$NULLOREF=..%Queue ..%Queue=##class(%Net.MQSend).%New()
		Set tOK=..%Queue.%Init(..QueueName,..QueueManager,..Channel,..ErrorFile)
		If tOK {
			If ..CharSet\1'=..CharSet {
				If ""'=..CharSet { $$$LOGWARNING("Configured CharSet "_..CharSet_" is not an integer value; will use default") }
				Do ..%Queue.%SetCharSet("")
			} Else {
				Do ..%Queue.%SetCharSet(..CharSet)
			}
		} Else {
			Set tError=..%Queue.%GetLastError()
			Set tSC=$$$ERROR($$$EnsErrGeneral,"MQSend %Init("_..QueueName_","_..QueueManager_","_..Channel_","_..ErrorFile_") failed: "_$S(""=tError:"no error text",1:tError))
		}
	} catch {
		Set tSC=$$$SystemError
	}
	Quit tSC
}

/// Sends an MQ Series message.  Note that pBody can be either a simple datatype (string) or a character stream
Method SendMessage(pBody As %String, pMsgId As %String = "") As %Status
{
	Set tSC=$$$OK
	try {
		If ..%initQueueNeeded {
			Set ..%Queue = $$$NULLOREF
			Set tSC = ..InitQueue()
			If $$$ISERR(tSC) Quit	;this will lead to an alert if alert on error is true
			Set ..%initQueueNeeded = 0
		}
		Set tSource=$S($IsObject(pBody)&&pBody.%Extends("%AbstractStream"):$G(pBody.Attributes("Source"),$G(pBody.Attributes("Filename"))),1:"")
		$$$catTRACE("protocol","Sending MQ Series Message with length="_$S($IsObject(pBody):pBody.Size,1:$L(pBody))_" and MsgId='"_pMsgId_"'"_$S(""'=tSource:" from source '"_tSource_"'",1:""))
		Set tOK=..%Queue.%SetMsgId(pMsgId)
		If tOK {
			If '$IsObject(pBody) {
				If $L(pBody)<32768 {
					Set tOK=..%Queue.%Put(pBody)
				} Else {
					Do ..%tempStream.Clear()
					Set tSC=..%tempStream.Write(pBody)  Quit:$$$ISERR(tSC)
					Set tOK=..%Queue.%PutStream(..%tempStream)
					Do ..%tempStream.Clear() ; clean up
				}
			} Else {
				If pBody.%Extends("%Library.FileStreamAdaptor") || pBody.%Extends("%Stream.FileBinary") {
					Set tOK=..%Queue.%PutStream(pBody)
				} ElseIf pBody.%Extends("%IO.I.Stream") {
					Do ..%tempStream.Clear()
					Do pBody.CopyReplaceArray(..%tempStream,,,,,,,,.tSC)  Quit:$$$ISERR(tSC)
					Set tOK=..%Queue.%PutStream(..%tempStream)
					Do ..%tempStream.Clear() ; clean up
				} Else {
					Do ..%tempStream.Clear()
					Set tSC=..%tempStream.CopyFrom(pBody)  Quit:$$$ISERR(tSC)
					Set tOK=..%Queue.%PutStream(..%tempStream)
					Do ..%tempStream.Clear() ; clean up
				}
			}
		}
		If 'tOK {
			Set tError=..%Queue.%GetLastError()
			Set tSC=$$$ERROR($$$EnsErrGeneral,"MQSend %Put(length "_$L(pBody)_") failed: "_$S(""=tError:"no error text",1:tError))
		}
	} catch {
		Set tSC=$$$SystemError
	}
	If $$$ISERR(tSC) {
		Set ..%initQueueNeeded = 1
		Set ..BusinessHost.Retry = 1
	}
	Quit tSC
}

/// This user callback method is called just before %OnClose()
Method OnTearDown() As %Status
{
	If ..%Queue'=$$$NULLOREF {
		$$$sysTRACE("Shutting down MQ "_..QueueName_" connection to "_..QueueManager_" on "_..Channel)
		Set ..%Queue=$$$NULLOREF
	}
	Quit $$$OK
}

}
