//
//  U4DSpriteLoader.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/29/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DSpriteLoader.h"
#include "tinyxml2.h"

namespace U4DEngine {
    
void U4DSpriteLoader::loadSpritesAssetFile(std::string uSpriteAtlasFile,std::string uSpriteAtlasImage){
    
    const char * atlasFile = uSpriteAtlasFile.c_str();
    
    bool loadOk=doc.LoadFile(atlasFile);
    
    if (!loadOk) {
        
        std::cout<<"Font Asset "<<uSpriteAtlasFile<<" loaded successfully"<<std::endl;
        
        loadSprites();
        
        spriteAtlasImage=uSpriteAtlasImage;
        
    }else{
        std::cout<<"Font Asset "<<uSpriteAtlasFile<<"was not found. Loading failed"<<std::endl;
        
    }
    
}

void U4DSpriteLoader::loadSprites(){
    
    tinyxml2::XMLElement* textureAtlas = doc.FirstChildElement("TextureAtlas");
    
    const char* uSpriteAtlasWidth=textureAtlas->Attribute("width");
    
    spriteAtlasWidth=atoi(uSpriteAtlasWidth);
    
    const char* uSpriteAtlasHeight=textureAtlas->Attribute("height");
    
    spriteAtlasHeight=atoi(uSpriteAtlasHeight);
    
    for(tinyxml2::XMLElement* sprite = textureAtlas->FirstChildElement("sprite"); sprite != NULL; sprite= sprite->NextSiblingElement("sprite"))
    {
        SPRITEDATA uSpriteData;
        
        const char* spriteName = sprite->Attribute("n");
        uSpriteData.name=spriteName;
        
        const char* spriteXPosition=sprite->Attribute("x");
        uSpriteData.x=atof(spriteXPosition);
        
        const char* spriteYPosition=sprite->Attribute("y");
        uSpriteData.y=atof(spriteYPosition);
        
        const char* spriteWidth=sprite->Attribute("w");
        uSpriteData.width=atoi(spriteWidth);
        
        const char* spriteHeight=sprite->Attribute("h");
        uSpriteData.height=atoi(spriteHeight);
        
        spriteData.push_back(uSpriteData);
        
    }
    
}

}
