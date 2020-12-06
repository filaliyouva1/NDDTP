/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

Include Ensemble

/// Data synchronization.<br>
Class Ens.Activity.Utils Extends %RegisteredObject [ System = 4 ]
{

/// tLocalTime, tUTC, tInstance, tNamespace, tHostType, tHostName, tUserDimension, tCount, tDuration, tQueueduration, tSquares
ClassMethod AddActivity(pTimeSlot As %String, pTimeSlotUTC As %String, pInstance As %String, pNamespaceJob As %String, pHostType As %String, pHostName As %String, pSiteDimension As %String, pCount As %String, pDuration As %String, pQueueDuration As %String, pDurationSquare As %String) As %Status [ Internal ]
{
	
	#dim tSC As %Status = $$$OK
	#dim e As %Exception.AbstractException
	#dim tCurrentJournal As %Integer = 0
	
	#dim tNamespace As %String
	
	#dim tTargetTimeSlotUTC, tTargetTimeSlot As %String
	
	#dim tCurCount, tCurDuration, tCurQueueDuration, tCurSquares As %Numeric
	#dim tID As %String
	
	#dim tLocked As %Integer
	
	
	Try {
			
		Set tNamespace = $P(pNamespaceJob,"~",1)
		
		Set tTargetTimeSlotUTC = pTimeSlotUTC
		Set tTargetTimeSlot = pTimeSlot
		
		Set tLocked = 0 
		If pSiteDimension = "" Set pSiteDimension = "-"
		Lock +^Ens.Activity.Data.Control(pInstance,pSiteDimension,tNamespace,pHostName):$SYSTEM.SQL.GetLockTimeout()
		If '$T {
			Set tSC = $$$ERROR($$$GeneralError,"Failed to get lock. Please retry")
			Quit
		} Else {
			Set tLocked = 1	
		}
		TStart
		
		&sql( SELECT ID, TotalCount, TotalDuration, TotalQueueDuration, TotalDurationSquare INTO :tID, :tCurCount, :tCurDuration, :tCurQueueDuration, :tCurSquares
		FROM Ens_Activity_Data.Seconds 
		WHERE TimeSlotUTC=:tTargetTimeSlotUTC AND Instance=:pInstance AND SiteDimension=:pSiteDimension AND Namespace=:tNamespace AND HostName=:pHostName
		)		
		If SQLCODE=0 {
			Set tCurCount = tCurCount + pCount
			Set tCurDuration = tCurDuration + pDuration
			Set tCurQueueDuration = tCurQueueDuration + pQueueDuration
			Set tCurSquares = tCurSquares + pDurationSquare
			&sql( UPDATE Ens_Activity_Data.Seconds (TotalCount, TotalDuration, TotalQueueDuration, TotalDurationSquare) 
			VALUES (:tCurCount, :tCurDuration, :tCurQueueDuration, :tCurSquares)  
			WHERE TimeSlotUTC=:tTargetTimeSlotUTC AND Instance=:pInstance AND SiteDimension=:pSiteDimension AND Namespace=:tNamespace AND HostName=:pHostName
			)
		} Else {
			&sql( INSERT INTO Ens_Activity_Data.Seconds (Instance, Namespace, SiteDimension, HostType, HostName, TimeSlot, TimeSlotUTC, TotalCount, TotalDuration, TotalQueueDuration, TotalDurationSquare) 
			VALUES (:pInstance, :tNamespace, :pSiteDimension, :pHostType, :pHostName, :tTargetTimeSlot, :tTargetTimeSlotUTC, :pCount, :pDuration, :pQueueDuration, :pDurationSquare)
			)
		}
		If SQLCODE {
			Set tSC = $$$ERROR($$$GeneralError,"SQLCODE="_SQLCODE)
			Quit
		}
		
		Set tTargetTimeSlotUTC = ..RoundTimeBack("hh",pTimeSlotUTC)
		Set tTargetTimeSlot = ..RoundTimeBack("hh",pTimeSlot)		

		&sql( SELECT ID, TotalCount, TotalDuration, TotalQueueDuration, TotalDurationSquare INTO :tID, :tCurCount, :tCurDuration, :tCurQueueDuration, :tCurSquares
		FROM Ens_Activity_Data.Hours 
		WHERE TimeSlotUTC=:tTargetTimeSlotUTC AND Instance=:pInstance AND SiteDimension=:pSiteDimension AND Namespace=:tNamespace AND HostName=:pHostName
		)		
		If SQLCODE=0 {
			Set tCurCount = tCurCount + pCount
			Set tCurDuration = tCurDuration + pDuration
			Set tCurQueueDuration = tCurQueueDuration + pQueueDuration
			Set tCurSquares = tCurSquares + pDurationSquare
			&sql( UPDATE Ens_Activity_Data.Hours (TotalCount, TotalDuration, TotalQueueDuration, TotalDurationSquare) 
			VALUES (:tCurCount, :tCurDuration, :tCurQueueDuration, :tCurSquares)  
			WHERE TimeSlotUTC=:tTargetTimeSlotUTC AND Instance=:pInstance AND SiteDimension=:pSiteDimension AND Namespace=:tNamespace AND HostName=:pHostName
			)
		} Else {
			&sql( INSERT INTO Ens_Activity_Data.Hours (Instance, Namespace, SiteDimension, HostType, HostName, TimeSlot, TimeSlotUTC, TotalCount, TotalDuration, TotalQueueDuration, TotalDurationSquare) 
			VALUES (:pInstance, :tNamespace, :pSiteDimension, :pHostType, :pHostName, :tTargetTimeSlot, :tTargetTimeSlotUTC, :pCount, :pDuration, :pQueueDuration, :pDurationSquare)
			)
		}
		If SQLCODE {
			Set tSC = $$$ERROR($$$GeneralError,"SQLCODE="_SQLCODE)
			Quit
		}

		Set tTargetTimeSlotUTC = ..RoundTimeBack("d",pTimeSlotUTC)
		Set tTargetTimeSlot = ..RoundTimeBack("d",pTimeSlot)		

		&sql( SELECT ID, TotalCount, TotalDuration, TotalQueueDuration, TotalDurationSquare INTO :tID, :tCurCount, :tCurDuration, :tCurQueueDuration, :tCurSquares
		FROM Ens_Activity_Data.Days 
		WHERE TimeSlotUTC=:tTargetTimeSlotUTC AND Instance=:pInstance AND SiteDimension=:pSiteDimension AND Namespace=:tNamespace AND HostName=:pHostName
		)		
		If SQLCODE=0 {
			Set tCurCount = tCurCount + pCount
			Set tCurDuration = tCurDuration + pDuration
			Set tCurQueueDuration = tCurQueueDuration + pQueueDuration
			Set tCurSquares = tCurSquares + pDurationSquare
			&sql( UPDATE Ens_Activity_Data.Days (TotalCount, TotalDuration, TotalQueueDuration, TotalDurationSquare) 
			VALUES (:tCurCount, :tCurDuration, :tCurQueueDuration, :tCurSquares)  
			WHERE TimeSlotUTC=:tTargetTimeSlotUTC AND Instance=:pInstance AND SiteDimension=:pSiteDimension AND Namespace=:tNamespace AND HostName=:pHostName
			)
		} Else {
			&sql( INSERT INTO Ens_Activity_Data.Days (Instance, Namespace, SiteDimension, HostType, HostName, TimeSlot, TimeSlotUTC, TotalCount, TotalDuration, TotalQueueDuration, TotalDurationSquare) 
			VALUES (:pInstance, :tNamespace, :pSiteDimension, :pHostType, :pHostName, :tTargetTimeSlot, :tTargetTimeSlotUTC, :pCount, :pDuration, :pQueueDuration, :pDurationSquare)
			)
		}
		If SQLCODE {
			Set tSC = $$$ERROR($$$GeneralError,"SQLCODE="_SQLCODE)
			Quit
		}

	} Catch e {
		Set tSC = e.AsStatus()
	}
	If tLocked {
		Try {
			Lock -^Ens.Activity.Data.Control(pInstance,pSiteDimension,tNamespace,pHostName)
			Set tLocked = 0
			If $$$ISERR(tSC) {
				TRollback
			} Else {
				TCommit
			}
		} Catch e {
			Set tSC = $$$ADDSC(tSC,e.AsStatus())
		}
	}
	Quit tSC
}

