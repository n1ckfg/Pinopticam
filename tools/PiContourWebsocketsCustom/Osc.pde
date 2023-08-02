import oscP5.*;
import netP5.*;

PVector dot1 = new PVector(0,0);
PVector dot2 = new PVector(0,0);

String ipNumber = "127.0.0.1";
int sendPort = 9998;
int receivePort = 7110;
int datagramSize = 1000000;
OscP5 oscP5;
NetAddress myRemoteLocation;

void oscSetup() {
  OscProperties op = new OscProperties();
  op.setListeningPort(receivePort);
  op.setDatagramSize(datagramSize);
  oscP5 = new OscP5(this, op);
  myRemoteLocation = new NetAddress(ipNumber, sendPort);
}

// Receive message example
void oscEvent(OscMessage msg) {
  //println(msg);
  if (msg.checkAddrPattern("/contour") && msg.checkTypetag("ssibbi")) {    
    int index = msg.get(2).intValue();
    byte[] readColorBytes = msg.get(3).blobValue();
    byte[] readPointsBytes = msg.get(4).blobValue();

    color c = decodeColorFromBytes(readColorBytes);
 
    ArrayList<PVector> points = decodePointsFromBytes(readPointsBytes);
    
    createStroke(index, c, points);
  }
}
