import Foundation
import Supabase

extension EventsService {
    func uploadEventCover(eventId: UUID, jpegData: Data) async throws -> String {
        let bucket = supabase.storage.from("event-covers")
        let path = "\(eventId.uuidString).jpg"

        try await bucket.upload(
            path,
            data: jpegData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )

        let url = try bucket.getPublicURL(path: path)
        return url.absoluteString
    }

    func updateEventCoverURL(eventId: UUID, coverURL: String) async throws {
        try await supabase
            .from("events")
            .update(["cover_url": coverURL])
            .eq("id", value: eventId)
            .execute()
    }
}
