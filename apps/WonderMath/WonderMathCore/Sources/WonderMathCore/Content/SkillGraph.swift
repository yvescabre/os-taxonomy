import Foundation

/// In-memory view of the prerequisite DAG.
///
/// Edge direction follows the dataset: `topicId` depends on `prerequisiteId`.
/// The graph tolerates dangling edges (a prerequisite that was filtered out of
/// the bundled subset) — they are simply ignored.
public struct SkillGraph: Sendable {

    /// edges[topicId] = its prerequisites; dependents[prerequisiteId] = topics it unlocks.
    public private(set) var edges: [String: [Dependency]] = [:]
    public private(set) var dependents: [String: [Dependency]] = [:]
    public private(set) var nodeIds: Set<String> = []

    public init() {}

    public init(dependencies: [Dependency], knownIds: Set<String>) {
        nodeIds = knownIds
        var e: [String: [Dependency]] = [:]
        var d: [String: [Dependency]] = [:]
        for dep in dependencies where dep.topicId != dep.prerequisiteId {
            // Only edges that survive fully inside the bundled subset matter
            // to the app; external prerequisites are treated as "assumed".
            guard knownIds.contains(dep.topicId), knownIds.contains(dep.prerequisiteId) else { continue }
            e[dep.topicId, default: []].append(dep)
            d[dep.prerequisiteId, default: []].append(dep)
        }
        edges = e
        dependents = d
    }

    /// All prerequisites of a topic within the bundled subset.
    public func prerequisites(of id: String) -> [Dependency] { edges[id] ?? [] }

    public func prerequisites(of id: String, strength: EdgeStrength) -> [Dependency] {
        prerequisites(of: id).filter { $0.strength == strength }
    }

    /// All hard prerequisites within the bundled subset.
    public func hardPrerequisites(of id: String) -> [Dependency] {
        prerequisites(of: id, strength: .hard)
    }

    /// Topics unlocked by mastering `id` (i.e. topics listing it as a hard
    /// prerequisite within the subset).
    public func unlocks(_ id: String, strength: EdgeStrength? = nil) -> [Dependency] {
        let all = dependents[id] ?? []
        guard let strength else { return all }
        return all.filter { $0.strength == strength }
    }

    /// Topological ordering of `ids` using only edges inside the subset —
    /// prerequisites always come before their dependents. Ties are broken
    /// deterministically (age range, then topic name) so the order is stable
    /// across runs.
    public func topologicalOrder<T: Sequence>(of ids: T, topics: (String) -> Topic?) -> [String]
        where T.Element == String {
        let scope = Set(ids)
        var indegree: [String: Int] = [:]
        var outgoing: [String: [String]] = [:]
        for id in scope {
            indegree[id] = 0
            outgoing[id] = []
        }
        for id in scope {
            for dep in edges[id] ?? [] where scope.contains(dep.prerequisiteId) {
                indegree[id] = (indegree[id] ?? 0) + 1
                outgoing[dep.prerequisiteId, default: []].append(id)
            }
        }
        func key(_ id: String) -> (Int, Int, String, String) {
            let t = topics(id)
            return (t?.ageRangeStart ?? 99, t?.ageRangeEnd ?? 99, t?.name ?? id, id)
        }
        var frontier = scope.filter { (indegree[$0] ?? 0) == 0 }.sorted { key($0) < key($1) }
        var order: [String] = []
        while let next = frontier.first {
            frontier.removeFirst()
            order.append(next)
            for child in outgoing[next] ?? [] {
                indegree[child] = (indegree[child] ?? 1) - 1
                if indegree[child] == 0 {
                    let pos = frontier.firstIndex { key($0) > key(child) } ?? frontier.endIndex
                    frontier.insert(child, at: pos)
                }
            }
        }
        // Any leftover ids sit in a cycle; append them deterministically so
        // callers never crash on malformed data.
        if order.count < scope.count {
            let remaining = scope.subtracting(order).sorted { key($0) < key($1) }
            order.append(contentsOf: remaining)
        }
        return order
    }

    /// True if the subgraph induced by `ids` is acyclic.
    public func isAcyclic<S: Sequence>(_ ids: S) -> Bool where S.Element == String {
        let scope = Set(ids)
        var indegree: [String: Int] = [:]
        for id in scope { indegree[id] = 0 }
        for id in scope {
            for dep in edges[id] ?? [] where scope.contains(dep.prerequisiteId) {
                indegree[id] = (indegree[id] ?? 0) + 1
            }
        }
        var queue = Array(scope.filter { (indegree[$0] ?? 0) == 0 })
        var visited = 0
        while let n = queue.first {
            queue.removeFirst()
            visited += 1
            for dep in dependents[n] ?? [] where scope.contains(dep.topicId) {
                indegree[dep.topicId] = (indegree[dep.topicId] ?? 1) - 1
                if indegree[dep.topicId] == 0 { queue.append(dep.topicId) }
            }
        }
        return visited == scope.count
    }
}
