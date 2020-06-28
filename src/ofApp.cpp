#include "ofApp.h"

//--------------------------------------------------------------
void ofApp::setup() {
    settings.loadFile("settings.xml");

    ofSetVerticalSync(false);
    ofHideCursor();

    framerate = settings.getValue("settings:framerate", 60);
    width = settings.getValue("settings:width", 640);
    height = settings.getValue("settings:height", 480);
    ofSetFrameRate(framerate);

    host = settings.getValue("settings:host", "127.0.0.1");
    postPort = settings.getValue("settings:post_port", 7110);
    streamPort = settings.getValue("settings:stream_port", 7111);
    wsPort = settings.getValue("settings:ws_port", 7112);

    debug = (bool) settings.getValue("settings:debug", 1);
    rpiCamVersion = settings.getValue("settings:rpi_cam_version", 1);
    stillCompression = settings.getValue("settings:still_compression", 100);

    // ~ ~ ~   get a persistent name for this computer   ~ ~ ~
    compname = "RPi";
    file.open(ofToDataPath("compname.txt"), ofFile::ReadWrite, false);
    ofBuffer buff;
    if (file) { // use existing file if it's there
        buff = file.readToBuffer();
        compname = buff.getText();
    } else { // otherwise make a new one
        compname += "_" + ofGetTimestampString("%y%m%d%H%M%S%i");
        ofStringReplace(compname, "\n", "");
        ofStringReplace(compname, "\r", "");
        buff.set(compname.c_str(), compname.size());
        ofBufferToFile("compname.txt", buff);
    }

    // * camera *
    ofFile settingsFile("settings.json");
    if (settingsFile.exists()) {
        ofBuffer jsonBuffer = ofBufferFromFile("settings.json");
        camSettings.parseJSON(jsonBuffer.getText());
    } else {
        camSettings.sensorWidth = 2592;
        camSettings.sensorHeight = 1944;       
        camSettings.stillPreviewWidth = width;
        camSettings.stillPreviewHeight = height;        
        camSettings.saturation = -100;
        camSettings.sharpness = 100;
        camSettings.brightness = 50;
        camSettings.stillQuality = 100;
        camSettings.enableStillPreview = true;
        camSettings.burstModeEnabled = true;
        camSettings.saveJSONFile();   
    }
    
    // ~ override settings ~
    // https://github.com/jvcleave/ofxOMXCamera/blob/master/src/ofxOMXCameraSettings.h
    camSettings.stillPreviewWidth = width;
    camSettings.stillPreviewHeight = height;
    if (rpiCamVersion == 1) {
        camSettings.sensorWidth = 2592;
        camSettings.sensorHeight = 1944;  
    } else if (rpiCamVersion == 2) {
        camSettings.sensorWidth = 3280;
        camSettings.sensorHeight = 2464;  
    }
    camSettings.stillQuality = stillCompression;
    //camSettings.enablePixels = true;
    camSettings.enableTexture = true;
    camSettings.autoISO = false;
    camSettings.autoShutter = false;
    camSettings.savedPhotosFolderName = "DocumentRoot/photos"; // default "photos"
    camSettings.photoGrabberListener = this; //not saved in JSON file
    cam.setup(camSettings);
    
    // * stream video *
    // https://github.com/bakercp/ofxHTTP/blob/master/libs/ofxHTTP/include/ofx/HTTP/IPVideoRoute.h
    // https://github.com/bakercp/ofxHTTP/blob/master/libs/ofxHTTP/src/IPVideoRoute.cpp
    streamSettings.setPort(streamPort);
    streamSettings.ipVideoRouteSettings.setMaxClientConnections(settings.getValue("settings:max_stream_connections", 5)); // default 5
    streamSettings.ipVideoRouteSettings.setMaxClientBitRate(settings.getValue("settings:max_stream_bitrate", 512)); // default 1024
    streamSettings.ipVideoRouteSettings.setMaxClientFrameRate(settings.getValue("settings:max_stream_framerate", 30)); // default 30
    streamSettings.ipVideoRouteSettings.setMaxClientQueueSize(settings.getValue("settings:max_stream_queue", 10)); // default 10
    streamSettings.ipVideoRouteSettings.setMaxStreamWidth(width); // default 1920
    streamSettings.ipVideoRouteSettings.setMaxStreamHeight(height); // default 1080
    streamSettings.fileSystemRouteSettings.setDefaultIndex("live_view.html");
    streamServer.setup(streamSettings);
    streamServer.start();

    shader.load("shaders/es/invert");
    fbo.allocate(width, height, GL_RGBA);
    pixels.allocate(width, height, OF_IMAGE_COLOR);

    // * post form *
    // https://bakercp.github.io/ofxHTTP/classofx_1_1_h_t_t_p_1_1_simple_post_server_settings.html
    // https://github.com/bakercp/ofxHTTP/blob/master/libs/ofxHTTP/src/PostRoute.cpp
    postSettings.setPort(postPort);
    postSettings.postRouteSettings.setUploadRedirect("result.html");
    postServer.setup(postSettings);
    postServer.postRoute().registerPostEvents(this);
    postServer.start();

    ofSystem("cp /etc/hostname " + ofToDataPath("DocumentRoot/js/"));
    host = ofSystem("cat /etc/hostname");
    host.pop_back(); // last char is \n

    // * websockets *
    // https://github.com/bakercp/ofxHTTP/blob/master/libs/ofxHTTP/include/ofx/HTTP/WebSocketConnection.h
    // https://github.com/bakercp/ofxHTTP/blob/master/libs/ofxHTTP/src/WebSocketConnection.cpp
    wsSettings.setPort(wsPort);
    wsServer.setup(wsSettings);
    wsServer.webSocketRoute().registerWebSocketEvents(this);
    wsServer.start();

    // events: connect, open, close, idle, message, broadcast
}

