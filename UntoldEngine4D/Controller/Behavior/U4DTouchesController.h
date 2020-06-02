//
//  U4DTouchesController.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DTouchesController__
#define __UntoldEngine__U4DTouchesController__

#include <iostream>
#include <vector>
#include "U4DGameController.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"
#include "U4DTouches.h"

namespace U4DEngine {
    
/**
 * @ingroup controller
 * @brief The U4DTouchesController class manages the touch inputs (buttons and joysticks) detected on iOS devices
 */
class U4DTouchesController:public U4DGameController{
  
private:
    
    U4DTouches *userTouch;
    
public:
    
    /**
     * @brief Constructor for class
     */
    U4DTouchesController();
    
    /**
     * @brief Destructor for class
     */
    ~U4DTouchesController();

    /**
     * @brief initialization method
     * @details In the initialization method, controller entities such as buttons and joysticks are created. callbacks are also created and linked
     */
    void init();
    
};

}

#endif /* defined(__UntoldEngine__U4DTouchesController__) */
