//
//  PlayMenuLayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/5/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayMenuLayer.h"
#include "TeamSettings.h"

PlayMenuLayer::PlayMenuLayer(std::string uLayerName):U4DEngine::U4DLayer(uLayerName),kitSelection(0){
    
}

PlayMenuLayer::~PlayMenuLayer(){
    
    delete player;
    delete walkAnimation;
    delete kitMenuShader;
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();

    if (director->getDeviceOSType()==U4DEngine::deviceOSIOS) {
        delete aButton;
        delete joystick;
    }
}

void PlayMenuLayer::init(){
    
    setBackgroundImage("futbolblankscreen.png");
    
    //render the player
    player=new U4DEngine::U4DGameObject();

    if(player->loadModel("player0")){

        player->setShader("vertexKitShader","fragmentKitShader");
        
        player->setNormalMapTexture("redkitnormal.png");
        
        //Default Uniform
        U4DEngine::U4DVector4n jersey(0.8,0.66,0.07,0.0);
        U4DEngine::U4DVector4n shorts(0.07,0.28,0.61,0.0);
        U4DEngine::U4DVector4n cleats(0.0,0.0,0.0,0.0);
        U4DEngine::U4DVector4n socks(0.9,0.9,0.9,0.0);
        
        player->updateShaderParameterContainer(0,jersey);
        player->updateShaderParameterContainer(1,shorts);
        player->updateShaderParameterContainer(2,cleats);
        player->updateShaderParameterContainer(3,socks);
        
        //send info to gpu
        player->loadRenderingInformation();
        
        player->translateBy(-2.5,0.0,0.0);

        //add to layer scenegraph
        addChild(player);
        
    }
    
    walkAnimation=new U4DEngine::U4DAnimation(player);
    
    if(player->loadAnimationToModel(walkAnimation, "walking")){

        //If animation data was successfully loaded, you can set other parameters here. For now, we won't do this.

    }
    
    walkAnimation->play(); 
    
    //Add the shader
    
    kitMenuShader=new U4DEngine::U4DShaderEntity(1);
    
    kitMenuShader->setEnableBlending(false);

    kitMenuShader->setShader("vertexKitMenuShader","fragmentKitMenuShader");

    kitMenuShader->setTexture0("teamkitmenu.png");

    kitMenuShader->setShaderDimension(400.0, 200.0);

    kitMenuShader->translateTo(0.3, 0.0, 0.0);

    kitMenuShader->loadRenderingInformation();

    //add to layer scenegraph
    addChild(kitMenuShader,-10);
    
    //Create the UI Elements
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();

    if (director->getDeviceOSType()==U4DEngine::deviceOSIOS) {
//        aButton=new U4DEngine::U4DButton("buttonA",0.6,-0.6,103.0,103.0,"ButtonA.png","ButtonAPressed.png");

        //create the Joystick
        joystick=new U4DEngine::U4DJoystick("joystick",-0.7,-0.6,"joyStickBackground.png",130.0,130.0,"joystickDriver.png");
        
        //addChild(aButton,-20);
        addChild(joystick);
    }

}

void PlayMenuLayer::selectKit(int uValue){
    
    kitSelection=(kitSelection+uValue)%4;

    int selection=std::abs(kitSelection);

    U4DEngine::U4DVector4n jersey(0.0,0.0,0.0,0.0);
    U4DEngine::U4DVector4n shorts(0.0,0.0,0.0,0.0);
    U4DEngine::U4DVector4n cleats(0.0,0.0,0.0,0.0);
    U4DEngine::U4DVector4n socks(0.0,0.0,0.0,0.0);

    if (selection==0) {

        //choose kit 0
        jersey=U4DEngine::U4DVector4n(0.8,0.66,0.07,0.0);
        shorts=U4DEngine::U4DVector4n(0.07,0.28,0.61,0.0);
        cleats=U4DEngine::U4DVector4n(0.0,0.0,0.9,0.0);
        socks=U4DEngine::U4DVector4n(0.9,0.9,0.9,0.0);



    }else if(selection==1){
        //choose kit 1
        jersey=U4DEngine::U4DVector4n(0.7,0.06,0.14,0.0);
        shorts=U4DEngine::U4DVector4n(0.86,0.86,0.86,0.0);
        cleats=U4DEngine::U4DVector4n(0.9,0.9,0.0,0.0);
        socks=U4DEngine::U4DVector4n(0.7,0.06,0.14,0.0);

    }else if(selection==2){
        //choose kit 2
        jersey=U4DEngine::U4DVector4n(0.78,0.05,0.12,0.0);
        shorts=U4DEngine::U4DVector4n(0.02,0.21,0.46,0.0);
        cleats=U4DEngine::U4DVector4n(0.9,0.0,0.0,0.0);
        socks=U4DEngine::U4DVector4n(0.9,0.9,0.9,0.0);
    }else if(selection==3){
        //choose kit 3
        jersey=U4DEngine::U4DVector4n(0.78,0.05,0.12,0.0);
        shorts=U4DEngine::U4DVector4n(0.78,0.05,0.12,0.0);
        cleats=U4DEngine::U4DVector4n(0.0,0.0,0.9,0.0);
        socks=U4DEngine::U4DVector4n(0.9,0.9,0.9,0.0);
    }


    player->updateShaderParameterContainer(0,jersey);
    player->updateShaderParameterContainer(1,shorts);
    player->updateShaderParameterContainer(2,cleats);
    player->updateShaderParameterContainer(3,socks);

    U4DEngine::U4DVector4n param(selection,0.0,0.0,0.0);
    kitMenuShader->updateShaderParameterContainer(0, param);

    TeamSettings *teamSettings=TeamSettings::sharedInstance();

    std::vector<U4DEngine::U4DVector4n> teamKit{jersey,shorts,cleats,socks};
    teamSettings->setTeamAKit(teamKit);
    
}
