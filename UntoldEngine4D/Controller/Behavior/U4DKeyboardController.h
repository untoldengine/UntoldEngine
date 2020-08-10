//
//  U4DKeyboardInput.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __MVCTemplate__U4DKeyboardInput__
#define __MVCTemplate__U4DKeyboardInput__

#include <iostream>
#include <vector>
#include "U4DGameController.h"
#include "U4DMacKey.h"
#include "U4DMacMouse.h"
#include "U4DMacArrowKey.h"
#include "CommonProtocols.h"


namespace U4DEngine {
    
    /**
     * @ingroup controller
     * @brief The U4DKeyboardController class manages the user inputs detected on the keyboard and mouse on a mac
     */
    class U4DKeyboardController:public U4DGameController{
        
    private:

        U4DMacKey *keyW;
        U4DMacKey *keyA;
        U4DMacKey *keyD;
        U4DMacKey *keyS;
        U4DMacArrowKey *arrowKey;
        U4DMacKey *macKeyShift;
        U4DMacKey *macKeySpace;
        U4DMacMouse *mouseLeftButton;
        U4DMacMouse *macMouse;
        
    public:

        /**
         * @brief Constructor for class
         */
        U4DKeyboardController();
        
        /**
         * @brief Destructor for class
         */
        ~U4DKeyboardController();
        
        /**
         * @brief Initialization method
         * @details In the initialization method, controller entities such as mac keys and mouse are created. Callbacks are also created and linked.
         */
        void init();
        
        void getUserInputData(unichar uCharacter, INPUTELEMENTACTION uInputAction);
        

    };
    
}

#endif /* defined(__MVCTemplate__U4DKeyboardInput__) */
