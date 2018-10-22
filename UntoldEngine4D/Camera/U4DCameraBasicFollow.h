//
//  U4DCameraBasicFollow.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/21/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCameraBasicFollow_hpp
#define U4DCameraBasicFollow_hpp

#include <stdio.h>
#include "U4DCameraInterface.h"

namespace U4DEngine {
    
    class U4DModel;
    
}

namespace U4DEngine {
    
    class U4DCameraBasicFollow:public U4DCameraInterface{
        
    private:
        
        /**
         @brief Instace for the U4DCameraBasicFollow singleton
         */
        static U4DCameraBasicFollow* instance;
        
        U4DModel *model;
        
        float xOffset;
        
        float yOffset;
        
        float zOffset;
        
    protected:
        
        U4DCameraBasicFollow();
        
        ~U4DCameraBasicFollow();
        
    public:
        
        /**
         @brief Method which returns an instace of the U4DCameraBasicFollow singleton
         
         @return instance of the U4DCameraBasicFollow singleton
         */
        static U4DCameraBasicFollow* sharedInstance();
        
        void update(double dt);
        
        void setParameters(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset);
        
    };
    
}
#endif /* U4DCameraBasicFollow_hpp */
