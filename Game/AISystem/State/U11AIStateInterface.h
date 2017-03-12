//
//  U11AIStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AIStateInterface_hpp
#define U11AIStateInterface_hpp

#include <stdio.h>

class U11AIStrategyInterface;

class U11AIStateInterface {
    
public:
    
    virtual ~U11AIStateInterface(){};
    
    virtual void enter(U11AIStrategyInterface *uAIStrategy)=0;
    
    virtual void execute(U11AIStrategyInterface *uAIStrategy, double dt)=0;
    
    virtual void exit(U11AIStrategyInterface *uAIStrategy)=0;
 
};
#endif /* U11AIStateInterface_hpp */
