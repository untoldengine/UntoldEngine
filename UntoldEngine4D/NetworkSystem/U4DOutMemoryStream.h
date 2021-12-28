//
//  U4DOutMemoryStream.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DOutMemoryStream_hpp
#define U4DOutMemoryStream_hpp

#include <stdio.h>
#include <string>
#include <vector>
#include <cstdlib>
#include <algorithm>

namespace U4DEngine {

    class U4DOutMemoryStream {

    private:
        
        char * mBuffer;
        u_int32_t mHead;
        u_int32_t mCapacity;
        
        void reallocBuffer(u_int32_t inNewLength);
        
    public:
        
        U4DOutMemoryStream();

        ~U4DOutMemoryStream();

    
        //get a pointer to the data in the stream
        const char* getBufferPtr() const;
        u_int32_t getLength() const;
        
        template< typename T > void write( T inData )
        {
            static_assert( std::is_arithmetic< T >::value ||
                          std::is_enum< T >::value,
                          "Generic Write only supports primitive data types" );
                          write( &inData, sizeof( inData ) );
           
        }
        
        void write(const void* inData, size_t inByteCount);
        
        void write( const std::vector< int >& inIntVector );
            
        template< typename T >
        void write( const std::vector< T >& inVector )
        {
            u_int32_t elementCount = inVector.size();
            write( elementCount );
            for( const T& element : inVector )
            {
                Write( element );
            }
        }

        void write( const std::string& inString );
        
        
    };

}


#endif /* U4DOutMemoryStream_hpp */
