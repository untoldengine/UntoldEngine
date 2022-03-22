//
//  U4DFieldAnalyzer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DFieldAnalyzer_hpp
#define U4DFieldAnalyzer_hpp

#include <stdio.h>
#include <unordered_map>
#include <vector>
#include "U4DVector2n.h"
#include "U4DSegment.h"

#include "U4DTeam.h"
#include "U4DPlayer.h"


namespace U4DEngine {

struct Cell{
    Cell(int px,int py):influence(0.0),isTeam(1.0){x=px;y=py;}
    
    int x,y;
    float influence;
    float isTeam;

    bool operator==(const Cell &p) const{
        return x==p.x && y==p.y;
    }
    
};

struct hash_fn{
    
    std::size_t operator()(const Cell &cell) const{
        std::size_t h1=std::hash<int>()(cell.x);
        std::size_t h2=std::hash<int>()(cell.y);
        
        return h1^h2;
    }
    
};

class U4DFieldAnalyzer {
    
private:
    
    static U4DFieldAnalyzer *instance;
    
    std::vector<Cell> cellContainer;
    
    std::unordered_map<Cell, int, hash_fn> cellMap;
    
    
protected:
    
    U4DFieldAnalyzer();
    
    ~U4DFieldAnalyzer();
    
public:
    
    static U4DFieldAnalyzer* sharedInstance();
    
    void init();
    
    std::vector<Cell> &getCellContainer();
    
    void analyzeField(U4DTeam *uTeam, U4DTeam *uOppositeTeam);
    
    void analyzePlayerInfluence(U4DPlayer *uPlayer, bool isTeamate);
    
    Cell &getCell(U4DEngine::U4DVector2n &uPosition);
    
};

}

#endif /* U4DFieldAnalyzer_hpp */