ClassMethod AddActivityList(pActivityList As %String = "") As %Status [ Internal ]
{
	#dim tSC As %Status = $$$OK
	#dim e As %Exception.AbstractException
	
	Try {
		Set tData = pActivityList
		Set tStatsCategory = $LG(tData,1)
		If tStatsCategory '= "SC" {
			Set tSC = $$$ERROR($$$NotImplemented)
			Quit
		}
		Set tDays = $LG(tData,2)
		Set tSeconds = $LG(tData,3)
		Set tLocalTime = $LG(tData,4)
		Set tUTC = $LG(tData,5)
		Set tInstance = $LG(tData,6)
		Set tNamespace = $LG(tData,7)
		Set tHostType = $LG(tData,8)
		Set tHostName = $LG(tData,9)
		Set tUserDimension = $LG(tData,10)
		Set tCount = $LG(tData,11)
		Set tDuration = $LG(tData,12)
		Set tQueueduration = $LG(tData,13)
		Set tSquares = $LG(tData,14)
		Set tSC = ##class(Ens.Activity.Utils).AddActivity(tLocalTime, tUTC, tInstance, tNamespace, tHostType, tHostName, tUserDimension, tCount, tDuration, tQueueduration, tSquares)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod RoundTimeBack(pPeriod As %String, pTime As %String) As %String [ Internal ]
{
	Quit $CASE(pPeriod,
		"yy":$P(pTime,"-")_"-01-01",	;Rounded to Jan 1st
		"mm":$P(pTime,"-",1,2)_"-01", 	;Rounded to 1st of the month
		"d" :$P(pTime," ")_" 00:00:00",	;Rounded to midnight (day start)
		"hh":$P(pTime,":")_":00:00",	;Rounded to hour start
		"mi":$P(pTime,":",1,2)_":00",	;Rounded to minute start
		:pTime							;Stay the same
		)
}

ClassMethod Purge(pPeriodToKeep As %String = "", pClassScale As %String = "", Output pCount As %Integer) As %Status
{
	#dim tSC As %Status = $$$OK
	#dim e As %Exception.AbstractException

	#dim tNowUTC = $ZDATETIME($ZTIMESTAMP,3)		
	#dim tPeriod As %String
	#dim tAmount As %Integer
	#dim tCutOffDate As %String
	
	#dim tStatement As %SQL.Statement
	#dim tResult As %String

	#dim tClass As %String = ""
	
	#dim tCurrentJournal As %Integer = 0
	If $$CURRENT^%SYS.NOJRN() {
		Set tCurrentJournal = 1
		Do DISABLE^%SYS.NOJRN		
	}

	Try {
		Set pCount = 0
		Set tAmount = +pPeriodToKeep
		If tAmount = 0 && (pPeriodToKeep'=pPeriodToKeep) {Set tSC = $$$ERROR($$$GeneralError,"Invalid period to keep")  Quit}
		Set tDateAddScale = $P(pPeriodToKeep,tAmount,2)
		If tDateAddScale = "" Set tDateAddScale = "D" 
		Set tPeriod = pClassScale
		If tPeriod = "" Set tPeriod = tDateAddScale
		Set tPeriod = $ZCVT(tPeriod,"L")
		Set tClass = $Case(tPeriod,"s":"Seconds","hh":"Hours","d":"Days")
		Set tCutOffDate = $SYSTEM.SQL.DATEADD(tDateAddScale,-tAmount,tNowUTC)
		Set tStatement = ##class(%SQL.Statement).%New()
		Set tSC = tStatement.%Prepare("SELECT ID FROM Ens_Activity_Data."_tClass_" WHERE TimeSlotUTC <= ?")
		Set tResult = tStatement.%Execute(tCutOffDate)
		While tResult.%Next() {
			Do $CLASSMETHOD("Ens.Activity.Data."_tClass,"%DeleteId",tResult.ID)
			Set pCount = pCount +1
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If tCurrentJournal Do ENABLE^%SYS.NOJRN
	Quit tSC
}

ClassMethod getFromTempGlobal() As %String [ Internal, Private ]
{
		Try {
			// Sample data:
			// $$$StatsPersistCountersRoot("DEVBUS~2336",63334,6704,1,"RESTaCSP3","enterpriseid 525","count") = 20
			// $$$StatsPersistCountersRoot("DEVBUS~2336",63334,6704,1,"RESTaCSP3","enterpriseid 525","duration") = .225824
			// $$$StatsPersistCountersRoot("DEVBUS~2336",63334,6704,1,"RESTaCSP3","enterpriseid 525","queue") = .5
			// $$$StatsPersistCountersRoot("DEVBUS~2336",63334,6704,1,"RESTaCSP3","enterpriseid 525","d2") = .0144
			Set tBatch = 0
			Set tInstance = ##class(%SYS.System).GetUniqueInstanceName()
			Set tStatsInterval = ##class(Ens.Util.Statistics).StatsCounterInterval()
			Set tNamespace = $O($$$StatsPersistCountersRoot(""))
			While (tNamespace'="") {
				Set tDay = ""
				Set tTimeStampDay = $ZTS
				Set tTimeStampSeconds = $P(tTimeStampDay,",",2)\tStatsInterval*tStatsInterval // Current tSeconds slot
				Set tTimeStampDay = +tTimeStampDay
				
				If tBatch Set tBatchStream = ##class(%Stream.TmpBinary).%New()
				For {
					Set tDay = $O($$$StatsPersistCountersRoot(tNamespace,tDay))
					If (tDay="") Quit
					Set tSecondsSlot = ""
					For {
						Set tSecondsSlot = $O($$$StatsPersistCountersRoot(tNamespace,tDay,tSecondsSlot))
						If tSecondsSlot="" Quit
						If (tDay<tTimeStampDay) || ((tDay=tTimeStampDay) && ($P(tSecondsSlot,",",2)<tTimeStampSeconds)) {
							// Time slot is in the past
							Set tHostType = ""
							For {
								Set tHostType = $O($$$StatsPersistCountersRoot(tNamespace,tDay,tSecondsSlot,tHostType))
								If tHostType="" Quit
								Set tHostName = ""
								For {	
									Set tHostName = $O($$$StatsPersistCountersRoot(tNamespace,tDay,tSecondsSlot,tHostType,tHostName))
									If tHostName="" Quit
									Set tUserDimension = ""
									For {
										Set tUserDimension = $O($$$StatsPersistCountersRoot(tNamespace,tDay,tSecondsSlot,tHostType,tHostName,tUserDimension))
										If tUserDimension="" Quit
										Set tCount = $G($$$StatsPersistCountersRoot(tNamespace,tDay,tSecondsSlot,tHostType,tHostName,tUserDimension,"count"),0)
										Set tDuration = $G($$$StatsPersistCountersRoot(tNamespace,tDay,tSecondsSlot,tHostType,tHostName,tUserDimension,"duration"),0)
										Set tQueueDuration = $G($$$StatsPersistCountersRoot(tNamespace,tDay,tSecondsSlot,tHostType,tHostName,tUserDimension,"queue"),0)
										Set tSquares = $G($$$StatsPersistCountersRoot(tNamespace,tDay,tSecondsSlot,tHostType,tHostName,tUserDimension,"d2"),0)
										Set tSeconds = (tSecondsSlot*tStatsInterval)
										Set tUTC = $ZDT(tDay_","_tSeconds,3)
										Set tLocalTime = $$$timeUTCtoLocal(tUTC)
										#;"SC" = stats counters
										If tBatch {
											Do tBatchStream.Write($S(tBatchStream.Size = 0:"[",1:","))
											Do tBatchStream.Write("{""A"":"""_"SC"_""",""B"":"""_tDay_""",""C"":"""_tSecondsSlot_
																	""",""D"":"""_tLocalTime_""",""E"":"""_tUTC_""",""F"":"""_tInstance_
																	""",""G"":"""_tNamespace_""",""H"":"""_tHostType_""",""I"":"""_tHostName_
																	""",""J"":"""_tUserDimension_""",""K"":"""_tCount_""",""L"":"""_tDuration_
																	""",""M"":"""_tQueueDuration_""",""N"":"""_tSquares_""",""O"":"""_tHostName_
																	""",""P"":"""_tUserDimension_""",""Q"":"""_tCount_""",""R"":"""_tDuration_
																	""",""S"":"""_tQueueDuration_""",""T"":"""_ tSquares)
											Do tBatchStream.Write("}")
										} Else {
											/*
											Set tSC = ..OnAddActivity("SC",tDay,tSecondsSlot,tLocalTime, tUTC, ..%Instance, tNamespace, tHostType, tHostName, tUserDimension, tCount, tDuration, tQueueDuration, tSquares)
											If tSC {
												Kill $$$StatsPersistCountersRoot(tNamespace,tDay,tSecondsSlot,tHostType,tHostName,tUserDimension) // Not using a lock here to avoid slowing things down, it is unlikely to need a lock as only sending data in past tSeconds slot
											} Else {
												Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
											}
											*/
										}
									} // End loop on tUserDimension
								} // End loop on tHostName
							} // End loop on tHostType
						} // End if
					} // End loop on tSecondsSlot
				} // End loop on tDay
				Set tNamespace = $O($$$StatsPersistCountersRoot(tNamespace))
			} // End while tNamespace
			If tBatch,(tBatchStream.Size>0) {
				Do tBatchStream.Write("]")
				Do tBatchStream.Rewind()
				;Set tSC = ..OnAddBatchActivity(tBatchStream)
			}
		} Catch e {
			Set tSC = e.AsStatus()
		}
}

}
