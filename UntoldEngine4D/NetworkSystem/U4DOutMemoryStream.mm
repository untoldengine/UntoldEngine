//
//  U4DOutMemoryStream.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DOutMemoryStream.h"

namespace U4DEngine {

void U4DOutMemoryStream::reallocBuffer(u_int32_t inNewLength){
    
    mBuffer=static_cast<char*>(std::realloc(mBuffer, inNewLength));
    
    //we have to handle any realloc failure here
    
    mCapacity=inNewLength;
    
}

U4DOutMemoryStream::U4DOutMemoryStream():mBuffer(nullptr),mHead(0),mCapacity(0){
    
    reallocBuffer(32);
}

U4DOutMemoryStream::~U4DOutMemoryStream(){
    std::free(mBuffer);
}



//get a pointer to the data in the stream
const char* U4DOutMemoryStream::getBufferPtr() const{
    return mBuffer;
    
}
u_int32_t U4DOutMemoryStream::getLength() const {
    return mHead;
    
}


void U4DOutMemoryStream::write(const void* inData, size_t inByteCount){
    
    //make sure we have space
    u_int32_t resultHead=mHead+static_cast<u_int32_t>(inByteCount);
    if (resultHead>mCapacity) {
        reallocBuffer(std::max(mCapacity*2,resultHead));
    }
    
    //copy into buffer at head
    std::memcpy(mBuffer+mHead,inData,inByteCount);
    
    //increment head for next write
    mHead=resultHead;
}

void U4DOutMemoryStream::write( const std::vector< int >& inIntVector )
    {
        size_t elementCount = inIntVector.size();
        write( elementCount );
        write( inIntVector.data(), elementCount * sizeof( int ) );
    }


void U4DOutMemoryStream::write( const std::string& inString ){
        size_t elementCount = inString.size() ;
        write(elementCount);
        write( inString.data(), elementCount * sizeof( char ) );
    }

}
