import oscP5.*;
import netP5.*;
  
OscP5 oscP5;
NetAddress myRemoteLocation, sendTo;
String distance, velocity;
float tempo = 0;
int maxDistance = 780;
int minDistance = 50;

void setup() {
  size(400,400);
  frameRate(25);
  /* start oscP5, listening for incoming messages at port 12000 */
  oscP5 = new OscP5(this,5103);
  distance = "0.5";
  velocity = "0.5";
  
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
  /* send the message */
  if ((millis()-tempo)>1000){
    //distanceGrowth();
    //speedChange();
    OscMessage myMessage = new OscMessage("/distance");
    OscMessage myMessageVelocity = new OscMessage("/speed");    
    myMessage.add(float(distance));
    myMessageVelocity.add(float(velocity));
    print("speed "); println(velocity);
    print("distance "); println(distance);
    //print("distance"); println(distance);
    oscP5.send(myMessage, sendTo); 
    oscP5.send(myMessageVelocity, sendTo);
    tempo = millis();
  };
  if(keyPressed){
    OscMessage myMessage2 = new OscMessage("/start");
    myMessage2.add(1);
    oscP5.send(myMessage2, sendTo); 
  }
}

/* incoming osc message are forwarded to the oscEvent method. */
void oscEvent(OscMessage theOscMessage){
  /* print the address pattern and the typetag of the received OscMessage */
  Object[] received = theOscMessage.arguments();
 
  if(theOscMessage.checkAddrPattern("/speed")==true) {
    velocity = received[0].toString();
  }
  
  if(theOscMessage.checkAddrPattern("/distance")==true) {
    distance = received[0].toString();
  }
  
  if(theOscMessage.checkAddrPattern("/control")==true) {
      OscMessage myMessage2 = new OscMessage("/start");
      myMessage2.add(1);
      oscP5.send(myMessage2, sendTo); 
  }


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

void distanceGrowth(){
  distance = str((float(distance)+0.03)%1);
}

void speedChange(){
  velocity = str((float(velocity)+0.009)%1);
}
