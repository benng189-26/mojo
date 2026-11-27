// Test fixture for scripts/safety-check.sh --self-test.
// Every line below must be caught. This file is never compiled or run.
import Foundation
import Network

func planted(_ a: URL, _ b: URL) throws {
    try FileManager.default.moveItem(at: a, to: b)
    try FileManager.default.removeItem(at: a)
    try FileManager.default.trashItem(at: a, resultingItemURL: nil)
    try Data().write(to: b)
    let task = URLSession.shared.dataTask(with: a)
    _ = task
}
