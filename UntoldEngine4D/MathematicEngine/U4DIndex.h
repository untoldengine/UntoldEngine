//
//  U4DIndex.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DIndex__
#define __UntoldEngine__U4DIndex__

#include <iostream>

namespace U4DEngine {
    
/**
 *  Class in charge of index
 */

class U4DIndex{
  
private:
    
public:
    /**
     *  x-index
     */
    int x;
    
    /**
     *  y-index
     */
    int y;
    
    /**
     *  z-index
     */
    int z;
    
    /**
     *  Constructor
     */
    U4DIndex():x(0),y(0),z(0){};
    
    /**
     *  Constructor
     *
     *  @param nx     x-index
     *  @param ny     y-index
     *  @param nz     z-index
     */
    U4DIndex(int nx,int ny,int nz):x(nx),y(ny),z(nz){}
    
    /**
     *  Destructor
     */
    ~U4DIndex(){};
    
    /**
     *  Copy Constructor
     */
    U4DIndex(const U4DIndex& a):x(a.x),y(a.y),z(a.z){};
    
    /**
     *  Copy Constructor
     */
    inline U4DIndex& operator=(const U4DIndex& a){
        
        x=a.x;
        y=a.y;
        z=a.z;
        
        return *this;
        
    };
    
    /**
     *  Debug-show the vector on the output log
     */
    void show();
    
};
    
}
#endif /* defined(__UntoldEngine__U4DIndex__) */
