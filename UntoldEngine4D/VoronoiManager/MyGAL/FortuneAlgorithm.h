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
#include <unordered_map>
// My includes
#include "PriorityQueue.h"
#include "Diagram.h"
#include "Beachline.h"
#include "Event.h"
#include "util.h"

/**
 * \brief Namespace of MyGAL
 */
namespace mygal
{

/**
 * \brief Implementation of Fortune's algorithm
 *
 * \tparam T Floating point type (`float`, `double` or `long double`) to use in the algorithm
 *
 * \author Pierre Vigier
 */
template<typename T>
class FortuneAlgorithm
{
public:
    /**
     * \brief Constructor of FortuneAlgorithm
     *
     * The points must all be unique.
     *
     * \param points Coordinates of the sites that will be used to generate the Voronoi diagram
     */
    explicit FortuneAlgorithm(std::vector<Vector2<T>> points) : mDiagram(std::move(points))
    {

    }

    /**
     * \brief Execute Fortune's algorithm to construct the diagram
     *
     * At the end of this method, the diagram is unbounded. The method 
     * FortuneAlgorithm::bound shoud be called to bound the diagram.
     */
    void construct()
    {
        // Initialize event queue
        for (auto i = std::size_t(0); i < mDiagram.getNbSites(); ++i)
            mEvents.push(std::make_unique<Event<T>>(mDiagram.getSite(i)));

        // Process events
        while (!mEvents.isEmpty())
        {
            auto event = mEvents.pop();
            mBeachlineY = event->y;
            if (event->type == Event<T>::Type::Site)
                handleSiteEvent(event.get());
            else
                handleCircleEvent(event.get());
        }
    }

    /**
     * \brief Bound the Voronoi diagram
     *
     * The method FortuneAlgorithm::construct must be called before this one to construct the diagram.
     *
     * The algorithm does not guarantee that the box passed as parameter will
     * be used for bounding. It only guarantees that the used box contains the
     * one passed as parameter.
     *
     * \param box Smallest box to use for bounding
     * 
     * \return True if no error occurs during intersection, false otherwise
     */
    bool bound(Box<T> box)
    {
        auto success = true;
        // 1. Make sure the bounding box contains all the vertices
        for (const auto& vertex : mDiagram.getVertices()) // Much faster when using vector<unique_ptr<Vertex*>, maybe we can only test vertices in border cells to speed up
        {
            box.left = std::min(vertex.point.x, box.left);
            box.bottom = std::min(vertex.point.y, box.bottom);
            box.right = std::max(vertex.point.x, box.right);
            box.top = std::max(vertex.point.y, box.top);
        }
        // 2. Retrieve all non bounded half edges from the beach line
        auto linkedVertices = std::list<LinkedVertex>();
        auto vertices = VerticeOnFrontierContainer(mDiagram.getNbSites());
        if (!mBeachline.isEmpty())
        {
            auto arc = mBeachline.getLeftmostArc();
            while (!mBeachline.isNil(arc->next))
            {
                success = boundEdge(box, arc, arc->next, linkedVertices, vertices) && success;
                arc = arc->next;
            }
        }
        // 3. Add corners if necessary
        for (auto& kv : vertices)
            success = addCorners(box, linkedVertices, kv.second) && success;
        // 4. Join the half-edges
        for (auto& kv : vertices)
            joinHalfEdges(kv.first, kv.second);
        // Return the status
        return success;
    }

    /**
     * \brief Return the constructed diagram
     *
     * The diagram is moved thus the method can only be called once.
     *
     * \return Diagram constructed by the class
     */
    Diagram<T> getDiagram()
    {
        return std::move(mDiagram);
    }

private:
    Diagram<T> mDiagram;
    Beachline<T> mBeachline;
    PriorityQueue<Event<T>> mEvents;
    T mBeachlineY;

    // Algorithm

