//
//  U4DLight.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DLights.h"
#include "U4DDirector.h"
#include "U4DOpenGLLight.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
U4DLights::U4DLights(){

    setEntityType(LIGHT);
    
    U4DDirector *director=U4DDirector::sharedInstance();
    director->loadLight(this);
    
    openGlManager=new U4DOpenGLLight(this);
    openGlManager->setShader("lightShader");
    
    
    setLightSphere(0.1, 15, 15);
    
};

U4DLights::~U4DLights(){

#warning need to remove this light
    //remove the light from the director
};

void U4DLights::draw(){
    openGlManager->draw();
}

void U4DLights::setLightIndex(int uIndex){
    
    index=uIndex;
}

int U4DLights::getLightIndex(){
    
    return index;
}

void U4DLights::setLightSphere(float uRadius,int uRings, int uSectors){
    
    //radius=uRadius;
    float R=1.0/(uRings-1);
    float S=1.0/(uSectors-1);
    
    int r,s;
    
    for (r=0; r<uRings; r++) {
        
        for (s=0; s<uSectors; s++) {
            
            float uY=sin(-M_PI_2+M_PI*r*R);
            float uX=cos(2*M_PI * s * S) * sin( M_PI * r * R );
            float uZ=sin(2*M_PI * s * S) * sin( M_PI * r * R );
            
            uX*=uRadius;
            uY*=uRadius;
            uZ*=uRadius;
            
            U4DVector3n vec(uX,uY,uZ);
            
            bodyCoordinates.addVerticesDataToContainer(vec);
            
            //push to index
            int curRow=r*uSectors;
            int nextRow=(r+1)*uSectors;
            
            U4DIndex index(curRow+s,nextRow+s,nextRow+(s+1));
            bodyCoordinates.addIndexDataToContainer(index);
            
            U4DIndex index2(curRow+s,nextRow+s,curRow+(s+1));
            bodyCoordinates.addIndexDataToContainer(index2);

            
        }
    }
    
    
}

}