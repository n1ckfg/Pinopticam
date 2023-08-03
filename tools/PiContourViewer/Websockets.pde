import websockets.*;

WebsocketClient wsc;
int maxSize = 1024;

void wsSetup(){ 
  try {
    wsc = new WebsocketClient(this, "ws://nfg-rpi-4-2.local:7112");
} catch (Exception e) {
    println("Failed to connect to websocket server.");
  }
}

void webSocketEvent(String msg){
  //msg = msg.replace("\n","").replace("\r","");
  try {
    JSONObject json = parseJSONObject(msg);
    int index = json.getInt("index");
    color c = decodeColorFromBase64(json.getString("colors"));
    ArrayList<PVector> points = decodePointsFromBase64(json.getString("points"));
    createStroke(index, c, points);
  } catch (Exception e) { 
    println("Could not decode message.");
  }
}
