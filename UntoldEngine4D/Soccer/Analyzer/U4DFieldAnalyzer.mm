//
//  U4DFieldAnalyzer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DFieldAnalyzer.h"
#include "U4DGameConfigs.h"

namespace U4DEngine {

U4DFieldAnalyzer* U4DFieldAnalyzer::instance=0;

U4DFieldAnalyzer::U4DFieldAnalyzer(){
    
    //initialize the mapping
    init();
    
}

U4DFieldAnalyzer::~U4DFieldAnalyzer(){
    
    
    
}

U4DFieldAnalyzer* U4DFieldAnalyzer::sharedInstance(){
    
    if (instance==0) {
        
        instance=new U4DFieldAnalyzer();
        
    }
    
    return instance;
}

void U4DFieldAnalyzer::init(){
    
    //initialize the cells and map them
    //see the nav mesh to see the grid space. this is basically (8x8) or (gridspace *2 * gridspace *2)
    int count=0;
    int gridSpace=4;
    
    for (int y=-gridSpace; y<=gridSpace; y++) {
        for (int x=-gridSpace; x<=gridSpace; x++) {
            
            Cell cell(x,y);
            
            cellMap[cell]=count;
            
            cellContainer.push_back(cell);
            
            count++;
        
        }
    
    }
    
}



std::vector<Cell> &U4DFieldAnalyzer::getCellContainer(){
    
    return cellContainer;
    
}

Cell &U4DFieldAnalyzer::getCell(U4DEngine::U4DVector2n &uPosition){
    
    //First map cell to position to index in container
    int index=cellMap[{(int)uPosition.x,(int)uPosition.y}];
    
    //get cell from container
    Cell &cell=cellContainer.at(index);
    
    return cell;
}


void U4DFieldAnalyzer::analyzeField(U4DTeam *uTeam, U4DTeam *uOppositeTeam){
    
    //clear all cell influence
    
    for(auto& n:cellContainer){
        n.influence=0.0;
    }
    
    //Add the influence from teammates
    for(const auto&n:uTeam->getPlayers()){
        analyzePlayerInfluence(n,true);
    }
    
    //Add the influence from opposite team
    for(const auto&n:uOppositeTeam->getPlayers()){
        analyzePlayerInfluence(n,false);
    }
    
}

void U4DFieldAnalyzer::analyzePlayerInfluence(U4DPlayer *uPlayer, bool isTeamate){
    
    U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
    
    U4DEngine::U4DVector2n playerPos(uPlayer->getAbsolutePosition().x,uPlayer->getAbsolutePosition().z);
    float teammateFactor=1.0;
    float isPartOfTeam=1.0;
    
    //this data comes from the nav mesh which is split into a 8x8 (gridspace*2 * gridspace*2)
    
    
    float fieldWidthCell=gameConfigs->getParameterForKey("cellAnalyzerWidth");
    float fieldHeightCell=gameConfigs->getParameterForKey("cellAnalyzerHeight");
    
    playerPos.x=floor(playerPos.x/fieldWidthCell);
    playerPos.y=ceil(playerPos.y/fieldHeightCell);
    
    //First map cell to position to index in container
    int cellIndex=cellMap[{(int)playerPos.x,(int)playerPos.y}];
    
    //get cell from container
    Cell &cell=cellContainer.at(cellIndex);
    
    if(isTeamate==false){
        teammateFactor=-1.0;
        isPartOfTeam=0.0;
    }
    
    cell.influence=1.0*teammateFactor;
    cell.isTeam=isPartOfTeam;
    
    
    float cellInfluenceFactor=1.0;

    //Get neighbors cell influence
    for (int j=-1; j<=1; j++ ) {
        for (int i=-1; i<=1; i++ ) {

            int neighborIndex=cellMap[{(int)playerPos.x+i,(int)playerPos.y+j}];

            Cell &neighborCell=cellContainer.at(neighborIndex);

            if (cellIndex!=neighborIndex) {

                if (abs(i*j)==1) {
                    cellInfluenceFactor=0.6;
                }else{
                    cellInfluenceFactor=0.8;
                }

                neighborCell.influence+=cellInfluenceFactor*teammateFactor;
                neighborCell.isTeam=isPartOfTeam;

            }

        }

    }
    
}

}