//--------------------------------------------------------------
void ofApp::update() {
    if (!slowVideoUpdate) {
        updateStreamingVideo();
    } else if (ofGetElapsedTimef() > slowVideoInterval) {
        updateStreamingVideo();
        ofResetElapsedTimeCounter();        
    }
}

void ofApp::updateStreamingVideo() {
    if (cam.isFrameNew() && cam.isTextureEnabled()) {
        fbo.begin();
        if (doShader) shader.begin();
        cam.draw(0,0);
        if (doShader) shader.end();
        fbo.end();
        fbo.readToPixels(pixels);
        streamServer.send(pixels);
    }
}

//--------------------------------------------------------------
void ofApp::draw() {
    if (debug && cam.isTextureEnabled()) {
        fbo.draw(0, 0);
    } 
}

// ~ ~ ~ CAM ~ ~ ~
void ofApp::onTakePhotoComplete(string fileName) {
    ofLog() << "onTakePhotoComplete fileName: " << fileName;  

    endTakePhoto(fileName);
}

// ~ ~ ~ POST ~ ~ ~
void ofApp::onHTTPPostEvent(ofxHTTP::PostEventArgs& args) {
    ofLogNotice("ofApp::onHTTPPostEvent") << "Data: " << args.getBuffer().getText();

    beginTakePhoto();
}


void ofApp::onHTTPFormEvent(ofxHTTP::PostFormEventArgs& args) {
    ofLogNotice("ofApp::onHTTPFormEvent") << "";
    ofxHTTP::HTTPUtils::dumpNameValueCollection(args.getForm(), ofGetLogLevel());
    
    beginTakePhoto();
}


void ofApp::onHTTPUploadEvent(ofxHTTP::PostUploadEventArgs& args) {
    std::string stateString = "";

    switch (args.getState()) {
        case ofxHTTP::PostUploadEventArgs::UPLOAD_STARTING:
            stateString = "STARTING";
            break;
        case ofxHTTP::PostUploadEventArgs::UPLOAD_PROGRESS:
            stateString = "PROGRESS";
            break;
        case ofxHTTP::PostUploadEventArgs::UPLOAD_FINISHED:
            stateString = "FINISHED";
            break;
    }

    ofLogNotice("ofApp::onHTTPUploadEvent") << "";
    ofLogNotice("ofApp::onHTTPUploadEvent") << "         state: " << stateString;
    ofLogNotice("ofApp::onHTTPUploadEvent") << " formFieldName: " << args.getFormFieldName();
    ofLogNotice("ofApp::onHTTPUploadEvent") << "orig. filename: " << args.getOriginalFilename();
    ofLogNotice("ofApp::onHTTPUploadEvent") <<  "     filename: " << args.getFilename();
    ofLogNotice("ofApp::onHTTPUploadEvent") <<  "     fileType: " << args.getFileType().toString();
    ofLogNotice("ofApp::onHTTPUploadEvent") << "# bytes xfer'd: " << args.getNumBytesTransferred();
}

