/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

/// This adapter is for connecting to IBM WebSphere MQ.
Class EnsLib.MQSeries.InboundAdapter Extends Ens.InboundAdapter [ ClassType = "", ProcedureBlock, System = 4 ]
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

/// This setting specifies the IBM Coded Character Set Id. If you do not specify a value, the MQ system assumes the messages use the default character set 
/// specified for the MQ client.
Property CharSet As %Integer;

Parameter SETTINGS = "QueueManager:Basic,Channel:Basic,QueueName:Basic,CharSet,ErrorFile:Dev";

/// In your Service's OnInit() method, set this property to the name of a class you would like to receive as the Stream property of the pInput Message argument to your OnProcessInput method.
/// If this value is empty or begins with a * character then the Body string property will be used unless the input is too long for the system maximum string size.
/// If this value is empty or *, the class "%Stream.GlobalCharacter" will be used if the input is too long.
Property ContentStreamClassname As %String [ InitialExpression = "*%Stream.GlobalCharacter" ];

/// The live Queue object
Property %Queue As %Net.MQRecv [ Internal ];

/// Temp storage for %GetStream
Property %tempStream As %Stream.FileCharacter [ Internal ];

/// This is set if the queue needs to be initialized again after the job has started.
/// Default is 0 since OnInit() calls initialize and the job will not start if not successful.
Property %initQueueNeeded As %Boolean [ InitialExpression = 0 ];

/// This user callback method is called just after %OnNew()
Method OnInit() As %Status
{
	Set tSC = ..InitQueue()
	If $$$ISERR(tSC) Set ..%initQueueNeeded = 1
	#; Do not prevent job starting if cannot initialise on connection. 
	#; If still error initialising in first poll it will be reported in the event log and available for Alert on Error
	Quit $$$OK
}

/// This user callback method is called for the first poll and after if there is an error.
Method InitQueue() As %Status
{
	Set tSC=$$$OK
	try {
		$$$sysTRACE("InitQueue Initializing with "_..QueueManager_" on "_..Channel)
		Set:$$$NULLOREF=..%Queue ..%Queue=##class(%Net.MQRecv).%New()
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
			Set tSC=$$$ERROR($$$EnsErrGeneral,"MQRecv %Init("_..QueueName_","_..QueueManager_","_..Channel_","_..ErrorFile_") failed: "_$S(""=tError:"no error text",1:tError))
		}
	} catch {
		Set tSC=$$$SystemError
	}
	Quit tSC
}

/// default InboundAdapter behavior: always call ProcessInput on CallInterval
Method OnTask() As %Status
{
	Set tSC=$$$OK, (tMsg,tStream)=$$$NULLOREF, tQId="", tUseStream=0
	try {
		If ..%initQueueNeeded {
			Set ..%Queue = $$$NULLOREF
			Set tSC = ..InitQueue()
			If $$$ISERR(tSC) Quit	;this will lead to an alert if alert on error is true
			Set ..%initQueueNeeded = 0
			$$$SetHostMonitor(..BusinessHost.%ConfigName,$$$eMonitorStatus,"OK")
		}
		$$$catTRACE("ontask","Checking for MQ Series input with timeout "_..CallInterval)
		Set tMsg=##class(EnsLib.MQSeries.Message).%New()
		Set tChar1=$E(..ContentStreamClassname), tUseStream=$Case(tChar1,"*":0,"":0,:1)
		Set tStreamClass=$S(tUseStream:..ContentStreamClassname, 1:$E(..ContentStreamClassname,2,*))
		Set:""=tStreamClass tStreamClass="%Stream.FileCharacter"
		// NOTE: Timeout is in milliseconds
		If tUseStream && ($classmethod(tStreamClass,"%Extends","%Library.FileStreamAdaptor") || $classmethod(tStreamClass,"%Extends","%Stream.FileBinary")) {
			Set tStream=$classmethod(tStreamClass,"%New")
			Set tSC=tStream.Write("")  Quit:$$$ISERR(tSC) ; force filename
			Set tOK=..%Queue.%GetStream(tStream,..CallInterval*1000)
			$$$catTRACE("protocol","GetStream A tOK:" _ tOK)
			Set:tOK tSC=tStream.Rewind()  Quit:$$$ISERR(tSC)
		} Else { ; don't use a stream unless the message is too big
			Do ..%tempStream.Clear()
			Set tSC=..%tempStream.Write("")  Quit:$$$ISERR(tSC) ; force filename
			Set tOK=..%Queue.%GetStream(..%tempStream, ..CallInterval*1000)
			$$$catTRACE("protocol","GetStream B tOK:" _ tOK)
			Set:tOK tSC=..%tempStream.Rewind()  Quit:$$$ISERR(tSC)
			If tOK && (tUseStream || (..%tempStream.Size > $$$MaxLocalLength)) {
				Set tStream=$classmethod(tStreamClass,"%New"), tUseStream=1
				If tStream.%Extends("%IO.I.Stream") {
					Do tStream.CopyFrom(..%tempStream,,,.tSC)  Quit:$$$ISERR(tSC)
				} Else {
					Set tSC=tStream.CopyFrom(..%tempStream)  Quit:$$$ISERR(tSC)
				}
			} Else {
				Set:tOK tContent=..%tempStream.Read($$$MaxLocalLength,.tSC)  Quit:$$$ISERR(tSC)
			}
			Do ..%tempStream.Clear() ; clean up
		}
		If tOK {
			Set tOK=..%Queue.%MsgId(.tQId) 
			$$$catTRACE("protocol","MsgId tOK:" _ tOK)
		}
		If tOK {
			Set tMsg.MessageId=tQId, tMsg.Source=..QueueManager_":"_..Channel_":"_..QueueName_":"_tQId
			If tUseStream {
				Set tMsg.Body=""
				Set tMsg.BodyStream=tStream
				Set:tStream.%Extends("%AbstractStream") tStream.Attributes("Source")=tMsg.Source
			} Else {
				Set tMsg.Body=tContent
				Set tMsg.BodyStream=$$$NULLOREF
			}
			$$$catTRACE("protocol","Received MQ Series message with ID '"_tQId_"' and length "_tMsg.BodySize)
			Set tSC=..BusinessHost.ProcessInput(tMsg)
		} Else {
			Set tError=..%Queue.%GetLastError()
			#; Error 2033 means "no message available to receive from queue"
			If (+tError'=2033),(tError'=0),$L(tError) {
				Set tSC=$$$ERROR($$$EnsErrGeneral,"MQRecv %GetStream() or %MsgId() failed: "_$S(""=tError:"no error text",1:tError))
			}
		}
	} catch {
		Set tSC=$$$SystemError
	}
	If $$$ISERR(tSC) {
		Set ..BusinessHost.%WaitForNextCallInterval=1	; prevent runaway spin on error
		Set ..%initQueueNeeded = 1 						; reconnect next poll
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
