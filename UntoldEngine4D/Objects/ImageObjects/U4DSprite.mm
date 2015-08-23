//
//  U4DSprite.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/27/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DSprite.h"
#include "U4DOpenGLSprite.h"
#include <string>

namespace U4DEngine {
    
U4DSprite::U4DSprite(U4DSpriteLoader *uSpriteLoader){
    
    openGlManager=new U4DOpenGLSprite(this);
    openGlManager->setShader("spriteShader");
    
    spriteLoader=uSpriteLoader;
    
};

void U4DSprite::setSprite(const char* uSprite){

   //search for the sprite in the atlas manager
    
    for (int i=0; i<spriteLoader->spriteData.size(); i++) {
        
        SpriteData spriteData;
        
        spriteData=spriteLoader->spriteData.at(i);
        
        
        if (strcmp(spriteData.name, uSprite)==0) {
            
            const char * spriteImage = spriteLoader->spriteAtlasImage.c_str();
            
            openGlManager->setDiffuseTexture(spriteImage); 

            //set the rectangle for the sprite
            openGlManager->setImageDimension(spriteData.width, spriteData.height,spriteLoader->spriteAtlasWidth,spriteLoader->spriteAtlasHeight);
            
            //set the offset for the sprite
            std::vector<float> data={spriteData.x/spriteLoader->spriteAtlasWidth,spriteData.y/spriteLoader->spriteAtlasHeight};
            
            addCustomUniform("offset", data);
            
        }
    }
    
    openGlManager->loadRenderingInformation();
   
}

void U4DSprite::changeSprite(const char* uSprite){
    
    SpriteData spriteData;
    
    for (int i=0; i<spriteLoader->spriteData.size(); i++) {
        
        spriteData=spriteLoader->spriteData.at(i);
    
    
            if (strcmp(spriteData.name, uSprite)==0) {
        
                //set the offset for the sprite
                std::vector<float> data={spriteData.x/spriteLoader->spriteAtlasWidth,spriteData.y/spriteLoader->spriteAtlasHeight};
            
                updateUniforms("offset", data);
                
            }
    }
}

void U4DSprite::draw(){
    
    
    openGlManager->draw();
    
}

}
