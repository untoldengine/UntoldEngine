//
//  U4DLayer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/20/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DLayer_hpp
#define U4DLayer_hpp

#include <stdio.h>
#include "U4DEntity.h"
#include "U4DImage.h"
#include <string>

namespace U4DEngine {

    /**
    @ingroup scene
    @brief The U4DLayer class represents layer objects. Layers are object that can be rendered on top of the view component.
    */
    class U4DLayer:public U4DEntity {
        
    private:
        
        /**
         @brief background image for the layer
         */
        U4DImage backgroundImage;
        
    public:
        
        /**
         @brief Layer constructor
         @param uLayerName layer name
         */
        U4DLayer(std::string uLayerName);
        
        /**
         @brief Layer class destructor
         */
        virtual ~U4DLayer();
        
        /**
         @brief init method for the layer
         */
        virtual void init(){};
        
        /**
         @brief update the layer during every game tick
         @param dt game tick
         */
        void update(double dt);
        
        /**
         @brief sets the background image for the layer
         @param uBackGroundImage layer background image name
         */
        void setBackgroundImage(const char* uBackGroundImage);
        
        /**
         @brief renders the layer object
         @param uRenderEncoder encoder for metal rendering
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
    };

}


#endif /* U4DLayer_hpp */
