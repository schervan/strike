/// Physics category bit masks.
nonisolated enum PhysicsCategory {
    static let none: UInt32 = 0
    static let hero: UInt32 = 1 << 0
    static let enemy: UInt32 = 1 << 1
    static let heroShot: UInt32 = 1 << 2
    static let wall: UInt32 = 1 << 3
    static let pickup: UInt32 = 1 << 4
}
