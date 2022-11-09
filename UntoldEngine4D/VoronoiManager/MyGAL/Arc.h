/* MyGAL
 * Copyright (C) 2019 Pierre Vigier
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#pragma once

// My includes
#include "Diagram.h"

/**
 * \brief Namespace of MyGAL
 */
namespace mygal
{

template<typename T>
class Event;

template<typename T>
struct Arc
{
    enum class Color{Red, Black};
    enum class Side{Left, Right};

    // Hierarchy
    Arc<T>* parent;
    Arc<T>* left;
    Arc<T>* right;
    // Diagram
    typename Diagram<T>::Site* site;
    typename Diagram<T>::HalfEdge* leftHalfEdge;
    typename Diagram<T>::HalfEdge* rightHalfEdge;
    Event<T>* event;
    // Optimizations
    Arc<T>* prev;
    Arc<T>* next;
    // Only for balancing
    Color color;
    // To know if the arc is towards -inf or +inf
    Side side;
};

}