    void handleSiteEvent(Event<T>* event)
    {
        auto site = event->site;
        // 1. Check if the beachline is empty
        if (mBeachline.isEmpty())
        {
            mBeachline.setRoot(mBeachline.createArc(site));
            return;
        }
        // 2. Look for the arc above the site
        auto arcToBreak = mBeachline.locateArcAbove(site->point, mBeachlineY);
        deleteEvent(arcToBreak);
        // 3. Replace this arc by the new arcs
        auto middleArc = breakArc(arcToBreak, site);
        auto leftArc = middleArc->prev; 
        auto rightArc = middleArc->next;
        // 4. Add an edge in the diagram
        addEdge(leftArc, middleArc);
        middleArc->rightHalfEdge = middleArc->leftHalfEdge;
        rightArc->leftHalfEdge = leftArc->rightHalfEdge;
        // 5. Check circle events
        // Left triplet
        if (!mBeachline.isNil(leftArc->prev))
            addEvent(leftArc->prev, leftArc, middleArc);
        // Right triplet
        if (!mBeachline.isNil(rightArc->next))
            addEvent(middleArc, rightArc, rightArc->next);
    }

    void handleCircleEvent(Event<T>* event)
    {
        auto point = event->point;
        auto arc = event->arc;
        // 1. Add vertex
        auto vertex = mDiagram.createVertex(point);
        // 2. Delete all the events with this arc
        auto leftArc = arc->prev;
        auto rightArc = arc->next;
        deleteEvent(leftArc);
        deleteEvent(rightArc);
        // 3. Update the beachline and the diagram
        removeArc(arc, vertex);
        // 4. Add new circle events
        // Left triplet
        if (!mBeachline.isNil(leftArc->prev))
            addEvent(leftArc->prev, leftArc, rightArc);
        // Right triplet
        if (!mBeachline.isNil(rightArc->next))
            addEvent(leftArc, rightArc, rightArc->next);
    }

    // Arcs

    Arc<T>* breakArc(Arc<T>* arc, typename Diagram<T>::Site* site)
    {
        // Create the new subtree
        auto middleArc = mBeachline.createArc(site);
        auto leftArc = mBeachline.createArc(arc->site, Arc<T>::Side::Left);
        leftArc->leftHalfEdge = arc->leftHalfEdge;
        auto rightArc = mBeachline.createArc(arc->site, Arc<T>::Side::Right);
        rightArc->rightHalfEdge = arc->rightHalfEdge;
        // Insert the subtree in the beachline
        mBeachline.replace(arc, middleArc);
        mBeachline.insertBefore(middleArc, leftArc);
        mBeachline.insertAfter(middleArc, rightArc);
        // Delete old arc
        delete arc;
        // Return the middle arc
        return middleArc;
    }

    void removeArc(Arc<T>* arc, typename Diagram<T>::Vertex* vertex)
    {
        // End edges
        setDestination(arc->prev, arc, vertex);
        setDestination(arc, arc->next, vertex);
        // Join the edges of the middle arc
        arc->leftHalfEdge->next = arc->rightHalfEdge;
        arc->rightHalfEdge->prev = arc->leftHalfEdge;
        // Update beachline
        mBeachline.remove(arc);
        // Create a new edge
        auto prevHalfEdge = arc->prev->rightHalfEdge;
        auto nextHalfEdge = arc->next->leftHalfEdge;
        addEdge(arc->prev, arc->next);
        setOrigin(arc->prev, arc->next, vertex);
        setPrevHalfEdge(arc->prev->rightHalfEdge, prevHalfEdge);
        setPrevHalfEdge(nextHalfEdge, arc->next->leftHalfEdge);
        // Delete node
        delete arc;
    }

    // Breakpoints
    
    bool isMovingRight(const Arc<T>* left, const Arc<T>* right) const
    {
        return left->site->point.y < right->site->point.y;
    }

    T getInitialX(const Arc<T>* left, const Arc<T>* right, bool movingRight) const
    {
        return movingRight ? left->site->point.x : right->site->point.x;
    }

    // Edges

    void addEdge(Arc<T>* left, Arc<T>* right)
    {
        // Create two new half edges
        left->rightHalfEdge = mDiagram.createHalfEdge(left->site->face);
        right->leftHalfEdge = mDiagram.createHalfEdge(right->site->face);
        // Set the two half edges twins
        left->rightHalfEdge->twin = right->leftHalfEdge;
        right->leftHalfEdge->twin = left->rightHalfEdge;
    }

