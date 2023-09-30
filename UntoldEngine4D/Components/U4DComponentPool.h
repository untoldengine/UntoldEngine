//
//  ComponentPool.hpp
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 3/5/23.
//

#ifndef U4DComponentPool_hpp
#define U4DComponentPool_hpp

#include <stdio.h>
#include "Constants.h"

namespace U4DEngine {

    extern int s_componentCounter;
    template <class T>
    int getComponentId(){
        static int s_componentId=s_componentCounter++;
        return s_componentId;
        
    }

    //component pool
    struct U4DComponentPool{
      
        U4DComponentPool(size_t uElementSize){
            elementSize=uElementSize;
            pData=new char[elementSize*MAX_ENTITIES];
        }
        
        ~U4DComponentPool(){
            delete[] pData;
        }
        
        inline void *get(size_t uIndex){
            //looking up the component at the desired index
            return pData+uIndex*elementSize;
        }
        
        char* pData{nullptr};
        size_t elementSize{0};
    };

}

#endif /* ComponentPool_hpp */
