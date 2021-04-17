//
//  FieldAnalyzer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/26/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "FieldAnalyzer.h"

FieldAnalyzer* FieldAnalyzer::instance=0;

FieldAnalyzer::FieldAnalyzer(){
    
    //initialize the mapping
    init();
    
}

FieldAnalyzer::~FieldAnalyzer(){
    
    
    
}

FieldAnalyzer* FieldAnalyzer::sharedInstance(){
    
    if (instance==0) {
        
        instance=new FieldAnalyzer();
        
    }
    
    return instance;
}

void FieldAnalyzer::init(){
    
    //initialize the cells and map them
    int count=0;
    int gridSpace=10;
    
    for (int y=-gridSpace; y<=gridSpace; y++) {
        for (int x=-gridSpace; x<=gridSpace; x++) {
            
            Cell cell(x,y);
            
            cellMap[cell]=count;
            
            cellContainer.push_back(cell);
            
            count++;
        
        }
    
    }
    
}



std::vector<Cell> &FieldAnalyzer::getCellContainer(){
    
    return cellContainer;
    
}

Cell &FieldAnalyzer::getCell(U4DEngine::U4DVector2n &uPosition){
    
    //First map cell to position to index in container
    int index=cellMap[{(int)uPosition.x,(int)uPosition.y}];
    
    //get cell from container
    Cell &cell=cellContainer.at(index);
    
    return cell;
}


void FieldAnalyzer::analyzeField(Team *uTeam, Team *uOppositeTeam){
    
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

void FieldAnalyzer::analyzePlayerInfluence(Player *uPlayer, bool isTeamate){
    
    U4DEngine::U4DVector2n playerPos(uPlayer->getAbsolutePosition().x,uPlayer->getAbsolutePosition().z);
    float teammateFactor=1.0;
    float isPartOfTeam=1.0;
    
    float fieldWidthCell=8.0;
    float fieldHeightCell=4.7;
    
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
