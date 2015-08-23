//
//  U4DBoneData.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoneData__
#define __UntoldEngine__U4DBoneData__

#include <iostream>
#include <vector>
#include <string>

#include "U4DMatrix4n.h"
#include "U4DDualQuaternion.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
class U4DBoneData{
    
private:
    
    
public:

    U4DBoneData();
    ~U4DBoneData();
    
    std::string name;
    
    int index;
    
    U4DDualQuaternion localSpace;
    
    U4DDualQuaternion absoluteSpace;
    
    U4DDualQuaternion finalSpace;

    U4DDualQuaternion inverseBindPoseSpace;

    U4DDualQuaternion bindPoseSpace;
  
    U4DDualQuaternion restAbsolutePoseSpace;
    
    U4DDualQuaternion animationPoseSpace;
    
    std::vector<float> vertexWeightContainer;
    
    U4DBoneData *parent;
    
    U4DBoneData *prevSibling;
    
    U4DBoneData *next;
    
    U4DBoneData *lastDescendant;
    
    U4DBoneData *getFirstChild();
    
    U4DBoneData *getLastChild();
    
    U4DBoneData *getNextSibling();
    
    U4DBoneData *getPrevSibling();
    
    U4DBoneData *prevInPreOrderTraversal();
    
    U4DBoneData *nextInPreOrderTraversal();
    
    void addBoneToTree(U4DBoneData *uChild);
    
    void removeBoneFromTree(U4DBoneData *uChild);
    
    void changeLastDescendant(U4DBoneData *uNewLastDescendant);
    
    U4DBoneData *searchChildrenBone(std::string uBoneName);
    
    void iterateChildren();
    
    bool isLeaf();
    
    bool isRoot();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DBoneData__) */
