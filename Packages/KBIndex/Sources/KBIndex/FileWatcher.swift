import CoreServices
import Foundation

/// One changed item, relative to the vault root.
public struct WatchedPath: Sendable, Hashable {
    public let path: String
    public let isDirectory: Bool
}

/// A coalesced group of FSEvents.
public struct WatchBatch: Sendable {
    public var paths: [WatchedPath]
    /// FSEvents lost track (dropped events, ID wrap, root moved): only a full reconcile is safe.
    public var needsRescan: Bool
    /// The last event ID in the batch; persist it once the batch is applied.
    public var lastEventID: UInt64
}

/// FSEvents for one vault, as an `AsyncStream`. File-level events, hidden folders filtered out.
///
/// The FSEvents callback runs on a private serial `DispatchQueue` (the one exception CLAUDE.md
/// allows) and only yields into the stream; all real work happens in actors downstream.
public enum FileWatcher {
    /// `FSEventsGetCurrentEventId()`: take this *before* a full reconcile, then watch since it,
    /// so nothing that changes during the reconcile is missed.
    public static func currentEventID() -> UInt64 {
        FSEventsGetCurrentEventId()
    }

    /// Identifies the FSEvents database of the volume holding `root`. If it changes, stored
    /// event IDs are meaningless and a full reconcile is needed.
    public static func databaseUUID(for root: URL) -> String? {
        var info = stat()
        guard stat(root.path(percentEncoded: false), &info) == 0,
              let uuid = FSEventsCopyUUIDForDevice(info.st_dev) else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }

    /// Watches `root`. With `since`, replays events after that ID first (changes made while
    /// granite was closed). The stream ends, and FSEvents stops, when the consumer is cancelled.
    public static func events(root: URL, since: UInt64? = nil, latency: Double = 0.2) -> AsyncStream<WatchBatch> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            // FSEvents reports real paths ("/private/var/…"), but Foundation's resolvingSymlinksInPath()
            // strips a leading "/private". Match against the realpath(3) form and the Foundation form.
            let resolved = realPath(root.path(percentEncoded: false))
            let foundation = root.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
            let box = CallbackBox(prefixes: Set([resolved, foundation].map { $0.hasSuffix("/") ? $0 : $0 + "/" }),
                                  continuation: continuation)
            let handle = StreamHandle()
            var context = FSEventStreamContext(
                version: 0, info: Unmanaged.passRetained(box).toOpaque(),
                retain: nil, release: { info in
                    if let info { Unmanaged<CallbackBox>.fromOpaque(info).release() }
                }, copyDescription: nil)
            let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagNoDefer)
            guard let stream = FSEventStreamCreate(
                kCFAllocatorDefault, fileWatcherCallback, &context, [resolved] as CFArray,
                since ?? FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags
            ) else {
                continuation.yield(WatchBatch(paths: [], needsRescan: true, lastEventID: 0))
                continuation.finish()
                return
            }
            handle.start(stream)
            continuation.onTermination = { _ in handle.stop() }
        }
    }
}

/// Owns the FSEventStreamRef. Every access happens on `queue`, which is what makes the
/// unchecked Sendable conformance sound.
private final class StreamHandle: @unchecked Sendable {
    let queue = DispatchQueue(label: "granite.filewatcher")
    private var stream: FSEventStreamRef?

    func start(_ stream: FSEventStreamRef) {
        queue.sync {
            self.stream = stream
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        queue.async {
            guard let stream = self.stream else { return }
            self.stream = nil
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}

/// Passed to the C callback through `context.info`. Only used on the watcher's queue.
private final class CallbackBox: @unchecked Sendable {
    let prefixes: Set<String>
    let continuation: AsyncStream<WatchBatch>.Continuation

    init(prefixes: Set<String>, continuation: AsyncStream<WatchBatch>.Continuation) {
        self.prefixes = prefixes
        self.continuation = continuation
    }

    func relative(_ absolute: String) -> String? {
        guard let prefix = prefixes.first(where: { absolute.hasPrefix($0) }) else { return nil }
        let path = String(absolute.dropFirst(prefix.count))
        guard !path.isEmpty, !path.split(separator: "/").contains(where: { $0.hasPrefix(".") }) else { return nil }
        return path
    }
}

/// The canonical path the kernel reports, or the input if it cannot be resolved.
func realPath(_ path: String) -> String {
    guard let resolved = realpath(path, nil) else { return path }
    defer { free(resolved) }
    return String(cString: resolved)
}

private let rescanFlags = FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped
    | kFSEventStreamEventFlagKernelDropped | kFSEventStreamEventFlagEventIdsWrapped | kFSEventStreamEventFlagRootChanged)
private let directoryFlag = FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir)
private let historyDoneFlag = FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone)

private func fileWatcherCallback(
    _ stream: ConstFSEventStreamRef, _ info: UnsafeMutableRawPointer?, _ count: Int,
    _ eventPaths: UnsafeMutableRawPointer, _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIDs: UnsafePointer<FSEventStreamEventId>
) {
    guard let info else { return }
    let box = Unmanaged<CallbackBox>.fromOpaque(info).takeUnretainedValue()
    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] ?? []
    var batch = WatchBatch(paths: [], needsRescan: false, lastEventID: 0)
    var seen = Set<WatchedPath>()
    for index in 0..<count {
        let flags = eventFlags[index]
        batch.lastEventID = max(batch.lastEventID, eventIDs[index])
        if flags & rescanFlags != 0 { batch.needsRescan = true }
        if flags & historyDoneFlag != 0 { continue }
        guard index < paths.count, let relative = box.relative(paths[index]) else { continue }
        let isDirectory = flags & directoryFlag != 0
        if !isDirectory && !relative.lowercased().hasSuffix(".md") { continue }
        let item = WatchedPath(path: relative, isDirectory: isDirectory)
        if seen.insert(item).inserted { batch.paths.append(item) }
    }
    if batch.needsRescan || !batch.paths.isEmpty || batch.lastEventID > 0 {
        box.continuation.yield(batch)
    }
}
