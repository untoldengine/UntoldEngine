//
//  U4DFontLoader.h
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DFontLoader__
#define __UntoldEngine__U4DFontLoader__

#include <iostream>
#include <vector>
#include <string>
#include "CommonProtocols.h"
#include "tinyxml2.h"

namespace U4DEngine {
    
class U4DFontLoader{
    
private:
    
    tinyxml2::XMLDocument doc;
    
public:
    
    U4DFontLoader(){};
    
    ~U4DFontLoader(){};
    
    std::vector<FontData> fontData;
    
    std::string fontAtlasImage;
    
    float fontAtlasWidth;
    
    float fontAtlasHeight;
    
    void loadFont();
    
    void loadFontAssetFile(std::string uFontAtlasFile,std::string uFontAtlasImage);
    
};

}

#endif /* defined(__UntoldEngine__U4DFontLoader__) */
