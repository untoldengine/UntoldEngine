//
//  LoadingWorld.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/19/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "LoadingWorld.h"
#include "U4DSprite.h"
#include "U4DSpriteAnimation.h"
#include "U4DDirector.h"
#include "UserCommonProtocols.h"

using namespace U4DEngine;

LoadingWorld::LoadingWorld(){
    
}

LoadingWorld::~LoadingWorld(){
    
    
    
}

void LoadingWorld::init(){
    
    //Add image
    loadingBackgroundImage=new U4DEngine::U4DImage();
    
    //set the image to use and the desire width and height
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //use the dimensions of the display
    float width=director->getDisplayWidth();
    float height=director->getDisplayHeight();
    
    loadingBackgroundImage->setImage("marsloadingscene.png",width,height);
    
    addChild(loadingBackgroundImage);
    
    //Line 1. create a a sprite loader object
    spriteLoader=new U4DEngine::U4DSpriteLoader();

    //Line 2. load the sprite information into the loader
    spriteLoader->loadSpritesAssetFile("loading.xml", "loading.png");

    //Line 3. Create a sprite object
    U4DEngine::U4DSprite *mySprite=new U4DEngine::U4DSprite(spriteLoader);

    //Line 4. Set the sprite to render
    mySprite->setSprite("loading1.png");

    //Line 5.Add it to the world
    addChild(mySprite,-2);

    //Line 6. translate the sprite
    mySprite->translateTo(0.0,0.2,0.0);
    
    //Line 7. Load all the sprite animation data into the structure
    U4DEngine::SPRITEANIMATIONDATA spriteAnimationData;

    spriteAnimationData.animationSprites.push_back("loading1.png");
    spriteAnimationData.animationSprites.push_back("loading2.png");
    spriteAnimationData.animationSprites.push_back("loading3.png");

    //Line 8. set a delay for the animation
    spriteAnimationData.delay=0.2;
    
    //Line 9. create a sprite animation object
    U4DEngine::U4DSpriteAnimation *spriteAnim=new U4DEngine::U4DSpriteAnimation(mySprite,spriteAnimationData);

    //Line 10. Play the sprite animation
    spriteAnim->play();
    
}


void LoadingWorld::update(double dt){
    
}


