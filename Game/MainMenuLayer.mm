//
//  MainMenuLayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/5/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "MainMenuLayer.h"

MainMenuLayer::MainMenuLayer(std::string uLayerName):U4DEngine::U4DLayer(uLayerName),menuSelection(0){
    
}

MainMenuLayer::~MainMenuLayer(){
    
    delete menuShader;
    delete aButton;
    delete joystick;
    delete fontLoader;
    delete menuInstructions;
}

void MainMenuLayer::init(){
    
    setBackgroundImage("futbolblankscreen.png");
    
    //create shader as children of layer
    
    menuShader=new U4DEngine::U4DShaderEntity(1);

    menuShader->setShader("vertexMenuSelectionShader","fragmentMenuSelectionShader");

    menuShader->setTexture0("menuSelection.png");

    menuShader->setShaderDimension(300.0, 200.0);

    menuShader->translateTo(0.0, 0.0, 0.0);

    menuShader->loadRenderingInformation();

    //add shader as child in scenegraph
    addChild(menuShader);
    
    //Create the UI Elements
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();

    if (director->getDeviceOSType()==U4DEngine::deviceOSIOS) {
        
        aButton=new U4DEngine::U4DButton("buttonA",0.7,-0.6,103.0,103.0,"ButtonA.png","ButtonAPressed.png");

        //create the Joystick
        joystick=new U4DEngine::U4DJoyStick("joystick",-0.7,-0.6,"joyStickBackground.png",130.0,130.0,"joystickDriver.png",80.0,80.0);
        
        addChild(aButton);
        addChild(joystick);
    
    }else{
        
        if(!director->getGamePadControllerPresent()){
            
            //Game controller detected
            
            //load up text
            //1. Create a Font Loader object
            fontLoader=new U4DEngine::U4DFontLoader();

            //2. Load font data into the font loader object. Such as the xml file and image file
            fontLoader->loadFontAssetFile("gameFont.xml", "gameFont.png");
            
            //3. Create a text object. Provide the font loader object and the spacing between letters
            menuInstructions=new U4DEngine::U4DText(fontLoader, 30);
            
            menuInstructions->setText("USE ARROW KEYS. SPACE TO ENTER");
            
            //5. If desire, set the text position. Remember the coordinates for 2D objects, such as text is [-1.0,1.0]
            menuInstructions->translateTo(-0.80, -0.70, 0.0);

            //6. Add the text to the scenegraph
            addChild(menuInstructions);
        
        }
        
    }
    
}

void MainMenuLayer::selectOptionInMenu(int uValue){
    
    menuSelection=(menuSelection+uValue)%3;

    int selection=std::abs(menuSelection);
    
    U4DEngine::U4DVector4n param(0.0,selection,0.0,0.0);
    menuShader->updateShaderParameterContainer(0, param);
    
}
