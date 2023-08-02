// Based on websockets library by Lasse Steenbock Vestergaard

import java.lang.reflect.Method;
import java.net.URI;
import java.io.IOException;
import java.lang.reflect.Method;
import java.util.concurrent.CountDownLatch;
import org.eclipse.jetty.websocket.client.ClientUpgradeRequest;
import org.eclipse.jetty.websocket.client.WebSocketClient;
import org.eclipse.jetty.websocket.api.Session;
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketConnect;
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketError;
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketMessage;
import org.eclipse.jetty.websocket.api.annotations.WebSocket;
import processing.core.PApplet;


public class WebsocketClient {
  
  private Method webSocketEvent;
  private WebsocketClientEvents socket;
  
  public WebsocketClient(PApplet parent, String endpointURI) {
    parent.registerMethod("dispose", this);
    
    try {
          webSocketEvent = parent.getClass().getMethod("webSocketEvent", String.class);
        } catch (Exception e) { }
    
    WebSocketClient client = new WebSocketClient();   
    try {
      socket = new WebsocketClientEvents(parent, webSocketEvent);
      client.start();
      URI echoUri = new URI(endpointURI);
      ClientUpgradeRequest request = new ClientUpgradeRequest();      
      client.connect(socket, echoUri, request);
      socket.getLatch().await();
    } catch (Throwable t) {
      t.printStackTrace();
    }
  }
  
  public void sendMessage(String message){
    socket.sendMessage(message);
  }
  
  public void dispose(){
    // Anything in here will be called automatically when the parent sketch shuts down.
  }
  
}


@WebSocket
public class WebsocketClientEvents {
  
  private Session session;
  CountDownLatch latch = new CountDownLatch(1);
  private PApplet parent;
  private Method onMessageEvent;
  private int maxMessageSize = 1000000;
  private int maxBufferMessages = 10;
  
  public WebsocketClientEvents(PApplet p, Method event) {
    parent = p;
    onMessageEvent = event;
  }
 
  @OnWebSocketMessage
  public void onText(Session session, String message) throws IOException {
    if (onMessageEvent != null) {
      try {
        onMessageEvent.invoke(parent, message);
      } catch (Exception e) {
        System.err
            .println("Disabling webSocketEvent() because of an error.");
        e.printStackTrace();
        onMessageEvent = null;
      }
    }
  }

  @OnWebSocketConnect
  public void onConnect(Session session) {
    this.session = session;
    //this.session.getPolicy().setMaxBinaryMessageBufferSize(maxMessageSize * maxBufferMessages); 
    //this.session.getPolicy().setMaxBinaryMessageSize(maxMessageSize); 
    //this.session.getPolicy().setMaxTextMessageBufferSize(maxMessageSize * maxBufferMessages); 
    //this.session.getPolicy().setMaxTextMessageSize(maxMessageSize); 
    // ~ ~
    println(this.session.getPolicy().getMaxBinaryMessageBufferSize()); 
    println(this.session.getPolicy().getMaxBinaryMessageSize()); 
    println(this.session.getPolicy().getMaxTextMessageBufferSize()); 
    println(this.session.getPolicy().getMaxTextMessageSize()); 
    latch.countDown();
  }

  public void sendMessage(String str) {
    try {
      session.getRemote().sendString(str);
    } catch (IOException e) {
      e.printStackTrace();
    }
  }

  @OnWebSocketError
  public void onError(Throwable cause) {
    System.out.printf("onError(%s: %s)%n",cause.getClass().getSimpleName(), cause.getMessage());
    cause.printStackTrace(System.out);
  }

  public CountDownLatch getLatch() {
    return latch;
  }
  
}
