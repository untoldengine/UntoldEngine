//
//  FieldAnalyzer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/26/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef FieldAnalyzer_hpp
#define FieldAnalyzer_hpp

#include <stdio.h>
#include <unordered_map>
#include <vector>
#include "U4DVector2n.h"
#include "U4DSegment.h"

#include "Team.h"
#include "Player.h"

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

class FieldAnalyzer {
    
private:
    
    static FieldAnalyzer *instance;
    
    std::vector<Cell> cellContainer;
    
    std::unordered_map<Cell, int, hash_fn> cellMap;
    
    
protected:
    
    FieldAnalyzer();
    
    ~FieldAnalyzer();
    
public:
    
    static FieldAnalyzer* sharedInstance();
    
    void init();
    
    std::vector<Cell> &getCellContainer();
    
    void analyzeField(Team *uTeam, Team *uOppositeTeam);
    
    void analyzePlayerInfluence(Player *uPlayer, bool isTeamate);
    
    Cell &getCell(U4DEngine::U4DVector2n &uPosition);
    
};

#endif /* FieldAnalyzer_hpp */
