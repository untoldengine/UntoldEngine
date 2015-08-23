//
//  U4DSphericalBoundingTree.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/17/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DSphericalBoundingTree__
#define __UntoldEngine__U4DSphericalBoundingTree__

#include <iostream>
#include <vector>
#include "U4DOctTreeHierachy.h"
#include "U4DDynamicModel.h"


using namespace std;

class U4DSphericalBoundingTree:public U4DOctTreeHierachy{
  
private:
    
public:
    U4DSphericalBoundingTree(){};
    
    ~U4DSphericalBoundingTree(){};
    
   void addGeometry();
};

#endif /* defined(__UntoldEngine__U4DSphericalBoundingTree__) */
