//
//  U4DSpriteLoader.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/29/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DSpriteLoader__
#define __UntoldEngine__U4DSpriteLoader__

#include <iostream>
#include <vector>
#include <string>
#include "CommonProtocols.h"
#include "tinyxml2.h"


namespace U4DEngine {
    
/**
 @brief The U4DSpriteLoader class is in charge of loading sprite information
 */
class U4DSpriteLoader{
    
private:
    
    /**
     @brief XML document read by the loader
     */
    tinyxml2::XMLDocument doc;
    
public:
    
    /**
     @brief Constructor for the sprite loader
     */
    U4DSpriteLoader();
    
    /**
     @brief Destructor for the sprite loader
     */
    ~U4DSpriteLoader();
    
    /**
     @brief Vector containing sprite data
     */
    std::vector<SPRITEDATA> spriteData;
    
    /**
     @brief Name of the image atlas containing the sprite images
     */
    std::string spriteAtlasImage;
    
    /**
     @brief Sprite atlas image width
     */
    float spriteAtlasWidth;
    
    /**
     @brief Sprite atlas image height
     */
    float spriteAtlasHeight;
  
    /**
     @brief Method which loads the sprite file into the engine
     
     @param uSpriteAtlasFile  Sprite Atlas file name
     @param uSpriteAtlasImage Sprite Atlas image name
     */
    void loadSpritesAssetFile(std::string uSpriteAtlasFile,std::string uSpriteAtlasImage);
    
    /**
     @brief Method which loads sprite information
     */
    void loadSprites();
    
};

}

#endif /* defined(__UntoldEngine__U4DSpriteLoader__) */
