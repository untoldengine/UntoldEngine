//
//  U4DScene.hpp
//  UntoldEnginePro
//
//  Created by Harold Serrano on 3/5/23.
//

#ifndef U4DScene_hpp
#define U4DScene_hpp

#include <stdio.h>
#include <vector>
#include "Constants.h"
#include "U4DEntity.h"
#include "U4DComponentPool.h"


namespace U4DEngine {

struct U4DScene{

    struct EntityDesc{
        EntityID id;
        ComponentMask mask;
    };
    
    template<typename T>
    void remove(EntityID id){
        //ensures you are not accessing an entity that has been deleted
        if(entities[getEntityIndex(id)].id != id) return;
        
        int componentId=getId<T>();
        entities[getEntityIndex(id)].mask.reset(componentId);
    }
    
    void destroyEntity(EntityID id){
        EntityID newId=createEntityId(EntityIndex(-1), getEntityVersion(id)+1);
        entities[getEntityIndex(id)].id=newId;
        entities[getEntityIndex(id)].mask.reset();
        freeEntities.push_back(getEntityIndex(id));
    }
    //create new entities
    EntityID newEntity(){
        
        if(!freeEntities.empty()){
            EntityIndex newIndex=freeEntities.back();
            freeEntities.pop_back();
            EntityID newId=createEntityId(newIndex, getEntityVersion(entities[newIndex].id));
            entities[newIndex].id=newId;
            return entities[newIndex].id;
        }
        int entityIndex=EntityIndex(entities.size());
        entities.push_back({createEntityId(entityIndex, 0),ComponentMask()});
        return entities.back().id;
    }
    
    //Assign a component to an entity
//    template<typename T>
//    void assign(EntityID id){
//        int componentId=getId<T>();
//        entities[id].mask.set(componentId);
//    }
    
    template<typename T>
    T* assign(EntityID id){
    
        int componentId=getComponentId<T>();
        
        //not enough component
        if(componentPools.size()<=componentId){
            componentPools.resize(componentId+1);
        }
        
        //new component make a new pool
        if(componentPools[componentId]==nullptr){
            componentPools[componentId]=new U4DComponentPool(sizeof(T));
        }
        
        //looks up the component in the pool
        T* pComponent=new (componentPools[componentId]->get(getEntityIndex(id))) T();
        
        //set the bit for this component to true and return the created component
        entities[getEntityIndex(id)].mask.set(componentId);
        
        return pComponent;
        
    }
    
    template<typename T>
    T* Get(EntityID id)
    {
      int componentId = getComponentId<T>();
      if (!entities[getEntityIndex(id)].mask.test(componentId))
        return nullptr;

      T* pComponent = static_cast<T*>(componentPools[componentId]->get(getEntityIndex(id)));
      return pComponent;
    }
    
    std::vector<EntityDesc> entities;
    std::vector<U4DComponentPool*> componentPools;
    std::vector<EntityIndex> freeEntities;
};

template<typename... ComponentTypes>
struct U4DSceneView{
    
    U4DSceneView(U4DScene& scene):pScene(&scene){
        
        if(sizeof...(ComponentTypes)==0){
            all=true;
        }else{
            // Unpack the template parameters into an initializer list
            int componentIds[]={0,getComponentId<ComponentTypes>() ... };
            
            for(int i=1;i<(sizeof...(ComponentTypes)+1); i++){
                componentMask.set(componentIds[i]);
            }
        }
    }
    
    
    
    
    U4DScene *pScene{nullptr};
    ComponentMask componentMask;
    bool all{false};
    
    struct Iterator{
        
        Iterator(U4DScene *pScene, EntityIndex index, ComponentMask mask, bool all): pScene(pScene), index(index), mask(mask), all(all){}
        
        EntityID operator*() const{
            return pScene->entities[index].id;
        }
        
        bool operator==(const Iterator& other)const{
            return index==other.index || index == pScene->entities.size();
        }
        
        bool operator!=(const Iterator& other)const{
            return index != other.index && index !=pScene->entities.size();
        }
        
        bool validIndex(){
            return isEntityValid(pScene->entities[index].id)&&(all|| mask==(mask&pScene->entities[index].mask));
        }
        
        Iterator& operator++(){
            do{
                index++;
                
            }while(index < pScene->entities.size() && !validIndex());
            return *this;
        }
        
        
        
        EntityIndex index;
        U4DScene *pScene;
        ComponentMask mask;
        bool all{false};
    };
    
    const Iterator begin() const
    {
      int firstIndex = 0;
      while (firstIndex < pScene->entities.size() &&
        (componentMask != (componentMask & pScene->entities[firstIndex].mask)
          || !isEntityValid(pScene->entities[firstIndex].id)))
      {
        firstIndex++;
      }
      return Iterator(pScene, firstIndex, componentMask, all);
    }
    
    const Iterator end() const
    {
      return Iterator(pScene, EntityIndex(pScene->entities.size()), componentMask, all);
    }
    
};

}
#endif /* U4DScene_hpp */