// ~ ~ ~ WEBSOCKETS ~ ~ ~
void ofApp::onWebSocketOpenEvent(ofxHTTP::WebSocketEventArgs& evt) {
    cout << "Websocket connection opened." << endl;// << evt.getConnectionRef().getClientAddress().toString() << endl;
}


void ofApp::onWebSocketCloseEvent(ofxHTTP::WebSocketCloseEventArgs& evt) {
    cout << "Websocket connection closed." << endl; //<< evt.getConnectionRef().getClientAddress().toString() << endl;
}


void ofApp::onWebSocketFrameReceivedEvent(ofxHTTP::WebSocketFrameEventArgs& evt) {
    cout << "Websocket frame was received:" << endl; // << evt.getConnectionRef().getClientAddress().toString() << endl;
    string msg = evt.frame().getText();
    cout <<  msg << endl;

    if (msg == "take_photo") {
        beginTakePhoto();
    } else if (msg == "update_slow") {
        slowVideoUpdate = true;
    } else if (msg == "update_fast") {
        slowVideoUpdate = false;
    }
    /*
    ofxJSONElement json;

    if (json.parse(evt.getFrameRef().getText())) {
        //std::cout << json.toStyledString() << std::endl;

        if (json.isMember("command") && json["command"] == "SET_BACKGROUND_COLOR") {
            if (json["data"] == "white") {
                //bgColor = ofColor::white;
            } else if (json["data"] == "black") {
                //bgColor = ofColor::black;
            } else {
                //cout << "Unknown color: " << json["data"].toStyledString() << endl;
            }
        }
    } else {
        //ofLogError("ofApp::onWebSocketFrameReceivedEvent") << "Unable to parse JSON: "  << evt.getFrameRef().getText();
    }
    */
}


void ofApp::onWebSocketFrameSentEvent(ofxHTTP::WebSocketFrameEventArgs& evt) {
    cout << "Websocket frame was sent." << endl;
}


void ofApp::onWebSocketErrorEvent(ofxHTTP::WebSocketErrorEventArgs& evt) {
    cout << "Websocket Error." << endl; //<< evt.getConnectionRef().getClientAddress().toString() << endl;
}

// ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
void ofApp::createResultHtml(string fileName) {
    string photoIndexFileName = "DocumentRoot/result.html";
    ofBuffer buff;
    ofFile photoIndexFile;
    photoIndexFile.open(ofToDataPath(photoIndexFileName), ofFile::ReadWrite, false);

    string photoIndex = "<!DOCTYPE html>\n";
    
    if (fileName == "none") { // use existing file if it's there
        photoIndex += "<html><head><meta http-equiv=\"refresh\" content=\"0\"></head><body>\n";
        photoIndex += "WAIT\n";
    } else { // otherwise make a new one
        photoIndex += "<html><head></head><body>\n";
        
        string lastFile = ofFilePath::getFileName(fileName);

        //lastPhotoTakenName = ofFilePath::getFileName(fileName);
        lastPhotoTakenName = host + "_" + lastFile;
        ofSystem("mv " + ofToDataPath("DocumentRoot/photos/" + lastFile) + " " + ofToDataPath("DocumentRoot/photos/" + lastPhotoTakenName));
        
        photoIndex += "<a href=\"photos/" + lastPhotoTakenName + "\">" + lastPhotoTakenName + "</a>\n";
    }

    photoIndex += "</body></html>\n";

    buff.set(photoIndex.c_str(), photoIndex.size());
    ofBufferToFile(photoIndexFileName, buff);
}

void ofApp::beginTakePhoto() {
    cam.takePhoto();
    createResultHtml("none");
    doShader = true;
}

void ofApp::endTakePhoto(string fileName) {
    createResultHtml(fileName);
    doShader = false;

    string msg = host + "," + lastPhotoTakenName;
    wsServer.webSocketRoute().broadcast(ofxHTTP::WebSocketFrame(msg));
}
