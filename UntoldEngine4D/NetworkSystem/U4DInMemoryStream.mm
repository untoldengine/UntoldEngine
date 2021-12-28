//
//  U4DInMemoryStream.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DInMemoryStream.h"

namespace U4DEngine {

U4DInMemoryStream::U4DInMemoryStream(char* inBuffer, u_int32_t inByteCount):mBuffer(inBuffer),mCapacity(inByteCount),mHead(0){
     
}

U4DInMemoryStream::~U4DInMemoryStream(){
    //Commenting this line out since enet_packet_destroy is already destroying the packet
    //std::free(mBuffer);
    
}

u_int32_t U4DInMemoryStream::getRemainingDataSize() const{
    return mCapacity-mHead;
}

void U4DInMemoryStream::read(void* outData, u_int32_t inByteCount){
    
    u_int32_t resultHead=mHead+inByteCount;
    
    if (resultHead>mCapacity) {
        //handle error, no data to read
    }
    
    std::memcpy(outData, mBuffer+mHead, inByteCount);
    
    mHead=resultHead;
}


}
