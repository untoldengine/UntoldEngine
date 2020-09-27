//
//  U4DCheckbox.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/23/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCheckbox_hpp
#define U4DCheckbox_hpp

#include <stdio.h>
#include <vector>
#include "U4DDirector.h"
#include "U4DEntity.h"
#include "U4DCallbackInterface.h"
#include "CommonProtocols.h"
#include "U4DShaderEntity.h"

namespace U4DEngine {
    class U4DImage;
    class U4DControllerInterface;
    class U4DText;
}

namespace U4DEngine {

/**
 * @ingroup controller
 * @brief The U4DCheckbox class manages slider entities
 *
 */
class U4DCheckbox:public U4DShaderEntity{
  
private:
    
    
    float left,right,bottom,top;
    
    /**
     * @brief position of the button of the texture
     */
    U4DVector2n centerPosition;
    
    /**
     * @brief current touch position detected
     */
    U4DVector2n currentPosition;
    
    int state;
    
    int previousState;
    
    float dataValue;
    
    U4DText *labelText;
    
public:
    
    
    U4DCheckbox(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight, std::string uLabel, std::string uFontData);
    
    
    ~U4DCheckbox();
    
    
    U4DCallbackInterface *pCallback;
    
    
    U4DControllerInterface *controllerInterface;
    
    
    void update(double dt);
    
    
    void action();

    
    bool changeState(INPUTELEMENTACTION uInputAction, U4DVector2n uPosition);
    
    void changeState(int uState);
    
    int getState();
    
    void setState(int uState);
    
    bool getIsPressed();
    
    bool getIsReleased();
    
    bool getIsActive();
    
    void setCallbackAction(U4DCallbackInterface *uAction);

};

}
#endif /* U4DCheckbox_hpp */
