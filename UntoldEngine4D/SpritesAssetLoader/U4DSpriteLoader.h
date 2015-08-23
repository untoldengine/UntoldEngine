//
//  U4DSpriteLoader.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/29/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DSpriteLoader__
#define __UntoldEngine__U4DSpriteLoader__

#include <iostream>
#include <vector>
#include <string>
#include "CommonProtocols.h"
#include "tinyxml2.h"


namespace U4DEngine {
    
class U4DSpriteLoader{
    
private:
    
    tinyxml2::XMLDocument doc;
    
public:
    
    U4DSpriteLoader(){};
    
    ~U4DSpriteLoader(){};
    
    std::vector<SpriteData> spriteData;
    
    std::string spriteAtlasImage;
    
    float spriteAtlasWidth;
    
    float spriteAtlasHeight;
  
    void loadSpritesAssetFile(std::string uSpriteAtlasFile,std::string uSpriteAtlasImage);
    
    void loadSprites();
    
};

}

#endif /* defined(__UntoldEngine__U4DSpriteLoader__) */
