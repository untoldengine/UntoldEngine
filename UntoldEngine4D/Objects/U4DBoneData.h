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

/**
 @brief The U4DBoneData class holds bone information for the 3D entity
 */
class U4DBoneData{
    
private:
    
    
public:

    /**
     @brief Constructor for the class
     */
    U4DBoneData();
    
    /**
     @brief Destructor for the class
     */
    ~U4DBoneData();
    
    /**
     @brief Name of bone
     */
    std::string name;
    
    /**
     @brief Index of bone
     */
    int index;
    
    /**
     @brief Local space of the bone
     */
    U4DDualQuaternion localSpace;
    
    /**
     @brief Absolute space of the bone
     */
    U4DDualQuaternion absoluteSpace;
    
    /**
     @brief Final space of the bone
     */
    U4DDualQuaternion finalSpace;

    /**
     @brief Inverse bind pose space of the bone
     */
    U4DDualQuaternion inverseBindPoseSpace;

    /**
     @brief Bind pose space of the bone
     */
    U4DDualQuaternion bindPoseSpace;
  
    /**
     @brief Absolute space of the bone in rest position
     */
    U4DDualQuaternion restAbsolutePoseSpace;
    
    /**
     @brief Pose space of the bone during animation
     */
    U4DDualQuaternion animationPoseSpace;
    
    /**
     @brief Container holding the vertex weights of the bone
     */
    std::vector<float> vertexWeightContainer;
    
    /**
     @brief Bone parent
     */
    U4DBoneData *parent;
    
    /**
     @brief Bone previous sibling
     */
    U4DBoneData *prevSibling;
    
    /**
     @brief Bone Next pointer
     */
    U4DBoneData *next;
    
    /**
     @brief Bone last descendant
     */
    U4DBoneData *lastDescendant;
    
    /**
     @brief Method which returns the first child of the bone in the scenegraph
     
     @return First child of the bone
     */
    U4DBoneData *getFirstChild();
    
    /**
     @brief Method which returns the last child of the bone in the scenegraph
     
     @return Last child of the bone
     */
    U4DBoneData *getLastChild();
    
    /**
     @brief Method which returns the next sibling of the bone in the scenegraph
     
     @return Next sibling of the bone
     */
    U4DBoneData *getNextSibling();
    
    /**
     @brief Method which returns the previous sibling of the bone in the scenegraph
     
     @return Previous sibling of the bone
     */
    U4DBoneData *getPrevSibling();
    
    /**
     @brief Method which returns the bone's previous sibling in pre-order traversal order
     
     @return Returns the bone's previous sibling in pre-order traversal order
     */
    U4DBoneData *prevInPreOrderTraversal();
    
    /**
     @brief Method which returns the bone's next pointer in pre-order traversal order
     
     @return Returns the bone's next pointer in pre-order traversal order
     */
    U4DBoneData *nextInPreOrderTraversal();
    
    /**
     @brief Method which adds a bone to the scenegraph
     
     @param uChild Bone to add to the scenegraph
     */
    void addBoneToTree(U4DBoneData *uChild);
    
    /**
     @brief Method which removes a bone from the scenegraph
     
     @param uChild Bone to remove from the scenegraph
     */
    void removeBoneFromTree(U4DBoneData *uChild);
    
    /**
     @brief Method which changes the bone's last descendant in the scenegraph
     
     @param uNewLastDescendant Last descendant of the bone
     */
    void changeLastDescendant(U4DBoneData *uNewLastDescendant);
    
    /**
     @brief Method which searches for a bone children in the scenegraph
     
     @param uBoneName Bone's name
     
     @return Children bone with the given name
     */
    U4DBoneData *searchChildrenBone(std::string uBoneName);
    
    /**
     @todo document this
     */
    int getChildrenBoneIndex(std::string uBoneName);
    
    /**
     @brief Method which returns true if the bone represents a leaf node in the scenegraph
     
     @return Returns true if the bone represents a leaf node in the scenegraph
     */
    bool isLeaf();
    
    /**
     @brief Method which returns true if the bone represents a root node in the scenegraph
     
     @return Returns true if the bone represents a root node in the scenegraph
     */
    bool isRoot();
    
    /**
     @todo document this
     */
    U4DDualQuaternion getBoneAnimationPoseSpace();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DBoneData__) */
