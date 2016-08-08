//
//  U4DLight.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DLights__
#define __UntoldEngine__U4DLights__

#include <iostream>
#include "U4DEntity.h"

namespace U4DEngine {
    
    class U4DLights:public U4DEntity{
        
    private:
        
    protected:
        
        /**
         *  Light Constructor
         */
        U4DLights();
        
        /**
         *  Light Destructor
         */
        ~U4DLights();
        
        /**
         *  Copy constructor
         */
        U4DLights(const U4DLights& value);
        
        /**
         *  Copy constructor
         */
        U4DLights& operator=(const U4DLights& value);
        
    public:
        
        /**
         *  Instance for U4DLights Singleton
         */
        static U4DLights* instance;
        
        /**
         *  SharedInstance for U4DLights Singleton
         */
        static U4DLights* sharedInstance();
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DLights__) */
