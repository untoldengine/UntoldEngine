//
//  U4DSlider.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/21/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSlider_hpp
#define U4DSlider_hpp

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
 * @brief The U4DSlider class manages slider entities
 *
 */
class U4DSlider:public U4DShaderEntity{
  
private:
    
    
    float left,right,bottom,top;
    
    /**
     * @brief position of the button of the texture
     */
    U4DVector2n centerPosition;
    
    /**
     * @brief current touch position detected
     */
    
    
    int state;
    
    int previousState;
    
    U4DVector2n currentPosition;
    
    U4DText *valueText;
    
    U4DText *labelText;
    
    U4DVector2n defaultScaleRange;
    
    U4DVector2n scaleRange;
    
public:
    
    
    U4DSlider(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight, std::string uLabel, std::string uFontData,U4DVector2n uScaleRange);
    
    
    ~U4DSlider();
    
    
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

    float dataValue;
    
    void setScaleRange(U4DVector2n uScaleRange);
    
};

}
#endif /* U4DSlider_hpp */
