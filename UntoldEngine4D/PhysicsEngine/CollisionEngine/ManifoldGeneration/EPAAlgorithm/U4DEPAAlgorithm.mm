//
//  U4DEPAAlgorithm.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DEPAAlgorithm.h"

namespace U4DEngine{
    
    void U4DEPAAlgorithm::determineCollisionManifold(U4DStaticModel* uModel1, U4DStaticModel* uModel2, std::vector<U4DSimplexStruct> uQ){
        
        //determine penetration and normal vector
        
        //steps
        
        //1. Build the initial polytope from the tetrahedron  produced by GJK
        
        //2. Pick the closest face of the polytope to the origin
        
        //3. Generate the next point to be included in the polytope by getting the support point in the direction of the picked
        //triangle's normal
        
        //4. If this point is no further from the origin than the picked triangle then go to step 7.
        
        //5. Remove all faces from the polytop that can be seen by this new point, this will create a hole
        // that must be filled with new faces built from the new support point in the remaining points from the old faces.
        
        //6. Go to step 2
        
        //7. Use the current closest triangle to the origin to extrapolate the contact information
        
        
        
    }
    
    
}