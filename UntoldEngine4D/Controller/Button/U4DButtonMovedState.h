//
//  U4DButtonMovedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DButtonMovedState_hpp
#define U4DButtonMovedState_hpp

#include <stdio.h>
#include "U4DButton.h"
#include "U4DButtonStateInterface.h"

namespace U4DEngine {
    
    /**
     * @ingroup controller
     * @brief The U4DButtonMovedState class manages the state of the U4DButton when a move gesture is detected on the iOS device. This class is a singleton
     */
    class U4DButtonMovedState:public U4DButtonStateInterface {
        
    private:
        
        /**
         * @brief Class constructor
         * @details The constructor is set as private since the class is a singleton
         */
        U4DButtonMovedState();
        
        /**
         * @brief Class destructor
         */
        ~U4DButtonMovedState();
        
    public:
        
        /**
         * @brief Static variable to prevent multiple instances of the class to be created.
         * @details This is necessary since the class is a singleton
         */
        static U4DButtonMovedState* instance;
        
        /**
         * @brief Method to get a single instance of the class
         * @return gets one instance of the class
         */
        static U4DButtonMovedState* sharedInstance();
        
        /**
         * @brief Enter method
         * @details This methods initiazes any properties required for the state. For example, it may change the image of the button from pressed or released. 
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
#endif /* U4DButtonMovedState_hpp */
