// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

public func objectPropertyStream<T: NSObject, V: Sendable>(
  for source: T,
  on keyPath: KeyPath<T, V>,
  _ block: @escaping (V) async -> Void
) async {
  let (stream, continuation) = AsyncStream<V>.makeStream()
  let observerToken = source.observe(keyPath, options: [.initial, .new]) { _, change in
    if let value = change.newValue {
      continuation.yield(value)
    }
  }

  let silenceWarning: (NSKeyValueObservation) -> Void = { _ in }
  silenceWarning(observerToken)

  for await value in stream {
    await block(value)
  }
}
