import Foundation

enum LayoutPattern: Int, CaseIterable, Codable {
    case diagonal = 0, cross, ring, cluster, scatter, corners, spiral, arrow
    case checker, columns, rows, wedge, lattice, halo, zigzag

    var title: String {
        switch self {
        case .diagonal: return "Diagonal"
        case .cross: return "Cross"
        case .ring: return "Ring"
        case .cluster: return "Cluster"
        case .scatter: return "Scatter"
        case .corners: return "Corners"
        case .spiral: return "Spiral"
        case .arrow: return "Arrow"
        case .checker: return "Checker"
        case .columns: return "Columns"
        case .rows: return "Rows"
        case .wedge: return "Wedge"
        case .lattice: return "Lattice"
        case .halo: return "Halo"
        case .zigzag: return "Zigzag"
        }
    }
}

/// A built-in layout: a board size plus the anchor cells objects can occupy.
struct BoardLayout: Identifiable, Codable, Hashable {
    let id: Int
    let pattern: LayoutPattern
    let size: BoardSize
    let variant: Int
    let anchors: [Coord]
    let theme: ObjectTheme

    var name: String { "\(pattern.title) \(size.label) V\(variant + 1)" }

    /// Canonical serialisation: board size + object placement. Used to prove distinctness.
    var canonicalKey: String {
        let cells = anchors.map { "\($0.row),\($0.column)" }.sorted().joined(separator: ";")
        return "\(size.dimension)#\(cells)"
    }
}

struct LayoutCatalog {

    static let variantsPerPattern = 5

    /// Minimum anchor count per board tier, sized so the hardest difficulty that
    /// maps to that board still has room for objects plus decoys.
    static func minAnchors(for size: BoardSize) -> Int {
        let profile = DifficultyProfile(level: size.tierIndex + 1)
        return min(profile.objectCount + profile.decoyCount, size.cellCount - 1)
    }

    /// Deterministically built once, deduplicated on canonical key.
    static let all: [BoardLayout] = build()

    static func layout(id: Int) -> BoardLayout {
        all[((id % all.count) + all.count) % all.count]
    }

    static func layouts(for size: BoardSize) -> [BoardLayout] {
        all.filter { $0.size == size }
    }

    private static func build() -> [BoardLayout] {
        var seen = Set<String>()
        var result: [BoardLayout] = []
        var nextID = 0
        for size in BoardSize.allCases {
            for pattern in LayoutPattern.allCases {
                for variant in 0..<variantsPerPattern {
                    let seed = SeededRandom.mix([UInt64(size.dimension),
                                                 UInt64(pattern.rawValue + 1) &* 7919,
                                                 UInt64(variant + 1) &* 104729])
                    var rng = SeededRandom(seed: seed)
                    let anchors = anchorCells(pattern: pattern, size: size, variant: variant, rng: &rng)
                    guard anchors.count >= 3 else { continue }
                    let candidate = BoardLayout(id: nextID,
                                                pattern: pattern,
                                                size: size,
                                                variant: variant,
                                                anchors: anchors,
                                                theme: ObjectTheme.allCases[(pattern.rawValue + variant) % ObjectTheme.allCases.count])
                    if seen.insert(candidate.canonicalKey).inserted {
                        result.append(candidate)
                        nextID += 1
                    }
                }
            }
        }
        return result
    }

    // MARK: - Pattern geometry

    private static func anchorCells(pattern: LayoutPattern,
                                    size: BoardSize,
                                    variant: Int,
                                    rng: inout SeededRandom) -> [Coord] {
        let dim = size.dimension
        var cells = rawCells(pattern: pattern, dim: dim, variant: variant, rng: &rng)
        cells = dedupe(cells, dim: dim)

        let target = min(minAnchors(for: size) + (variant % 4), dim * dim - 1)

        if cells.count > target {
            // Rotate the natural order by the variant so different variants keep
            // different subsets of the same shape.
            let offset = variant % max(1, cells.count)
            let rotated = Array(cells[offset...] + cells[..<offset])
            cells = Array(rotated.prefix(target))
        } else if cells.count < target {
            var present = Set(cells)
            var attempts = 0
            while cells.count < target && attempts < dim * dim * 8 {
                attempts += 1
                let c = Coord(rng.int(dim), rng.int(dim))
                if present.insert(c).inserted { cells.append(c) }
            }
        }
        return cells.sorted { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }
    }

    private static func dedupe(_ cells: [Coord], dim: Int) -> [Coord] {
        var seen = Set<Coord>()
        var out: [Coord] = []
        for c in cells where c.row >= 0 && c.row < dim && c.column >= 0 && c.column < dim {
            if seen.insert(c).inserted { out.append(c) }
        }
        return out
    }

