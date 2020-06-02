//
//  U4DLayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/20/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DLayer.h"
#include "U4DDirector.h"

namespace U4DEngine {

    //contructor
    U4DLayer::U4DLayer(std::string uLayerName){
        
        //set name for layer
        setName(uLayerName);
        
    }

    //destructor
    U4DLayer::~U4DLayer(){
        
    }

    void U4DLayer::update(double dt){
        
    }

    void U4DLayer::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        
        backgroundImage.render(uRenderEncoder);
          
        
    }

    void U4DLayer::setBackgroundImage(const char* uBackGroundImage){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        float width=director->getDisplayWidth();
        float height=director->getDisplayHeight();
        
        backgroundImage.setImage(uBackGroundImage,width,height);
        
    }

}

