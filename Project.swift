import ProjectDescription

let project = Project(
    name: "LBI",
    targets: [
        .target(
            name: "LBI",
            destinations: .iOS,
            product: .app,
            bundleId: "com.san-fo.app",
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "San Fo",
                    "NSPhotoLibraryUsageDescription": "San Fo uses your photo library so you can add photos to your business listing.",
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            buildableFolders: [
                "LBI/Sources",
                "LBI/Resources",
            ],
            entitlements: "LBI/LBI.entitlements",
            dependencies: [
                .external(name: "Kingfisher"),
            ]
        ),
        .target(
            name: "LBITests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.san-fo.app.tests",
            infoPlist: .default,
            buildableFolders: [
                "LBI/Tests"
            ],
            dependencies: [.target(name: "LBI")]
        ),
    ]
)
