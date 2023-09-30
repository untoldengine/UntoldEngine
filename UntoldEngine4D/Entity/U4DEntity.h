//
//  U4DEntity.h
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 3/5/23.
//

#ifndef U4DEntity_h
#define U4DEntity_h
#include <stdio.h>
#include <bitset>
#include "Constants.h"

namespace U4DEngine {
typedef std::bitset<MAX_COMPONENTS> ComponentMask;
#define INVALID_ENTITY createEntityId(EntityIndex(-1),0)
inline EntityID createEntityId(EntityIndex index, EntityVersion version){
    
    //shift the index up 32, and put the version in the bottom
    return ((EntityID)index<<32) | ((EntityID)version);
}

inline EntityIndex getEntityIndex(EntityID id){
    //shift donw 32 so we lose the version and get out index
    return id>>32;
}

inline EntityVersion getEntityVersion(EntityID id){

    //Cast to a 32 bit int to get our version number (losing the top 32 bits)
    return (EntityVersion)id;
}

inline bool isEntityValid(EntityID id){
    //check if the index is our invalid index
    return (id>>32) != EntityIndex(-1);
}
}


#endif /* U4DEntity_h */