    private static func rawCells(pattern: LayoutPattern,
                                 dim: Int,
                                 variant: Int,
                                 rng: inout SeededRandom) -> [Coord] {
        switch pattern {
        case .diagonal:
            let offset = variant % dim
            var out: [Coord] = []
            for r in 0..<dim { out.append(Coord(r, (r + offset) % dim)) }
            if variant % 2 == 1 {
                for r in 0..<dim { out.append(Coord(r, (dim - 1 - r + offset) % dim)) }
            }
            return out

        case .cross:
            let mid = (dim / 2 + variant) % dim
            var out: [Coord] = []
            for i in 0..<dim { out.append(Coord(mid, i)) }
            for i in 0..<dim { out.append(Coord(i, mid)) }
            return out

        case .ring:
            let inset = variant % max(1, dim / 2)
            let lo = inset, hi = dim - 1 - inset
            guard hi > lo else { return [Coord(lo, lo)] }
            var out: [Coord] = []
            for c in lo...hi { out.append(Coord(lo, c)) }
            for r in (lo + 1)...hi { out.append(Coord(r, hi)) }
            if hi - 1 >= lo { for c in stride(from: hi - 1, through: lo, by: -1) { out.append(Coord(hi, c)) } }
            if hi - 1 >= lo + 1 { for r in stride(from: hi - 1, through: lo + 1, by: -1) { out.append(Coord(r, lo)) } }
            return out

        case .cluster:
            let block = max(2, min(dim, 2 + variant % 3))
            let r0 = rng.int(max(1, dim - block + 1))
            let c0 = rng.int(max(1, dim - block + 1))
            var out: [Coord] = []
            for r in r0..<min(dim, r0 + block) {
                for c in c0..<min(dim, c0 + block) { out.append(Coord(r, c)) }
            }
            return out

        case .scatter:
            var out: [Coord] = []
            var present = Set<Coord>()
            let count = min(dim * dim - 1, dim * 2 + variant)
            var guardCount = 0
            while out.count < count && guardCount < dim * dim * 10 {
                guardCount += 1
                let c = Coord(rng.int(dim), rng.int(dim))
                if present.insert(c).inserted { out.append(c) }
            }
            return out

        case .corners:
            let block = max(1, min(dim / 2, 1 + variant % 3))
            var out: [Coord] = []
            for r in 0..<block {
                for c in 0..<block {
                    out.append(Coord(r, c))
                    out.append(Coord(r, dim - 1 - c))
                    out.append(Coord(dim - 1 - r, c))
                    out.append(Coord(dim - 1 - r, dim - 1 - c))
                }
            }
            return out

        case .spiral:
            var out: [Coord] = []
            var top = 0, bottom = dim - 1, left = 0, right = dim - 1
            var walk: [Coord] = []
            while top <= bottom && left <= right {
                for c in left...right { walk.append(Coord(top, c)) }
                if top + 1 <= bottom { for r in (top + 1)...bottom { walk.append(Coord(r, right)) } }
                if left <= right - 1 && top < bottom {
                    for c in stride(from: right - 1, through: left, by: -1) { walk.append(Coord(bottom, c)) }
                }
                if top + 1 <= bottom - 1 && left < right {
                    for r in stride(from: bottom - 1, through: top + 1, by: -1) { walk.append(Coord(r, left)) }
                }
                top += 1; bottom -= 1; left += 1; right -= 1
            }
            let step = 2 + variant % 2
            var i = variant % max(1, step)
            while i < walk.count { out.append(walk[i]); i += step }
            return out

        case .arrow:
            let apexRow = variant % 2 == 0 ? 0 : dim - 1
            let dir = apexRow == 0 ? 1 : -1
            let apexCol = min(dim - 1, max(0, dim / 2 + (variant % 3) - 1))
            var out: [Coord] = [Coord(apexRow, apexCol)]
            var step = 1
            while step < dim {
                let r = apexRow + dir * step
                if r < 0 || r >= dim { break }
                out.append(Coord(r, apexCol - step))
                out.append(Coord(r, apexCol + step))
                step += 1
            }
            return out

        case .checker:
            let parity = variant % 2
            var out: [Coord] = []
            for r in 0..<dim {
                for c in 0..<dim where (r + c) % 2 == parity {
                    out.append(Coord(r, c))
                }
            }
            let skip = 1 + variant % 3
            return out.enumerated().compactMap { $0.offset % skip == 0 ? $0.element : nil }

        case .columns:
            var out: [Coord] = []
            let a = variant % dim
            let b = (a + max(2, dim / 3)) % dim
            for r in 0..<dim { out.append(Coord(r, a)); out.append(Coord(r, b)) }
            return out

        case .rows:
            var out: [Coord] = []
            let a = variant % dim
            let b = (a + max(2, dim / 3)) % dim
            for c in 0..<dim { out.append(Coord(a, c)); out.append(Coord(b, c)) }
            return out

        case .wedge:
            var out: [Coord] = []
            let flip = variant % 2 == 0
            for r in 0..<dim {
                for c in 0...r where c < dim {
                    out.append(flip ? Coord(r, c) : Coord(r, dim - 1 - c))
                }
            }
            let skip = 1 + variant % 3
            return out.enumerated().compactMap { $0.offset % skip == 0 ? $0.element : nil }

        case .lattice:
            let off = variant % 2
            var out: [Coord] = []
            var r = off
            while r < dim {
                var c = off
                while c < dim { out.append(Coord(r, c)); c += 2 }
                r += 2
            }
            return out

        case .halo:
            let center = dim / 2
            let radius = 1 + variant % max(1, center + 1)
            var out: [Coord] = []
            for r in 0..<dim {
                for c in 0..<dim {
                    let d = max(abs(r - center), abs(c - center))
                    if d == radius { out.append(Coord(r, c)) }
                }
            }
            return out

        case .zigzag:
            var out: [Coord] = []
            let stride0 = 1 + variant % 2
            for r in 0..<dim {
                let forward = r % 2 == 0
                var c = forward ? 0 : dim - 1
                while c >= 0 && c < dim {
                    out.append(Coord(r, c))
                    c += forward ? (1 + stride0) : -(1 + stride0)
                }
            }
            return out
        }
    }
}
