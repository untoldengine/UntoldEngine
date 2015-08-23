//
//  U4DScene.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MVCTemplate__U4DScene__
#define __MVCTemplate__U4DScene__

#include <iostream>
#include <vector>
#include "U4DEntityManager.h"
#include "U4DWorld.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
class U4DTouches;
}

namespace U4DEngine {
    
class U4DScene{
    
private:
    
    U4DControllerInterface *gameController;
    U4DWorld* gameWorld;
    U4DEntityManager *entityManager;
    
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
    virtual void draw() final;
    
    void touchBegan(const U4DTouches &touches);
    void touchEnded(const U4DTouches &touches);
    void touchMoved(const U4DTouches &touches);
    
};

}

#endif /* defined(__MVCTemplate__U4DScene__) */
