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

// STL
#include <array>
// My includes
#include "Vector2.h"
#include "util.h"

/**
 * \brief Namespace of MyGAL
 */
namespace mygal
{

template<typename T>
class Diagram;

template<typename T>
class FortuneAlgorithm;

/**
 * \brief Class representing a box
 *
 * Be careful, the y-axis is oriented to the top like in math.
 * This `bottom` must be lower to `top`.
 *
 * \author Pierre Vigier
 */
template<typename T>
class Box
{
public:
    T left; /**< x-coordinate of the left side of the box */
    T bottom; /**< y-coordinate of the bottom side of the box */
    T right;/**< x-coordinate of the right side of the box */
    T top; /**< y-coordinate of the top side of the box */

    bool contains(const Vector2<T>& point) const
    {
        return almostBetween(point.x, left, right) && almostBetween(point.y, bottom, top);
    }

private:
    friend Diagram<T>;
    friend FortuneAlgorithm<T>;

    enum class Side : int {Left, Bottom, Right, Top};

    struct Intersection
    {
        Side side;
        Vector2<T> point;
    };

    // Useful for Fortune's algorithm
    Intersection getFirstIntersection(const Vector2<T>& origin, const Vector2<T>& direction) const
    {
        // origin must be in the box
        auto intersection = Intersection{};
        auto t = std::numeric_limits<T>::infinity();
        if (direction.x > static_cast<T>(0.0))
        {
            t = (right - origin.x) / direction.x;
            intersection.side = Side::Right;
            intersection.point = origin + t * direction;
        }
        else if (direction.x < static_cast<T>(0.0))
        {
            t = (left - origin.x) / direction.x;
            intersection.side = Side::Left;
            intersection.point = origin + t * direction;
        }
        if (direction.y > static_cast<T>(0.0))
        {
            auto newT = (top - origin.y) / direction.y;
            if (newT < t)
            {
                intersection.side = Side::Top;
                intersection.point = origin + newT * direction;
            }
        }
        else if (direction.y < static_cast<T>(0.0))
        {
            auto newT = (bottom - origin.y) / direction.y;
            if (newT < t)
            {
                intersection.side = Side::Bottom;
                intersection.point = origin + newT * direction;
            }
        }
        return intersection;
    }

    // Useful for diagram intersection
    int getIntersections(const Vector2<T>& origin, const Vector2<T>& destination, std::array<Intersection, 2>& intersections) const
    {
        // WARNING: If the intersection is a corner, both intersections are equals
        // I tried to add this test (i == 0 || !almostEqual(t[0], t[1])) to detect duplicates
        // But it does not make a big difference
        auto direction = destination - origin;
        auto t = std::array<T, 2>();
        auto i = std::size_t(0); // index of the current intersection
        // Left
        if (strictlyLower(origin.x, left) || strictlyLower(destination.x, left))
        {   
            t[i] = (left - origin.x) / direction.x;
            if (strictlyBetween(t[i], static_cast<T>(0.0), static_cast<T>(1.0)))
            {
                intersections[i].side = Side::Left;
                intersections[i].point = origin + t[i] * direction;
                // Check that the intersection is inside the box
                if (almostBetween(intersections[i].point.y, bottom, top))
                    ++i;
            }
        }
        // Right
        if (strictlyGreater(origin.x, right) || strictlyGreater(destination.x, right))
        {   
            t[i] = (right - origin.x) / direction.x;
            if (strictlyBetween(t[i], static_cast<T>(0.0), static_cast<T>(1.0)))
            {
                intersections[i].side = Side::Right;
                intersections[i].point = origin + t[i] * direction;
                // Check that the intersection is inside the box
                if (almostBetween(intersections[i].point.y, bottom, top))
                    ++i;
            }
        }
        // Bottom
        if (strictlyLower(origin.y, bottom) || strictlyLower(destination.y, bottom))
        {   
            t[i] = (bottom - origin.y) / direction.y;
            if (i < 2 && strictlyBetween(t[i], static_cast<T>(0.0), static_cast<T>(1.0)))
            {
                intersections[i].side = Side::Bottom;
                intersections[i].point = origin + t[i] * direction;
                // Check that the intersection is inside the box
                if (almostBetween(intersections[i].point.x, left, right))
                    ++i;
            }
        }
        // Top
        if (strictlyGreater(origin.y, top) || strictlyGreater(destination.y, top))
        {   
            t[i] = (top - origin.y) / direction.y;
            if (i < 2 && strictlyBetween(t[i], static_cast<T>(0.0), static_cast<T>(1.0)))
            {
                intersections[i].side = Side::Top;
                intersections[i].point = origin + t[i] * direction;
                // Check that the intersection is inside the box
                if (almostBetween(intersections[i].point.x, left, right))
                    ++i;
            }
        }
        // Sort the intersections from the nearest to the farthest
        if (i == 2 && t[0] > t[1])
            std::swap(intersections[0], intersections[1]);
        return i;
    }
};

}
