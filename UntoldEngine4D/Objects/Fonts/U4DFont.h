//
//  U4DFont.h
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DFont__
#define __UntoldEngine__U4DFont__

#include <iostream>
#include <vector>
#include "CommonProtocols.h"
#include "U4DImage.h"

namespace U4DEngine {
    
class U4DFontLoader;

}

namespace U4DEngine {

/**
 @brief The U4DFont class represents fonts entities
 */
class U4DFont:public U4DImage{
    
private:

    /**
     @brief Pointer to font loader
     */
    U4DFontLoader *fontLoader;
    
    /**
     @brief Text to render
     */
    const char* text;
    
    /**
     @brief Container to text information
     */
    std::vector<TEXTDATA> textContainer;
    
    /**
     @brief Text spacing
     */
    float textSpacing;
    
public:
    
    /**
     @brief Constructor of class
     
     @param uFontLoader Font loader object
     */
    U4DFont(U4DFontLoader* uFontLoader);

    /**
     @brief Destructor of class
     */
    ~U4DFont();
    
    /**
     @brief Copy constructor
     */
    U4DFont(const U4DFont& value);
    
    /**
     @brief Copy constructor
     */
    U4DFont& operator=(const U4DFont& value);

    /**
     @brief Name of font image
     */
    const char* fontImage;
    
    /**
     @brief Method which sets font  to use
     */
    void setFont();
    
    /**
     @brief Method which sets text to render
     
     @param uText Text to render
     */
    void setText(const char* uText);
    
    /**
     @brief Method which starts the rendering process of the entity
     */
    void draw();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DFont__) */
