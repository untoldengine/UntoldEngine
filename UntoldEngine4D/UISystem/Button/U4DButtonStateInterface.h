//
//  U4DButtonStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DButtonStateInterface_hpp
#define U4DButtonStateInterface_hpp

#include <stdio.h>
#include "U4DButton.h"

namespace U4DEngine {
    
    /**
     * @ingroup controller
     * @brief The U4DButtonStateInterface controls the state objects of the button, such as idle, pressed, moved, released
     */
    class U4DButtonStateInterface {
        
        
    public:
        
        virtual ~U4DButtonStateInterface(){};
        
        /**
         * @brief Enter method
         * @details This methods initiazes any properties required for the state. For example, it may change the image of the button from pressed or released. 
         * 
         * @param uButton button entity
         */
        virtual void enter(U4DButton *uButton)=0;
        
        /**
         * @brief Execution method
         * @details This method is constantly being called by the state manager. It manages any state changes
         * 
         * @param uButton button entity
         * @param dt game tick
         */
        virtual void execute(U4DButton *uButton, double dt)=0;
        
        /**
         * @brief Exit method
         * @details This method is called before changing to a new state. It resets any needed properties of the entity
         * 
         * @param uButton button entity
         */
        virtual void exit(U4DButton *uButton)=0;
        
    };
    
}

#endif /* U4DButtonStateInterface_hpp */
