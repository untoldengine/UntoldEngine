//
//  U4DScene.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __MVCTemplate__U4DScene__
#define __MVCTemplate__U4DScene__

#include <iostream>
#include <vector>
#include "U4DEntityManager.h"
#include "U4DWorld.h"
#include "U4DControllerInterface.h"
#include "U4DGameModelInterface.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
class U4DTouches;
}

namespace U4DEngine {
    
class U4DScene{
    
private:
    
    U4DControllerInterface *gameController;
    U4DWorld* gameWorld;
    U4DGameModelInterface *gameModel;
    
public:
    
    //constructor
    U4DScene();

    //destructor
    ~U4DScene();
    
    //copy constructor
    U4DScene(const U4DScene& value){}; 
    U4DScene& operator=(const U4DScene& value){return *this;};
    
    virtual void init();
    
    virtual void setGameWorldControllerAndModel(U4DWorld *uGameWorld,U4DControllerInterface *uGameController, U4DGameModelInterface *uGameModel) final;
    
    virtual void update(float dt) final;
    virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder) final;
    
    virtual void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture) final;
    
    void touchBegan(const U4DTouches &touches);
    void touchEnded(const U4DTouches &touches);
    void touchMoved(const U4DTouches &touches);
    
    /**
     @todo document this
     */
    void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction);
    
    /**
     @todo document this
     */
    void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction);
    
    /**
     @todo document this
     */
    void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis);
    
    /**
     @todo document this
     */
    void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction);
    
    /**
     @todo document this
     */
    void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction);
    
    /**
     @todo document this
     */
    void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis);
    
    /**
     @todo document this
     */
    void macMousePressBegan(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
    
    /**
     @todo document this
     */
    void macMousePressEnded(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction);
    
    /**
     @todo document this
     */
    void macMouseDragged(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
    
    /**
     @todo document this
     */
    void determineVisibility();
    
};

}

#endif /* defined(__MVCTemplate__U4DScene__) */
