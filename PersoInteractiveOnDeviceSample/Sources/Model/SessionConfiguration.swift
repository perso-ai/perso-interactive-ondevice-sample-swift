//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import PersoInteractiveOnDeviceSDK

struct SessionConfiguration: Hashable {
    let modelStyle: ModelStyle
    let sttType: STTType
    let llmType: LLMType
    let prompt: Prompt
    let document: Document?
    let ttsType: TTSType
    let mcpServers: [MCPServer]
}
