/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

/// This class is designed to demonstrate how to connect to a JMS server by using the Java Gateway.
/// 
/// If this is the first time you are running the test please follow these prerequisite steps:
/// 	<br />
/// 	<br />1) Download and install a JMS server -- in this example ActiveMQ is used.
/// 	<br />
/// 	<br />2) Start the JMS server. For ActiveMQ, navigate to the /bin subdirectory of the installation directory and run "activemq start"
/// 	<br />
///     <br />3) Start the Java Gateway and run the InitializeTest method providing the location of the JMS broker jar. For example, a recently installed version of ActiveMQ could be in: "C:\activemq\activemq-all-5.14.0.jar"
/// 	<br />
///     <br />4) Call "do ##class(EnsLib.JavaGateway.JMSTest).RunTest()" from terminal to run the test, passing the appropriate arguments. If the Java Gateway is running on the local machine at port 5555, and the JMS Server is running on the localmachine at port 61616, run: do ##class(EnsLib.JavaGateway.JMSTest).RunTest("localhost",5555,"tcp://localhost:61616"). The third argument specifies the transport protocol followed by the address where the JMS server can be found.
///     <br />
///     <br />To run an interactive version of the test, open two cache terminals. In one, call "do ##class(EnsLib.JavaGateway.JMSTest).TestProducer("localhost",5555,"tcp://localhost:61616")" and in the other call "do ##class(EnsLib.JavaGateway.JMSTest).TestConsumer("localhost",5555,"tcp://localhost:61616")". The producer's terminal will prompt for messages which should be displayed shortly in the consumer's terminal. Press enter to send. To exit type "QUIT" or "quit".
///     <br />
///     <br />Please look at the specifics of the methods below for more details. In general this example is an adaptation of the "Hello World" example from Apache ActiveMQ. Specifically versions of the HelloWorldProducer and HelloWorldConsumer are implemented in ObjectScript. The original example can be found here: <a href="http://activemq.apache.org/hello-world.html">http://activemq.apache.org/hello-world.html</a>
///     <br />
Class EnsLib.JavaGateway.JMSTest Extends %RegisteredObject
{

ClassMethod InitializeTest(pJMSBrokerJar As %String = "", pGatewayHost As %String = "localhost", pGatewayPort As %String = 5555)
{
	// Alert the Java Gateway to required dependencies
	Set classPath=##class(%ListOfDataTypes).%New()
	Do classPath.Insert(pJMSBrokerJar)	
	
	// These classes represent Java data type used in the example code.
	// They are required for the specific example adapted from the ActiveMQ example and other examples might require additional
	// classes to be imported.
	Do ##class(%Net.Remote.ImportHelper).Import("javax.jms.Connection",classPath,port,host)
	Do ##class(%Net.Remote.ImportHelper).Import("javax.jms.DeliveryMode",classPath,port,host)
	Do ##class(%Net.Remote.ImportHelper).Import("javax.jms.Destination",classPath,port,host)
	Do ##class(%Net.Remote.ImportHelper).Import("javax.jms.ExceptionListener",classPath,port,host)
	Do ##class(%Net.Remote.ImportHelper).Import("javax.jms.JMSException",classPath,port,host)
	Do ##class(%Net.Remote.ImportHelper).Import("javax.jms.Message",classPath,port,host)
	Do ##class(%Net.Remote.ImportHelper).Import("javax.jms.MessageConsumer",classPath,port,host)
	Do ##class(%Net.Remote.ImportHelper).Import("javax.jms.MessageProducer",classPath,port,host)
	Do ##class(%Net.Remote.ImportHelper).Import("javax.jms.Session",classPath,port,host)
	Do ##class(%Net.Remote.ImportHelper).Import("javax.jms.TextMessage",classPath,port,host)
	Do ##class(%Net.Remote.ImportHelper).Import("org.apache.activemq.ActiveMQConnectionFactory",classPath,port,host)
}

ClassMethod RunTest(pGatewayHost As %String = "localhost", pGatewayPort As %String = 5555, pBrokerAddress As %String = "vm://localhost")
{
	Do ..TestProducer(pGatewayHost,pGatewayPort,pBrokerAddress,0)
	Do ..TestConsumer(pGatewayHost,pGatewayPort,pBrokerAddress,0)
}

ClassMethod TestProducer(pGatewayHost As %String = "localhost", pGatewayPort As %String = 5555, pBrokerAddress As %String = "vm://localhost", pInteractive As %Boolean = 1)
{
	Set tGW = ##class(%Net.Remote.Gateway).%New() 
	W tGW.%Connect(pGatewayHost,pGatewayPort,,,,,,0) 
	
	// Instantiate a connection factory, create a session, queue, producer and message and use the producer
	// To send the message
	Set factory = ##class(org.apache.activemq.ActiveMQConnectionFactory).%New(tGW,pBrokerAddress) 
	Set connection = factory.createConnection() 
	Do connection.start() 
	Set session = connection.createSession(0,##class(javax.jms.Session).%GetParameter("AUTOuACKNOWLEDGE")) 
	Set destination = session.createQueue("TEST.FOO") 
	Set producer = session.createProducer(.destination) 
	Do producer.setDeliveryMode(##class(javax.jms.DeliveryMode).%GetParameter("PERSISTENT")) 
	Set text="HELLO CONSUMER!" 
	Set message = session.createTextMessage(text) 
	Do producer.send(message) 
	If (pInteractive) {
			For i=1:1:5 {
			Write !,"Enter message to send >>  "
	    	Read messageText
	        // queues are usually used for PERSISTENT messages
	        Set message = session.createTextMessage(messageText)
	    	Do producer.send(message) 
	    	Quit:((messageText="QUIT")||(messageText="quit"))
			}
	}
	Do session.close() 
	Do connection.close()
}

ClassMethod TestConsumer(pGatewayHost As %String = "localhost", pGatewayPort As %String = 5555, pBrokerAddress As %String = "vm://localhost", pInteractive As %Boolean = 1)
{
	Set tGW = ##class(%Net.Remote.Gateway).%New() 
	W tGW.%Connect(pGatewayHost,pGatewayPort,,,,,,0) 
	
	// Instantiate a connection factory, create a session, queueand consumer and tell the consumer to listen to messages
	Set factory = ##class(org.apache.activemq.ActiveMQConnectionFactory).%New(tGW,pBrokerAddress) 
	Set connection = factory.createConnection() 
	D connection.start() 
	Set session = connection.createSession(0,##class(javax.jms.Session).%GetParameter("AUTOuACKNOWLEDGE")) 
	Set destination = session.createQueue("TEST.FOO") 
	Set consumer = session.createConsumer(destination) 
	
	// receive() parameter is timeout -- 0 means no timeout
	Set message = consumer.receive(0) 
	W !,message.getText(),!! 
	If (pInteractive) {
		Write "Listening for messages...",!
		While (1) {
			Set message=consumer.receive() 
			Set messageText = message.getText()
			Write "Message Text: "_messageText,!,!
			Quit:(messageText="QUIT")||(messageText="quit")
		}
	}
	Do consumer.close() 
	Do session.close() 
	Do connection.close()
}

}
