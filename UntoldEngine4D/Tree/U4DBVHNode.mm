//
//  U4DBVHNode.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/8/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBVHNode_mm
#define U4DBVHNode_mm

#include "U4DBVHNode.h"

namespace U4DEngine {
    
    template <typename T>
    U4DBVHNode<T>::U4DBVHNode():splitIndex(0){
        
        aabbVolume=new U4DAABB();
    }
    
    template <typename T>
    U4DBVHNode<T>::~U4DBVHNode(){
        
        delete aabbVolume;
        
    }
    
    template <typename T>
    U4DAABB* U4DBVHNode<T>::getAABBVolume(){
        return aabbVolume;
    }
    
    template <typename T>
    std::vector<T *> U4DBVHNode<T>::getModelsContainer(){
        
        return modelsContainer;
    
    }
    
    template <typename T>
    void U4DBVHNode<T>::addModelToContainer(T *uModel){
        
        modelsContainer.push_back(uModel);
    }

    template <typename T>
    void U4DBVHNode<T>::addModelToContainerAtIndex(int uIndex, T *uModel){
        
        modelsContainer.at(uIndex)=uModel;
    }
  
    template <typename T>
    void U4DBVHNode<T>::copyModelsContainer(std::vector<T *> uModelsContainer){
        
        modelsContainer=uModelsContainer;
    }
    
    template <typename T>
    void U4DBVHNode<T>::setSplitIndex(int uSplitIndex){
        
        splitIndex=uSplitIndex;
    }
    
    template <typename T>
    int U4DBVHNode<T>::getSplitIndex(){
        
        return splitIndex;
    }

}

#endif
