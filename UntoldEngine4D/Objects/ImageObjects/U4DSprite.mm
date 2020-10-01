//
//  U4DSprite.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/27/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DSprite.h"
#include <string>
#include "U4DRenderSprite.h"
#include "U4DDirector.h"
#include "U4DResourceLoader.h"

namespace U4DEngine {
    
    U4DSprite::U4DSprite(U4DSpriteLoader *uSpriteLoader):spriteAtlasImage(nullptr),spriteOffset(0.0,0.0){
        
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
        U4DResourceLoader *resourceLoader=U4DResourceLoader::sharedInstance();
        
        //THIS SECTION NEEDS TO BE FIXED. 
        for (int i=0; i<spriteLoader->spriteData.size(); i++) {
            
            spriteData=spriteLoader->spriteData.at(i);
            
            if (strcmp(spriteData.name, uSprite)==0) {
                
                    renderManager->setTexture0(spriteLoader->spriteAtlasImage.c_str());

                if(resourceLoader->loadTextureDataToEntity(renderManager, spriteLoader->spriteAtlasImage.c_str())){

                    //set the rectangle for the sprite
                    setSpriteDimension(spriteData.width, spriteData.height,spriteLoader->spriteAtlasWidth,spriteLoader->spriteAtlasHeight);

                    U4DVector2n offset(spriteData.x/spriteLoader->spriteAtlasWidth,spriteData.y/spriteLoader->spriteAtlasHeight);

                    setSpriteOffset(offset);

                    renderManager->loadRenderingInformation();
                    
                    
                }                   
                
                break;
                
            }
        
        }
        
    }

    void U4DSprite::updateSprite(const char* uSprite){
        
        //search for the sprite in the atlas manager
        SPRITEDATA spriteData;
        
        for (int i=0; i<spriteLoader->spriteData.size(); i++) {
            
            spriteData=spriteLoader->spriteData.at(i);
            
            if (strcmp(spriteData.name, uSprite)==0) {
                
                //set the offset for the sprite
                U4DVector2n offset(spriteData.x/spriteLoader->spriteAtlasWidth,spriteData.y/spriteLoader->spriteAtlasHeight);
                
                setSpriteOffset(offset);
                    
                break;
                
            }
        
        }
    }


    void U4DSprite::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
        
    }
    
    void U4DSprite::setSpriteDimension(float uSpriteWidth,float uSpriteHeight, float uAtlasWidth,float uAtlasHeight){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        float widthFontTexture=uSpriteWidth/uAtlasWidth;
        float heightFontTexture=uSpriteHeight/uAtlasHeight;
        
        float width=uSpriteWidth/director->getDisplayWidth();
        float height=uSpriteHeight/director->getDisplayHeight();
        float depth=0.0;
        
        
        //vertices
        U4DVector3n v1(width,height,depth);
        U4DVector3n v4(width,-height,depth);
        U4DVector3n v2(-width,-height,depth);
        U4DVector3n v3(-width,height,depth);
        
        bodyCoordinates.addVerticesDataToContainer(v1);
        bodyCoordinates.addVerticesDataToContainer(v4);
        bodyCoordinates.addVerticesDataToContainer(v2);
        bodyCoordinates.addVerticesDataToContainer(v3);
        
        //texture
        U4DVector2n t4(0.0,0.0);  //top left
        U4DVector2n t1(1.0*widthFontTexture,0.0);  //top right
        U4DVector2n t3(0.0,1.0*heightFontTexture);  //bottom left
        U4DVector2n t2(1.0*widthFontTexture,1.0*heightFontTexture);  //bottom right
        
        
        bodyCoordinates.addUVDataToContainer(t1);
        bodyCoordinates.addUVDataToContainer(t2);
        bodyCoordinates.addUVDataToContainer(t3);
        bodyCoordinates.addUVDataToContainer(t4);
        
        
        U4DIndex i1(0,1,2);
        U4DIndex i2(2,3,0);
        
        //index
        bodyCoordinates.addIndexDataToContainer(i1);
        bodyCoordinates.addIndexDataToContainer(i2);
        
    }
    
    void U4DSprite::setSpriteOffset(U4DVector2n &uSpriteOffset){
        
        spriteOffset=uSpriteOffset;
        
    }
    
    U4DVector2n& U4DSprite::getSpriteOffset(){
        
        return spriteOffset;
        
    }

}
