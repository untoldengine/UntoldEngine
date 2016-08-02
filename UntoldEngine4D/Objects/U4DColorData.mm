//
//  U4DColorData.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/1/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DColorData.h"

namespace U4DEngine {
    
    U4DColorData::U4DColorData(float &uRed, float &uGreen, float &uBlue, float &uAlpha){
        
        colorData[0]=uRed;
        colorData[1]=uGreen;
        colorData[2]=uBlue;
        colorData[3]=uAlpha;
        
    }
    
    U4DColorData::U4DColorData(const U4DColorData& uValue){
        
        for (int i=0; i<4; i++) {
            
            colorData[i]=uValue.colorData[i];
        }
    }
    
    U4DColorData& U4DColorData::operator=(const U4DColorData& uValue){
        
        for (int i=0; i<4; i++) {
            
            colorData[i]=uValue.colorData[i];
        }
        
        return *this;
        
    }
    
    U4DColorData::~U4DColorData(){
        
    }
    
    
}