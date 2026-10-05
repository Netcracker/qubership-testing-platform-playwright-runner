# QSTP3 Overview

## Functionality

QSTP 3.0 (Qubership **Testing Platform** v.3.0) is designed to support the full functional automated testing lifecycle for modern web applications. 
It includes capabilities such as Cross-browser, Cross-platform, and Cross-language testing, as well as Mobile Web testing.

QSTP 3.0 enables the execution of various test types consisting of diverse steps, including UI interactions, SQL queries, and SSH commands. 
It supports multiple integration protocols such as HTTP (REST, SOAP), JMS (ActiveMQ, WebLogic), and Kafka.

Supported Test Types:
- E2E functional tests / UI tests
- Integration tests
- API tests / Availability tests / Backward compatibility tests
- HA (High Aviliabiity) tests

QSTP 3.0 is also used for advanced use -cases:
- Environment availability pre-checks
- Test Data generation and management
- South-bound system stubs / Golden template usage / Proxy mode
- Assisting manual testing with automated steps
- All-in-one validation on a single page

QSTP 3.0 doesn't support and can't be used for:
- Unit tests / Test before then application is up and running
- Contracts tests
- SVT (System Volume Testing)

## What is QSTP 3.0

QSTP 3.0 is an integration project of open-source tools that are industry standards. It covers the full cycle of functional and E2E testing and supports both semi-manual and automated testing approaches.

The QSTP 3.0 technology stack is primarily designed to automate the testing of cloud solutions, but it is easily extendable to other solutions. QSTP 3.0 has a distributed deployment scheme: design time on a local machine and mass launch (runtime) on a test environment with centralized storage.

The QSTP 3.0 concept suggests integrating a GenAI model with:
- An IDE for creating and updating AT scripts, validations, and stubs.
- A reports database for troubleshooting.

## QSTP 3.0 contracts for runners usage

- **Playwright** is used for E2E test automation and acts as an orchestrator when a Bruno collection needs to be called within an E2E test. Various types of steps can be involved during E2E testing, such as Excel data processing, UI navigation, REST API calls, and SSH commands.
- **Pytest** or **Robot framework** is primarily used when tests need to be executed within Kubernetes (e.g., HA tests), as Pytest can interact directly with the K8s cluster.
- **Bruno** is utilized for north-bound integration testing. Individual calls can be aggregated into collections.
- **MockServer** is used to stub south-bound system behavior. Stubs are implemented via MockServer and support various interfaces: REST, SOAP over HTTP, JMS (ActiveMQ and WebLogic), Kafka, HTTP2, and CLI.
- Detailed reports are available in native runner formats as well as **Allure** report format.