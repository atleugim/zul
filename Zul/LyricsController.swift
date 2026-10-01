import Foundation
import Observation

@Observable
final class LyricsController {
  // Nil while there's no track, the lookup is in flight, or it failed.
  private(set) var lyrics: Lyrics?
  // Corrects badly timed LRC files; positive shows lyrics sooner, like LRC's [offset:].
  private(set) var trackOffset: TimeInterval = 0
  @ObservationIgnored private var query: LyricsQuery?
  @ObservationIgnored private var task: Task<Void, Never>?
  @ObservationIgnored private let fetch: (NowPlaying) async throws -> LyricsRecord?
  @ObservationIgnored private let cache: LyricsCache
  @ObservationIgnored private let retryDelay: Duration
  // Shared by every track: LRCLIB's rate limit is per client, not per song.
  @ObservationIgnored private var rateLimitedUntil = Date.distantPast

  // The service shares this cache because it also holds the per-track offsets.
  init(
    fetch: ((NowPlaying) async throws -> LyricsRecord?)? = nil,
    cache: LyricsCache = LyricsCache(),
    retryDelay: Duration = .seconds(5)
  ) {
    self.fetch = fetch ?? LyricsService(cache: cache).lyrics(for:)
    self.cache = cache
    self.retryDelay = retryDelay
  }

  // Only tracks with a cache entry keep an offset; without lyrics there's nothing to shift.
  func setTrackOffset(_ offset: TimeInterval) {
    guard let query, var entry = cache.entry(for: query) else { return }
    entry.offset = offset
    cache.store(entry, for: query)
    trackOffset = offset
  }

  // Returns the fetch task so tests can await it.
  @discardableResult
  func update(for track: NowPlaying?) -> Task<Void, Never>? {
    let query = track.map { LyricsQuery(track: $0) }
    // The adapter also emits on play/pause and seeks; only a different track needs new lyrics.
    guard query != self.query else { return nil }
    self.query = query
    task?.cancel()
    lyrics = nil
    trackOffset = query.flatMap { cache.entry(for: $0)?.offset } ?? 0
    guard let track else { return nil }

    task = Task {
      // Nil on error, unlike a successful lookup that found nothing (.notFound).
      var lyrics: Lyrics?
      // LRCLIB answers 503 under load, so a failure gets a couple of spaced-out retries.
      for attempt in 0..<3 where lyrics == nil {
        if attempt > 0 { try? await Task.sleep(for: retryDelay * attempt) }
        let rateLimitWait = rateLimitedUntil.timeIntervalSinceNow
        if rateLimitWait > 0 { try? await Task.sleep(for: .seconds(rateLimitWait)) }
        guard !Task.isCancelled else { return }
        do {
          lyrics = try await Lyrics(record: fetch(track))
        } catch LRCLIBError.rateLimited(let retryAfter) {
          rateLimitedUntil = .now.addingTimeInterval(retryAfter)
        } catch {}
      }
      // Everything here runs on the main actor, so a cancelled task means a newer track
      // took over; its late response must not overwrite that track's lyrics.
      guard !Task.isCancelled else { return }
      self.lyrics = lyrics
      // Forgetting the failed track lets the adapter's next event for it (play, seek) try again.
      if lyrics == nil { self.query = nil }
    }
    return task
  }
}
