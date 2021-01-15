//
//  U4DRenderFont.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderFont_hpp
#define U4DRenderFont_hpp

#include <stdio.h>
#include "U4DRenderEntity.h"
#include "U4DRenderImage.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"


namespace U4DEngine {
    
    /**
     * @ingroup renderingengine
     * @brief The U4DRenderFont class manages the rendering of font entities
     * 
     */
    class U4DRenderFont:public U4DRenderImage {
        
    private:
        
        /**
         * @brief the font object the class will manage
         */
        U4DImage *u4dObject;
        
    public:
        
        /**
         * @brief Constructor for class
         * @details It sets the font entity it will manage
         * 
         * @param uU4DImage font entity
         */
        U4DRenderFont(U4DImage *uU4DImage);
        
        /**
         * @brief class destructor
         */
        ~U4DRenderFont();
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix and any rendering flags. It encodes the pipeline, buffers and issues the draw command
         * 
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         * @brief Updates the font rendering data
         * @details This method is called by the U4DText class whenever the text changes
         */
        void updateRenderingInformation();
        
        /**
         * @brief Modifies font rendering data if required
         * @details This method is called by the U4DText class. If the text container size changes, it loads a new set of attributes. 
         */
        void modifyRenderingInformation();
        
        /**
         * @brief clears all attributes containers
         * @details clears attributes containers such as vertices and UVs
         */
        void clearModelAttributeData();
        
    };
    
}

#endif /* U4DRenderFont_hpp */
