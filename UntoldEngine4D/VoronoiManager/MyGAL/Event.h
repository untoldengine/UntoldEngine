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
#include "Vector2.h"
#include "Diagram.h"

/**
 * \brief Namespace of MyGAL
 */
namespace mygal
{

template<typename T>
class Arc;

template<typename T>
class Event
{
public:
    enum class Type{Site, Circle};

    // Site event
    explicit Event(typename Diagram<T>::Site* site) : type(Type::Site), x(site->point.x), y(site->point.y), index(-1), site(site)
    {

    }

    // Circle event
    Event(T y, Vector2<T> point, Arc<T>* arc) : type(Type::Circle), x(point.x), y(y), index(-1), point(point), arc(arc)
    {

    }

    const Type type;
    T x;
    T y;
    int index;
    // Site event
    typename Diagram<T>::Site* site;
    // Circle event
    Vector2<T> point;
    Arc<T>* arc;

};

template<typename T>
bool operator<(const Event<T>& lhs, const Event<T>& rhs)
{
    return lhs.y < rhs.y || (lhs.y == rhs.y && lhs.x < rhs.x);
}

template<typename T>
std::ostream& operator<<(std::ostream& os, const Event<T>& event)
{
    if (event.type == Event<T>::Type::Site)
        os << "S(" << event.site->index << ", " << event.site->point << ")";
    else
        os << "C(" << event.arc << ", " << event.y << ", " << event.point << ")";
    return os;
}

}
