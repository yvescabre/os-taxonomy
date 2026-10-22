import Foundation

public enum Operation: String, Codable, CaseIterable, Sendable {
    case add, subtract, multiply, divide

    /// Exact integer evaluation. Returns nil when the result would not be a
    /// whole number or division by zero would occur.
    public func apply(_ lhs: Int, _ rhs: Int) -> Int? {
        switch self {
        case .add: return lhs + rhs
        case .subtract: return lhs - rhs
        case .multiply: return lhs * rhs
        case .divide:
            guard rhs != 0, lhs % rhs == 0 else { return nil }
            return lhs / rhs
        }
    }

    /// The operation that "undoes" this one.
    public var inverse: Operation {
        switch self {
        case .add: return .subtract
        case .subtract: return .add
        case .multiply: return .divide
        case .divide: return .multiply
        }
    }

    /// Glyph used in UI and explanations.
    public var symbol: String {
        switch self {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        }
    }
}

public enum Operand: Codable, Hashable, Sendable {
    case known(Int)
    case unknown

    public var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }

    public var knownValue: Int? {
        if case .known(let v) = self { return v }
        return nil
    }
}

/// A two-term expression: `lhs op rhs`.
public struct Expr: Codable, Hashable, Sendable {
    public var lhs: Operand
    public var operation: Operation
    public var rhs: Operand

    public init(lhs: Operand, op: Operation, rhs: Operand) {
        self.lhs = lhs
        self.operation = op
        self.rhs = rhs
    }

    public static func known(_ lhs: Int, _ op: Operation, _ rhs: Int) -> Expr {
        Expr(lhs: .known(lhs), op: op, rhs: .known(rhs))
    }

    /// Evaluate after substituting `values` for unknowns (in left-to-right
    /// order). Nil if the expression can't be evaluated exactly.
    public func evaluate(filling values: [Int] = []) -> Int? {
        var vi = 0
        func resolve(_ o: Operand) -> Int? {
            switch o {
            case .known(let v): return v
            case .unknown:
                guard vi < values.count else { return nil }
                defer { vi += 1 }
                return values[vi]
            }
        }
        guard let l = resolve(lhs), let r = resolve(rhs) else { return nil }
        return operation.apply(l, r)
    }

    public var unknownCount: Int { (lhs.isUnknown ? 1 : 0) + (rhs.isUnknown ? 1 : 0) }

    /// Render tokens for the bridge UI.
    public var tokens: [BridgeToken] {
        [operandToken(lhs), .operation(operation), operandToken(rhs)]
    }

    private func operandToken(_ o: Operand) -> BridgeToken {
        switch o {
        case .known(let v): return .number(v)
        case .unknown: return .gap
        }
    }
}

/// `left = right` with one or more unknowns.
public struct Equation: Codable, Hashable, Sendable {
    public var left: Expr
    /// `op` is ignored when `right` is a single value, but kept so both sides
    /// share one type.
    public var right: Expr

    public init(left: Expr, right: Expr) {
        self.left = left
        self.right = right
    }

    /// Plain "expression = value" equation, e.g. `8 + ? = 11`.
    public static func result(_ lhs: Int, _ op: Operation, _ rhs: Int, equals result: Int) -> Equation {
        Equation(left: Expr(lhs: .known(lhs), op: op, rhs: .known(rhs)),
                 right: Expr(lhs: .known(result), op: .add, rhs: .known(0)))
    }

    public var tokens: [BridgeToken] {
        left.tokens + [.equals] + rightTokens
    }

    /// Right-hand tokens; a "plain" side (`x + 0`) renders as a single token.
    public var rightTokens: [BridgeToken] {
        if right.operation == .add, right.rhs == .known(0) {
            switch right.lhs {
            case .known(let v): return [.number(v)]
            case .unknown: return [.gap]
            }
        }
        var t: [BridgeToken] = []
        switch right.lhs {
        case .known(let v): t.append(.number(v))
        case .unknown: t.append(.gap)
        }
        t.append(.operation(right.operation))
        switch right.rhs {
        case .known(let v): t.append(.number(v))
        case .unknown: t.append(.gap)
        }
        return t
    }

