//
//  Constants.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/21/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef UntoldEngine_Constants_h
#define UntoldEngine_Constants_h
#include <simd/simd.h>
namespace U4DEngine {
const int MAX_COMPONENTS=32;
const int MAX_ENTITIES=1000;

typedef unsigned long long  EntityID;
typedef unsigned int EntityIndex;
typedef unsigned int EntityVersion;

const int numOfVerticesPerBlock=24;
const int numOfIndicesPerBlock=36;
const int sizeOfChunk=32;
const int sizeOfChunkHalf=sizeOfChunk/2;
const unsigned long MaxNumberOfBlocks = sizeOfChunk*sizeOfChunk*sizeOfChunk;


const int maxNumberOfModels=1000;



}

#endif
