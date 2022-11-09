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
#include <vector>
#include <list>
#include <unordered_set>
// My includes
#include "Box.h"
#include "Triangulation.h"

/**
 * \brief Namespace of MyGAL
 */
namespace mygal
{

template<typename T>
class FortuneAlgorithm;

/**
 * \brief Data structure representing a partitioning of the space
 *
 * \author Pierre Vigier
 */
template<typename T>
class Diagram
{
public:
    
    Diagram(){};
    
    struct HalfEdge;
    struct Face;

    /**
     * \brief Point associated with a face of the partitioning
     */
    struct Site
    {
        std::size_t index; /**< Index of the site in mSites */
        Vector2<T> point; /**< Coordinates of the site */
        Face* face; /**< Face associated with the site */
    };

    /**
     * \brief Vertex of a face
     */
    struct Vertex
    {
        Vector2<T> point; /**< Coordinates of the vertex */

    private:
        friend Diagram<T>;
        typename std::list<Vertex>::iterator it;
    };

    /**
     * \brief Half-edge of a face
     */
    struct HalfEdge
    {
        Vertex* origin = nullptr; /**< First vertex of the half-edge */
        Vertex* destination = nullptr; /**< Second vertex of the half-edge */
        HalfEdge* twin = nullptr; /**< Twin half-edge */
        Face* incidentFace; /**< Face to which this half-edge belongs to */
        HalfEdge* prev = nullptr; /**< Previous half-edge in the face frontier */
        HalfEdge* next = nullptr; /**< Next half-edge in the face frontier */

    private:
        friend Diagram;
        typename std::list<HalfEdge>::iterator it;
    };

    /**
     * \brief Structure representing a cell in the diagram
     *
     * The outer component of the face is represented as a doubly linked list.
     * If the face is bounded, the list is circular.
     */
    struct Face
    {
        Site* site; /**< Site associated with this face */
        HalfEdge* outerComponent; /**< A half-edge of the face */
    };

    // Remove copy operations

    Diagram(const Diagram&) = delete;
    Diagram& operator=(const Diagram&) = delete;

    // Move operations

    /**
     * \brief Default move constructor
     */
    Diagram(Diagram&&) = default;

    /**
     * \brief Default move assignment operator
     */
    Diagram& operator=(Diagram&&) = default;

    // Accessors

    /**
     * \brief Get sites
     * 
     * \return Const reference to the vector of sites of the diagram
     */
    const std::vector<Site>& getSites() const
    {
        return mSites;
    }

    /**
     * \brief Get a site
     *
     * \param i Index of the requested site
     *
     * \return Const pointer to the requested site
     */
    const Site* getSite(std::size_t i) const
    {
        return &mSites[i];
    }

    /**
     * \brief Get the number of sites
     *
     * \return The number of sites
     */
    std::size_t getNbSites() const
    {
        return mSites.size();
    }

    /**
     * \brief Get faces
     * 
     * \return Const reference to the vector of faces of the diagram
     */
    const std::vector<Face>& getFaces() const
    {
        return mFaces;
    }

    /**
     * \brief Get a face
     *
     * \param i Index of the site associated with the requested face
     *
     * \return Const pointer to the requested face
     */
    const Face* getFace(std::size_t i) const
    {
        return &mFaces[i];
    }

    /**
     * \brief Get vertices
     *
     * \return Const reference to the list of vertices of the diagram
     */
    const std::list<Vertex>& getVertices() const
    {
        return mVertices;
    }

    /**
     * \brief Get half-edges
     *
     * \return Const reference to the list of half-edges of the diagram
     */
    const std::list<HalfEdge>& getHalfEdges() const
    {
        return mHalfEdges;
    }

    // Intersection with a box

