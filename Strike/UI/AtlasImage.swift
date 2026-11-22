import SpriteKit
import SwiftUI

/// SwiftUI image of a texture inside a SpriteKit atlas (looked up by plain name, QA-001).
struct AtlasImage: View {
    let name: String
    let atlas: String

    init(_ name: String, atlas: String = "ui") {
        self.name = name
        self.atlas = atlas
    }

    var body: some View {
        Image(uiImage: AtlasImageCache.image(name, atlas: atlas))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .accessibilityHidden(true)
    }
}

@MainActor
enum AtlasImageCache {
    private static var images: [String: UIImage] = [:]

    static func image(_ name: String, atlas: String) -> UIImage {
        let key = "\(atlas)/\(name)"
        if let i = images[key] { return i }
        let cg = SKTextureAtlas(named: atlas).textureNamed(name).cgImage()
        let image = UIImage(cgImage: cg, scale: 2, orientation: .up)
        images[key] = image
        return image
    }
}
