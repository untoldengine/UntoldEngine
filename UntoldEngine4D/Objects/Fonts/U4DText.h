//
//  U4DText.h
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
     @brief The U4DText class represents fonts entities
     */
    class U4DText:public U4DImage{
        
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
        
        int currentTextContainerSize;
        
    public:
        
        /**
         @brief Constructor of class
         
         @param uFontLoader Font loader object
         */
        U4DText(U4DFontLoader* uFontLoader, float uTextSpacing);

        /**
         @brief Destructor of class
         */
        ~U4DText();
        
        /**
         @brief Copy constructor
         */
        U4DText(const U4DText& value);
        
        /**
         @brief Copy constructor
         */
        U4DText& operator=(const U4DText& value);

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
        
        void setTextSpacing(float uTextSpacing);
        
        void parseText(const char* uText);
        
        void loadText();
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void setTextDimension(U4DVector3n &uFontPositionOffset, U4DVector2n &uFontUV, int uTextCount, float uTextWidth,float uTextHeight, float uAtlasWidth,float uAtlasHeight);
    };
        
}

#endif /* defined(__UntoldEngine__U4DFont__) */
