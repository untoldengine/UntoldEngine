//
//  U11AIAnalyzer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AIAnalyzer_hpp
#define U11AIAnalyzer_hpp

#include <stdio.h>

class U11AIStrategyInterface;

class U11AIAnalyzer {

private:
    
    U11AIStrategyInterface *aiStrategy;
    
public:
    
    U11AIAnalyzer();
    
    ~U11AIAnalyzer();
    
    void setAIStrategy(U11AIStrategyInterface *uStrategy);
    
};

#endif /* U11AIAnalyzer_hpp */
