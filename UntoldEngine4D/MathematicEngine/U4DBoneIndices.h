//
//  U4DBoneIndices.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/21/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoneIndices__
#define __UntoldEngine__U4DBoneIndices__

#include <iostream>

namespace U4DEngine {
    
class U4DBoneIndices{
    
private:
    
public:
    
    int x;
    
    int y;
    
    int z;
    
    int w;
    
    
    U4DBoneIndices():x(0),y(0),z(0),w(0){};
    
    
    U4DBoneIndices(int nx,int ny,int nz,int nw):x(nx),y(ny),z(nz),w(nw){}
    
    
    ~U4DBoneIndices(){};
    
    
    U4DBoneIndices(const U4DBoneIndices& a):x(a.x),y(a.y),z(a.z),w(a.w){};
    
    
    inline U4DBoneIndices& operator=(const U4DBoneIndices& a){
        
        x=a.x;
        y=a.y;
        z=a.z;
        w=a.w;
        
        return *this;
        
    };
    
    void show();
};

}

#endif /* defined(__UntoldEngine__U4DBoneIndices__) */
