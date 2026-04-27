<p align="center">
  <img src="AppIcon.png" width="128" alt="Symply Logo">
</p>

# Symply
Symply is a lightweight macOS SwiftUI application designed to automate the migration of local folders to an external SSD by creating symbolic links. It allows you to quickly offload large folders to an external drive to save space, while preserving access via seamless symlinks.

## One-Click Deployment & Installation

You can easily get the latest version of Symply without building from source:

1. Go to the [Releases](../../releases) page of this repository.
2. Download the latest `Symply.zip` asset.
3. Extract the ZIP file.
4. Drag and drop `Symply.app` to your `Applications` folder.

> Note: If macOS prevents the app from running because it is from an unidentified developer, right-click (or Control-click) the app and select **Open**.

## Building from Source

If you prefer to build Symply from source yourself, follow these steps:

### Prerequisites
- macOS 14.0 or later
- Xcode and Swift installed (`xcode-select --install`)

### Build Steps
Clone the repository and run the provided build script:

```bash
git clone https://github.com/YOUR_USERNAME/symply.git
cd symply
./build_app.sh
```

This will automatically build the Swift package and generate a self-contained `Symply.app` bundle in the same directory. You can then launch it or move it to your Applications folder.

## GitHub Actions Automated Release

This repository is fully set up for "One-Click Deployment" using GitHub Actions. 
Whenever you push a tag that starts with `v` (e.g., `v1.0.1`), a GitHub Action workflow will automatically:
1. Build `Symply.app` using `build_app.sh`.
2. Zip the app into `Symply.zip`.
3. Create a new GitHub Release with the ZIP attached.

To create a new release, simply run:
```bash
git tag v1.0.1
git push origin v1.0.1
```
