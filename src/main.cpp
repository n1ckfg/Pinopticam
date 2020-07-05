#include "ofMain.h"
#include "ofApp.h"

//========================================================================
int main() {

#ifdef TARGET_OPENGLES
	ofGLESWindowSettings settings;
	settings.glesVersion = 2;
	settings.windowMode = OF_FULLSCREEN;
	ofCreateWindow(settings);
#else
        ofGLFWWindowSettings settings;
        settings.glesVersion = 2;
        settings.windowMode = OF_FULLSCREEN;
        settings.numSamples = 0;
        ofCreateWindow(settings);                       // <-------- setup the GL context
#endif

	// this kicks off the running of my app
	// can be OF_WINDOW or OF_FULLSCREEN
	// pass in width and height too:
	ofRunApp(new ofApp());

}
