###############################################################################
# StabilizerChain and Scheier-Sims algorithm
###############################################################################

function sift(g::Perm{I}, base::Vector{<:Integer}, transversals::AbstractVector{Orb}) where {I<:Integer, Orb<:AbstractOrbit}
    h = g

    for (i, Δ) in enumerate(transversals)
        β = base[i]^h
        β ∈ Δ || return h, I(i)
        # uᵦ = Δ[β]
        h = h*getinv(Δ, β) # assuming: Δ=orbits[i] is based on base[i]
    end
    return h, I(length(transversals)+1)
end

@doc doc"""
    initial_bsgs(gens::AbstractVector{<:perm}[, B::AbstractVector{<:Integer}=I[])
Compute the initial base and strong generating set from generators `gens` and initial base `B`.

It will remove duplicates and may reorder points in `B`. If the initial base
is not provided the first point moved by each of `gens` will be taken.
"""
function initial_bsgs(gens::AbstractVector{Perm{I}}, B::AbstractVector{I}=I[]) where I<:Integer
    B = filter(b -> !all(fixes.(gens, b)), B)

    if isempty(B)
        G = parent(first(gens))
        B = unique!([firstmoved(g) for g in gens if firstmoved(g) > 0])
        sort!(B)
    end

    S = [[g for g in gens if firstmoved(g)≥ b] for b in B]

    return B, S
end

function Base.show(io::IO, ::MIME"text/plain", sc::StabilizerChain)
    println(io, "StabilizerChain of size $(order(sc)) with base $(base(sc))")
    for i in 1:length(sc)
        b, S, Δ = sc[i]
        println(io, "Orbit:\t", collect(Δ))
        println(io, "Stabilized by:")
		Base.print_array(io, S)
		println(io, "")
    end
end

Base.show(io::IO, sc::StabilizerChain) =
	print(io, "StabilizerChain of size $(order(sc)) with base $(base(sc))")


@doc doc"""
    StabilizerChain(gens, B)
Construct the initial `StabilizerChain` object from generators `gens` and initial basis `B`.

The returned `StabilizerChain` is **not** completed. Use `schreier_sims!` for completion.
"""
function StabilizerChain(gens::AbstractVector{Perm{I}}, B::AbstractVector{I}=I[]) where I
    B, S = initial_bsgs(gens, B)
    T = [Schreier(gs, pt) for (pt, gs) in zip(B, S)]
    return StabilizerChain(B, S, T)
end

@doc doc"""
    sgs(sc::StabilizerChain)
Return strong generating set of the group defined by `sc`, i.e. unique generators
for all of the stabilizers in `sc`.
"""
sgs(sc::StabilizerChain) = unique!(vcat(sc.sgs...))

@doc doc"""
    base(sc::StabilizerChain)
Return the base of the stabilizer chain.
"""
@inline base(sc::StabilizerChain) = sc.base

@inline Base.length(sc::StabilizerChain) = length(sc.base)
@inline Base.getindex(sc::StabilizerChain, n) = sc.base[n], sc.sgs[n], sc.transversals[n]

@doc doc"""
    sift(g::Perm, sc::StabilizerChain) → (h, depth)::Tuple{Perm, Int}
Sift the element `g` through the StabilizerChain.

The returned tuple consists of
 * `h::Perm` → the residual of `g` after dividing by the stabilizers of `sc`
 * `depth` → the depth where the sifting procedure has stopped.

If `depth` is less than or equal to depth of `sc` (i.e. `length(sc)`) then `g`
does not belong to the group generated by `sc`.
If `h == length(sc) + 1` and `h` is the identity element then `g` belons to
the group generated by `sc`.
"""
sift(g::Perm, sc::StabilizerChain) = sift(g, sc.base, sc.transversals)

@doc doc"""
    push!(sc::StabilizerChain{I}, pt::I} where I
Extend the chain by pushing point `pt` to the base of `sc`.

The corresponding `sgs` and `transversals` fields are also extended
(to match `base` in length), but are **not initialized**.
"""
function Base.push!(sc::StabilizerChain{I}, pt::I) where I
    push!(sc.base, pt)
    push!(sc.sgs, Perm{I}[])
    resize!(sc.transversals, length(sc.transversals)+1)
    return pt
end

@doc doc"""
    recompute_transversal!(sc::StabilizerChain, depth)
Recompute the Schreier tree of `sc` at depth `depth`.

This allows shallower Schreier trees after `pushing` generators to `sc`.
"""
@inline function recompute_transversal!(sc::StabilizerChain, depth)
    sc.transversals[depth] = Schreier(sc.sgs[depth], sc.base[depth])
end

@doc doc"""
    push!(sc::StabilizerChain, h, depth[, recompute=false])
Add generator `h` to `sc` at depth `depth`.

If `recompute=true`, then the Schreier tree will be recomputed (as it may become shallower).
"""
function Base.push!(sc::StabilizerChain{I, GEl}, h::GEl, depth::Int; recompute::Bool=false) where {I, GEl}
    push!(sc.sgs[depth], h)
    recompute && recompute_transversal!(sc, depth)
    return h
end

@doc doc"""
    order(sc::StabilizerChain) → BigInt
Compute the order of the group generated by `sc`.
"""
AbstractAlgebra.order(sc::StabilizerChain) = order(BigInt, sc)
AbstractAlgebra.order(::Type{T}, sc::StabilizerChain) where T =
	mapreduce(length, *, sc.transversals, init=one(T))

@doc doc"""
	transversals(sc::StabilizerChain)
Return the transversals (as a Vector) from stabilizer chain `sc`.
"""
transversals(sc::StabilizerChain) = sc.transversals

function next!(baseimages::AbstractVector{<:Integer}, transversals)
	for position in length(baseimages):-1:1
		t = transversals[position]
		if islast(t, baseimages[position])
			@debug "last point in orbit: spilling at" position collect(t), baseimages[position]
			baseimages[position] = first(t)
		else
			@debug "next point in orbit: incrementing at" position collect(t), baseimages[position]
			# TODO: replace by next(t, position)
			orbit_points = collect(t)
			idx = findfirst(isequal(baseimages[position]), orbit_points)
			baseimages[position] = orbit_points[idx + 1]
			break
		end
	end
	return baseimages
end
