import Foundation

/// Watches `inbox/` for dropped JSON messages.
///
/// Two mechanisms on purpose: a kqueue vnode source for instant delivery, and
/// a slow poll as a safety net (network volumes, missed events, app asleep).
/// Consumed files move to `archive/` so a crash can't replay them.
final class Inbox {
    var onMessage: (AgentMessage) -> Void = { _ in }

    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var pollTimer: Timer?
    private var drainScheduled = false
    private let archiveLimit = 300

    func start() {
        Paths.ensureDirectories()
        drain()
        beginWatching()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.drain()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        source?.cancel()
        source = nil
    }

    // MARK: - Watching

    private func beginWatching() {
        source?.cancel()
        source = nil

        let fd = open(Paths.inbox.path, O_EVTONLY)
        guard fd >= 0 else { return }
        descriptor = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .revoke],
            queue: .main)

        src.setEventHandler { [weak self, weak src] in
            guard let self, let src else { return }
            let flags = src.data
            if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
                // Directory replaced from under us: re-establish the watch.
                Paths.ensureDirectories()
                self.beginWatching()
            }
            self.scheduleDrain()
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    /// Coalesce bursts (an agent sending 5 messages in a loop) into one pass.
    private func scheduleDrain() {
        guard !drainScheduled else { return }
        drainScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.drainScheduled = false
            self?.drain()
        }
    }

    // MARK: - Draining

    private func drain() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: Paths.inbox,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        else { return }

        let files = entries
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                if l == r { return lhs.lastPathComponent < rhs.lastPathComponent }
                return l < r
            }

        for url in files {
            defer { moveToArchive(url) }
            guard let data = try? Data(contentsOf: url), !data.isEmpty else { continue }
            guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let message = AgentMessage(json: json)
            else { continue }
            onMessage(message)
        }

        if !files.isEmpty { pruneArchive() }
    }

    private func moveToArchive(_ url: URL) {
        let fm = FileManager.default
        let stamp = String(format: "%.0f", Date().timeIntervalSince1970 * 1000)
        let dest = Paths.archive.appendingPathComponent("\(stamp)-\(url.lastPathComponent)")
        if (try? fm.moveItem(at: url, to: dest)) == nil {
            try? fm.removeItem(at: url)
        }
    }

    private func pruneArchive() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: Paths.archive,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])
        else { return }
        guard entries.count > archiveLimit else { return }

        let sorted = entries.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return l < r
        }
        for url in sorted.prefix(entries.count - archiveLimit) {
            try? fm.removeItem(at: url)
        }
    }
}
