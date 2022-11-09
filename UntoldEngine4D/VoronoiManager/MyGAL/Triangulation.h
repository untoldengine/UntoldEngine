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

/**
 * \brief Namespace of MyGAL
 */
namespace mygal
{

/**
 * \brief Data structure representing a triangulation
 *
 * \author Pierre Vigier
 */
class Triangulation
{
public:
    
    Triangulation(){};
    
    /**
     * \brief Constructor of Triangulation
     *
     * \param neighbors Neighbors for each vertex of the triangulation
     */
    explicit Triangulation(std::vector<std::vector<std::size_t>> neighbors) : mNeighbors(std::move(neighbors))
    {

    }

    /**
     * \brief Get the number of vertices
     *
     * \return The number of vertices
     */
    std::size_t getNbVertices() const
    {
        return mNeighbors.size();
    }

    /**
     * \brief Get the neighbors of a vertex
     *
     * \param i Index of the vertex
     *
     * \return The neighbors of vertex `i`
     */
    const std::vector<std::size_t>& getNeighbors(std::size_t i) const
    {
        return mNeighbors[i];
    }

private:
    std::vector<std::vector<std::size_t>> mNeighbors;
};

}
