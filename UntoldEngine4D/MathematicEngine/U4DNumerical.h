//
//  U4DNumerical.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/6/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DNumerical_hpp
#define U4DNumerical_hpp

#include <stdio.h>
#include "Constants.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include <simd/simd.h>

namespace U4DEngine {
    
    /**
     @ingroup mathengine
     @brief The U4DNumerical provides numerical robustness in floating point comparison, rounding errors and random number generation
     */
    class U4DNumerical {
        
    private:
        
    public:
        
        /**
         @brief Default constructor for U4DNumerical
         */
        U4DNumerical();
        
        /**
         @brief Default destructor for U4DNumerical
         */
        ~U4DNumerical();
        
        /**
         @brief Method which compares if two floating value are equal using absolute comparison
         
         @param uNumber1 Floating value to compare
         @param uNumber2 Floating value to compare
         @param uEpsilon Epsilon used in comparison
         
         @return Returns true if two floating value are equal
         */
        bool areEqualAbs(float uNumber1, float uNumber2, float uEpsilon);
        
        /**
         @brief Method which compares if two floating value are equal using relative comparison
         
         @param uNumber1 Floating value to compare
         @param uNumber2 Floating value to compare
         @param uEpsilon Epsilon used in comparison
         
         @return Returns true if two floating value are equal
         */
        bool areEqualRel(float uNumber1, float uNumber2, float uEpsilon);
        
        /**
         @brief Method which compares if two floating value are equal
         
         @param uNumber1 Floating value to compare
         @param uNumber2 Floating value to compare
         @param uEpsilon Epsilon used in comparison
         
         @return Returns true if two floating value are equal
         */
        bool areEqual(float uNumber1, float uNumber2, float uEpsilon);
        
        /**
         @brief Document this
         */
        float getRandomNumberBetween(float uMinValue, float uMaxValue);
        
        /**
         * @brief Converts 4x4 matrix to SIMD format
         * @details Converts 4x4 matrix to SIMD format used by the GPU shaders
         *
         * @param uMatrix 3x3 Matrix
         * @return Matrix in SIMD format
         */
        matrix_float4x4 convertToSIMD(U4DEngine::U4DMatrix4n &uMatrix);
        
        /**
         * @brief Converts 3x3 matrix to SIMD format
         * @details Converts 3x3 matrix to SIMD format used by the GPU shaders
         *
         * @param uMatrix 3x3 Matrix
         * @return Matrix in SIMD format
         */
        matrix_float3x3 convertToSIMD(U4DEngine::U4DMatrix3n &uMatrix);
        
        /**
         * @brief Converts vector of 4 dimensions into SIMD format
         * @details Converts vector of 4n dimentsions into SIMD format
         *
         * @param uVector 4n vector dimension
         * @return vector in SIMD format
         */
        vector_float4 convertToSIMD(U4DEngine::U4DVector4n &uVector);
        
        /**
         * @brief Converts vector of 3 dimensions into SIMD format
         * @details Converts vector of 3n dimentsions into SIMD format
         *
         * @param uVector 3n vector dimension
         * @return vector in SIMD format
         */
        vector_float3 convertToSIMD(U4DEngine::U4DVector3n &uVector);
        
        /**
         * @brief Converts vector of 2 dimensions into SIMD format
         * @details Converts vector of 2n dimentsions into SIMD format
         *
         * @param uVector 2n vector dimension
         * @return vector in SIMD format
         */
        vector_float2 convertToSIMD(U4DEngine::U4DVector2n &uVector);
        
        /**
         * @brief Sets property used to determine if entity is within frustum
         * @details If the property is set, the entity is rendered, else is ignored
         *
         * @param uValue true for is within the frustum, false if is not
         */
            
    };

}


#endif /* U4DNumerical_hpp */
