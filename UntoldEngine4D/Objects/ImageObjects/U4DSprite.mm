//
//  U4DSprite.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/27/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DSprite.h"
#include "U4DRenderSprite.h"
#include <string>

namespace U4DEngine {
    
        U4DSprite::U4DSprite(U4DSpriteLoader *uSpriteLoader):spriteAtlasImage(nullptr){
        
        renderManager=new U4DRenderSprite(this);
        
        setShader("vertexSpriteShader", "fragmentSpriteShader");
        
        spriteLoader=uSpriteLoader;
        
    }
        
    U4DSprite::~U4DSprite(){

        delete renderManager;
        
    }

    void U4DSprite::setSprite(const char* uSprite){

            //search for the sprite in the atlas manager
            SPRITEDATA spriteData;
            
            for (int i=0; i<spriteLoader->spriteData.size(); i++) {
                
                spriteData=spriteLoader->spriteData.at(i);
                
                if (strcmp(spriteData.name, uSprite)==0) {
                    
                    if (spriteAtlasImage==nullptr) {
                        
                        spriteAtlasImage = spriteLoader->spriteAtlasImage.c_str();
                        
                        renderManager->setDiffuseTexture(spriteAtlasImage);
                        
                        //set the rectangle for the sprite
                        renderManager->setSpriteDimension(spriteData.width, spriteData.height,spriteLoader->spriteAtlasWidth,spriteLoader->spriteAtlasHeight);
                        
                        U4DVector2n offset(spriteData.x/spriteLoader->spriteAtlasWidth,spriteData.y/spriteLoader->spriteAtlasHeight);
                        
                        renderManager->setSpriteOffset(offset);
                        
                        renderManager->loadRenderingInformation();
                        
                        
                    }else{
                     
                        //set the offset for the sprite
                        U4DVector2n offset(spriteData.x/spriteLoader->spriteAtlasWidth,spriteData.y/spriteLoader->spriteAtlasHeight);
                        
                        renderManager->setSpriteOffset(offset);
                        
                    }
                    
                    break;
                    
                }
            
            }
        
    }


    void U4DSprite::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
        
    }

}
