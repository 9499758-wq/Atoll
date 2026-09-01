import Foundation

struct AgentStatus {
    let active: Bool
    let title: String
    let detail: String
    let symbol: String
}

struct WeatherStatus {
    let title: String
    let detail: String
    let symbol: String
}

@MainActor
final class AtollRPC {
    private let url = URL(string: "ws://127.0.0.1:9020")!
    private let bundleID = "com.local.AtollBridge"

    func call(method: String, params: [String: Any] = [:], timeout: TimeInterval = 8) -> String {
        let sem = DispatchSemaphore(value: 0)
        let task = URLSession.shared.webSocketTask(with: url)
        task.resume()
        var full = params
        full["bundleIdentifier"] = bundleID
        let payload: [String: Any] = ["jsonrpc":"2.0", "method": method, "params": full, "id": UUID().uuidString]
        let box = ManagedAtomicString("")
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            let text = String(data: data, encoding: .utf8)!
            task.send(.string(text)) { error in
                if let error {
                    box.set("SEND_ERROR: \(error.localizedDescription)")
                    sem.signal()
                    return
                }
                task.receive { result in
                    switch result {
                    case .success(.string(let s)): box.set(s)
                    case .success(.data(let d)): box.set(String(data: d, encoding: .utf8) ?? "")
                    case .success: box.set("UNKNOWN_MESSAGE")
                    case .failure(let e): box.set("RECV_ERROR: \(e.localizedDescription)")
                    }
                    sem.signal()
                }
            }
        } catch {
            box.set("JSON_ERROR: \(error.localizedDescription)")
            sem.signal()
        }
        if sem.wait(timeout: .now() + timeout) == .timedOut {
            box.set("TIMEOUT")
        }
        task.cancel(with: .normalClosure, reason: nil)
        return box.value
    }
}

final class ManagedAtomicString {
    private let lock = NSLock()
    private var _value: String
    init(_ value: String) { _value = value }
    func set(_ value: String) { lock.lock(); _value = value; lock.unlock() }
    var value: String { lock.lock(); defer { lock.unlock() }; return _value }
}

func shell(_ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: args[0])
    p.arguments = Array(args.dropFirst())
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = Pipe()
    do { try p.run(); p.waitUntilExit() } catch { return "" }
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

func agentStatus() -> AgentStatus {
    let ps = shell(["/bin/ps", "-axo", "pid,pcpu,pmem,comm"])
    let patterns = ["codex", "claude", "opencode", "gemini", "copilot", "cursor", "openclaw", "goose", "aider", "crush", "amp", "qwen", "roo"]
    var hits: [(String, Double)] = []
    for line in ps.split(separator: "\n").map(String.init) {
        let lower = line.lowercased()
        guard patterns.contains(where: { lower.contains($0) }) else { continue }
        if lower.contains("atollbridge") { continue }
        let parts = line.split(separator: " ")
        let cpu = parts.count > 1 ? Double(parts[1]) ?? 0 : 0
        hits.append((line, cpu))
    }
    if hits.isEmpty {
        return AgentStatus(active: false, title: "AI 空闲", detail: "没有检测到 Codex/Claude 任务", symbol: "sparkles")
    }
    hits.sort { $0.1 > $1.1 }
    let top = hits.prefix(3).map { $0.0.split(separator: "/").last.map(String.init) ?? $0.0 }.joined(separator: " | ")
    return AgentStatus(active: true, title: "AI 正在工作", detail: top, symbol: "terminal")
}

func weatherStatus() -> WeatherStatus {
    let sem = DispatchSemaphore(value: 0)
    var result = WeatherStatus(title: "天气", detail: "暂时无法更新", symbol: "cloud")
    let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=23.13&longitude=113.26&current=temperature_2m,weather_code,wind_speed_10m&timezone=auto")!
    URLSession.shared.dataTask(with: url) { data, _, _ in
        defer { sem.signal() }
        guard let data,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cur = obj["current"] as? [String: Any] else { return }
        let temp = cur["temperature_2m"] as? Double ?? 0
        let wind = cur["wind_speed_10m"] as? Double ?? 0
        let code = cur["weather_code"] as? Int ?? 0
        let desc = code == 0 ? "晴" : (code < 4 ? "多云" : "天气变化")
        result = WeatherStatus(title: "广州 \(Int(round(temp)))°C", detail: "\(desc) · 风速 \(Int(round(wind))) km/h", symbol: "cloud.sun")
    }.resume()
    _ = sem.wait(timeout: .now() + 8)
    return result
}

@main
struct Main {
    static func main() {
        let rpc = AtollRPC()
        print("AUTH", rpc.call(method: "atoll.requestAuthorization"))
        let agent = agentStatus()
        let weather = weatherStatus()
        let line = agent.active ? "\(agent.title) — \(agent.detail)" : "\(weather.title) — \(weather.detail)"
        print(line)
    }
}
