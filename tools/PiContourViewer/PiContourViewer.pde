import peasy.PeasyCam;

PeasyCam cam;

float dotSize = 20;
ArrayList<Stroke> strokesBuffer;
boolean clicked = false;
boolean isDrawing = false;
int fps = 60;
int markTime = 0;
Frame frame;

void setup() {
  size(640, 480, P3D);
  frameRate(60);
  cam =  new PeasyCam(this, width/2, height/2, 400, 50);
  strokesBuffer = new ArrayList<Stroke>();
  frame = new Frame(strokesBuffer);
  //oscSetup();
  wsSetup();
  fps = int((1.0/float(fps)) * 1000);
}

void draw() {
  background(0);
  
  int time = millis();
  if (time > markTime + fps) {
    markTime = time;
    frame = new Frame(strokesBuffer);
    //strokesBuffer = new ArrayList<Stroke>();
  }
  
  frame.draw();
  
  surface.setTitle("" + frameRate);
}

void createStroke(int index, color c, ArrayList<PVector> points) {
  Stroke newStroke = new Stroke(index, c, points);

  boolean doReplace = false;
  int replaceIndex = 0;
  
  for (int i=0; i<strokesBuffer.size(); i++) {
    Stroke s = strokesBuffer.get(i);
    if (s.index == index) {
      replaceIndex = i;
      doReplace = true;
      break;
    }
  }
      
  if (doReplace) {
    strokesBuffer.set(replaceIndex, newStroke);
  } else {
    strokesBuffer.add(newStroke);
  }

  int time = millis();
  for (int i=0; i<strokesBuffer.size(); i++) {
    Stroke s = strokesBuffer.get(i);
    if (time > s.timestamp + s.lifespan) {
      strokesBuffer.remove(i);
    }
  }
}
