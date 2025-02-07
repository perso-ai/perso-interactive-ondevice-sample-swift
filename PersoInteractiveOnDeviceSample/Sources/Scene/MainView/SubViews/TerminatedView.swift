//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import SwiftUI

struct TerminatedView: View {
    let retryAction: () -> Void

    var body: some View {
        VStack {
            Text("Terminated Session")
                .foregroundStyle(.white)
                .font(.subheadline)

            Button("Retry", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
