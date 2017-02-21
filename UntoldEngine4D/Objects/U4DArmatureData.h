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

/**
 @brief The U4DArmatureData class represents the bone armature of the 3D entity
 */
class U4DArmatureData{
    
private:
    
    /**
     @brief Pointer to the 3D entity whose armature belongs to
     */
    U4DModel    *u4dModel;
    
public:
    
    /**
     @brief Constructor for the class
     */
    U4DArmatureData(U4DModel *uModel);
    
    /**
     @brief Destructor for the class
     */
    ~U4DArmatureData();
    
    /**
     @brief Pointer to the bone representing the root bone.
     */
    U4DBoneData* rootBone;
    
    /**
     @brief Bind shape space of the armature
     */
    U4DDualQuaternion bindShapeSpace;
    
    /**
     @brief Container holding all bones belonging to the armature
     */
    std::vector<U4DBoneData*> boneDataContainer;
    
    /**
     @brief Method which adds a bone to the armature tree
     
     @param uParent Parent of the bone
     @param uChild  Bone to add
     */
    void addBoneToTree(U4DBoneData *uParent,U4DBoneData *uChild);
    
    /**
     @brief Method which removes a bone from the armature tree
     
     @param uChildBoneName Bone to remove
     */
    void removeBoneFromTree(std::string uChildBoneName);
    
    /**
     @brief Method which updates the bone index count
     */
    void updateBoneIndexCount();
    
    /**
     @brief Method which assigns a bone to be the root bone for the armature
     
     @param uBoneData Bone to assign as root bone
     */
    void setRootBone(U4DBoneData* uBoneData);

    /**
     @brief Method which starts the bone sorting and prepares the attribute data (bone weight) of the bones
     */
    void setVertexWeightsAndBoneIndices();
    
    /**
     @brief Method which sends bone weight and indices (attributes) to the opengl buffer
     
     @param uBoneDataContainer    Armature bone container
     @param boneVertexWeightIndex Bone vertex weight array index
     */
    void prepareAndSendBoneDataToBuffer(std::vector<U4DBoneData*> &uBoneDataContainer,int boneVertexWeightIndex);
    
    /**
     @brief Method use to heap-down sort the bones
     
     @param uBoneDataContainer    Armature bone container
     @param boneVertexWeightIndex Bone vertex weight array index
     @param root                  index of root bone
     @param bottom                bottom index
     */
    void reHeapDown(std::vector<U4DBoneData*> &uBoneDataContainer,int boneVertexWeightIndex, int root, int bottom);
    
    /**
     @brief Method to heap sort the bones
     
     @param uBoneDataContainer    Armature bone container
     @param boneVertexWeightIndex Bone vertex weight array index
     */
    void heapSorting(std::vector<U4DBoneData*> &uBoneDataContainer,int boneVertexWeightIndex);
    
    /**
     @brief Method used to swap the bone's array index
     
     @param uBoneDataContainer Armature bone container
     @param uindex1            Bone array index
     @param uindex2            Bone array index
     */
    void swap(std::vector<U4DBoneData*> &uBoneDataContainer,int uindex1, int uindex2);
    
    /**
     @brief Method which adds bones to the armature bone container
     */
    void setBoneDataContainer();
    
    /**
     @brief Method which sets the absolute space of the bone
     */
    void setBoneAbsoluteSpace();
    
    /**
     @brief Method which sets the rest pose matrix of each bone
     */
    void setRestPoseMatrix();
    
    
};
    
}

#endif /* defined(__UntoldEngine__U4DArmatureData__) */
