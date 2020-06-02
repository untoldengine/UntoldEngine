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

    class U4DLayer:public U4DEntity {
        
    private:
        
        U4DImage backgroundImage;
        
    public:
        
        //contructor
        U4DLayer(std::string uLayerName);
        
        //destructor
        ~U4DLayer();
        
        virtual void init(){};
        
        void update(double dt);
        
        void setBackgroundImage(const char* uBackGroundImage);
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
    };

}


#endif /* U4DLayer_hpp */
