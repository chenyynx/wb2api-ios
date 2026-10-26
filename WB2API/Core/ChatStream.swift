import Foundation

/// 流式聊天的一帧：正文增量 + 末尾 usage 里的 completion tokens。
struct ChatStreamChunk: Equatable, Sendable {
    let text: String?
    let completionTokens: Int?
}

/// 解析后的一条 SSE 事件。
enum ChatStreamEvent: Equatable, Sendable {
    case chunk(ChatStreamChunk)
    case done
    case failure(String)
}

/// OpenAI 兼容 SSE 的纯解析器：网络层只负责读行，格式判断都在这里，方便单测。
enum ChatStreamParser {
    static func parse(line: String) -> ChatStreamEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }

        let payload = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { return .done }
        guard !payload.isEmpty,
              let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let error = object["error"] as? [String: Any] {
            return .failure((error["message"] as? String) ?? "上游返回错误")
        }

        var text: String?
        if let choices = object["choices"] as? [[String: Any]],
           let delta = choices.first?["delta"] as? [String: Any] {
            if let content = delta["content"] as? String, !content.isEmpty {
                text = content
            } else if let reasoning = (delta["reasoning_content"] as? String) ?? (delta["reasoning"] as? String),
                      !reasoning.isEmpty {
                // 推理模型的可见正文可能是空的，思考 token 同样算输出速度。
                text = reasoning
            }
        }

        var completionTokens: Int?
        if let usage = object["usage"] as? [String: Any] {
            completionTokens = usage["completion_tokens"] as? Int
            if completionTokens == nil, let number = usage["completion_tokens"] as? NSNumber {
                completionTokens = number.intValue
            }
        }

        guard text != nil || completionTokens != nil else { return nil }
        return .chunk(ChatStreamChunk(text: text, completionTokens: completionTokens))
    }
}

/// 输出速度计算：只算首字之后到流结束的时间，不含 prefill/TTFB。
enum SpeedMath {
    static func tokensPerSecond(tokens: Int, from firstTokenAt: Date, to endAt: Date) -> Double? {
        let seconds = endAt.timeIntervalSince(firstTokenAt)
        guard tokens > 0, seconds > 0.001 else { return nil }
        return Double(tokens) / seconds
    }
}
