//
//  U4DTouchesController.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DTouchesController__
#define __UntoldEngine__U4DTouchesController__

#include <iostream>
#include <vector>
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    
class U4DWorld;
class U4DGameModelInterface;
class U4DTouches;
class U4DButton;
class U4DJoyStick;
class U4DImage;
class U4DVector2n;
}

namespace U4DEngine {
    
class U4DTouchesController:public U4DControllerInterface{
  
private:
    
    U4DWorld *gameWorld;
    U4DGameModelInterface *gameModel;
    bool receivedAction;
    
public:
    //constructor
    U4DTouchesController();
    
    //destructor
    ~U4DTouchesController();

    virtual void init(){};
    void keyboardInput(int key){};
    
    void touchBegan(const U4DTouches &touches);
    void touchMoved(const U4DTouches &touches);
    void touchEnded(const U4DTouches &touches);
    
    void add(U4DButton *uButton);
    void changeState(const U4DTouches &touches,TOUCHSTATE touchState);
    
    void add(U4DJoyStick *uJoyStick);
    
    void render(id <MTLRenderCommandEncoder> uRenderEncoder);
    void update(float dt);
    
    void setGameWorld(U4DWorld *uGameWorld);
    void setGameModel(U4DGameModelInterface *uGameModel);
    
    U4DWorld* getGameWorld();
    U4DGameModelInterface* getGameModel();
    
    U4DJoyStick *getJoyStickWithName(std::string uName);
    U4DButton* getButtonWithName(std::string uName);
    
    void sendTouchUpdateToModel();
    
    void setReceivedAction(bool uValue);
};

}

#endif /* defined(__UntoldEngine__U4DTouchesController__) */