    void setOrigin(Arc<T>* left, Arc<T>* right, typename Diagram<T>::Vertex* vertex)
    {
        left->rightHalfEdge->destination = vertex;
        right->leftHalfEdge->origin = vertex;
    }

    void setDestination(Arc<T>* left, Arc<T>* right, typename Diagram<T>::Vertex* vertex)
{
    left->rightHalfEdge->origin = vertex;
    right->leftHalfEdge->destination = vertex;
}

    void setPrevHalfEdge(typename Diagram<T>::HalfEdge* prev, typename Diagram<T>::HalfEdge* next)
    {
        prev->next = next;
        next->prev = prev;
    }

    // Events

    void addEvent(Arc<T>* left, Arc<T>* middle, Arc<T>* right)
    {
        auto y = T();
        auto convergencePoint = computeConvergencePoint(left->site->point, middle->site->point, right->site->point, y);
        // Check that the bottom of the circle is below the beachline
        if (!almostLower(y, mBeachlineY))
            return;
        // Check that the event is valid by checking that the middle arc will indeed shrink
        // To do that we check in which direction the breakpoint are moving and that the
        // convergence point is somewhere the breakpoints are moving to
        auto leftBreakpointMovingRight = isMovingRight(left, middle);
        auto rightBreakpointMovingRight = isMovingRight(middle, right);
        auto leftInitialX = getInitialX(left, middle, leftBreakpointMovingRight);
        auto rightInitialX = getInitialX(middle, right, rightBreakpointMovingRight);
        if (!(!leftBreakpointMovingRight && rightBreakpointMovingRight) &&
            ((leftBreakpointMovingRight && almostLower(leftInitialX, convergencePoint.x)) ||
            (!leftBreakpointMovingRight && almostGreater(leftInitialX, convergencePoint.x))) &&
            ((rightBreakpointMovingRight && almostLower(rightInitialX, convergencePoint.x)) ||
            (!rightBreakpointMovingRight && almostGreater(rightInitialX, convergencePoint.x))))
        {
            auto event = std::make_unique<Event<T>>(y, convergencePoint, middle);
            middle->event = event.get();
            mEvents.push(std::move(event));
        }
    }

    void deleteEvent(Arc<T>* arc)
    {
        if (arc->event != nullptr)
        {
            mEvents.remove(arc->event->index);
            arc->event = nullptr;
        }
    }

    Vector2<T> computeConvergencePoint(const Vector2<T>& point1, const Vector2<T>& point2, const Vector2<T>& point3, T& y) const
    {
        auto v1 = (point1 - point2).getOrthogonal();
        auto v2 = (point2 - point3).getOrthogonal();
        auto delta = static_cast<T>(0.5) * (point3 - point1);
        auto denom = v1.getDet(v2);
        // If there is no solution (points are aligned)
        if (almostZero(denom))
        {
            // Infinity means that the event will never be added to the event queue
            y = std::numeric_limits<T>::infinity();
            return Vector2<T>();
        }
        // Otherwise, there is a solution
        auto t = delta.getDet(v2) / denom;
        auto center = static_cast<T>(0.5) * (point1 + point2) + t * v1;
        auto r = center.getDistance(point1);
        y = center.y - r;
        return center;
    }

    // Bounding

    struct LinkedVertex
    {
        typename Diagram<T>::HalfEdge* prevHalfEdge;
        typename Diagram<T>::Vertex* vertex;
        typename Diagram<T>::HalfEdge* nextHalfEdge;
    };

    using VerticeOnFrontierContainer = std::unordered_map<std::size_t, std::array<LinkedVertex*, 8>>;

