//
//  U4DColorData.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/1/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DColorData_hpp
#define U4DColorData_hpp

#include <stdio.h>

namespace U4DEngine {
    
    class U4DColorData{
        
    private:
        
    public:
        
        float colorData[4]={0};
        
        U4DColorData(float &uRed, float &uGreen, float &uBlue, float &uAlpha);
        
        U4DColorData(const U4DColorData& uValue);
        
        U4DColorData& operator=(const U4DColorData& uValue);
        
        ~U4DColorData();
        
    };
}

#endif /* U4DColorData_hpp */
