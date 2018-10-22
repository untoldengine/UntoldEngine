//
//  U4DCameraThirdPerson.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/21/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCameraThirdPerson_hpp
#define U4DCameraThirdPerson_hpp

#include <stdio.h>
#include "U4DCameraInterface.h"

namespace U4DEngine {
    
    class U4DModel;
    
}

namespace U4DEngine {
    
    class U4DCameraThirdPerson:public U4DCameraInterface{
        
    private:
        
        /**
         @brief Instace for the U4DCameraThirdPerson singleton
         */
        static U4DCameraThirdPerson* instance;
        
        U4DModel *model;
        
        float xOffset;
        
        float yOffset;
        
        float zOffset;
        
    protected:
        
        U4DCameraThirdPerson();
        
        ~U4DCameraThirdPerson();
        
    public:
        
        /**
         @brief Method which returns an instace of the U4DCameraThirdPerson singleton
         
         @return instance of the U4DCameraThirdPerson singleton
         */
        static U4DCameraThirdPerson* sharedInstance();
        
        void update(double dt);
        
        void setParameters(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset);
        
    };
    
}
#endif /* U4DCameraThirdPerson_hpp */
