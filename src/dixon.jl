import AbstractAlgebra: exponent

exponent(G::AbstractAlgebra.Group) = exponent(conjugacy_classes(G))
exponent(cclasses::AbstractVector) = lcm(order.(first.(cclasses)))

dixon_prime(G::AbstractAlgebra.Group) = dixon_prime(order(G), exponent(G))

function dixon_prime(cclasses::AbstractVector)
    ordG = sum(length, cclasses)
    m = exponent(cclasses)
    return dixon_prime(ordG, m)
end

function dixon_prime(ordG::Integer, exponent::Integer)
    p = 2floor(Int, sqrt(ordG))
    while p < 1000
        p = nextprime(p+1)
        iszero((p-1) % exponent) && break
    end
    return p
end

struct CCMatrix{T, C} <: AbstractMatrix{T} # M_r
    cc::Vector{C} # vector of conjugacy classes to fix the order
    r::Int # the index of conjugacy class
    m::Matrix{T} # cache of class coefficients

    function CCMatrix(cc::A, r::Int, T::Type=Int) where {C, A<:AbstractVector{C}}
        M = -ones(T, length(cc), length(cc))
        new{T, C}(cc, r, M)
    end
end

Base.size(M::CCMatrix) = size(M.m)
Base.IndexStyle(::Type{<:CCMatrix}) = IndexCartesian()

function Base.getindex(M::CCMatrix, s::Integer, t::Integer)
    if isone(-M.m[s,t])
        M.m[s,:] .= 0
        r = M.r
        out = one(first(first(M.cc)))

        for g in M.cc[r]
            for h in M.cc[s]
                out = mul!(out, g, h)
                for t in 1:size(M, 1)
                    if out == first(M.cc[t])
                        M.m[s, t] += 1
                        break
                    end
                end
            end
        end

    end
    return M.m[s,t]
end