    /**
     * \brief Compute the intersection between the diagram and a box
     *
     * The diagram must be bounded before calling this method.
     *
     * \return True if no error occurs during intersection, false otherwise
     */
    bool intersect(Box<T> box)
    {
        auto success = true;
        auto processedHalfEdges = std::unordered_set<HalfEdge*>();
        auto verticesToRemove = std::unordered_set<Vertex*>();
        for (const auto& site : mSites)
        {
            auto halfEdge = site.face->outerComponent;
            auto inside = box.contains(halfEdge->origin->point);
            auto outerComponentDirty = !inside;
            auto incomingHalfEdge = static_cast<HalfEdge*>(nullptr); // First half edge coming in the box
            auto outgoingHalfEdge = static_cast<HalfEdge*>(nullptr); // Last half edge going out the box
            auto incomingSide = typename Box<T>::Side{};
            auto outgoingSide = typename Box<T>::Side{};
            do
            {
                auto intersections = std::array<typename Box<T>::Intersection, 2>{};
                auto nbIntersections = box.getIntersections(halfEdge->origin->point, halfEdge->destination->point, intersections);
                auto nextInside = box.contains(halfEdge->destination->point);
                auto nextHalfEdge = halfEdge->next;
                // The two points are outside the box 
                if (!inside && !nextInside)
                {
                    // The edge is outside the box
                    if (nbIntersections == 0)
                    {
                        verticesToRemove.emplace(halfEdge->origin);
                        removeHalfEdge(halfEdge);
                    }
                    // The edge crosses twice the frontiers of the box
                    else if (nbIntersections == 2)
                    {
                        verticesToRemove.emplace(halfEdge->origin);
                        if (processedHalfEdges.find(halfEdge->twin) != processedHalfEdges.end())
                        {
                            halfEdge->origin = halfEdge->twin->destination;
                            halfEdge->destination = halfEdge->twin->origin;
                        }
                        else
                        {
                            halfEdge->origin = createVertex(intersections[0].point);
                            halfEdge->destination = createVertex(intersections[1].point);
                        }
                        if (outgoingHalfEdge != nullptr)
                            link(box, outgoingHalfEdge, outgoingSide, halfEdge, intersections[0].side);
                        if (incomingHalfEdge == nullptr)
                        {
                           incomingHalfEdge = halfEdge;
                           incomingSide = intersections[0].side;
                        }
                        outgoingHalfEdge = halfEdge;
                        outgoingSide = intersections[1].side;
                        processedHalfEdges.emplace(halfEdge);
                    }
                    else
                        success = false;
                }
                // The edge is going outside the box
                else if (inside && !nextInside)
                {
                    // We accept >= 1 as a corner can be found twice
                    if (nbIntersections >= 1)
                    {
                        if (processedHalfEdges.find(halfEdge->twin) != processedHalfEdges.end())
                            halfEdge->destination = halfEdge->twin->origin;
                        else
                            halfEdge->destination = createVertex(intersections[0].point);
                        outgoingHalfEdge = halfEdge;
                        outgoingSide = intersections[0].side;
                        processedHalfEdges.emplace(halfEdge);
                    }
                    else
                        success = false;
                }
                // The edge is coming inside the box
                else if (!inside && nextInside)
                {
                    // We accept >= 1 as a corner can be found twice
                    if (nbIntersections >= 1)
                    {
                        verticesToRemove.emplace(halfEdge->origin);
                        if (processedHalfEdges.find(halfEdge->twin) != processedHalfEdges.end())
                            halfEdge->origin = halfEdge->twin->destination;
                        else
                            halfEdge->origin = createVertex(intersections[0].point);
                        if (outgoingHalfEdge != nullptr)
                            link(box, outgoingHalfEdge, outgoingSide, halfEdge, intersections[0].side);
                        if (incomingHalfEdge == nullptr)
                        {
                           incomingHalfEdge = halfEdge;
                           incomingSide = intersections[0].side;
                        }
                        processedHalfEdges.emplace(halfEdge);
                    }
                    else
                        success = false;
                }
                halfEdge = nextHalfEdge;
                // Update inside
                inside = nextInside;
            } while (halfEdge != site.face->outerComponent);
            // Link the last and the first half edges inside the box
            if (outerComponentDirty && incomingHalfEdge != nullptr)
                link(box, outgoingHalfEdge, outgoingSide, incomingHalfEdge, incomingSide);
            // Set outer component
            if (outerComponentDirty)
                site.face->outerComponent = incomingHalfEdge;
        }
        // Remove vertices
        for (auto& vertex : verticesToRemove)
            removeVertex(vertex);
        // Return the status
        return success;
    }

    // Lloyd's relaxation

    /**
     * \brief Compute a Lloyd relaxation
     *
     * For each cell of the diagram, the algorithm computes the centroid of this cell.
     *
     * The diagram must be bounded before calling this method.
     *
     * \return Vector of centroids of the cells
     */
    std::vector<Vector2<T>> computeLloydRelaxation() const
    {
        auto sites = std::vector<Vector2<T>>();
        for (const auto& face : mFaces)
        {
            auto area = static_cast<T>(0.0);
            auto centroid = Vector2<T>();
            auto halfEdge = face.outerComponent;
            // Compute centroid of the face
            do
            {
                auto det = halfEdge->origin->point.getDet(halfEdge->destination->point);
                area += det;
                centroid += (halfEdge->origin->point + halfEdge->destination->point) * det;
                halfEdge = halfEdge->next;
            } while (halfEdge != face.outerComponent);
            area *= 0.5;
            centroid *= 1.0 / (6.0 * area);
            sites.push_back(centroid);
        }
        return sites;
    }

