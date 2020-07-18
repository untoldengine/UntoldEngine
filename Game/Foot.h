//
//  Foot.hpp
//  Dribblr
//
//  Created by Harold Serrano on 5/31/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef Foot_hpp
#define Foot_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Player;

class Foot:public U4DEngine::U4DGameObject {

private:
    
    Player *player;
    
public:
    
    Foot(Player *uPlayer);
    
    ~Foot();

    bool init(const char* uModelName);
       
    void update(double dt);
    
};

#endif /* Foot_hpp */
