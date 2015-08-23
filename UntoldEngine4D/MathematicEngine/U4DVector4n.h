//
//  U4DVector4n.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DVector4n__
#define __UntoldEngine__U4DVector4n__

#include <iostream>

namespace U4DEngine {
    
class U4DVector4n{
    
public:
    
    /**
     *  x-component
     */
    float x;
    
    /**
     *  y-component
     */
    float y;
    
    /**
     *  z-component
     */
    float z;
    
    float w;
    
    /**
     *  Constructor
     */
    U4DVector4n(){};
    
    /**
     *  Constructor initialized with three components
     */
    
    U4DVector4n(float nx,float ny,float nz,float nw):x(nx),y(ny),z(nz),w(nw){}
    
    /**
     *  Destructor
     */
    ~U4DVector4n(){};
    
    /**
     *  Copy constructor
     */
    U4DVector4n(const U4DVector4n& a):x(a.x),y(a.y),z(a.z),w(a.w){};
    
    /**
     *  Copy constructor
     */
    inline U4DVector4n& operator=(const U4DVector4n& a){
        
        x=a.x;
        y=a.y;
        z=a.z;
        w=a.w;
        
        return *this;
        
    };
    
    /**
     *  Debug-show the vector on the output log
     */
    void show();
    
    float getX();
    float getY();
    float getZ();
    float getW();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DVector4n__) */