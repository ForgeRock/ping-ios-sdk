# Contributing to the Ping Identity iOS SDK

First off, thank you for considering contributing to the Ping Identity iOS SDK! We appreciate your time and effort.

This document outlines the guidelines for contributing to this project. Please take a moment to review it before you get started.

## Getting Started

1.  **Fork the repository** on GitHub.
2.  **Clone your fork** locally:
    ```sh
    git clone https://github.com/YOUR_USERNAME/ping-ios-sdk.git
    ```
3.  **Open the project** in Xcode. You can open `SampleApps/Ping.xcworkspace` to see the SDK modules and sample app.

## Building and Testing

Before submitting any changes, please ensure that you can build the project and that all tests pass.

To run all unit tests, you can use Xcode's test runner (Product > Test) or execute the following command from the root of the project:

```sh
xcodebuild test -workspace SampleApps/Ping.xcworkspace -scheme PingTestHost -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'
```

Ensure that all existing tests pass and that you add new tests for any new functionality you introduce.

## Standard of Practice

This project follows the internal standards of practice maintained by the Ping Identity SDK team. Please review and adhere to these guidelines before submitting any code:

- [iOS Style Guide](https://github.com/ForgeRock/sdk-standards-of-practice/blob/main/code-style/ios-styleguide.md) 
- [iOS Security Guidelines](https://github.com/ForgeRock/sdk-standards-of-practice/blob/main/security/security-guidelines-ios.md)

In general, try to match the style of the existing code in the project.

## Submitting a Pull Request

1.  Create a new branch for your feature or bug fix:
    ```sh
    git checkout -b your-feature-branch
    ```
2.  Make your changes and commit them with a clear and concise message.
3.  Ensure all tests pass.
4.  Push your branch to your fork:
    ```sh
    git push origin your-feature-branch
    ```
5.  Open a **Pull Request** to the `develop` branch of the original repository.
6.  In your Pull Request, please follow the template provided. This includes:
    *   **Linking to a JIRA ticket** if applicable.
    *   Providing a **clear description and justification** of the changes you have made.

Your pull request will be reviewed by the project maintainers. You may be asked to make changes before your PR is merged.

## License

By contributing to the Ping Identity iOS SDK, you agree that your contributions will be licensed under the [MIT License](LICENSE) that covers the project.
