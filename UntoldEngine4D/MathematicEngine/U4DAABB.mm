//
//  U4DAABB.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/28/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DAABB.h"

namespace U4DEngine {

    U4DAABB::U4DAABB(){
        
        
    }
    
    U4DAABB::~U4DAABB(){
        
    }
    
    U4DAABB::U4DAABB(U4DPoint3n &uMinPoint, U4DPoint3n &uMaxPoint){
        
        minPoint=uMinPoint;
        maxPoint=uMaxPoint;
        
    }
    
    void U4DAABB::setMinPoint(U4DPoint3n& uMinPoint){
        
        minPoint=uMinPoint;
    }
    
    void U4DAABB::setMaxPoint(U4DPoint3n& uMaxPoint){
        
        maxPoint=uMaxPoint;
        
    }
    
    U4DPoint3n U4DAABB::getMinPoint(){
        return minPoint;
    }
    
    U4DPoint3n U4DAABB::getMaxPoint(){
        return maxPoint;
    }
    
    
    bool U4DAABB::didCollideWithAABB(U4DAABB &uAABB){
        
        //Exit with no intersection if separated along an axis
        
        if (maxPoint.x<uAABB.minPoint.x || minPoint.x>uAABB.maxPoint.x) return false;
        if (maxPoint.y<uAABB.minPoint.y || minPoint.y>uAABB.maxPoint.y) return false;
        if (maxPoint.z<uAABB.minPoint.z || minPoint.z>uAABB.maxPoint.z) return false;
        
        //overlapping on all axes means AABBs are intersecting
        
        return true;
    }
    
}