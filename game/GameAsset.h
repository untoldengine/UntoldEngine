//
//  GameAsset.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef GameAsset_hpp
#define GameAsset_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class GameAsset:public U4DEngine::U4DGameObject {
    
private:
    
public:
    
    GameAsset();
    
    ~GameAsset();
    
    bool init(const char* uModelName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* GameAsset_hpp */
