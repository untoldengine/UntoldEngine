//
//  U4DOctTreeHierachy.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/17/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOctTreeHierachy__
#define __UntoldEngine__U4DOctTreeHierachy__

#include <iostream>
#include "U4DCollisionEngine.h"
#include "U4DBoundingVolume.h"
#include "U4DVector3n.h"
#include "U4DDynamicModel.h"


class U4DCollisionEngine;

class U4DOctTreeHierachy{
    
private:
    
protected:
    
    U4DDynamicModel* body;
    
public:
    
    U4DOctTreeHierachy(){};
    
    ~U4DOctTreeHierachy(){};
    
    struct TreeCoordinates{
        U4DVector3n dimensions;
        U4DVector3n position;
    };
    
    TreeCoordinates treeCoordinates;
    vector<U4DOctTreeHierachy*> children;
    
    U4DBoundingVolume* childrenGeometry;
        
    void add(U4DOctTreeHierachy *uChild);
    //void add(U4DBoundingVolume* uChild);
    
    void remove(U4DOctTreeHierachy *uChild);
    U4DOctTreeHierachy *getChild(int i);
    
    void buildTree(U4DDynamicModel* uBody);
    vector<U4DVector3n> innerCubeVertices(float uWidth,float uHeight,float uDepth);
    
    virtual void addGeometry(){};
};

#endif /* defined(__UntoldEngine__U4DOctTreeHierachy__) */
