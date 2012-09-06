/**
 * oscP5sendreceive by andreas schlegel
 * example shows how to send and receive osc messages.
 * oscP5 website at http://www.sojamo.de/oscP5
 */
 
import oscP5.*;
import netP5.*;
  
OscP5 oscP5;
NetAddress myRemoteLocation, sendTo;
String distance;
float tempo = 0;
int maxDistance = 400;
int minDistance = 50;

void setup() {
  size(400,400);
  frameRate(25);
  /* start oscP5, listening for incoming messages at port 12000 */
  oscP5 = new OscP5(this,5103);
  distance = "1000";
  
  /* myRemoteLocation is a NetAddress. a NetAddress takes 2 parameters,
   * an ip address and a port number. myRemoteLocation is used as parameter in
   * oscP5.send() when sending osc packets to another computer, device, 
   * application. usage see below. for testing purposes the listening port
   * and the port of the remote location address are the same, hence you will
   * send messages back to this sketch.
   */
  myRemoteLocation = new NetAddress("0.0.0.0",5103);
  sendTo = new NetAddress("127.0.0.1",57120);
}


void draw() {
  background(0);
  
  /* in the following different ways of creating osc messages are shown by example */
  OscMessage myMessage = new OscMessage("/distance"); 
  myMessage.add(mapDistance(distance));
  /* send the message */
  if ((millis()-tempo)>1000){
    oscP5.send(myMessage, sendTo); 
    tempo = millis();
  }; 
}

/* incoming osc message are forwarded to the oscEvent method. */
void oscEvent(OscMessage theOscMessage){
  /* print the address pattern and the typetag of the received OscMessage */
  Object[] received = theOscMessage.arguments();
  distance = received[0].toString();
  // println(distance);
//  print("### received an osc message.");
//  print(" addrpattern: "+theOscMessage.addrPattern());
//  println(" typetag: "+theOscMessage.typetag());
}

float mapDistance(String distance){
  float fDistance = float(distance);
  // mapping ...
  fDistance = (((fDistance*(-1))+minDistance)/(maxDistance-minDistance))+1;
  if (fDistance>1){fDistance=1;}
  else if(fDistance<0) {fDistance=0;};
  println(fDistance);
  return fDistance;
}
