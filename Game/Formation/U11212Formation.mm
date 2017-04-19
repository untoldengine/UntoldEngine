//
//  U11212Formation.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11212Formation.h"
#include "U11Field.h"
#include "U4DAABB.h"
#include "U11PlayerSpace.h"

U11212Formation::U11212Formation(){
    
}

U11212Formation::~U11212Formation(){
    
}

std::vector<U11PlayerSpace> U11212Formation::partitionField(U11Field *uField, std::string uFieldSide){
    
    if (uFieldSide.compare("leftside")==0) {
        
        return partitionFieldFromLeftSide(uField);
        
    }else{
        
        return partitionFieldFromRightSide(uField);
        
    }
    
}

std::vector<U11PlayerSpace> U11212Formation::partitionFieldFromLeftSide(U11Field *uField){
    
    //partition the field along the x axis into 3 aabbs to get the assigned positions
    
    U4DEngine::U4DVector3n xDirection(1.0,0.0,0.0);
    U4DEngine::U4DAABB fieldAABB=uField->getFieldAABB();
    
    std::vector<U4DEngine::U4DAABB> formationFirstLevelPartition=partitionAABBAlongDirection(fieldAABB, xDirection, 3);
    
    U4DEngine::U4DAABB formationLeftFieldSpace=formationFirstLevelPartition.at(0);
    U4DEngine::U4DAABB formationMidFieldSpace=formationFirstLevelPartition.at(1);
    U4DEngine::U4DAABB formationRightFieldSpace=formationFirstLevelPartition.at(2);
    
    //for each space, partition the space accordingly
    
    U4DEngine::U4DVector3n zDirection(0.0,0.0,1.0);
    
    //Partition the left space into 2
    std::vector<U4DEngine::U4DAABB> formationLeftFieldPartition=partitionAABBAlongDirection(formationLeftFieldSpace, zDirection, 2);
    
    //partition the mid space into 1
    std::vector<U4DEngine::U4DAABB> formationMidFieldPartition=partitionAABBAlongDirection(formationMidFieldSpace, zDirection, 1);
    
    //Partition the right space into 2
    std::vector<U4DEngine::U4DAABB> formationRightFieldPartition=partitionAABBAlongDirection(formationRightFieldSpace, zDirection, 2);
    
    
    //load all assigned spaces into a container
    std::vector<U4DEngine::U4DAABB> formationSpacesContainer;
    
    for(auto n: formationLeftFieldPartition){
        
        formationSpacesContainer.push_back(n);
        
    }
    
    for(auto n:formationMidFieldPartition){
        
        formationSpacesContainer.push_back(n);
        
    }
    
    for(auto n:formationRightFieldPartition){
        
        formationSpacesContainer.push_back(n);
        
    }
    
    
    //partition the field to get the home positions
    
    std::vector<U4DEngine::U4DAABB> homeFirstLevelPartition=partitionAABBAlongDirection(fieldAABB, xDirection, 2);
    
    U4DEngine::U4DAABB leftHomeSpace=homeFirstLevelPartition.at(0);
    
    std::vector<U4DEngine::U4DAABB> homeSecondLevelPartition=partitionAABBAlongDirection(leftHomeSpace, xDirection, 3);
    
    U4DEngine::U4DAABB homeLeftFieldSpace=homeSecondLevelPartition.at(0);
    U4DEngine::U4DAABB homeMidFieldSpace=homeSecondLevelPartition.at(1);
    U4DEngine::U4DAABB homeRightFieldSpace=homeSecondLevelPartition.at(2);
    
    //partition the home space into smaller spaces
    
    //Partition the left home space into 2
    std::vector<U4DEngine::U4DAABB> homeLeftFieldPartition=partitionAABBAlongDirection(homeLeftFieldSpace, zDirection, 2);
    
    //partition the mid home space into 1
    std::vector<U4DEngine::U4DAABB> homeMidFieldPartition=partitionAABBAlongDirection(homeMidFieldSpace, zDirection, 1);
    
    //partition the right home space into 2
    std::vector<U4DEngine::U4DAABB> homeRightFieldPartition=partitionAABBAlongDirection(homeRightFieldSpace, zDirection, 2);
    
    //load all the info into the container
    
    std::vector<U4DEngine::U4DAABB> homeSpacesContainer;
    
    for(auto n:homeLeftFieldPartition){
        homeSpacesContainer.push_back(n);
    }
    
    for(auto n:homeMidFieldPartition){
        homeSpacesContainer.push_back(n);
    }
    
    for(auto n:homeRightFieldPartition){
        homeSpacesContainer.push_back(n);
    }
    
    std::vector<U11PlayerSpace> playerSpaceContainer;
    
    for (int i=0; i<homeSpacesContainer.size(); i++) {
        
        U11PlayerSpace playerSpace;
        U4DEngine::U4DPoint3n homePosition=homeSpacesContainer.at(i).getCenter();
        U4DEngine::U4DPoint3n formationPosition=formationSpacesContainer.at(i).getCenter();
        U4DEngine::U4DAABB formationSpace=formationSpacesContainer.at(i);
        
        playerSpace.setHomePosition(homePosition);
        playerSpace.setFormationPosition(formationPosition);
        playerSpace.setFormationSpace(formationSpace);
        
        playerSpaceContainer.push_back(playerSpace);
        
    }
    
    return playerSpaceContainer;
}

