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
#include <ostream> // Maybe make it optional
#include <cmath>

/**
 * \brief Namespace of MyGAL
 */
namespace mygal
{

// Declarations

template<typename T>
class Vector2;
template<typename T>
Vector2<T> operator-(Vector2<T> lhs, const Vector2<T>& rhs);

// Implementations

/**
 * \brief Class representing a 2D vector
 *
 * This class can be used to represent a 2D point too.
 *
 * \author Pierre Vigier
 */
template<typename T>
class Vector2
{
public:
    T x; /**< x-coordinate of the vector */
    T y; /**< y-coordinate of the vector */

    /**
     * \brief Default constructor
     *
     * \param x x-coordinate
     * \param y y-coordinate
     */
    Vector2(T x = 0.0, T y = 0.0) : x(x), y(y)
    {

    }

    // Unary operators

    /**
     * \brief Compute the opposite vector
     *
     * \return The opposite vector
     *
     */
    Vector2<T> operator-() const
    {
        return Vector2<T>(-x, -y);
    }

    /**
     * \brief Add a vector
     * 
     * \param other Vector to add
     *
     * \return This vector after addition
     */
    Vector2<T>& operator+=(const Vector2<T>& other)
    {
        x += other.x;
        y += other.y;
        return *this;
    }

    /**
     * \brief Substract a vector
     * 
     * \param other Vector to substract
     *
     * \return This vector after substraction
     */
    Vector2<T>& operator-=(const Vector2<T>& other)
    {
        x -= other.x;
        y -= other.y;
        return *this;
    }

    /**
     * \brief Multiply by a scalar
     * 
     * \param t Scalar to multiply by
     *
     * \return This vector after multiplication
     */
    Vector2<T>& operator*=(T t)
    {
        x *= t;
        y *= t;
        return *this; 
    }
    
    // Other operations
    
    /**
     * \brief Get the orthogonal vector
     *
     * \return The orthogonal vector
     */
    Vector2<T> getOrthogonal() const
    {
        return Vector2<T>(-y, x);
    }

    /**
     * \brief Compute the euclidean norm of the vector
     *
     * \return The euclidean norm of the vector
     */
    T getNorm() const
    {
        return std::sqrt(x * x + y * y);
    }

    /**
     * \brief Compute the euclidean distance of this point to another point
     *
     * In this function vectors are interpreted as points.
     *
     * \param other Other point to compute the distance from
     *
     * \return The euclidean distance of this point to `other`
     */
    T getDistance(const Vector2<T>& other) const
    {
        return (*this - other).getNorm();
    }

    /**
     * \brief Compute the determinant with another vector
     *
     * \param other Other vector to compute the determinant with
     *
     * \return The determinant of this vector with `other`
     */
    T getDet(const Vector2<T>& other) const
    {
        return x * other.y - y * other.x;
    }
};

// Binary operators

/**
 * \relates Vector2
 * \brief Compute the sum of two vectors
 *
 * \param lhs First vector
 * \param rhs Second vector
 *
 * \return Sum of these two vectors
 */
template<typename T>
Vector2<T> operator+(Vector2<T> lhs, const Vector2<T>& rhs)
{
    lhs += rhs;
    return lhs;
}

/**
 * \relates Vector2
 * \brief Compute the difference of two vectors
 *
 * \param lhs First vector
 * \param rhs Second vector
 *
 * \return Difference of these two vectors
 */
template<typename T>
Vector2<T> operator-(Vector2<T> lhs, const Vector2<T>& rhs)
{
    lhs -= rhs;
    return lhs;
}

/**
 * \relates Vector2
 * \brief Compute the product of a scalar by a vector
 *
 * \param t Scalar
 * \param vec Vector
 *
 * \return Product of this scalar by this vector
 */
template<typename T>
Vector2<T> operator*(T t, Vector2<T> vec)
{
    vec *= t;
    return vec;
}

/**
 * \relates Vector2
 * \brief Compute the product of a vector by a scalar
 *
 * \param vec Vector
 * \param t Scalar
 *
 * \return Product of this vector by this scalar
 */
template<typename T>
Vector2<T> operator*(Vector2<T> vec, T t)
{
    return t * vec;
}

/**
 * \relates Vector2
 * \brief Insert a vector in a stream
 *
 * \param os Stream in which to insert the vector in
 * \param vec Vector to insert in the stream
 *
 * \return Stream after insertion
 */
template<typename T>
std::ostream& operator<<(std::ostream& os, const Vector2<T>& vec)
{
    os << "(" << vec.x << ", " << vec.y << ")";
    return os;
}

}
