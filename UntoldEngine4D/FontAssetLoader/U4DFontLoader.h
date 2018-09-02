//
//  U4DFontLoader.h
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DFontLoader__
#define __UntoldEngine__U4DFontLoader__

#include <iostream>
#include <vector>
#include <string>
#include "CommonProtocols.h"
#include "tinyxml2.h"

namespace U4DEngine {

/**
 @ingroup loader
 @brief The U4DFontLoader class is in charge of loading font information
 */
class U4DFontLoader{
    
private:
    
    /**
     @brief XML document read by the loader
     */
    tinyxml2::XMLDocument doc;
    
public:
    
    /**
     @brief Constructor for the font loader
     */
    U4DFontLoader();
    
    /**
     @brief Destructor for the font loader
     */
    ~U4DFontLoader();
    
    /**
     @brief Vector containing font data
     */
    std::vector<FONTDATA> fontData;
    
    /**
     @brief Name of the image atlas containing the font images
     */
    std::string fontAtlasImage;
    
    /**
     @brief Font atlas image width
     */
    float fontAtlasWidth;
    
    /**
     @brief Font atlas image height
     */
    float fontAtlasHeight;
    
    /**
     @brief Method which loads font information
     */
    void loadFont();
    
    /**
     @brief Method which loads the font file into the engine
     
     @param uFontAtlasFile  Font Atlas file name
     @param uFontAtlasImage Font Atlas image name
     */
    void loadFontAssetFile(std::string uFontAtlasFile,std::string uFontAtlasImage);
    
};

}

#endif /* defined(__UntoldEngine__U4DFontLoader__) */
