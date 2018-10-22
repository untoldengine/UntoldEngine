//
//  U4DCameraInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/21/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCameraInterface_hpp
#define U4DCameraInterface_hpp

#include <stdio.h>

namespace U4DEngine {

    class U4DModel;

}

namespace U4DEngine {
    
    class U4DCameraInterface{
        
    private:
        
        
    public:
        
        virtual ~U4DCameraInterface(){};
        
        virtual void update(double dt)=0;
        
        virtual void setParameters(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset)=0;

    };
    
}

#endif /* U4DCameraInterface_hpp */
