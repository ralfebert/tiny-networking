import Foundation
import os
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public extension Endpoint {

    @discardableResult
    /// Loads an endpoint by creating (and directly resuming) a data task.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint.
    ///   - onComplete: The completion handler.
    /// - Returns: The data task.
    func load(onComplete: @escaping (Result<A, Error>) -> Void) -> URLSessionDataTask {
        os_log(">>> %s", log: EndpointLogging.log, type: .debug, self.description)

        let task = self.urlSession.dataTask(with: self.request, completionHandler: { data, response, error in

            if let error = error {
                os_log("Error for %s: %s", log: EndpointLogging.log, type: .error, self.description, String(describing: error))
                onComplete(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                onComplete(.failure(EndpointError(description: "Response was not a HTTPURLResponse")))
                return
            }

            do {
                os_log("Got response: %i bytes", log: EndpointLogging.log, type: .debug, data?.count ?? 0)
                try self.validate(data, httpResponse)
                if let result = try self.parse(data, httpResponse) {
                    onComplete(.success(result))
                } else {
                    onComplete(.failure(NoDataError()))
                }
            } catch let e {
                onComplete(.failure(e))
                return
            }

        })
        task.resume()
        return task
    }
}

#if canImport(Combine)
    import Combine

    @available(iOS 13, macOS 10.15, watchOS 6, tvOS 13, *)
    public extension Endpoint {
        /// Returns a publisher that wraps a URL session data task for a given Endpoint.
        ///
        /// - Parameters:
        ///   - endpoint: The endpoint.
        /// - Returns: The publisher of a dataTask.
        func load() -> AnyPublisher<A, Error> {
            os_log(">>> %s", log: EndpointLogging.log, type: .debug, self.description)
            return self.urlSession.dataTaskPublisher(for: self.request)
                .mapError { (error) -> Error in
                    os_log("Error for %s: %s", log: EndpointLogging.log, type: .error, self.description, String(describing: error))
                    return error
                }
                .tryMap { data, response in
                    try self.handleResponse(data: data, response: response)
                }
                .eraseToAnyPublisher()
        }

        func handleResponse(data: Data, response: URLResponse) throws -> A {
            os_log("Got response: %i bytes", log: EndpointLogging.log, type: .debug, data.count)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EndpointError(description: "Response was not a HTTPURLResponse")
            }

            try self.validate(data, httpResponse)
            if let result = try self.parse(data, httpResponse) {
                return result
            } else {
                throw NoDataError()
            }
        }
    }
#endif
