//
//  U4DButtonStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DButtonStateManager_hpp
#define U4DButtonStateManager_hpp

#include <stdio.h>
#include "U4DButtonStateInterface.h"

class U4DButton;

namespace U4DEngine {
    
    /**
     * @ingroup controller
     * @brief The U4DButtonStateManager class manages the state of the U4DButton
     */
    class U4DButtonStateManager{
        
    private:
        
        /**
         * @brief Pointer to the U4DButton entity
         */
        U4DButton *button;
        
        /**
         * @brief U4DButton previous state
         */
        U4DButtonStateInterface *previousState;

        /**
         * @brief U4DButton current state
         */
        U4DButtonStateInterface *currentState;
        
    public:
        
        /**
         * @brief Class constructor
         * @details Initializes the U4DButton states previous and current to null. It also sets the U4DButton it will manage
         * 
         * @param uButton U4DButton entity
         */
        U4DButtonStateManager(U4DButton *uButton);
        
        /**
         * @brief Class destructor
         */
        ~U4DButtonStateManager();
        
        /**
         * @brief Changes the state of the U4DButton entity
         * @details Before changing states, it calls the exit and enter methods of current state
         * 
         * @param uState button state object
         */
        void changeState(U4DButtonStateInterface *uState);
        
        /**
         * @brief Calls the execute method of the current state
         * @details This method is constantly called during every game tick
         * @param dt game tick
         */
        void update(double dt);
        
        /**
         * @brief Gets the current state of the U4DButton entity
         * @return Current state
         */
        U4DButtonStateInterface *getCurrentState();
        
    };
    
}

#endif /* U4DButtonStateManager_hpp */
