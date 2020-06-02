//
//  U4DButtonPressedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DButtonPressedState_hpp
#define U4DButtonPressedState_hpp

#include <stdio.h>
#include "U4DButton.h"
#include "U4DButtonStateInterface.h"

namespace U4DEngine {
    
    /**
     * @ingroup controller
     * @brief The U4DButtonPressedState class manages the pressed state of the button. This class is a singleton
     */
    class U4DButtonPressedState:public U4DButtonStateInterface {
        
    private:
        
        /**
         * @brief Class constructor
         * @details The constructor is set as private since the class is a singleton
         */
        U4DButtonPressedState();
        
        /**
         * @brief Class destructor
         */
        ~U4DButtonPressedState();
        
    public:
        
        /**
         * @brief Static variable to prevent multiple instances of the class to be created.
         * @details This is necessary since the class is a singleton
         */
        static U4DButtonPressedState* instance;
        
        /**
         * @brief Method to get a single instance of the class
         * @return gets one instance of the class
         */
        static U4DButtonPressedState* sharedInstance();
        
        /**
         * @brief Enter method
         * @details It calls the callback action and changes the image of the button
         * 
         * @param uButton button entity
         */
        void enter(U4DButton *uButton);
        
        /**
         * @brief Execution method
         * @details This method is constantly being called by the state manager. It manages any state changes
         * 
         * @param uButton button entity
         * @param dt game tick
         */
        void execute(U4DButton *uButton, double dt);
        
        /**
         * @brief Exit method
         * @details This method is called before changing to a new state. It resets any needed properties of the entity
         * 
         * @param uButton button entity
         */
        void exit(U4DButton *uButton);
        
    };
    
}
#endif /* U4DButtonPressedState_hpp */
