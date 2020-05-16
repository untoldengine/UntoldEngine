//
//  U4DInputElement.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/8/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DInputElement_hpp
#define U4DInputElement_hpp

#include <stdio.h>
#include "U4DVector2n.h"
#include "CommonProtocols.h"

namespace U4DEngine{
    class U4DControllerInterface;
}

namespace U4DEngine {

    class U4DInputElement {
        
        private:

        protected:
            
            INPUTELEMENTTYPE inputElementType;
        
        public:
            
            U4DInputElement(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface);
            
            ~U4DInputElement();
        
            U4DControllerInterface *controllerInterface;
        
            INPUTELEMENTTYPE getInputElementType();
        
            void setControllerInterface(U4DControllerInterface* uControllerInterface);
            
            virtual void changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition){};
            
            virtual void update(double dt){};
        
    };

}



#endif /* U4DInputElement_hpp */
