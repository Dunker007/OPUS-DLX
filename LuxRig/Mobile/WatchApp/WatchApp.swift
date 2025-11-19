// LuxRig Apple Watch App
import SwiftUI
import WatchKit

/**
 * LuxRig Watch App for Apple Watch
 * Features:
 * - Portfolio glance
 * - Price alerts
 * - Quick trade actions
 * - Complications
 */

struct ContentView: View {
    @State private var portfolioValue: Double = 40000
    @State private var change24h: Double = 5.2

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Portfolio Header
                VStack {
                    Text("Portfolio")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("$\(portfolioValue, specifier: "%.0f")")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.green)

                    Text(String(format: "%+.1f%%", change24h))
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 5)

                Divider()

                // Top Holdings
                VStack(alignment: .leading, spacing: 8) {
                    HoldingRow(symbol: "BTC", amount: "0.5", value: "$25,000", change: 5.2)
                    HoldingRow(symbol: "ETH", amount: "5.0", value: "$10,000", change: 3.8)
                    HoldingRow(symbol: "SOL", amount: "100", value: "$5,000", change: -2.1)
                }

                Divider()

                // Quick Actions
                VStack(spacing: 8) {
                    Button(action: { /* Quick buy */ }) {
                        Label("Quick Buy", systemImage: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                    }

                    Button(action: { /* Quick sell */ }) {
                        Label("Quick Sell", systemImage: "arrow.down.circle.fill")
                            .foregroundColor(.red)
                    }

                    Button(action: { /* Alerts */ }) {
                        Label("Alerts", systemImage: "bell.fill")
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

struct HoldingRow: View {
    let symbol: String
    let amount: String
    let value: String
    let change: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(symbol)
                    .font(.headline)
                Text(amount)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(value)
                    .font(.caption)
                Text(String(format: "%+.1f%%", change))
                    .font(.caption2)
                    .foregroundColor(change > 0 ? .green : .red)
            }
        }
        .padding(.vertical, 2)
    }
}

// Complications for Watch Face
struct LuxRigComplications: View {
    var body: some View {
        VStack {
            Text("$40K")
                .font(.caption)
            Text("+5.2%")
                .font(.caption2)
                .foregroundColor(.green)
        }
    }
}

@main
struct LuxRig_Watch_App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