    /// Total unknowns across both sides.
    public var unknownCount: Int { left.unknownCount + right.unknownCount }

    /// Substitute `values` for all unknowns (left side first) and check equality.
    public func check(_ values: [Int]) -> Bool? {
        let lv = left.evaluate(filling: values)
        let rv = right.evaluate(filling: Array(values.dropFirst(left.unknownCount)))
        guard let l = lv, let r = rv else { return nil }
        return l == r
    }

    /// For a single-unknown equation, solve it structurally and verify with
    /// `check`. Nil when unsolvable or not a single-unknown equation. For the
    /// + − × ÷ family the solution — when it exists — is unique by algebra,
    /// so a verified candidate is THE answer.
    public func solve() -> Int? {
        guard unknownCount == 1 else { return nil }
        let candidate: Int?
        if let k = left.evaluate(filling: []) {
            // gap on the right side: k = rightExpr(?)
            candidate = solveExpr(right, equals: k)
        } else if let k = right.evaluate(filling: []) {
            // gap on the left side: leftExpr(?) = k
            candidate = solveExpr(left, equals: k)
        } else {
            return nil
        }
        guard let c = candidate, check([c]) == true else { return nil }
        return c
    }

    /// Solve `expr(?) = target` for a single unknown, per operand position.
    private func solveExpr(_ e: Expr, equals target: Int) -> Int? {
        switch (e.lhs, e.rhs) {
        case (.unknown, .known(let b)):
            // ? op b = target
            switch e.operation {
            case .add: return target - b
            case .subtract: return target + b
            case .multiply: return b != 0 && target % b == 0 ? target / b : nil
            case .divide: return target * b
            }
        case (.known(let a), .unknown):
            // a op ? = target
            switch e.operation {
            case .add: return target - a
            case .subtract: return a - target
            case .multiply: return a != 0 && target % a == 0 ? target / a : nil
            case .divide: return target != 0 && a % target == 0 ? a / target : nil
            }
        default: return nil
        }
    }

    /// Numbers worth trying when enumerating solutions — all known values,
    /// their one-step and two-step combinations, and a small neighbourhood.
    /// Used by the solvability test-suite to prove uniqueness empirically
    /// (bounded so generation stays deterministic).
    public func candidateWindow() -> [Int] {
        let knowns = [left.lhs, left.rhs, right.lhs, right.rhs].compactMap(\.knownValue)
        var level = Set(knowns)
        var all = level
        for _ in 0..<2 {
            var next = level
            for l in all {
                for r in knowns {
                    for op in Operation.allCases {
                        if let v = op.apply(l, r), abs(v) < 10_000_000 { next.insert(v) }
                    }
                }
            }
            all.formUnion(next)
            level = next
        }
        let maxKnown = abs(knowns.max().map(abs) ?? 10)
        for v in -2...(maxKnown + 12) { all.insert(v) }
        return Array(all).sorted()
    }
}

public enum BridgeToken: Codable, Hashable, Sendable {
    case number(Int)
    case operation(Operation)
    case equals
    case gap
}

/// Equation shapes the bridge mechanic can produce.
public enum BridgeForm: String, Codable, CaseIterable, Sendable {
    /// `a + b = ?`
    case resultUnknown
    /// `? + b = c`
    case firstOperandUnknown
    /// `a + ? = c`
    case secondOperandUnknown
    /// `c = ? + b` (answer on the left — counters "answer comes after =").
    case answerLeft
    /// `a + b = ? + c` (both sides work — counters "=" as compute).
    case balance
    /// `a × b = b × ?` (commutativity).
    case commutativeSwap
}
