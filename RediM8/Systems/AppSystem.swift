import Foundation

@MainActor
protocol AppSystem: AnyObject {
    func start()
    func stop()
}