std::vector<U11PlayerSpace> U11212Formation::partitionFieldFromRightSide(U11Field *uField){
    
    //partition the field along the x axis into 3 aabbs to get the assigned positions
    
    U4DEngine::U4DVector3n xDirection(1.0,0.0,0.0);
    U4DEngine::U4DAABB fieldAABB=uField->getFieldAABB();
    
    std::vector<U4DEngine::U4DAABB> formationFirstLevelPartition=partitionAABBAlongDirection(fieldAABB, xDirection, 3);
    
    U4DEngine::U4DAABB formationLeftFieldSpace=formationFirstLevelPartition.at(0);
    U4DEngine::U4DAABB formationMidFieldSpace=formationFirstLevelPartition.at(1);
    U4DEngine::U4DAABB formationRightFieldSpace=formationFirstLevelPartition.at(2);
    
    //for each space, partition the space accordingly
    
    U4DEngine::U4DVector3n zDirection(0.0,0.0,1.0);
    
    //Partition the left space into 2
    std::vector<U4DEngine::U4DAABB> formationLeftFieldPartition=partitionAABBAlongDirection(formationLeftFieldSpace, zDirection, 2);
    
    //partition the mid space into 1
    std::vector<U4DEngine::U4DAABB> formationMidFieldPartition=partitionAABBAlongDirection(formationMidFieldSpace, zDirection, 1);
    
    //Partition the right space into 2
    std::vector<U4DEngine::U4DAABB> formationRightFieldPartition=partitionAABBAlongDirection(formationRightFieldSpace, zDirection, 2);
    
    
    //load all assigned spaces into a container
    std::vector<U4DEngine::U4DAABB> formationSpacesContainer;
    
    for(auto n: formationLeftFieldPartition){
        
        formationSpacesContainer.push_back(n);
        
    }
    
    for(auto n:formationMidFieldPartition){
        
        formationSpacesContainer.push_back(n);
        
    }
    
    for(auto n:formationRightFieldPartition){
        
        formationSpacesContainer.push_back(n);
        
    }
    
    
    //partition the field to get the home positions
    
    std::vector<U4DEngine::U4DAABB> homeFirstLevelPartition=partitionAABBAlongDirection(fieldAABB, xDirection, 2);
    
    U4DEngine::U4DAABB rightHomeSpace=homeFirstLevelPartition.at(1);
    
    std::vector<U4DEngine::U4DAABB> homeSecondLevelPartition=partitionAABBAlongDirection(rightHomeSpace, xDirection, 3);
    
    U4DEngine::U4DAABB homeLeftFieldSpace=homeSecondLevelPartition.at(0);
    U4DEngine::U4DAABB homeMidFieldSpace=homeSecondLevelPartition.at(1);
    U4DEngine::U4DAABB homeRightFieldSpace=homeSecondLevelPartition.at(2);
    
    //partition the home space into smaller spaces
    
    //Partition the left home space into 2
    std::vector<U4DEngine::U4DAABB> homeLeftFieldPartition=partitionAABBAlongDirection(homeLeftFieldSpace, zDirection, 2);
    
    //partition the mid home space into 1
    std::vector<U4DEngine::U4DAABB> homeMidFieldPartition=partitionAABBAlongDirection(homeMidFieldSpace, zDirection, 1);
    
    //partition the right home space into 2
    std::vector<U4DEngine::U4DAABB> homeRightFieldPartition=partitionAABBAlongDirection(homeRightFieldSpace, zDirection, 2);
    
    //load all the info into the container
    
    std::vector<U4DEngine::U4DAABB> homeSpacesContainer;
    
    for(auto n:homeLeftFieldPartition){
        homeSpacesContainer.push_back(n);
    }
    
    for(auto n:homeMidFieldPartition){
        homeSpacesContainer.push_back(n);
    }
    
    for(auto n:homeRightFieldPartition){
        homeSpacesContainer.push_back(n);
    }
    
    std::vector<U11PlayerSpace> playerSpaceContainer;
    
    for (int i=0; i<homeSpacesContainer.size(); i++) {
        
        U11PlayerSpace playerSpace;
        U4DEngine::U4DPoint3n homePosition=homeSpacesContainer.at(i).getCenter();
        U4DEngine::U4DPoint3n formationPosition=formationSpacesContainer.at(i).getCenter();
        U4DEngine::U4DAABB formationSpace=formationSpacesContainer.at(i);
        
        playerSpace.setHomePosition(homePosition);
        playerSpace.setFormationPosition(formationPosition);
        playerSpace.setFormationSpace(formationSpace);
        
        playerSpaceContainer.push_back(playerSpace);
        
    }
    
    return playerSpaceContainer;
    
}
