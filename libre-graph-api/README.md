# Libre Graph Api

An API for open Cloud Collaboration. See the [Libre Graph Home](https://libregraph.github.io/) for more details.

This API is inspired by [Microsoft Graph API](https://developer.microsoft.com/en-us/graph).


## Goal

The project goal is to provide an open source standard for open Cloud Collaboration.

Libre Graph is open source and open to any open source project that implements endpoints of the API.


## Influence and differences from Microsoft Graph API

Libre Graph API draws significant inspiration from the Microsoft Graph API,
particularly in its approach to providing a unified endpoint for accessing various services and data.
We believe that the model provided by Microsoft Graph API is a robust and efficient way
to facilitate integration and collaboration across different services.

However, Libre Graph API is not identical to Microsoft Graph API.
We have made specific extensions and modifications to better suit our needs and goals:

1. **Extended Functionality**: We have added specific endpoints and features unique to our implementation, designed to enhance collaboration and integration within the open source ecosystem.
2. **Custom Extensions**: Certain functionalities have been extended to provide additional features that are not present in the Microsoft Graph API.
3. **Beta Features**: Some endpoints are currently in beta, allowing us to continuously innovate and adapt to user needs before finalizing them.


## Specification

The API specification uses the OpenAPI Specification (OAS) standard.

The [OpenAPI Specification (OAS)](https://swagger.io/specification/) defines a standard, language-agnostic interface to RESTful APIs which allows both humans and computers to discover and understand the capabilities of the service without access to source code, documentation, or through network traffic inspection. When properly defined, a consumer can understand and interact with the remote service with a minimal amount of implementation logic.

An OpenAPI definition can then be used by documentation generation tools to display the API, code generation tools to generate servers and clients in various programming languages, testing tools, and many other use cases.

## Documentation

You can find a rendered version of the [API documentation](https://opencloud-eu.github.io/libre-graph-api/) in our dev docs.

## Clients

Client code can be generated from the API spec.

For example, to run the generator for the C++ bindings locally, run the following docker-based command:
```bash
docker run --rm -v "${PWD}:/local" openapitools/openapi-generator-cli generate --enable-post-process-file  -t local/templates/cpp-qt-client  -i local/api/openapi-spec/v1.0.yaml -g cpp-qt-client -o /local/out/cpp
```
That generates the output in out/cpp.


### Available client libraries
- [C++/Qt](https://github.com/opencloud-eu/libre-graph-api-cpp-qt-client)
- [go](https://github.com/opencloud-eu/libre-graph-api-go)
- [php](https://github.com/opencloud-eu/libre-graph-api-php)
- [typescript-axios](https://github.com/opencloud-eu/libre-graph-api-typescript-axios)

