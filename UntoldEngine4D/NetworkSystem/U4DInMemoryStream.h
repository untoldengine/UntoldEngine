//
//  U4DInMemoryStream.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DInMemoryStream_hpp
#define U4DInMemoryStream_hpp

#include <stdio.h>
#include <cstdlib>
#include <algorithm>
#include <vector>
#include <string>

namespace U4DEngine {

class U4DInMemoryStream {

private:

    char *mBuffer;
    u_int32_t mHead;
    u_int32_t mCapacity;
    
public:
    
    U4DInMemoryStream(char* inBuffer, u_int32_t inByteCount);

    ~U4DInMemoryStream();

    u_int32_t getRemainingDataSize() const;
    
    void read(void* outData, u_int32_t inByteCount);
    
    template< typename T > void read( T& outData )
        {
            static_assert( std::is_arithmetic< T >::value ||
                           std::is_enum< T >::value,
                           "Generic Read only supports primitive data types" );
            read( &outData, sizeof( outData ) );
        }
        
    template< typename T >
    void read( std::vector< T >& outVector )
    {
        size_t elementCount;
        read( elementCount );
        outVector.resize( elementCount );
        for( const T& element : outVector )
        {
            read( element );
        }
    }
    
    
};

}
#endif /* U4DInMemoryStream_hpp */
