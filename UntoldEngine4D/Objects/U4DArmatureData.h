//
//  U4DArmatureData.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DArmatureData__
#define __UntoldEngine__U4DArmatureData__

#include <iostream>
#include <vector>
#include "U4DDualQuaternion.h"

namespace U4DEngine {
class U4DBoneData;
class U4DModel;
}

namespace U4DEngine {
    
class U4DArmatureData{
    
private:
    
    U4DModel    *u4dModel;
    
public:
    
    U4DArmatureData(U4DModel *uModel);
    
    ~U4DArmatureData();
    
    U4DBoneData* rootBone;
    
    U4DDualQuaternion bindShapeSpace;
    
    std::vector<U4DBoneData*> boneDataContainer;
    
    void addBoneToTree(U4DBoneData *uParent,U4DBoneData *uChild);
    void removeBoneFromTree(std::string uChildBoneName);
    
    void updateBoneIndexCount();
    void setRootBone(U4DBoneData* uBoneData);

    void setVertexWeightsAndBoneIndices();
    
    void prepareAndSendBoneDataToBuffer(std::vector<U4DBoneData*> &uBoneDataContainer,int boneVertexWeightIndex);
    void reHeapDown(std::vector<U4DBoneData*> &uBoneDataContainer,int boneVertexWeightIndex, int root, int bottom);
    void heapSorting(std::vector<U4DBoneData*> &uBoneDataContainer,int boneVertexWeightIndex);
    void swap(std::vector<U4DBoneData*> &uBoneDataContainer,int uindex1, int uindex2);
    
    void setBoneDataContainer();
    void setBoneAbsoluteSpace();
    void setRestPoseMatrix();
};
    
}

#endif /* defined(__UntoldEngine__U4DArmatureData__) */
