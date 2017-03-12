//
//  U11AnalyzeState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AnalyzeState_hpp
#define U11AnalyzeState_hpp

#include <stdio.h>
#include "U11AIStateInterface.h"

class U11AIStrategyInterface;

class U11AIAnalyzeState:public U11AIStateInterface {

private:
    
    U11AIAnalyzeState();
    
    ~U11AIAnalyzeState();
    
public:
    
    static U11AIAnalyzeState* instance;
    
    static U11AIAnalyzeState* sharedInstance();
    
    void enter(U11AIStrategyInterface *uAIStrategy);
    
    void execute(U11AIStrategyInterface *uAIStrategy, double dt);
    
    void exit(U11AIStrategyInterface *uAIStrategy);
    
};
#endif /* U11AnalyzeState_hpp */