    bool boundEdge(const Box<T>& box, Arc<T>* leftArc, Arc<T>* rightArc, std::list<LinkedVertex>& linkedVertices,
        VerticeOnFrontierContainer& vertices)
    {
        auto success = true;
        // Bound the edge
        auto direction = (leftArc->site->point - rightArc->site->point).getOrthogonal();
        auto origin = (leftArc->site->point + rightArc->site->point) * static_cast<T>(0.5);
        // Line-box intersection
        auto intersection = box.getFirstIntersection(origin, direction);
        // Create a new vertex and ends the half edges
        auto vertex = mDiagram.createVertex(intersection.point);
        setDestination(leftArc, rightArc, vertex);
        // Initialize pointers
        if (vertices.find(leftArc->site->index) == vertices.end()) 
            vertices[leftArc->site->index].fill(nullptr); 
        if (vertices.find(rightArc->site->index) == vertices.end()) 
            vertices[rightArc->site->index].fill(nullptr); 
        // Check that the vertices are not already assigned
        success = vertices[leftArc->site->index][2 * static_cast<int>(intersection.side) + 1] == nullptr && success;
        success = vertices[rightArc->site->index][2 * static_cast<int>(intersection.side)] == nullptr && success;
        // Store the vertices on the boundaries
        linkedVertices.emplace_back(LinkedVertex{nullptr, vertex, leftArc->rightHalfEdge});
        vertices[leftArc->site->index][2 * static_cast<int>(intersection.side) + 1] = &linkedVertices.back();
        linkedVertices.emplace_back(LinkedVertex{rightArc->leftHalfEdge, vertex, nullptr});
        vertices[rightArc->site->index][2 * static_cast<int>(intersection.side)] = &linkedVertices.back();
        // Return the status
        return success;
    }

    bool addCorners(const Box<T>& box, std::list<LinkedVertex>& linkedVertices, std::array<LinkedVertex*, 8>& cellVertices)
    {
        auto success = true;
        // We check twice the first side to be sure that all necessary corners are added
        for (auto i = std::size_t(0); i < 5; ++i)
        {
            auto side = i % 4;
            auto nextSide = (side + 1) % 4;
            // Add first corner
            if (cellVertices[2 * side] == nullptr && cellVertices[2 * side + 1] != nullptr)
            {
                auto prevSide = (side + 3) % 4;
                auto corner = mDiagram.createCorner(box, static_cast<typename Box<T>::Side>(side));
                linkedVertices.emplace_back(LinkedVertex{nullptr, corner, nullptr});
                // Check that we are not erasing an already assigned vertex
                success = cellVertices[2 * prevSide + 1] == nullptr && success;
                // Store the vertex on the boundary
                cellVertices[2 * prevSide + 1] = &linkedVertices.back();
                cellVertices[2 * side] = &linkedVertices.back();
            }
            // Add second corner
            else if (cellVertices[2 * side] != nullptr && cellVertices[2 * side + 1] == nullptr)
            {
                auto corner = mDiagram.createCorner(box, static_cast<typename Box<T>::Side>(nextSide));
                linkedVertices.emplace_back(LinkedVertex{nullptr, corner, nullptr});
                // Check that we are not erasing an already assigned vertex
                success = cellVertices[2 * nextSide] == nullptr && success;
                // Store the vertex on the boundary
                cellVertices[2 * side + 1] = &linkedVertices.back();
                cellVertices[2 * nextSide] = &linkedVertices.back();
            }
        }
        // Return the status
        return success;
    }

    void joinHalfEdges(std::size_t i, std::array<LinkedVertex*, 8>& cellVertices)
    {
        for (auto side = std::size_t(0); side < 4; ++side)
        {
            // After addCorners have been executed either both cellVertices[2 * side]
            // and cellVertices[2 * side + 1] are assigned or both are nullptr
            // Maybe we can add an assertion to check that
            if (cellVertices[2 * side] != nullptr)
            {
                // Link vertices 
                auto halfEdge = mDiagram.createHalfEdge(mDiagram.getFace(i));
                halfEdge->origin = cellVertices[2 * side]->vertex;
                halfEdge->destination = cellVertices[2 * side + 1]->vertex;
                cellVertices[2 * side]->nextHalfEdge = halfEdge;
                halfEdge->prev = cellVertices[2 * side]->prevHalfEdge;
                if (cellVertices[2 * side]->prevHalfEdge != nullptr)
                    cellVertices[2 * side]->prevHalfEdge->next = halfEdge;
                cellVertices[2 * side + 1]->prevHalfEdge = halfEdge;
                halfEdge->next = cellVertices[2 * side + 1]->nextHalfEdge;
                if (cellVertices[2 * side + 1]->nextHalfEdge != nullptr)
                    cellVertices[2 * side + 1]->nextHalfEdge->prev = halfEdge;
            }
        }
    }
};

}
