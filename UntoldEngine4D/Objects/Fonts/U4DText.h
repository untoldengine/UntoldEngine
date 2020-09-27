//
//  U4DText.h
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DFont__
#define __UntoldEngine__U4DFont__

#include <iostream>
#include <vector>
#include "CommonProtocols.h"
#include "U4DImage.h"


namespace U4DEngine {

    /**
     @ingroup gameobjects
     @brief The U4DText class represents fonts entities
     */
    class U4DText:public U4DImage{
        
    private:

        /**
         @brief Text to render
         */
        const char* text;
        
        /**
         @brief Container to text information
         */
        std::vector<TEXTDATA> textContainer;
        
        /**
         @brief size of the text container
         */
        int currentTextContainerSize;
        
        /**
         @brief pointer to the rendering manager
         */
        U4DRenderManager *renderManager;
        
    public:
        
        /**
         @brief Constructor of class
         
         */
        U4DText(std::string uFontName);

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
         @brief Method which sets font  to use
         */
        void setFont();
        
        /**
         @brief Method which sets text to render
         
         @param uText Text to render
         */
        void setText(const char* uText);
        
        void setText(float uFloatValue);
        
        /**
         @brief parses the text into individual letters

         @param uText text to render
         */
        void parseText(const char* uText);
        
        
        /**
         @brief loads the text into a structure
         @details the text is loaded into the TEXTDATA structure which holds text information
         */
        void loadText();
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix and any rendering flags. It encodes the pipeline, buffers and issues the draw command
         *
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        
        /**
         @brief sets the text dimension

         @param uFontPositionOffset font position offset
         @param uFontUV font uv-coordinates
         @param uTextCount letter count
         @param uTextWidth texture text width
         @param uTextHeight texture text height
         */
        void setTextDimension(U4DVector3n &uFontPositionOffset, U4DVector2n &uFontUV, int uTextCount, float uTextWidth,float uTextHeight);
        
        U4DEngine::FONTDATA fontData;
    };
        
}

#endif /* defined(__UntoldEngine__U4DFont__) */
