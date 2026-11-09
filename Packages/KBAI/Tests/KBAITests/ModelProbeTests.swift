import Testing
@testable import KBAI

/// Availability depends on the machine; the test only checks that probing never crashes
/// and reports every route. It sends no prompt.
@Suite struct ModelProbeTests {
    @Test func reportsEveryRouteWithoutPrompting() async {
        let statuses = await ModelProbe.run(sendPrompt: false)
        #expect(statuses.map(\.route) == RouteStatus.Route.allCases)
        #expect(statuses.allSatisfy { $0.reply == nil && $0.latencyMs == nil })
        #expect(statuses.allSatisfy { !$0.detail.isEmpty })
    }
}
