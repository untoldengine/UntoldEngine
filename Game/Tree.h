//
//  Tree.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/21/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Tree_hpp
#define Tree_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Tree:public U4DEngine::U4DGameObject {
    
private:
    
public:
    Tree();
    ~Tree();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* Tree_hpp */