    // Triangulation

    /**
     * \brief Compute the triangulation induced by the diagram
     *
     * If the diagram is a Voronoi diagram then the output of this method is
     * a Delaunay triangulation.
     *
     * This method can be called even if the diagram is not bounded.
     *
     * \return The triangulation induced by the diagram
     */
    Triangulation computeTriangulation() const
    {
        auto neighbors = std::vector<std::vector<std::size_t>>(mSites.size());
        for (auto i = std::size_t(0); i < mSites.size(); ++i)
        {
            auto face = mFaces[i];
            auto halfEdge = face.outerComponent;
            while (halfEdge->prev != nullptr)
            {
                halfEdge = halfEdge->prev;
                if (halfEdge == face.outerComponent)
                    break;
            }
            while (halfEdge != nullptr)
            {
                if (halfEdge->twin != nullptr)
                    neighbors[i].push_back(halfEdge->twin->incidentFace->site->index);
                halfEdge = halfEdge->next;
                if (halfEdge == face.outerComponent)
                    break;
            }
        }
        return Triangulation(neighbors);
    }

public:
    std::vector<Site> mSites; /**< Sites of the diagram */
    std::vector<Face> mFaces; /**< Faces of the diagram */
    std::list<Vertex> mVertices; /**< Vertices of the diagram */
    std::list<HalfEdge> mHalfEdges; /**< Half-edges of the diagram */

    // Diagram construction

    template<typename>
    friend class FortuneAlgorithm;

    Diagram(const std::vector<Vector2<T>>& points)
    {
        mSites.reserve(points.size());
        mFaces.reserve(points.size());
        for (auto i = std::size_t(0); i < points.size(); ++i)
        {
            mSites.push_back(Diagram::Site{i, points[i], nullptr});
            mFaces.push_back(Diagram::Face{&mSites.back(), nullptr});
            mSites.back().face = &mFaces.back();
        }
    }

    Site* getSite(std::size_t i)
    {
        return &mSites[i];
    }

    Face* getFace(std::size_t i)
    {
        return &mFaces[i];
    }

    Vertex* createVertex(Vector2<T> point)
    {
        mVertices.emplace_back();
        mVertices.back().point = point;
        mVertices.back().it = std::prev(mVertices.end());
        return &mVertices.back();
    }

    Vertex* createCorner(Box<T> box, typename Box<T>::Side side)
    {
        switch (side)
        {
            case Box<T>::Side::Left:
                return createVertex(Vector2<T>(box.left, box.top));
            case Box<T>::Side::Bottom:
                return createVertex(Vector2<T>(box.left, box.bottom));
            case Box<T>::Side::Right:
                return createVertex(Vector2<T>(box.right, box.bottom));
            case Box<T>::Side::Top:
                return createVertex(Vector2<T>(box.right, box.top));
            default:
                return nullptr;
        }
    }

    HalfEdge* createHalfEdge(Face* face)
    {
        mHalfEdges.emplace_back();
        mHalfEdges.back().incidentFace = face;
        mHalfEdges.back().it = std::prev(mHalfEdges.end());
        if (face->outerComponent == nullptr)
            face->outerComponent = &mHalfEdges.back();
        return &mHalfEdges.back();
    }

    // Intersection with a box

    void link(Box<T> box, HalfEdge* start, typename Box<T>::Side startSide, HalfEdge* end, typename Box<T>::Side endSide)
    {
        auto halfEdge = start;
        auto side = static_cast<int>(startSide);
        while (side != static_cast<int>(endSide))
        {
            side = (side + 1) % 4;
            halfEdge->next = createHalfEdge(start->incidentFace);
            halfEdge->next->prev = halfEdge;
            halfEdge->next->origin = halfEdge->destination;
            halfEdge->next->destination = createCorner(box, static_cast<typename Box<T>::Side>(side));
            halfEdge = halfEdge->next;
        }
        halfEdge->next = createHalfEdge(start->incidentFace);
        halfEdge->next->prev = halfEdge;
        end->prev = halfEdge->next;
        halfEdge->next->next = end;
        halfEdge->next->origin = halfEdge->destination;
        halfEdge->next->destination = end->origin;
    }

    void removeVertex(Vertex* vertex)
    {
        mVertices.erase(vertex->it);
    }

    void removeHalfEdge(HalfEdge* halfEdge)
    {
        mHalfEdges.erase(halfEdge->it);
    }
};

}
