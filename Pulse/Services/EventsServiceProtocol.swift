import Foundation

protocol EventsServiceProtocol {
    // Events
    func fetchPublishedUpcoming(limit: Int) async throws -> [Event]
    func fetchMyEvents(limit: Int) async throws -> [Event]
    func fetchEvent(eventId: UUID) async throws -> Event
    func createEventReturning(_ insert: EventInsert) async throws -> Event
    func createEvent(_ insert: EventInsert) async throws
    func publishEvent(eventId: UUID) async throws

    // Media
    func uploadEventCover(eventId: UUID, jpegData: Data) async throws -> String
    func updateEventCoverURL(eventId: UUID, coverURL: String) async throws

    // Ticket types
    func fetchTicketTypes(eventId: UUID) async throws -> [TicketType]
    func createTicketTypes(_ inserts: [TicketTypeInsert]) async throws

    // Checkout / Orders
    func createOrder(eventId: UUID, items: [CheckoutItem]) async throws -> UUID
    func fetchMyOrdersWithEvent(limit: Int) async throws -> [OrderWithEvent]
    func fetchOrderItemsWithTicketTypes(orderId: UUID) async throws -> [OrderItemWithTicket]

    // RSVP
    func getMyRSVP(eventId: UUID) async throws -> EventRSVP?
    func upsertRSVP(eventId: UUID, status: String) async throws
    func cancelRSVP(eventId: UUID) async throws
    func fetchMyRSVPsWithEvent(limit: Int) async throws -> [RSVPWithEvent]
}
