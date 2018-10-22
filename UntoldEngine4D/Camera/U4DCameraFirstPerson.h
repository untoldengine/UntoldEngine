//
//  U4DCameraFirstPerson.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/21/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCameraFirstPerson_hpp
#define U4DCameraFirstPerson_hpp

#include <stdio.h>
#include "U4DCameraInterface.h"

namespace U4DEngine {
    
    class U4DModel;
    
}

namespace U4DEngine {
    
    class U4DCameraFirstPerson:public U4DCameraInterface{
        
    private:
        
        /**
         @brief Instace for the U4DCameraFirstPerson singleton
         */
        static U4DCameraFirstPerson* instance;
        
        U4DModel *model;
        
        float xOffset;
        
        float yOffset;
        
        float zOffset;
        
    protected:
        
        U4DCameraFirstPerson();
        
        ~U4DCameraFirstPerson();
        
    public:
        
        /**
         @brief Method which returns an instace of the U4DCameraFirstPerson singleton
         
         @return instance of the U4DCameraFirstPerson singleton
         */
        static U4DCameraFirstPerson* sharedInstance();
        
        void update(double dt);
        
        void setParameters(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset);
        
    };
    
}
#endif /* U4DCameraFirstPerson_hpp */
