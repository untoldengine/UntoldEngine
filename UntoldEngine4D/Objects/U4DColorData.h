//
//  U4DColorData.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/1/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DColorData_hpp
#define U4DColorData_hpp

#include <stdio.h>


namespace U4DEngine {

    /**
     @brief The U4DColorData class holds color information for the 3D entity
     */
    class U4DColorData{
        
    private:
        
    public:
       
        /**
         @brief Array holding the four components of a color (red, green, blue, alpha)
         */
        float colorData[4]={0};
        
        /**
         @brief Constructor for the class
         
         @param uRed    Red component of color
         @param uGreen  Green component of color
         @param uBlue   Blue component of color
         @param uAlpha  Alpha component of color
         */
        U4DColorData(float &uRed, float &uGreen, float &uBlue, float &uAlpha);
        
        /**
         @brief Copy constructor
         */
        U4DColorData(const U4DColorData& uValue);
        
        /**
         @brief Copy constructor
         
         @param uValue Color object to copy
         
         @return Copy of a Color object
         */
        U4DColorData& operator=(const U4DColorData& uValue);
        
        /**
         @brief Destructor for the class
         */
        ~U4DColorData();
        
    };
}

#endif /* U4DColorData_hpp */
