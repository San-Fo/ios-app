import ProjectDescription

let project = Project(
    name: "LBI",
    targets: [
        .target(
            name: "LBI",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.tuist.LBI",
            infoPlist: .extendingDefault(
                with: [
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
            dependencies: []
        ),
        .target(
            name: "LBITests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.tuist.LBITests",
            infoPlist: .default,
            buildableFolders: [
                "LBI/Tests"
            ],
            dependencies: [.target(name: "LBI")]
        ),
    ]
)
