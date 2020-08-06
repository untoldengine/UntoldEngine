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
    
}

void MainMenuLayer::init(){
    
    setBackgroundImage("futbolmenuscreen.png");
    
    //create shader as children of layer
    
    menuShader=new U4DEngine::U4DShaderEntity(1);

    menuShader->setShader("vertexMenuSelectionShader","fragmentMenuSelectionShader");

    menuShader->setTexture0("menuSelection.png");

    menuShader->setShaderDimension(300.0, 200.0);

    menuShader->translateTo(0.5, 0.0, 0.0);

    menuShader->loadRenderingInformation();

    //add shader as child in scenegraph
    addChild(menuShader);
    
}

void MainMenuLayer::selectOptionInMenu(int uValue){
    
    menuSelection=(menuSelection+uValue)%3;

    int selection=std::abs(menuSelection);
    
    U4DEngine::U4DVector4n param(0.0,selection,0.0,0.0);
    menuShader->updateShaderParameterContainer(0, param);
    
}
